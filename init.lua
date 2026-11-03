-- Nimbstia: keyboard-first macOS workbench on Hammerspoon. Entry point; every feature lives in its own module.
local Keep = require("keep")

hs.autoLaunch(true)      -- Mac açılınca başlasın
hs.dockIcon(false)       -- Dock'ta görünmesin, menü çubuğunda dursun
hs.menuIcon(false)     -- one menu bar item is enough: status.lua has reload + console
require("hs.ipc")         -- terminalden `hs` komutuyla erişim

-- Load a module without letting one broken file take down everything else; failures are listed in the status popover.
LOAD_ERRORS = {}
local function load(name)
  local ok, mod = pcall(require, name)
  if ok then return mod end
  table.insert(LOAD_ERRORS, name .. ": " .. tostring(mod))
  print("module failed: " .. name .. ": " .. tostring(mod))
  return nil
end

-- ⌘Q: kısa basış "@" yazar (Windows'taki AltGr+Q gibi), ~1 sn basılı tutunca uygulamayı kapatır.
-- (Windows'taki Alt alışkanlığı: Mac'te ⌘ aynı yerde duruyor.)
local HOLD = 0.9
local quitTimer = nil
local quitDone = false

local function onPress()
  quitDone = false
  quitTimer = hs.timer.doAfter(HOLD, function()
    local app = hs.application.frontmostApplication()
    if app then
      quitDone = true
      hs.alert.closeAll()
      hs.alert.show("Kapatıldı: " .. app:name(), 0.8)
      app:kill()
    end
  end)
end

local function onRelease()
  if quitTimer then quitTimer:stop(); quitTimer = nil end
  if not quitDone then
    hs.eventtap.keyStrokes("@")
  end
end

hs.hotkey.bind({ "cmd" }, "q", onPress, onRelease)

-- ⌃⌘L: ekranı kilitle, şifre ekranı gelsin (Windows'taki Win+L gibi).
hs.hotkey.bind({ "ctrl", "cmd" }, "l", function()
  hs.caffeinate.lockScreen()
end)



-- ⌃V: pano geçmişi paneli (Windows'taki Win+V gibi): metin, kopyalanan görseller ve Screenshots klasörü.
-- Ayrıntı: clipboard.lua / clipboard.html. ⌘V normal yapıştırır, dokunulmadı.
Clip = load("clipboard")
if Clip then hs.hotkey.bind({ "ctrl" }, "v", Clip.toggle) end

-- ⌃Space: pencere düzeni paneli. Düzenler ve oranlar: layouts.lua (⌥←/⌥→ ya da kartın −/+ butonları; ⌘Z geri al).
Layouts = load("layouts")
if Layouts then hs.hotkey.bind({ "ctrl" }, "space", Layouts.toggle) end

-- Window snapping (like Win+arrow): ⌃⌥← / ⌃⌥→ cycle the width ½ → ⅓ → ⅔ on repeated presses,
-- ⌃⌥↑ top half, ⌃⌥↓ bottom half, ⌃⌥↩ full, ⌃⌥C center, ⌃⌥⌘←/→ other screen, ⌃⌥Z undo.
hs.window.animationDuration = 0
-- A hung app must not freeze ⌘. or ⌃Space while we ask it for its windows (Accessibility timeout, seconds).
hs.window.timeout(0.5)
local MOD = { "ctrl", "alt" }
local WIDTHS = { 1 / 2, 1 / 3, 2 / 3 }
local lastSnap = { key = nil, i = 0, at = 0, win = nil }

local function remember(win) if Layouts then Layouts.remember({ win }) end end

local function place(win, x, y, w, h)
  remember(win)
  if win:isFullScreen() then win:setFullScreen(false) end
  win:moveToUnit(hs.geometry.rect(x, y, w, h))
end

local function cycle(side)
  return function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local now = hs.timer.secondsSinceEpoch()
    local again = lastSnap.key == side and lastSnap.win == win:id() and now - lastSnap.at < 2.5
    local i = again and (lastSnap.i % #WIDTHS) + 1 or 1
    lastSnap = { key = side, i = i, at = now, win = win:id() }
    local w = WIDTHS[i]
    place(win, side == "left" and 0 or 1 - w, 0, w, 1)
  end
end

local function snap(x, y, w, h)
  return function()
    local win = hs.window.focusedWindow()
    if win then lastSnap.key = nil; place(win, x, y, w, h) end
  end
end

hs.hotkey.bind(MOD, "left",   cycle("left"))
hs.hotkey.bind(MOD, "right",  cycle("right"))
hs.hotkey.bind(MOD, "up",     snap(0, 0, 1, 0.5))
hs.hotkey.bind(MOD, "down",   snap(0, 0.5, 1, 0.5))
hs.hotkey.bind(MOD, "return", snap(0, 0, 1, 1))
hs.hotkey.bind(MOD, "c",      snap(0.15, 0.08, 0.7, 0.84))
hs.hotkey.bind(MOD, "z",      function() if Layouts then Layouts.undo() end end)
local function toScreen(dir)
  return function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local target = dir == "next" and win:screen():next() or win:screen():previous()
    if target == win:screen() then hs.alert.show("Tek ekran var", 0.8); return end
    remember(win)
    win:moveToScreen(target, false, true)
  end
end
hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "right", toScreen("next"))
hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "left",  toScreen("prev"))



-- ⌘.: ekran görüntüsü (Lightshot yerine, Apple Silicon'a yerel). Alan seç, çiz, ⌘S kaydet, ⌘C/⌃C/↩ kaydet + kopyala.
-- Ayrıntı: shot.lua / shot.html. Görüntüler ~/Documents/Screenshots'a kaydedilir; ⌃V panelinde de görünür.
Shot = load("shot")
-- ⌘. is macOS' "cancel" key: an open menu swallows it before a normal hotkey sees it. An event tap
-- sees the key first, so ⌘. also works while any menu is open (and the menu ends up in the shot).
if Shot then
  shotTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
    if hs.keycodes.map[e:getKeyCode()] ~= "." or not e:getFlags():containExactly({ "cmd" }) then return false end
    local ok, err = pcall(Shot.trigger) -- heavy work runs after the tap returns
    if not ok then print("shot: " .. tostring(err)) end
    return true
  end):start()
end
-- ⌘. artık bizde. Lightshot (Intel) açılışta kendiliğinden başlarsa kısayolu geri alır: kapat ve kısayolu tazele.
local LIGHTSHOT = "com.skillbrains.lightshot"
local function stopLightshot(app)
  app:kill()
end
if Shot and hs.application.get(LIGHTSHOT) then stopLightshot(hs.application.get(LIGHTSHOT)) end
lightshotWatcher = hs.application.watcher.new(function(_, ev, app)
  if Shot and ev == hs.application.watcher.launched and app and app:bundleID() == LIGHTSHOT then stopLightshot(app) end
end):start()

-- ⌃⌥P: proje açıcı (~/Projects altındaki depolar; ↩ VS Code, ⌘↩ Terminal). Ayrıntı: projects.lua / projects.html.
Projects = load("projects")
if Projects then hs.hotkey.bind(MOD, "p", Projects.toggle) end

-- Terminal'de ⇧↩ = alt satır (Claude Code). Terminal.app ⇧↩'yu düz ↩ gibi gönderir; ⌃J'yi Claude Code yeni satır sayar.
newlineTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
  if hs.keycodes.map[e:getKeyCode()] ~= "return" or not e:getFlags():containExactly({ "shift" }) then return false end
  local app = hs.application.frontmostApplication()
  if not app or app:bundleID() ~= "com.apple.Terminal" then return false end
  Keep.after(0, function() hs.eventtap.keyStroke({ "ctrl" }, "j", 0) end)
  return true
end)
newlineTap:start()

-- Araçlar: uygulama kısayolları (⌃⌥⌘ + harf), ⌃⌥O metin oku, ⌃⌥T dönüştür, ⌃⌥S / ;şablon, ⌃⌥J Jira. Ayrıntı: tools.lua.
Tools = load("tools")
if Tools then
  local ok, err = pcall(Tools.start)
  if not ok then table.insert(LOAD_ERRORS, "tools.start: " .. tostring(err)) end
end

-- Pulstia (menü çubuğu simgesi): DEV bağlantısı, Claude kullanımı, araçlar, ⌃⌥K uyanık tut, ⌃⌥M mikrofon. Ayrıntı: status.lua + pulstia.html.
Status = load("status")
if Status then
  hs.hotkey.bind(MOD, "k", Status.toggleAwake)
  hs.hotkey.bind(MOD, "m", Status.toggleMic)
end

local HELP = {
  { keys = "⌃V", label = "Pastia · Pano Geçmişi" },
  { keys = "⌃Space", label = "Panestia · Pencere Düzenleri" },
  { keys = "⌘.", label = "Clipstia · Ekran Görüntüsü (⌘S Kaydet, ⌃C Kopyala)" },
  { keys = "⌃⌥P", label = "Repostia · Projeler" },
  { keys = "⌃⌥← / →", label = "Sola / Sağa Yasla (Tekrar Bas: ⅓ · ⅔)" },
  { keys = "⌃⌥↑ / ↓ / ↩", label = "Üst Yarı / Alt Yarı / Tam Ekran" },
  { keys = "⌃⌥C", label = "Ortala" },
  { keys = "⌃⌥Z", label = "Son Yerleşimi Geri Al" },
  { keys = "⌃⌥⌘← / →", label = "Diğer Ekrana Taşı" },
  { keys = "⌃⌥K", label = "Pulstia · Mac'i Uyanık Tut" },
  { keys = "⌃⌥M", label = "Pulstia · Mikrofonu Kapat / Aç" },
  { keys = "⌃⌘L", label = "Ekranı Kilitle" },
  { keys = "⌘Q", label = "@ Yazar (Basılı Tut: Uygulamayı Kapatır)" },
}
for _, h in ipairs(Tools and Tools.HELP or {}) do table.insert(HELP, h) end
if Status then
  local ok, err = pcall(Status.start, HELP)
  if not ok then table.insert(LOAD_ERRORS, "status.start: " .. tostring(err)) end
end

if #LOAD_ERRORS > 0 then
  hs.alert.show("⚠︎ Hammerspoon: " .. #LOAD_ERRORS .. " modül yüklenemedi (konsola bak)", 3)
else
  hs.alert.show("Nimbstia hazır · menü çubuğundaki simgeye tıkla", 1.8)
end
