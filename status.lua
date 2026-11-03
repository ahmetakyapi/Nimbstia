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
local LAUNCHER = Config.launcher
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

-- Menu bar glyph: the Nimbstia mark (one tall pane + two stacked panes), drawn at 2x and
-- marked as a template so macOS tints it for light/dark menu bars.
local function glyph()
  local k = 2
  local c = hs.canvas.new({ x = 0, y = 0, w = 18 * k, h = 18 * k })
  local black = { white = 0, alpha = 1 }
  c[1] = { type = "rectangle", action = "fill", fillColor = black, roundedRectRadii = { xRadius = 1.8 * k, yRadius = 1.8 * k },
    frame = { x = 1.5 * k, y = 3 * k, w = 6.6 * k, h = 12 * k } }
  c[2] = { type = "rectangle", action = "stroke", strokeColor = black, strokeWidth = 1.3 * k, roundedRectRadii = { xRadius = 1.6 * k, yRadius = 1.6 * k },
    frame = { x = 10.1 * k, y = 3.65 * k, w = 6.3 * k, h = 4.7 * k } }
  c[3] = { type = "rectangle", action = "stroke", strokeColor = black, strokeWidth = 1.3 * k, roundedRectRadii = { xRadius = 1.6 * k, yRadius = 1.6 * k },
    frame = { x = 10.1 * k, y = 9.65 * k, w = 6.3 * k, h = 4.7 * k } }
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
  if DEV then
    local h = health()
    out = out .. text("●", { font = { name = FONT, size = 8 }, baselineOffset = 1.5,
      color = h == "ok" and GREEN or h == "warn" and AMBER or h == "down" and RED or GREY })
    -- Words only when something needs attention; a healthy state is just the green dot.
    if h == "down" then out = out .. text(" VPN Kapalı")
    elseif h == "warn" then out = out .. text(" " .. DEV_NAME .. " Yanıt Vermiyor") end
  end
  if micMuted() then out = out .. text("  ● Mikrofon Kapalı", { color = RED }) end
  -- Claude usage appears only when it needs attention (≥ 80 % of a limit).
  local peak = Claude.peak()
  if peak and peak >= 80 then out = out .. text("  Claude %" .. math.floor(peak + 0.5), { color = peak >= 90 and RED or AMBER }) end
  local m = nextMeeting()
  if m then
    local mins = math.floor((m.start - os.time()) / 60)
    local title = utf8.len(m.title) > 22 and (m.title:sub(1, utf8.offset(m.title, 22) - 1) .. "…") or m.title
    out = out .. text("  " .. (mins <= 0 and "Şimdi · " or (mins .. " dk · ")) .. title, { color = mins <= 1 and AMBER or nil })
  end
  if hs.caffeinate.get("displayIdle") then out = out .. text("  ☕︎", { font = { name = FONT, size = 12 } }) end
  bar:setTitle(#out:getString() > 0 and out or nil)
  bar:setTooltip("Nimbstia")
  if M.pushPopover then M.pushPopover() end -- an open popover follows every state change
end

-- ---------------------------------------------------------------- VPN / DEV checks (async)

local checking = false
local checkStarted = 0
function M.check(manual)
  if not DEV then return end
  -- A check that never reported back (task failed to start or hung) must not freeze the dot.
  if checking and os.time() - checkStarted < 15 then return end
  checking, checkStarted = true, os.time()
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
local POP_W = 400 -- 380 px card + 10 px transparent inset on each side for the shadow
local pop

local function ago(t)
  local s = os.time() - t
  if s < 10 then return "az önce" end
  if s < 60 then return s .. " sn önce" end
  if s < 3600 then return math.floor(s / 60) .. " dk önce" end
  if s < 86400 then return math.floor(s / 3600) .. " sa önce" end
  return math.floor(s / 86400) .. " gün önce"
end

local function launcherOk() return LAUNCHER and LAUNCHER.path and hs.fs.attributes(LAUNCHER.path) ~= nil end

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
  { id = "clip",   name = "Pastia",   what = "Pano Geçmişi",      keys = "⌃V",     ok = function() return Clip end,    run = function() Clip.toggle() end },
  { id = "shot",   name = "Clipstia", what = "Ekran Görüntüsü",   keys = "⌘.",     ok = function() return Shot end,    run = function() Shot.start() end, delay = 0.3 },
  { id = "layout", name = "Panestia", what = "Pencere Düzenleri", keys = "⌃Space", ok = function() return Layouts end, run = function() Layouts.toggle() end },
  { id = "repo",   name = "Repostia", what = "Projeler",          keys = "⌃⌥P",    ok = function() return Projects end, run = function() Projects.toggle() end },
  { id = "text",   name = "Inkstia",  what = "Ekrandan Metin",    keys = "⌃⌥O",    ok = function() return Tools and Tools.ocr end, run = function() Tools.ocr() end, delay = 0.3 },
}

local function popoverData()
  local d = { errors = LOAD_ERRORS or {}, theme = Panel.theme(), shortcuts = M.help or {},
    toggles = { awake = hs.caffeinate.get("displayIdle") or false, mic = micMuted(), meetings = meetingsEnabled() } }
  if DEV then
    local h = health()
    d.health = h
    d.dev = { name = DEV_NAME, host = DEV_HOST,
      status = h == nil and "Kontrol Ediliyor…" or h == "ok" and ("Bağlı · " .. state.devMs .. " ms")
        or h == "warn" and "Yanıt Vermiyor" or "VPN Kapalı",
      checkedAgo = state.checkedAt > 0 and ago(state.checkedAt) or "" }
    d.forti = hs.application.pathForBundleID("com.fortinet.FortiClient") ~= nil
  end
  if launcherOk() then d.launcher = { title = LAUNCHER.title or "Başlatıcıyı Çalıştır" } end
  local u = Claude.usage()
  local peak
  if u then
    local limits = {}
    for _, l in ipairs(u.limits) do
      local pct = math.floor(l.percent + 0.5)
      if not peak or pct > peak then peak = pct end
      table.insert(limits, { label = l.label, percent = pct, resets = l.resetsAt and Claude.when(l.resetsAt) or "" })
    end
    local sessions = {}
    for _, ss in ipairs(Claude.sessions()) do table.insert(sessions, { name = ss.name, busy = ss.busy, url = ss.url }) end
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
  d.status = overall(peak)
  return d
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
  return { x = x, y = sf.y + 2, w = w, h = math.min(h, sf.h - 4) }
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
  elseif a == "forti" then
    after(function() hs.application.launchOrFocusByBundleID("com.fortinet.FortiClient") end)
  elseif a == "launcher" and launcherOk() then
    after(function() Keep.task("/usr/bin/open", nil, { LAUNCHER.path }) end)
  elseif a == "toggle" then
    if msg.id == "awake" then M.toggleAwake()
    elseif msg.id == "mic" then M.toggleMic()
    elseif msg.id == "meetings" then toggleMeetings() end
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
    onShow = function(p) p:js("Pulse.set(" .. hs.json.encode(popoverData()) .. ");Pulse.open()") end,
  })
  M.popover = pop
  bar:setClickCallback(function() pop:toggle() end)
  render()
  M.check(false)
  M.timer = hs.timer.doEvery(CHECK_EVERY, function() M.check(false) end)
  M.meetTimer = hs.timer.doEvery(MEET_EVERY, M.fetchMeetings)
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
function M.iconFrame() return bar and bar:frame() end
M.state = state
return M
