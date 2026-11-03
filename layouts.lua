-- Window layout picker (⌃Space): multi-app layouts with adjustable split, plus quick
-- placement actions for the window that was focused when the picker opened.
local Panel = require("panel")
local M = {}

local RATIO_KEY = "layout.ratios"
local LAST_KEY = "layout.last"
local RATIO_MIN, RATIO_MAX, RATIO_STEP = 0.2, 0.8, 0.05

local APPS = {
  code     = { bid = "com.microsoft.VSCode",            name = "VS Code",  color = "#2f80ed" },
  chrome   = { bid = "com.google.Chrome",               name = "Chrome",   color = "#f2b100" },
  claude   = { bid = "com.anthropic.claudefordesktop",  name = "Claude",   color = "#d97757" },
  teams    = { bid = "com.microsoft.teams2",            name = "Teams",    color = "#6264a7" },
  outlook  = { bid = "com.microsoft.Outlook",           name = "Outlook",  color = "#0f6cbd" },
  whatsapp = { bid = "net.whatsapp.WhatsApp",           name = "WhatsApp", color = "#25d366" },
  terminal = { bid = "com.apple.Terminal",              name = "Terminal", color = "#7c7c88" },
  spotify  = { bid = "com.spotify.client",              name = "Spotify",  color = "#1db954" },
}

-- Rect builders; r is the adjustable split (width of the first column).
local function cols(a, b)
  return function(r) return { { a, { 0, 0, r, 1 } }, { b, { r, 0, 1 - r, 1 } } } end
end
local function mainStack(a, b, c)
  return function(r) return { { a, { 0, 0, r, 1 } }, { b, { r, 0, 1 - r, 0.5 } }, { c, { r, 0.5, 1 - r, 0.5 } } } end
end
local function three(a, b, c, share)
  return function(r)
    local w2 = (1 - r) * share
    return { { a, { 0, 0, r, 1 } }, { b, { r, 0, w2, 1 } }, { c, { r + w2, 0, 1 - r - w2, 1 } } }
  end
end
local function single(a, rect) return function() return { { a, rect } } end end

local LAYOUTS = {
  -- "pair" uses the two most recently focused windows, whatever apps they are.
  { id = "pair",     group = "İki Uygulama", name = "Son İki Pencere Yan Yana", ratio = 0.50, pair = true,
    build = function(r) return { { "win1", { 0, 0, r, 1 } }, { "win2", { r, 0, 1 - r, 1 } } } end },
  { id = "browser",  group = "İki Uygulama", name = "Tarayıcı Ağırlıklı", ratio = 0.35, build = cols("code", "chrome") },
  { id = "code",     group = "İki Uygulama", name = "Kod Ağırlıklı",      ratio = 0.60, build = cols("code", "chrome") },
  { id = "half",     group = "İki Uygulama", name = "Yarı Yarıya",        ratio = 0.50, build = cols("code", "chrome") },
  { id = "claude",   group = "İki Uygulama", name = "Claude Yanında",     ratio = 0.65, build = cols("code", "claude") },
  { id = "terminal", group = "İki Uygulama", name = "Terminal Yanında",   ratio = 0.60, build = cols("code", "terminal") },
  { id = "meeting",  group = "İki Uygulama", name = "Toplantı",           ratio = 0.60, build = cols("teams", "chrome") },
  { id = "teams",    group = "İki Uygulama", name = "Teams Yanında",      ratio = 0.35, build = cols("code", "teams") },
  { id = "dev",      group = "Üç Uygulama",  name = "Geliştirme",          ratio = 0.50, build = mainStack("code", "chrome", "terminal") },
  { id = "ai",       group = "Üç Uygulama",  name = "Kod · Tarayıcı · Claude", ratio = 0.42, build = three("code", "chrome", "claude", 0.55) },
  { id = "comms",    group = "Üç Uygulama",  name = "İletişim",            ratio = 0.50, build = mainStack("outlook", "teams", "whatsapp") },
  { id = "focusCode",   group = "Odak", name = "Odak: VS Code", hideOthers = true, build = single("code", { 0.08, 0.04, 0.84, 0.92 }) },
  { id = "focusChrome", group = "Odak", name = "Odak: Chrome",  hideOthers = true, build = single("chrome", { 0.08, 0.04, 0.84, 0.92 }) },
  { id = "focusTeams",  group = "Odak", name = "Odak: Teams",   hideOthers = true, build = single("teams", { 0, 0, 1, 1 }) },
}

local ACTIONS = {
  { id = "left",    name = "Sol Yarı",      rect = { 0, 0, 0.5, 1 } },
  { id = "right",   name = "Sağ Yarı",      rect = { 0.5, 0, 0.5, 1 } },
  { id = "top",     name = "Üst Yarı",      rect = { 0, 0, 1, 0.5 } },
  { id = "bottom",  name = "Alt Yarı",      rect = { 0, 0.5, 1, 0.5 } },
  { id = "max",     name = "Tam Ekran",     rect = { 0, 0, 1, 1 } },
  { id = "center",  name = "Ortala",        rect = { 0.15, 0.08, 0.7, 0.84 } },
  { id = "l3",      name = "Sol Üçte Bir",  rect = { 0, 0, 1 / 3, 1 } },
  { id = "c3",      name = "Orta Üçte Bir", rect = { 1 / 3, 0, 1 / 3, 1 } },
  { id = "r3",      name = "Sağ Üçte Bir",  rect = { 2 / 3, 0, 1 / 3, 1 } },
  { id = "l23",     name = "Sol Üçte İki",  rect = { 0, 0, 2 / 3, 1 } },
  { id = "r23",     name = "Sağ Üçte İki",  rect = { 1 / 3, 0, 2 / 3, 1 } },
  { id = "tl",      name = "Sol Üst",       rect = { 0, 0, 0.5, 0.5 } },
  { id = "tr",      name = "Sağ Üst",       rect = { 0.5, 0, 0.5, 0.5 } },
  { id = "bl",      name = "Sol Alt",       rect = { 0, 0.5, 0.5, 0.5 } },
  { id = "br",      name = "Sağ Alt",       rect = { 0.5, 0.5, 0.5, 0.5 } },
  { id = "screen",  name = "Diğer Ekrana",  rect = { 0, 0, 1, 1 }, nextScreen = true },
}

-- ---------------------------------------------------------------- helpers

local ratios = hs.settings.get(RATIO_KEY) or {}
local lastId = hs.settings.get(LAST_KEY)

-- Undo: frames of the windows moved by the last placement (⌃⌥Z or the panel's ⌘Z).
local undoStack = {}
function M.remember(wins)
  local snap = {}
  for _, w in ipairs(wins) do
    if w and w:id() then table.insert(snap, { win = w, frame = w:frame() }) end
  end
  if #snap > 0 then
    table.insert(undoStack, snap)
    if #undoStack > 20 then table.remove(undoStack, 1) end
  end
end
function M.undo()
  local snap = table.remove(undoStack)
  if not snap then hs.alert.show("Geri alınacak yerleşim yok", 0.8); return end
  for _, s in ipairs(snap) do
    if s.win:application() then s.win:setFrame(s.frame) end
  end
  hs.alert.show("Yerleşim geri alındı", 0.7)
end

-- The two most recently focused standard windows (front to back), on any app.
local function recentPair(first)
  local a = first and first:isStandard() and first or nil
  local b
  for _, w in ipairs(hs.window.orderedWindows()) do
    if w:isStandard() and w:isVisible() and w:application() and
       (w:application():bundleID() ~= "org.hammerspoon.Hammerspoon") then
      if not a then a = w
      elseif w:id() ~= a:id() and not b then b = w end
    end
  end
  return a, b
end

local function ratioOf(L)
  return L.ratio and (ratios[L.id] or L.ratio) or nil
end

local function installed(bid)
  local ok, p = pcall(hs.application.pathForBundleID, bid)
  if ok then return p ~= nil and p ~= "" end
  return hs.image.imageFromAppBundle(bid) ~= nil
end

local iconCache = {}
local function iconURI(bid)
  if iconCache[bid] ~= nil then return iconCache[bid] or nil end
  local img = hs.image.imageFromAppBundle(bid)
  local uri = img and img:setSize({ w = 64, h = 64 }):encodeAsURLString() or false
  iconCache[bid] = uri
  return uri or nil
end

local function frameIn(f, r)
  return { x = f.x + r[1] * f.w, y = f.y + r[2] * f.h, w = r[3] * f.w, h = r[4] * f.h }
end

local function mainWindowOf(app)
  local w = app:mainWindow() or app:focusedWindow()
  if w and w:isStandard() then return w end
  for _, win in ipairs(app:allWindows()) do
    if win:isStandard() then return win end
  end
  return w
end

local function prepare(win)
  if win:isFullScreen() then win:setFullScreen(false) end
  if win:isMinimized() then win:unminimize() end
end

-- ---------------------------------------------------------------- applying

local applyTimer

local function applyLayout(L, screen, focused)
  local cells = L.build(ratioOf(L))
  local f = screen:frame()
  if L.pair then
    local a, b = recentPair(focused)
    if not (a and b) then hs.alert.show("Yan yana koymak için iki pencere gerekiyor", 1); return end
    M.remember({ a, b })
    for i, w in ipairs({ a, b }) do prepare(w); w:setFrame(frameIn(f, cells[i][2])) end
    b:raise(); a:focus()
    return
  end
  for _, c in ipairs(cells) do
    local app = hs.application.get(APPS[c[1]].bid)
    if app then app:unhide() else hs.application.launchOrFocusByBundleID(APPS[c[1]].bid) end
  end
  if applyTimer then applyTimer:stop() end
  local tries = 0
  applyTimer = hs.timer.doEvery(0.1, function()
    tries = tries + 1
    local wins = {}
    for i, c in ipairs(cells) do
      local app = hs.application.get(APPS[c[1]].bid)
      wins[i] = app and mainWindowOf(app)
    end
    local all = true
    for i = 1, #cells do if not wins[i] then all = false end end
    if not all and tries < 60 then return end
    applyTimer:stop(); applyTimer = nil
    M.remember(wins)

    for i = #cells, 1, -1 do
      local win = wins[i]
      if win then
        prepare(win)
        win:setFrame(frameIn(f, cells[i][2]))
        win:raise()
      end
    end
    if L.hideOthers then
      local keep = { ["org.hammerspoon.Hammerspoon"] = true }
      for _, c in ipairs(cells) do keep[APPS[c[1]].bid] = true end
      for _, app in ipairs(hs.application.runningApplications()) do
        if app:kind() == 1 and not keep[app:bundleID() or ""] and not app:isHidden() then app:hide() end
      end
    end
    if wins[1] then wins[1]:focus() end
    if not all then hs.alert.show("Bazı pencereler açılamadı", 1) end
  end)
end

local function applyAction(A, win)
  if not win then hs.alert.show("Yerleştirilecek pencere yok", 1); return end
  M.remember({ win })
  prepare(win)
  if A.nextScreen then
    local next = win:screen():next()
    if next == win:screen() then hs.alert.show("Tek ekran var", 0.8); return end
    win:moveToScreen(next, false, true)
  else
    win:setFrame(frameIn(win:screen():frame(), A.rect))
  end
  win:focus()
end

-- ---------------------------------------------------------------- page data

local function buildData(p)
  local apps = {}
  for key, a in pairs(APPS) do
    if installed(a.bid) then
      apps[key] = { name = a.name, color = a.color, icon = iconURI(a.bid), running = hs.application.get(a.bid) ~= nil }
    end
  end
  local w1, w2 = recentPair(p.prevWin)
  for key, w in pairs({ win1 = w1, win2 = w2 }) do
    local app = w:application()
    if app then
      apps[key] = { name = app:name(), color = key == "win1" and "#0a84ff" or "#8e5cf7",
        icon = app:bundleID() and iconURI(app:bundleID()), running = true }
    end
  end
  local layouts = {}
  for _, L in ipairs(LAYOUTS) do
    local cells, ok = {}, true
    for _, c in ipairs(L.build(ratioOf(L))) do
      if not apps[c[1]] then ok = false end
      table.insert(cells, { app = c[1], rect = c[2] })
    end
    if ok then
      table.insert(layouts, { id = L.id, group = L.group, name = L.name, cells = cells,
        adjustable = L.ratio ~= nil, ratio = ratioOf(L), custom = ratios[L.id] ~= nil, hideOthers = L.hideOthers or false })
    end
  end
  local actions = {}
  local multi = #hs.screen.allScreens() > 1
  for _, A in ipairs(ACTIONS) do
    if not A.nextScreen or multi then table.insert(actions, { id = A.id, name = A.name, rect = A.rect, nextScreen = A.nextScreen or false }) end
  end
  local win, winInfo = p.prevWin, nil
  if win and win:application() then
    local app = win:application()
    winInfo = { app = app:name(), title = win:title(), icon = app:bundleID() and iconURI(app:bundleID()) }
  end
  local screen = (win and win:screen()) or hs.screen.mainScreen()
  local f = screen:frame()
  return { apps = apps, layouts = layouts, actions = actions, win = winInfo, aspect = f.w / f.h,
    last = lastId, canUndo = #undoStack > 0 }
end

local function push(p, andOpen)
  p:js("Layouts.setData(" .. hs.json.encode(buildData(p)) .. ")" .. (andOpen and ";Layouts.open()" or ""))
end

local function findById(list, id)
  for _, x in ipairs(list) do if x.id == id then return x end end
end

local panel = Panel.new({
  name = "layouts",
  html = os.getenv("HOME") .. "/.hammerspoon/layouts.html",
  w = 980, h = 680,
  onShow = function(p) push(p, true) end,
  onMessage = function(p, msg)
    if msg.action == "apply" then
      local L = findById(LAYOUTS, msg.id)
      local A = findById(ACTIONS, msg.id)
      local win = p.prevWin
      local screen = (win and win:screen()) or hs.screen.mainScreen()
      p:hide(false)
      if L or A then lastId = msg.id; hs.settings.set(LAST_KEY, lastId) end
      if L then applyLayout(L, screen, win)
      elseif A then applyAction(A, win) end
    elseif msg.action == "undo" then
      p:hide(false)
      M.undo()
    elseif msg.action == "ratio" then
      local L = findById(LAYOUTS, msg.id)
      if not L or not L.ratio then return end
      if msg.reset then
        ratios[L.id] = nil
      else
        local r = ratioOf(L) + (msg.delta or 0)
        r = math.max(RATIO_MIN, math.min(RATIO_MAX, math.floor(r * 100 + 0.5) / 100))
        ratios[L.id] = (math.abs(r - L.ratio) < 0.001) and nil or r
      end
      hs.settings.set(RATIO_KEY, ratios)
      push(p, false)
    end
  end,
})

M.panel = panel
M.RATIO_STEP = RATIO_STEP
function M.toggle() panel:toggle() end

return M
