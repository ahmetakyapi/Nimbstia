-- One menu bar item for the day: VPN + DEV reachability, keep-awake, microphone mute,
-- upcoming meetings (opt-in, macOS Calendar) and the list of every shortcut.
local Keep = require("keep")
local M = {}

local HOME = os.getenv("HOME")
local Config = require("config")
local DEV = Config.devCheck -- nil = no VPN/DEV indicator
local DEV_HOST, DEV_PORT = DEV and DEV.host, DEV and tostring(DEV.port or 22)
local DEV_NAME = DEV and (DEV.name or "DEV") or nil
local CHECK_EVERY = 30
local MEET_EVERY = 60
local MEET_KEY = "status.meetings"
local Claude = require("claude")

local state = { vpn = nil, dev = nil, devMs = nil, iface = nil, checkedAt = 0, meetings = {}, meetErr = nil }
local bar

-- ---------------------------------------------------------------- title

local GREEN, RED, AMBER, GREY = { hex = "#30d158" }, { hex = "#ff453a" }, { hex = "#ff9f0a" }, { white = .55 }
local FONT = ".AppleSystemUIFont"

local function nextMeeting()
  local now = os.time()
  for _, m in ipairs(state.meetings) do
    if m.start > now - 300 and m.start - now < 15 * 60 then return m end
  end
end

local function micMuted()
  local d = hs.audiodevice.defaultInputDevice()
  return d and (d:inputMuted() or (d:inputVolume() or 1) == 0) or false
end

-- Menu bar glyph: the Nimbstia N (two rounded bars + a diagonal), drawn at 2x and marked as a
-- template so macOS tints it for light/dark menu bars.
local function glyph()
  local k = 2
  local c = hs.canvas.new({ x = 0, y = 0, w = 18 * k, h = 18 * k })
  local ink = { white = 0, alpha = 1 }
  -- Same geometry as assets/logo-mono.svg, on whole points so the uprights are crisp: panes 3 pt wide
  -- (x 3-6 and 12-15, y 3-15, radius 1), link 2.5 pt at 45 degrees between the centres of the pane ends.
  c[1] = { type = "segments", action = "stroke", strokeColor = ink, strokeWidth = 2.5 * k, strokeCapStyle = "round",
    coordinates = { { x = 4.5 * k, y = 4.5 * k }, { x = 13.5 * k, y = 13.5 * k } } }
  c[2] = { type = "rectangle", action = "fill", fillColor = ink, roundedRectRadii = { xRadius = 1 * k, yRadius = 1 * k },
    frame = { x = 3 * k, y = 3 * k, w = 3 * k, h = 12 * k } }
  c[3] = { type = "rectangle", action = "fill", fillColor = ink, roundedRectRadii = { xRadius = 1 * k, yRadius = 1 * k },
    frame = { x = 12 * k, y = 3 * k, w = 3 * k, h = 12 * k } }
  local img = c:imageFromCanvas()
  c:delete()
  return img:setSize({ w = 18, h = 18 }):template(true)
end

local function text(str, attrs)
  attrs = attrs or {}
  attrs.font = attrs.font or { name = FONT, size = 12.5 }
  return hs.styledtext.new(str, attrs)
end

-- Health of the configured host: "ok", "warn" (VPN up, host down), "down" (no VPN) or nil (not checked yet).
local function health()
  if state.vpn == nil then return nil end
  if state.vpn and state.dev then return "ok" end
  return state.vpn and "warn" or "down"
end

local function render()
  if not bar then return end
  local out = text("")
  local tip = "Nimbstia"
  if DEV then
    local h = health()
    -- Only a coloured dot next to the N (green · amber · red); the words live in the tooltip and the hub.
    out = out .. text("●", { font = { name = FONT, size = 8 }, baselineOffset = 1.5,
      color = h == "ok" and GREEN or h == "warn" and AMBER or h == "down" and RED or GREY })
    if h == "down" then tip = tip .. " · VPN Kapalı"
    elseif h == "warn" then tip = tip .. " · " .. DEV_NAME .. " Yanıt Vermiyor"
    elseif h == "ok" then tip = tip .. " · VPN Bağlı" end
  end
  if micMuted() then out = out .. text("  ● Mikrofon Kapalı", { color = RED }) end
  -- Claude usage lives in the hub only; the menu bar stays quiet about it.
  local m = nextMeeting()
  if m then
    local mins = math.floor((m.start - os.time()) / 60)
    local title = utf8.len(m.title) > 22 and (m.title:sub(1, utf8.offset(m.title, 22) - 1) .. "…") or m.title
    out = out .. text("  " .. (mins <= 0 and "Şimdi · " or (mins .. " dk · ")) .. title, { color = mins <= 1 and AMBER or nil })
  end
  if hs.caffeinate.get("displayIdle") then out = out .. text("  ☕︎", { font = { name = FONT, size = 12 } }) end
  bar:setTitle(#out:getString() > 0 and out or nil)
  bar:setTooltip(tip)
  if M.pushPopover then M.pushPopover() end -- an open popover follows every state change
end

-- ---------------------------------------------------------------- VPN / DEV checks (async)

local checking = false
-- The VPN service as macOS knows it (FortiClient and most VPN apps register a NetworkExtension
-- service). config devCheck.vpnService names it explicitly; otherwise the first VPN service wins.
local vpnName
local function vpnService()
  if DEV and DEV.vpnService then return DEV.vpnService end
  if vpnName ~= nil then return vpnName or nil end
  local out = hs.execute("/usr/sbin/scutil --nc list") or ""
  vpnName = false
  for line in out:gmatch("[^\n]+") do
    local name = line:match('VPN %([^)]*%)%s+"([^"]+)"')
    if name then vpnName = name; break end
  end
  return vpnName or nil
end

-- "scutil --nc status" → status word ("Connected", "Disconnected", "Connecting", …) and, while
-- connected, the epoch second the tunnel came up (LastStatusChangeTime, local "MM/DD/YYYY HH:MM:SS").
local function parseNcStatus(out)
  out = out or ""
  local status = out:match("^%s*(%a+)")
  local since
  local mo, dd, yy, hh, mi, ss = out:match("LastStatusChangeTime%s*:%s*(%d+)/(%d+)/(%d+)%s+(%d+):(%d+):(%d+)")
  if status == "Connected" and mo then
    since = os.time({ year = tonumber(yy), month = tonumber(mo), day = tonumber(dd),
      hour = tonumber(hh), min = tonumber(mi), sec = tonumber(ss) })
  end
  return status, since
end

local function ncStatus(svc, cb)
  return Keep.task("/usr/sbin/scutil", function(_, out) cb(parseNcStatus(out)) end, { "--nc", "status", svc })
end

local function applyNc(status, since)
  if status == "Connected" then state.vpnSince = since or state.vpnSince or os.time()
  elseif status == "Disconnected" or status == "Invalid" then state.vpnSince = nil end
  state.ncStatus = status
end

-- FortiClient's tunnel only starts when FortiTray opens the session (it holds the saved login);
-- "scutil --nc start" alone brings the extension up and it exits at once. So for a FortiClient
-- service, press "Connect to <profile>" in FortiTray's menu bar menu through Accessibility.
local function fortiConnect(done)
  local tray
  for _, a in ipairs(hs.application.runningApplications()) do
    if (a:bundleID() or ""):match("^com%.fortinet%..*[Tt]ray") or a:name() == "FortiTray" then tray = a; break end
  end
  if not tray then return done(false) end
  local ok, item = pcall(function()
    return hs.axuielement.applicationElementForPID(tray:pid()):attributeValue("AXExtrasMenuBar"):attributeValue("AXChildren")[1]
  end)
  if not ok or not item then return done(false) end
  item:performAction("AXPress")
  local tries = 0
  local function pick()
    tries = tries + 1
    local menu = (item:attributeValue("AXChildren") or {})[1]
    if not menu then
      if tries < 10 then return Keep.after(0.1, pick) end
      return done(false)
    end
    for _, m in ipairs(menu:attributeValue("AXChildren") or {}) do
      if (m:attributeValue("AXTitle") or ""):match("^Connect to ") and m:attributeValue("AXEnabled") then
        m:performAction("AXPress")
        return done(true)
      end
    end
    menu:performAction("AXCancel")
    done(false)
  end
  Keep.after(0.15, pick)
end

local function isForti(svc)
  local out = hs.execute("/usr/sbin/scutil --nc list") or ""
  for line in out:gmatch("[^\n]+") do
    if line:find('"' .. svc .. '"', 1, true) then return line:find("fortinet", 1, true) ~= nil end
  end
  return false
end

-- Poll the service until it reaches the wanted state (or gives up), then refresh the card at once
-- instead of waiting for the next periodic check.
local settleTimer
local function settle(svc, connect)
  local deadline = os.time() + (connect and 25 or 8)
  local function finish(reached)
    state.vpnBusy = nil
    if not reached then hs.alert.show(connect and "VPN bağlanamadı" or "VPN bağlantısı kesilemedi", 2) end
    state.vpn = state.ncStatus == "Connected"
    render()
    checking = false -- the next check must run now, not be skipped by an older one
    M.check(false)
  end
  local function poll()
    ncStatus(svc, function(status, since)
      applyNc(status, since)
      if (connect and status == "Connected") or (not connect and status == "Disconnected") then return finish(true) end
      if os.time() >= deadline then return finish(false) end
      settleTimer = Keep.after(0.5, poll)
    end)
  end
  poll()
end

-- Connect or disconnect, then follow the service until it settles.
function M.vpn(connect)
  local svc = vpnService()
  if not svc then hs.alert.show("VPN hizmeti bulunamadı", 1.5); return end
  if state.vpnBusy then return end
  state.vpnBusy = connect and "Bağlanıyor…" or "Bağlantı Kesiliyor…"
  if M.pushPopover then M.pushPopover() end
  local function viaScutil()
    Keep.task("/usr/sbin/scutil", function() settle(svc, connect) end, { "--nc", connect and "start" or "stop", svc })
  end
  if connect and isForti(svc) then
    -- FortiTray's menu takes focus and the hub closes on focus loss; bring it back to show progress.
    local wasOpen = M.popover and M.popover.visible
    fortiConnect(function(pressed)
      if wasOpen then Keep.after(0.3, function() if not M.popover.visible then M.popover:show() end end) end
      if pressed then return settle(svc, true) end
      -- FortiTray not reachable: hand over to the FortiClient window.
      state.vpnBusy = nil
      render()
      hs.application.launchOrFocusByBundleID("com.fortinet.FortiClient")
      hs.alert.show("FortiClient açıldı · bağlantıyı oradan başlatın", 2)
    end)
  else
    viaScutil()
  end
end

local checkStarted = 0
function M.check(manual)
  if not DEV then return end
  -- A check that never reported back (task failed to start or hung) must not freeze the dot.
  if checking and os.time() - checkStarted < 15 then return end
  checking, checkStarted = true, os.time()
  local svc = vpnService()
  if svc then ncStatus(svc, applyNc) end -- keeps the connected-since time for the hub
  local t0 = hs.timer.secondsSinceEpoch()
  local started = Keep.task("/sbin/route", function(_, out)
    local iface = (out or ""):match("interface:%s*(%S+)")
    local vpn = iface ~= nil and (iface:match("^utun") or iface:match("^ppp")) ~= nil
    local t1 = hs.timer.secondsSinceEpoch()
    local nc = Keep.task("/usr/bin/nc", function(code)
      checking = false
      local dev = code == 0
      local prevVpn, prevDev = state.vpn, state.dev
      state.vpn, state.dev, state.iface = vpn, dev, iface
      state.devMs = dev and math.floor((hs.timer.secondsSinceEpoch() - t1) * 1000) or nil
      state.checkedAt = os.time()
      if prevVpn ~= nil and prevVpn ~= vpn then
        hs.alert.show(vpn and "VPN bağlandı" or "⚠︎ VPN bağlantısı koptu", vpn and 1 or 3)
      elseif prevDev ~= nil and prevDev ~= dev and vpn then
        hs.alert.show(dev and (DEV_NAME .. " sunucusuna erişim geri geldi") or ("⚠︎ " .. DEV_NAME .. " sunucusuna erişilemiyor"), 2)
      elseif manual then
        hs.alert.show((vpn and "VPN bağlı" or "VPN kapalı") .. " · " .. DEV_NAME .. (dev and " erişilebilir" or " erişilemiyor"), 1.2)
      end
      render()
    end, { "-z", "-G", "2", DEV_HOST, DEV_PORT })
    if not nc then checking = false end
  end, { "-n", "get", DEV_HOST })
  if not started then checking = false end
  return t0
end

-- ---------------------------------------------------------------- keep awake / mic

function M.toggleAwake()
  local on = not hs.caffeinate.get("displayIdle")
  hs.caffeinate.set("displayIdle", on, true)
  hs.alert.show(on and "☕︎ Mac uyanık tutuluyor" or "Uyku normale döndü", 0.9)
  render()
end

-- Work-safe screen saver (saver.lua): the Mac keeps working behind it; any key or a real mouse move wakes it.
local Saver = require("saver")

local savedVolume
function M.toggleMic()
  local d = hs.audiodevice.defaultInputDevice()
  if not d then hs.alert.show("Mikrofon bulunamadı", 1); return end
  local mute = not micMuted()
  if not d:setInputMuted(mute) then
    -- Some devices have no mute switch: fall back to input volume.
    if mute then savedVolume = d:inputVolume(); d:setInputVolume(0) else d:setInputVolume(savedVolume or 75) end
  end
  hs.alert.closeAll()
  hs.alert.show(mute and "🎙̸  Mikrofon KAPALI" or "🎙  Mikrofon açık", { textSize = 22, radius = 14 }, mute and 1.5 or 0.9)
  render()
end

-- ---------------------------------------------------------------- meetings (macOS Calendar via EventKit)

local alerted = {}
local meetTask
local function meetingsEnabled() return hs.settings.get(MEET_KEY) == true end

local function notifyMeeting(m)
  local n = hs.notify.new(function() if m.url ~= "" then hs.urlevent.openURL(m.url) end end, {
    title = "Toplantı başlıyor: " .. m.title,
    informativeText = os.date("%H:%M", m.start) .. (m.location ~= "" and (" · " .. m.location) or ""),
    hasActionButton = m.url ~= "", actionButtonTitle = "Katıl", withdrawAfter = 0, soundName = "Glass",
  })
  n:send()
  hs.alert.show("📅  " .. m.title .. "  ·  " .. os.date("%H:%M", m.start), { textSize = 22, radius = 14 }, 5)
end

function M.fetchMeetings()
  if not meetingsEnabled() or (meetTask and meetTask:isRunning()) then return end
  meetTask = Keep.task("/usr/bin/osascript", function(code, out)
    local ok, data = pcall(hs.json.decode, out or "")
    if code ~= 0 or not ok or type(data) ~= "table" then state.meetErr = "okunamadı"; render(); return end
    if data.error then state.meetErr = "izin yok"; state.meetings = {}; render(); return end
    table.sort(data, function(a, b) return a.start < b.start end)
    state.meetings, state.meetErr = data, nil
    local now = os.time()
    for _, m in ipairs(data) do
      local key = m.id .. "@" .. m.start
      if not alerted[key] and m.start - now <= 70 and m.start - now > -120 then
        alerted[key] = true
        notifyMeeting(m)
      end
    end
    render()
  end, { "-l", "JavaScript", HOME .. "/.hammerspoon/bin/events.js" })
end

local function toggleMeetings()
  local on = not meetingsEnabled()
  hs.settings.set(MEET_KEY, on)
  if on then
    hs.alert.show("Toplantı uyarısı açıldı · macOS takvim izni isteyebilir", 2)
    M.fetchMeetings()
  else
    state.meetings = {}; render()
  end
end

-- ---------------------------------------------------------------- popover (pulstia.html)

local Panel = require("panel")
local POP_W = 500 -- 480 px card + 10 px transparent inset on each side for the shadow
local pop

local function ago(t)
  local s = os.time() - t
  if s < 10 then return "az önce" end
  if s < 60 then return s .. " sn önce" end
  if s < 3600 then return math.floor(s / 60) .. " dk önce" end
  if s < 86400 then return math.floor(s / 3600) .. " sa önce" end
  return math.floor(s / 86400) .. " gün önce"
end

-- The single most important thing to say about the day, for the popover header.
local function overall(claudePeak)
  local errs = LOAD_ERRORS or {}
  if #errs > 0 then return { text = #errs .. " Modül Yüklenemedi", tone = "bad" } end
  local h = DEV and health()
  if h == "down" then return { text = "VPN Kapalı", tone = "bad" } end
  if h == "warn" then return { text = DEV_NAME .. " Yanıt Vermiyor", tone = "warn" } end
  if claudePeak and claudePeak >= 80 then
    return { text = "Claude %" .. math.floor(claudePeak + 0.5), tone = claudePeak >= 90 and "bad" or "warn" }
  end
  if micMuted() then return { text = "Mikrofon Kapalı", tone = "warn" } end
  return { text = "Her Şey Yolunda", tone = "ok" }
end

local TOOLS = {
  { id = "clip",   name = "Pastia",   what = "Pano",      keys = "⌃V",     ok = function() return Clip end,    run = function() Clip.toggle() end },
  { id = "shot",   name = "Clipstia", what = "Ekran Görüntüsü", keys = "⌘.",     ok = function() return Shot end,    run = function() Shot.start() end, delay = 0.3 },
  { id = "layout", name = "Panestia", what = "Düzen", keys = "⌃Space", ok = function() return Layouts end, run = function() Layouts.toggle() end },
  { id = "repo",   name = "Repostia", what = "Projeler",          keys = "⌃⇧P",    ok = function() return Projects end, run = function() Projects.toggle() end },
  { id = "text",   name = "Lexstia",  what = "Metin Oku",    keys = "⌃⇧O",    ok = function() return Tools and Tools.ocr end, run = function() Tools.ocr() end, delay = 0.3 },
}

-- ---------------------------------------------------------------- system strip (CPU, memory, battery, disk)

-- ps reports %cpu per core (a busy app can show 190 %); everything shown is divided by the core count
-- so it reads as a share of the whole processor (0-100).
local CORES = (function() local ok, t = pcall(hs.host.cpuUsageTicks); return ok and t and tonumber(t.n) or 1 end)()

-- Memory in use the way Activity Monitor counts it (app + wired + compressed), in MB, and as a share.
-- The gauge and the detail view both read this, so they always show the same number.
local function memUsage()
  local ok, v = pcall(hs.host.vmStat)
  if not ok or not v or not v.memSize or v.memSize <= 0 or not v.pageSize then return nil end
  local used = ((v.pagesActive or 0) + (v.pagesWiredDown or 0) + (v.pagesUsedByVMCompressor or 0)) * v.pageSize
  return { usedMB = math.floor(used / 1048576 + 0.5), totalMB = math.floor(v.memSize / 1048576 + 0.5),
    pct = math.floor(used / v.memSize * 100 + 0.5) }
end

-- Overall CPU load since the previous sample (at least 0.5 s apart). The very first call only records
-- a sample and returns nil.
local cpuPrev
local function cpuLoad()
  local ok, t = pcall(hs.host.cpuUsageTicks)
  if not ok or not t or not t.overall then return cpuPrev and cpuPrev.pct end
  local o, now = t.overall, hs.timer.secondsSinceEpoch()
  local prev = cpuPrev
  if prev and now - prev.at < 0.5 then return prev.pct end
  local pct = prev and prev.pct
  if prev then
    local da, di = o.active - prev.active, o.idle - prev.idle
    if da + di > 0 then pct = math.floor(da / (da + di) * 100 + 0.5) end
  end
  cpuPrev = { at = now, active = o.active, idle = o.idle, pct = pct }
  return pct
end

-- Top memory users, grouped by app (Chrome/Electron helpers count towards their app). Async.
local function appName(cmd)
  local n = cmd:gsub("%s+Helper.*$", ""):gsub("%s+%(.*%)$", ""):gsub("%s+WebView$", "")
  return n
end
function M.fetchProcs()
  Keep.task("/bin/ps", function(code, out)
    if code ~= 0 or not pop or not pop.visible then return end
    local groups, total = {}, 0
    for line in (out or ""):gmatch("[^\n]+") do
      -- %cpu uses the locale's decimal mark ("23,6" on Turkish systems)
      local rss, cpu, cmd = line:match("^%s*(%d+)%s+([%d%.,]+)%s+(.+)$")
      if cpu then cpu = cpu:gsub(",", ".") end
      if rss then
        local name = appName(cmd)
        local g = groups[name] or { name = name, mb = 0, cpu = 0 }
        g.mb = g.mb + tonumber(rss) / 1024
        g.cpu = g.cpu + (tonumber(cpu) or 0)
        groups[name] = g
        total = total + tonumber(rss) / 1024
      end
    end
    local list = {}
    for _, g in pairs(groups) do table.insert(list, g) end
    local function topBy(key)
      table.sort(list, function(a, b) return a[key] > b[key] end)
      local out = {}
      for i = 1, math.min(10, #list) do
        local g = list[i]
        -- cpu as a share of the whole processor, one decimal below 10 %
        local c = g.cpu / CORES
        table.insert(out, { name = g.name, mb = math.floor(g.mb + 0.5), cpu = c >= 10 and math.floor(c + 0.5) or math.floor(c * 10 + 0.5) / 10 })
      end
      return out
    end
    local top, byCpu = topBy("mb"), topBy("cpu")
    local mem = memUsage()
    -- usedMB / memPct / cpuLoad are the same measurements the gauges show (the page syncs them back)
    -- The gauge shows the last CPU sample; reuse it while it is recent so both read the same number.
    local load = cpuPrev and cpuPrev.pct and hs.timer.secondsSinceEpoch() - cpuPrev.at < 10 and cpuPrev.pct or cpuLoad()
    pop:js("Pulse.setProcs(" .. hs.json.encode({ list = top, byCpu = byCpu, cores = CORES, cpuLoad = load,
      usedMB = mem and mem.usedMB, memPct = mem and mem.pct, memMB = mem and mem.totalMB }) .. ")")
  end, { "-axco", "rss=,%cpu=,comm=" })
end

local function systemData()
  local sys = { cpu = cpuLoad(), cores = CORES }
  pcall(function()
    local pct = hs.battery.percentage()
    if pct then sys.battery = { pct = math.floor(pct + 0.5), charging = hs.battery.isCharging() == true or hs.battery.powerSource() == "AC Power" } end
  end)
  local mem = memUsage()
  if mem then sys.mem = mem.pct end
  pcall(function()
    local root = hs.fs.volume.allVolumes()["/"]
    local free = root and (root.NSURLVolumeAvailableCapacityForImportantUsageKey or root.NSURLVolumeAvailableCapacityKey)
    local total = root and root.NSURLVolumeTotalCapacityKey
    if free then sys.disk = math.floor(free / 1e9 + 0.5) end
    if free and total and total > 0 then sys.diskUsed = math.floor((1 - free / total) * 100 + 0.5) end
  end)
  return sys
end

local githubData -- defined with the GitHub numbers below; popoverData only runs after start-up
local function popoverData()
  local d = { errors = LOAD_ERRORS or {}, theme = Panel.theme(), shortcuts = M.help or {},
    toggles = { awake = hs.caffeinate.get("displayIdle") or false, mic = micMuted(), meetings = meetingsEnabled(),
      saver = Saver.active } }
  d.portsFolded = hs.settings.get("nimbstia.portsFolded") == true
  if state.ports and #state.ports > 0 then
    d.ports = {}
    for _, x in ipairs(state.ports) do table.insert(d.ports, { port = x.port, cmd = x.cmd, folder = x.folder }) end
  end
  if DEV then
    local h = health()
    d.health = h
    d.dev = { name = DEV_NAME, title = DEV.title or "VPN Bağlantısı", host = DEV_HOST,
      status = state.vpnBusy or h == nil and "Kontrol Ediliyor…" or h == "ok" and ("Bağlı · " .. state.devMs .. " ms")
        or h == "warn" and "Yanıt Vermiyor" or "VPN Kapalı",
      checkedAgo = state.checkedAt > 0 and ago(state.checkedAt) or "", ms = state.devMs,
      state = state.vpnBusy and "busy" or h }
    d.forti = hs.application.pathForBundleID("com.fortinet.FortiClient") ~= nil
    if vpnService() then d.vpn = { connected = state.vpn == true, busy = state.vpnBusy, since = state.vpn and state.vpnSince or nil } end
  end
  local u = Claude.usage()
  local peak
  if u then
    local limits = {}
    for _, l in ipairs(u.limits) do
      local pct = math.floor(l.percent + 0.5)
      if not peak or pct > peak then peak = pct end
      local item = { label = l.label, percent = pct, resets = l.resetsAt and Claude.when(l.resetsAt) or "" }
      if l.weekly then
        Claude.record(l.percent, u.fetchedAt)
        local t = Claude.today(l.percent)
        if t then item.today = math.floor(t + 0.5) end
      end
      table.insert(limits, item)
    end
    local sessions = {}
    for _, ss in ipairs(Claude.sessions()) do
      table.insert(sessions, { name = ss.name, busy = ss.busy, url = ss.url,
        folder = ss.cwd and ss.cwd:match("[^/]+$") or nil, ago = ss.updated and ago(ss.updated) or nil })
    end
    d.claude = { plan = u.plan, updatedAgo = u.fetchedAt and ago(u.fetchedAt) or nil, limits = limits, sessions = sessions }
  end
  d.tools = {}
  for _, t in ipairs(TOOLS) do
    if t.ok() then table.insert(d.tools, { id = t.id, name = t.name, what = t.what, keys = t.keys }) end
  end
  if d.toggles.meetings then
    d.meetErr = state.meetErr and ("Takvim izni yok · Sistem Ayarları › Gizlilik › Takvimler") or nil
    d.meetings = {}
    for _, m in ipairs(state.meetings) do
      if #d.meetings < 3 and m["end"] > os.time() then
        table.insert(d.meetings, { time = os.date("%H:%M", m.start), title = m.title, url = m.url })
      end
    end
  end
  d.system = systemData()
  d.status = overall(peak)
  return d
end

-- ---------------------------------------------------------------- dev servers (listening TCP ports)

-- Local dev servers (npm run dev, Vite, Django, Rails, Ollama…) that are listening right now, with the
-- project folder they run in. AI coding agents start these and leave them behind; the hub shows them
-- with open / stop. Only the user's own processes are visible to lsof, so nothing here needs sudo.
local DEV_CMDS = { "node", "bun", "deno", "python", "Python", "ruby", "rails", "puma", "php", "java", "go", "air",
  "uvicorn", "gunicorn", "hugo", "jekyll", "nginx", "httpd", "caddy", "postgres", "mysqld", "redis", "mongod",
  "ollama", "dotnet", "beam.smp", "elixir", "next-server", "vite", "esbuild", "wrangler", "docker", "com.docker" }
local NOT_DEV = { ControlCenter = true, rapportd = true, sharingd = true, Spotify = true, Dropbox = true,
  ["Code Helper"] = true, ["Code Helper (Plugin)"] = true, Figma = true, ["figma_agent"] = true, Raycast = true,
  ["Google Chrome"] = true, ["Google Chrome Helper"] = true, Hammerspoon = true, ["Adobe Desktop Service"] = true }
local function isDev(cmd, port)
  if NOT_DEV[cmd] then return false end
  for _, c in ipairs(DEV_CMDS) do
    if cmd == c or cmd:sub(1, #c) == c then return true end
  end
  -- unknown binary on a classic dev port (go/rust servers, custom tools)
  return (port >= 3000 and port < 3100) or (port >= 4000 and port < 4400) or (port >= 5170 and port < 5180)
    or (port >= 8000 and port < 8100) or port == 8888 or port == 9000
end

function M.fetchPorts()
  Keep.task("/usr/sbin/lsof", function(code, out)
    if code ~= 0 and (out or "") == "" then state.ports = {}; if M.pushPopover then M.pushPopover() end; return end
    local found, seen, pid, cmd = {}, {}, nil, nil
    for line in (out or ""):gmatch("[^\n]+") do
      local k, v = line:sub(1, 1), line:sub(2)
      if k == "p" then pid = tonumber(v)
      elseif k == "c" then cmd = v
      elseif k == "n" and pid and cmd then
        local port = tonumber(v:match(":(%d+)$"))
        if port and port >= 1024 and not seen[port] and isDev(cmd, port) then
          seen[port] = true
          table.insert(found, { port = port, pid = pid, cmd = cmd })
        end
      end
    end
    table.sort(found, function(a, b) return a.port < b.port end)
    while #found > 6 do table.remove(found) end
    if #found == 0 then state.ports = {}; if M.pushPopover then M.pushPopover() end; return end
    -- second pass: the working directory of each server = the project it belongs to
    local pids = {}
    for _, x in ipairs(found) do table.insert(pids, tostring(x.pid)) end
    Keep.task("/usr/sbin/lsof", function(_, cwdOut)
      local cwd, cur = {}, nil
      for line in (cwdOut or ""):gmatch("[^\n]+") do
        local k, v = line:sub(1, 1), line:sub(2)
        if k == "p" then cur = tonumber(v) elseif k == "n" and cur then cwd[cur] = v end
      end
      for _, x in ipairs(found) do
        local dir = cwd[x.pid]
        x.folder = dir and dir ~= "/" and dir ~= HOME and dir:match("[^/]+$") or nil
      end
      state.ports = found
      if M.pushPopover then M.pushPopover() end
    end, { "-a", "-d", "cwd", "-p", table.concat(pids, ","), "-Fpn" })
  end, { "+c", "0", "-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn" })
end

-- ---------------------------------------------------------------- GitHub / git numbers (bin/dev-stats.py)

local devStats, devStatsBusy = nil, false
function M.fetchDevStats(force)
  if devStatsBusy then return end
  if not force and devStats and os.time() - (devStats.at or 0) < 90 then return end
  devStatsBusy = true
  -- low CPU priority (nice): never compete with what the user is doing
  Keep.task("/usr/bin/nice", function(code, out)
    devStatsBusy = false
    local ok, data = pcall(hs.json.decode, out or "")
    if code == 0 and ok and type(data) == "table" then
      devStats = data
      if M.pushPopover then M.pushPopover() end
      -- Repostia shows these numbers; refresh it if it is open.
      if Projects and Projects.panel and Projects.panel.visible and githubData then
        Projects.panel:js("Projects.setGitHub(" .. hs.json.encode(githubData() or {}) .. ")")
      end
    end
  end, (function()
    local args = { "-n", "10", "/usr/bin/python3", HOME .. "/.hammerspoon/bin/dev-stats.py" }
    -- config.githubOrg limits every number and PR list to one GitHub organisation
    if type(Config.githubOrg) == "string" and Config.githubOrg ~= "" then table.insert(args, "--org"); table.insert(args, Config.githubOrg) end
    return args
  end)())
end

function githubData()
  if not devStats then return nil end
  local g, h = devStats.git or {}, devStats.gh
  local function top(list)
    local out = {}
    for i, p in ipairs(list or {}) do
      if i > 8 then break end
      table.insert(out, { title = p.title, url = p.url, repo = p.repo, owner = p.owner, number = p.number, draft = p.draft, author = p.author, created = p.created })
    end
    return out
  end
  return {
    commits = g.commits or 0, added = g.added or 0, deleted = g.deleted or 0,
    prsToday = h and h.openedToday or nil, opened = h and top(h.opened) or nil,
    commitList = (function()
      local out = {}
      for i, c in ipairs(g.list or {}) do
        if i > 12 then break end
        table.insert(out, { sha = c.sha, subject = c.subject, t = c.t, added = c.added, deleted = c.deleted, repo = c.repo, owner = c.owner, url = c.url })
      end
      return out
    end)(),
    open = h and top(h.open) or nil, openCount = h and #(h.open or {}) or nil,
    review = h and top(h.review) or nil, reviewCount = h and #(h.review or {}) or nil,
    -- Repostia's Bugün / Bu Hafta / Bu Ay switch
    periods = (function()
      local out = {}
      for key, pd in pairs(type(g.periods) == "table" and g.periods or {}) do
        local list = {}
        for i, c in ipairs(pd.list or {}) do
          if i > 12 then break end
          table.insert(list, { sha = c.sha, subject = c.subject, t = c.t, added = c.added, deleted = c.deleted, repo = c.repo, owner = c.owner, url = c.url })
        end
        local prs = h and h.openedPeriods and h.openedPeriods[key]
        out[key] = { commits = pd.commits or 0, added = pd.added or 0, deleted = pd.deleted or 0, repos = pd.repos or 0,
          commitList = list, prs = prs and #prs or nil, opened = prs and top(prs) or nil }
      end
      return next(out) and out or nil
    end)(),
    days = type(g.days) == "table" and g.days or nil,
    org = devStats.org,
    updatedAgo = devStats.at and ago(devStats.at) or nil,
    ghMissing = h == nil,
  }
end

local function pushPopover()
  if pop and pop.visible then pop:js("Pulse.set(" .. hs.json.encode(popoverData()) .. ")") end
end
M.pushPopover = pushPopover

-- Right under the menu bar icon, kept inside the screen.
local function popPosition(_, w, h)
  local f = bar and bar:frame()
  local screen = hs.screen.mainScreen()
  if f then
    for _, sc in ipairs(hs.screen.allScreens()) do
      local sf = sc:fullFrame()
      if f.x >= sf.x and f.x < sf.x + sf.w then screen = sc end
    end
  end
  local sf = screen:frame()
  local x = f and (f.x + f.w / 2 - w / 2) or (sf.x + sf.w - w - 8)
  x = math.max(sf.x + 4, math.min(x, sf.x + sf.w - w - 4))
  -- a little below the menu bar, like Control Center, not glued to it
  return { x = x, y = sf.y + 8, w = w, h = math.min(h, sf.h - 12) }
end

local function onPopMessage(p, msg)
  local a = msg.action
  local function after(fn, sec) p:hide(false); Keep.after(sec or 0.12, fn) end
  if a == "size" and tonumber(msg.h) then
    p:resize(math.floor(tonumber(msg.h)))
  elseif a == "tool" then
    for _, t in ipairs(TOOLS) do
      if t.id == msg.id and t.ok() then after(t.run, t.delay) end
    end
  elseif a == "check" then
    M.check(true)
  elseif a == "procs" then
    M.fetchProcs()
  elseif a == "sys" then
    local targets = {
      battery = function() hs.urlevent.openURL("x-apple.systempreferences:com.apple.Battery-Settings.extension") end,
      disk = function() hs.urlevent.openURL("x-apple.systempreferences:com.apple.settings.Storage") end,
      activity = function() hs.application.launchOrFocusByBundleID("com.apple.ActivityMonitor") end,
    }
    if targets[msg.id] then after(targets[msg.id]) end
  elseif a == "vpn" then
    M.vpn(msg.v == "connect")
  elseif a == "forti" then
    after(function() hs.application.launchOrFocusByBundleID("com.fortinet.FortiClient") end)
  elseif a == "fold" then
    hs.settings.set("nimbstia.portsFolded", msg.v == true)
  elseif a == "port" and tonumber(msg.port) then
    local port = tonumber(msg.port)
    local hit
    for _, x in ipairs(state.ports or {}) do if x.port == port then hit = x end end
    if hit and msg.v == "open" then
      after(function() hs.urlevent.openURL("http://localhost:" .. port) end)
    elseif hit and msg.v == "stop" then
      -- only a pid we listed ourselves, never one the page made up
      Keep.task("/bin/kill", function() Keep.after(0.8, function() M.fetchPorts() end) end, { "-TERM", tostring(hit.pid) })
      hs.alert.show("Durduruldu: " .. hit.cmd .. " · :" .. port, 1)
    end
  elseif a == "toggle" then
    if msg.id == "awake" then M.toggleAwake()
    elseif msg.id == "mic" then M.toggleMic()
    elseif msg.id == "meetings" then toggleMeetings()
    elseif msg.id == "saver" then
      after(Saver.start, 0.3)
      return
    end
    pushPopover()
  elseif a == "theme" and (msg.v == "auto" or msg.v == "light" or msg.v == "dark") then
    Panel.setTheme(msg.v)
    p:js(Panel.themeJS())
    pushPopover()
  elseif a == "url" and type(msg.url) == "string" and msg.url:match("^https://") then
    after(function() hs.urlevent.openURL(msg.url) end)
  elseif a == "console" then
    after(function() hs.openConsole() end)
  elseif a == "reload" then
    after(hs.reload, 0.1)
  end
end

function M.togglePopover() if pop then pop:toggle() end end

-- ---------------------------------------------------------------- start

function M.start(help)
  M.help = help
  bar = hs.menubar.new(true, "nimbstia.status")
  bar:setIcon(glyph(), true)
  pop = Panel.new({
    name = "pulse", html = HOME .. "/.hammerspoon/pulstia.html", w = POP_W, h = 560,
    position = popPosition, onMessage = onPopMessage,
    onShow = function(p)
      cpuLoad() -- start a CPU sample; the push a second later shows the load over that second
      Keep.after(1.2, function() if pop and pop.visible then pushPopover() end end)
      p:js("Pulse.set(" .. hs.json.encode(popoverData()) .. ");Pulse.open()")
      M.fetchDevStats(false)
      M.fetchPorts()
    end,
  })
  M.popover = pop
  Panel.onThemeChange = function() pushPopover() end
  bar:setClickCallback(function() pop:toggle() end)
  render()
  M.check(false)
  M.timer = hs.timer.doEvery(CHECK_EVERY, function() M.check(false) end)
  M.meetTimer = hs.timer.doEvery(MEET_EVERY, M.fetchMeetings)
  -- git log over ~100 repos is the heaviest thing here: refresh on demand (popover / Repostia open)
  -- and only every 15 minutes in the background.
  M.statsTimer = hs.timer.doEvery(900, function() M.fetchDevStats(true) end)
  -- Follow Claude usage right away instead of waiting for the next tick: older Claude Code rewrites
  -- ~/.claude.json, newer ones go through statusline.sh → ~/.claude/cache/rate-limits.json.
  local function claudeChanged()
    if M.claudeTimer then M.claudeTimer:stop() end
    M.claudeTimer = hs.timer.doAfter(0.5, function() render() end)
  end
  M.claudeWatch = hs.pathwatcher.new(HOME .. "/.claude.json", claudeChanged):start()
  -- statusline.sh replaces the file with mv, so watch the directory and filter by name.
  M.rateLimitWatch = hs.pathwatcher.new(HOME .. "/.claude/cache", function(paths)
    for _, p in ipairs(paths) do
      if p:match("/rate%-limits%.json$") then return claudeChanged() end
    end
  end):start()
  M.fetchDevStats(true)
  M.fetchMeetings()
  M.tick = hs.timer.doEvery(20, render) -- meeting countdown in the title
  -- Re-check right away after wake or a network change instead of waiting for the next tick.
  M.wake = hs.caffeinate.watcher.new(function(ev)
    if ev == hs.caffeinate.watcher.systemDidWake then Keep.after(4, function() M.check(false) end) end
  end):start()
  M.net = hs.network.configuration.open()
  M.net:setCallback(function() Keep.after(2, function() M.check(false) end) end)
  M.net:monitorKeys({ "State:/Network/Global/IPv4" })
  M.net:start()
  M.audio = hs.audiodevice.watcher
  M.audio.setCallback(function() render() end)
  M.audio.start()
end

M.render = render
M._popoverData = popoverData -- exposed for tests
function M.githubData() return githubData and githubData() or nil end
function M.iconFrame() return bar and bar:frame() end
M.state = state
return M
