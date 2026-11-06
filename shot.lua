-- Clipstia: Lightshot-style screenshot tool. Freezes the screen under the mouse, the user drags a region
-- and annotates it (shot.html does all UI/drawing), then a full-resolution PNG is saved and optionally copied.
-- API: M.trigger() (⌘.), M.start() (toggle), M.close(), M.webview, M.visible, M.lastOpenMs, M.destroy()
--
-- Memory: encoding a full-screen hs.image (saveToFile / encodeAsURLString) leaks ~270 MB of native memory
-- per call in Hammerspoon 1.1, and loading a full-screen TIFF with hs.image.imageFromPath leaks ~58 MB.
-- So big images are never encoded or decoded in-process: the screen is captured to a file by
-- /usr/sbin/screencapture, crops are cut by /usr/bin/sips, and the instant on-screen freeze uses
-- screen:snapshot() (drawing it in a canvas does not leak). Lua only moves bytes around.
local Keep = require("keep")
local M = {}

-- Touch lazily-loaded Hammerspoon modules now so the first real use is fast and never prints a
-- "Loading extension" line from inside an async callback.
local _preload = { hs.base64, hs.canvas, hs.image, hs.pasteboard, hs.alert, hs.fs, hs.json, hs.timer, hs.mouse, hs.screen, hs.window, hs.application }

local HOME = os.getenv("HOME")
local DIR = HOME .. "/.hammerspoon"
local HTML = DIR .. "/shot.html"
local TMP_IMG = DIR .. "/clipdata/shot-current.tiff" -- lossless and twice as fast to write as PNG
local TMP_CROP = DIR .. "/clipdata/shot-crop.png"
local OUT_DIR = require("config").screenshotDir -- the clipboard panel lists the same folder

M.visible = false
M.ready = false
M.lastOpenMs = nil
M.lastTimings = {}

local wv, uc
local prevWin, prevApp
local pendingStart = nil   -- start args queued while the page is still loading
local session = 0         -- increments on every start; guards stale timers/messages
local shownSession = 0
local openT0 = 0
local failsafe
local exporting = false   -- an export (crop + save) of the previous session is still running
local exportGuard

local function readFile(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local d = f:read("a"); f:close()
  return d
end

local function jsonStr(s) return hs.json.encode({ s }):sub(2, -2) end

local function js(code)
  if wv then wv:evaluateJavaScript(code) end
end

local function uniquePath()
  hs.fs.mkdir(OUT_DIR)
  local base = OUT_DIR .. "/Ekran Resmi " .. os.date("%Y-%m-%d %H.%M.%S")
  local path, n = base .. ".png", 2
  while hs.fs.attributes(path) do path = base .. " (" .. n .. ").png"; n = n + 1 end
  return path
end

local function restoreFocus()
  if prevWin and prevWin:application() then prevWin:focus()
  elseif prevApp then prevApp:activate() end
end

local cur = nil       -- current session: { scale = pixels per point } (crops are cut from TMP_IMG)
local freezeCanvas   -- native copy of the frozen screen, shown instantly until the page has decoded its own copy

local function dropCanvas()
  if freezeCanvas then freezeCanvas:delete(); freezeCanvas = nil end
end

-- Hide the overlay right away; the page state is reset afterwards.
local function hideNow(restore)
  if failsafe then failsafe:stop(); failsafe = nil end
  if not M.visible then return end
  M.visible = false
  wv:hide()
  dropCanvas()
  if restore then restoreFocus() end
end

function M.close(restore)
  hideNow(restore ~= false)
  js("window.Shot && Shot.reset()")
  cur = nil
  os.remove(TMP_IMG); os.remove(TMP_CROP)
  -- The canvas image is a native object the Lua GC cannot see; collect once the session is over.
  Keep.after(1.5, function() if not M.visible then collectgarbage("collect") end end)
end

-- Capture `screen` into TMP_IMG out of process (≈110 ms). Returns true on success.
local function captureToFile(screen)
  hs.fs.mkdir(DIR .. "/clipdata")
  os.remove(TMP_IMG)
  local f = screen:fullFrame()
  -- Started directly (no shell) and waited for: the overlay must not appear before the capture is done.
  local rect = string.format("-R%d,%d,%d,%d", math.floor(f.x), math.floor(f.y), math.floor(f.w), math.floor(f.h))
  local t = hs.task.new("/usr/sbin/screencapture", nil, { "-x", "-t", "tiff", rect, TMP_IMG })
  if t and t:start() then t:waitUntilExit() end
  return hs.fs.attributes(TMP_IMG) ~= nil
end

-- Fallback when WKWebView refuses the file:// image: ship the PNG as a data URL.
local function sendDataUrl()
  local data = readFile(TMP_IMG)
  if not data then return end
  js("Shot.setSrc(" .. jsonStr("data:image/tiff;base64," .. hs.base64.encode(data)) .. ")")
end

local function finishExport(body)
  local png = hs.base64.decode(body.data or "")
  if M.debugLog then local f = io.open(M.debugLog, "a"); if f then f:write("export data=" .. tostring(body.data and #body.data) .. " png=" .. tostring(png and #png) .. "\n"); f:close() end end
  if not png or #png == 0 then
    hs.alert.show("Ekran görüntüsü kaydedilemedi", 1.5)
    return
  end
  local path = uniquePath()
  local f = io.open(path, "wb")
  if not f then
    hs.alert.show("Kaydedilemedi: " .. path, 2)
    return
  end
  f:write(png); f:close()
  M.lastExportMs = (hs.timer.secondsSinceEpoch() - (M.actionT0 or hs.timer.secondsSinceEpoch())) * 1000
  local name = path:match("([^/]+)$")
  if body.copy then
    if Clip and Clip.quietImages then Clip.quietImages(3) end
    -- PNG only: TIFF encoding doubled the clipboard-ready time and every target app (Teams, Chrome, Slack, VS Code) takes PNG.
    local types = { ["public.png"] = png }
    hs.pasteboard.writeAllData(types)
    M.lastClipboardMs = (hs.timer.secondsSinceEpoch() - (M.actionT0 or hs.timer.secondsSinceEpoch())) * 1000
    hs.alert.show("Kaydedildi + panoda: " .. name, 1.5)
  else
    hs.alert.show("Kaydedildi: " .. name, 1.5)
  end
end

local function onMessage(msg)
  local body = msg.body or {}
  local a = body.action
  if M.debugLog then local f = io.open(M.debugLog, "a"); if f then f:write(string.format("%.3f %s\n", hs.timer.secondsSinceEpoch(), tostring(a))); f:close() end end
  if a == "ready" then
    M.ready = true
    if pendingStart then local p = pendingStart; pendingStart = nil; p() end
  elseif a == "shown" then
    -- the page decoded its own copy of the frozen screen: drop the native placeholder
    shownSession = session
    dropCanvas()
    -- editing an image: start with the whole image selected, ready to crop or mark up
    if cur and cur.editRect then
      js("Shot.test(" .. hs.json.encode(cur.editRect) .. ",{objs:[]})")
      cur.editRect = nil
    end
    M.fullReadyMs = (hs.timer.secondsSinceEpoch() - openT0) * 1000
  elseif a == "imgError" then
    sendDataUrl()
  elseif a == "close" then
    M.close(true)
  elseif a == "hideNow" then
    M.actionT0 = hs.timer.secondsSinceEpoch()
    exporting = true
    -- Never block new screenshots for long if the page fails to send the export.
    if exportGuard then exportGuard:stop() end
    exportGuard = Keep.after(3, function() exporting = false end)
    hideNow(true)
  elseif a == "needCrop" then
    -- Cut the selection out of the captured file with sips (out of process); the page draws the
    -- annotations on top of this clean, untainted crop and sends back the finished PNG.
    local k = (cur and cur.scale) or 2
    local x, y = math.floor(body.x * k + 0.5), math.floor(body.y * k + 0.5)
    local w, h = math.max(1, math.floor(body.w * k + 0.5)), math.max(1, math.floor(body.h * k + 0.5))
    os.remove(TMP_CROP)
    Keep.task("/usr/bin/sips", function(code)
      local data = code == 0 and readFile(TMP_CROP) or nil
      os.remove(TMP_CROP)
      if not data then
        exporting = false
        hs.alert.show("Ekran görüntüsü kaydedilemedi", 1.5)
        js("window.Shot && Shot.reset()")
        return
      end
      js("Shot.setCrop(" .. jsonStr("data:image/png;base64," .. hs.base64.encode(data)) .. ")")
    end, { "-s", "format", "png", "-c", tostring(h), tostring(w), "--cropOffset", tostring(y), tostring(x), TMP_IMG, "--out", TMP_CROP })
  elseif a == "export" then
    hideNow(true)
    finishExport(body)
    cur = nil
    exporting = false
    js("window.Shot && Shot.reset()")
    os.remove(TMP_IMG)
    Keep.after(1.5, function() if not M.visible then collectgarbage("collect") end end)
  elseif a == "error" then
    pcall(print, "shot: page error: " .. tostring(body.message))
    if M.debugLog then local f = io.open(M.debugLog, "a"); if f then f:write("ERR " .. tostring(body.message) .. "\n"); f:close() end end
    if body.fatal then M.close(true) end
  end
end

local function create()
  local screen = hs.screen.mainScreen()
  uc = hs.webview.usercontent.new("shot")
  uc:setCallback(function(msg)
    local ok, err = pcall(onMessage, msg)
    if not ok then print("shot: " .. tostring(err)) end
  end)
  wv = hs.webview.new(screen:fullFrame(), { developerExtrasEnabled = false }, uc)
    :windowStyle({ "borderless" })
    :allowTextEntry(true)
    :transparent(true)
    :shadow(false)
    :closeOnEscape(false)
    :deleteOnClose(false)
    :level(hs.drawing.windowLevels.screenSaver)
    :behavior(hs.drawing.windowBehaviors.canJoinAllSpaces + hs.drawing.windowBehaviors.fullScreenAuxiliary)
  wv:url("file://" .. HTML .. "?lang=" .. require("panel").lang()) -- i18n.js reads ?lang=
  M.webview = wv
end

function M.destroy()
  if failsafe then failsafe:stop(); failsafe = nil end
  dropCanvas()
  if wv then pcall(function() wv:hide(); wv:delete() end) end
  wv, uc, M.webview, M.ready, M.visible = nil, nil, nil, false, false
end

-- True while some app shows an open menu (menus live on the pop-up menu window layer, 101).
function M.menuOpen()
  for _, w in ipairs(hs.window.list(true) or {}) do
    if w.kCGWindowLayer == 101 then return true end
  end
  return false
end

-- Entry point for ⌘. : if a menu is open, freeze the screen right now (the menu stays in the
-- shot), close the menu with Escape and open the editor a moment later, so that Escape can
-- never reach the overlay.
function M.trigger()
  if M.visible or exporting or not M.menuOpen() then return Keep.after(0, M.start) end
  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local snap = screen:snapshot()
  local ok = captureToFile(screen)
  hs.eventtap.keyStroke({}, "escape", 0)
  Keep.after(0.15, function() M.start({ captured = ok, snap = snap, screen = screen }) end)
end

-- opts.captured / opts.snap / opts.screen: the screen was already frozen (see M.trigger).
function M.start(opts)
  opts = type(opts) == "table" and opts or {}
  if M.visible then return M.close(true) end
  -- A previous capture is still being saved (≤ ~0.4 s): open right after it instead of
  -- letting its late messages hit the new session.
  if exporting then Keep.after(0.15, function() M.start(opts) end); return end
  if not wv then create() end
  local t0 = hs.timer.secondsSinceEpoch()
  local screen = opts.screen or hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  prevWin = hs.window.focusedWindow()
  prevApp = hs.application.frontmostApplication()

  -- Freeze the screen before anything is shown so the overlay never ends up in the capture.
  -- Editing an existing image (opts.noFreeze): TMP_IMG is already prepared, nothing to freeze.
  local img = opts.noFreeze and true or (opts.snap or screen:snapshot())
  if not (opts.captured or captureToFile(screen)) or not img then hs.alert.show("Ekran görüntüsü alınamadı", 1.5); return end
  local f = screen:fullFrame()
  local mode = screen:currentMode()
  cur = { scale = (mode and mode.scale) or 2, editRect = opts.editRect }
  local t1 = hs.timer.secondsSinceEpoch()

  session = session + 1
  local s = session
  openT0 = t0
  shownSession = 0
  M.visible = true
  M.fullReadyMs = nil

  -- Instant paint: native canvas with the frozen image (the page adds dim/selection on top, transparently).
  dropCanvas()
  if not opts.noFreeze then
    freezeCanvas = hs.canvas.new(f)
      :level(hs.drawing.windowLevels.screenSaver)
      :behavior(hs.drawing.windowBehaviors.canJoinAllSpaces + hs.drawing.windowBehaviors.fullScreenAuxiliary)
    freezeCanvas[1] = { type = "image", image = img, imageScaling = "scaleToFit", frame = { x = 0, y = 0, w = f.w, h = f.h } }
    freezeCanvas:show()
  end
  wv:frame(f)
  wv:show()
  wv:bringToFront(true)
  local win = wv:hswindow()
  if win then win:focus() end
  local t2 = hs.timer.secondsSinceEpoch()
  M.lastOpenMs = (t2 - t0) * 1000

  local function begin()
    js(require("panel").themeJS()) -- same light/dark choice as the other panels
    if s ~= session or not M.visible then return end
    -- the hint is shown on the first 3 opens only
    local n = hs.settings.get("shot.hintCount") or 0
    local showHint = n < 3
    if showHint then hs.settings.set("shot.hintCount", n + 1) end
    js(string.format("Shot.begin({w:%d,h:%d,hint:%s,wins:[]})", math.floor(f.w), math.floor(f.h), tostring(showHint)))
  end
  if M.ready then begin() else pendingStart = begin end

  -- The page loads the same file for its own full-resolution copy.
  Keep.after(0, function()
    if s ~= session or not M.visible then return end
    M.lastTimings = { capture = (t1 - t0) * 1000, firstPaint = M.lastOpenMs }
    local function load()
      if s ~= session or not M.visible then return end
      local src = string.format("file://%s?t=%d", TMP_IMG, math.floor(hs.timer.secondsSinceEpoch() * 1000))
      js(string.format("Shot.setSrc(%s)", jsonStr(src)))
    end
    if M.ready then load() else
      local prev = pendingStart
      pendingStart = function() prev(); load() end
    end
  end)

  if failsafe then failsafe:stop() end
  failsafe = hs.timer.doAfter(12, function()
    failsafe = nil
    if M.visible and shownSession ~= s then
      print("shot: page image never loaded, aborting")
      M.close(true)
      hs.alert.show("Ekran görüntüsü aracı açılamadı", 1.5)
    end
  end)
end

-- Open an existing image in the editor: it is scaled to fit and centred on a dark backdrop the size of
-- the screen (out of process, with sips), and the editor starts with the image selected. Saving writes
-- a new file; the original stays untouched.
function M.editFile(path)
  if M.visible or exporting or type(path) ~= "string" or not hs.fs.attributes(path) then return end
  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local f = screen:fullFrame()
  local mode = screen:currentMode()
  local k = (mode and mode.scale) or 2
  local W, H = math.floor(f.w * k), math.floor(f.h * k)
  local q = function(x) return "'" .. x:gsub("'", "'\\''") .. "'" end
  local info = hs.execute("/usr/bin/sips -g pixelWidth -g pixelHeight " .. q(path)) or ""
  local iw, ih = tonumber(info:match("pixelWidth:%s*(%d+)")), tonumber(info:match("pixelHeight:%s*(%d+)"))
  if not iw or not ih then hs.alert.show("Görsel açılamadı", 1.5); return end
  local s = math.min(1, W * 0.86 / iw, H * 0.8 / ih)
  local dw, dh = math.floor(iw * s), math.floor(ih * s)
  hs.fs.mkdir(DIR .. "/clipdata")
  os.remove(TMP_IMG)
  local scaled = DIR .. "/clipdata/edit-scaled.tiff"
  hs.execute(string.format("/usr/bin/sips -s format tiff -z %d %d %s --out %s >/dev/null && /usr/bin/sips --padToHeightWidth %d %d --padColor 15171C %s --out %s >/dev/null",
    dh, dw, q(path), q(scaled), H, W, q(scaled), q(TMP_IMG)))
  os.remove(scaled)
  if not hs.fs.attributes(TMP_IMG) then hs.alert.show("Görsel açılamadı", 1.5); return end
  local rect = { x = math.floor((W - dw) / 2 / k), y = math.floor((H - dh) / 2 / k), w = math.floor(dw / k), h = math.floor(dh / k) }
  M.start({ captured = true, noFreeze = true, screen = screen, editRect = rect })
end

-- Replace a previous instance (re-running dofile) so only one hidden webview exists.
if _G.Shot and type(_G.Shot) == "table" and _G.Shot ~= M and _G.Shot.destroy then pcall(_G.Shot.destroy) end

create()
return M
