-- Work-safe screen saver in the style of the macOS lock screen: the desktop picture with a slow drift,
-- the date and a large clock on top. The Mac keeps working behind it (Claude Code sessions, browser tabs,
-- downloads). Any key or click wakes it; the mouse has to move a little more than a nudge. It fades out
-- instead of vanishing. Nothing but the date and the clock is drawn on top of the picture.
-- The system is kept from idle-sleeping while it runs; displays may still sleep. Not a lock.
-- Closing the lid still sleeps the Mac.
local Keep = require("keep")
local M = { active = false }

local FONT_CLOCK = ".AppleSystemUIFontRounded-Bold"
local FONT_DATE = ".AppleSystemUIFontDemi"
local EN = (function() local ok, P = pcall(require, "panel"); return ok and P.lang and P.lang() == "en" end)()

local DAYS = EN and { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
  or { "Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi" }
local MONTHS = EN and { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }
  or { "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık" }

local canvases, tap, clockTimer, watchdog, driftTimer = {}, nil, nil, nil, nil
local tookSleepHold, drift, phase = false, { x = 0, y = 0 }, 0
local info = {} -- canvas -> { f = screen frame, iw, ih = picture size or nil }

-- Element indexes
local BG, DIM, SHADE, DATE, CLOCK = 1, 2, 3, 4, 5

local function dateText()
  local d = os.date("*t")
  return EN and string.format("%s, %s %d", DAYS[d.wday], MONTHS[d.month], d.day)
    or string.format("%s, %d %s", DAYS[d.wday], d.day, MONTHS[d.month])
end

-- The picture fills the screen (aspect fill) and drifts slowly: a gentle zoom and pan over ~90 s.
local function placePicture(c)
  local i = info[c]
  if not i.iw then return end
  local f = i.f
  local scale = math.max(f.w / i.iw, f.h / i.ih) * (1.08 + 0.03 * math.sin(phase))
  local w, h = i.iw * scale, i.ih * scale
  c[BG].frame = { x = (f.w - w) / 2 + math.cos(phase * 0.7) * f.w * 0.012, y = (f.h - h) / 2 + math.sin(phase * 0.5) * f.h * 0.012, w = w, h = h }
end

-- Text frames, shifted by `drift` once a minute so nothing sits still for hours (burn-in).
local function layout(c)
  local f = info[c].f
  local clockSize = math.floor(math.min(f.h * 0.19, f.w * 0.16))
  local top = f.h * 0.11 + drift.y
  c[DATE].frame = { x = drift.x, y = top, w = f.w, h = 40 }
  c[DATE].textSize = math.max(20, math.floor(clockSize * 0.15))
  c[CLOCK].frame = { x = drift.x, y = top + 34, w = f.w, h = clockSize * 1.25 }
  c[CLOCK].textSize = clockSize
end

local function build(screen)
  local f = screen:fullFrame()
  local c = hs.canvas.new(f)
  local url = screen:desktopImageURL()
  local path = url and url:gsub("^file://", ""):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
  local img = path and hs.image.imageFromPath(path)
  local sz = img and img:size()
  info[c] = { f = f, iw = sz and sz.w > 0 and sz.w or nil, ih = sz and sz.h > 0 and sz.h or nil }
  local shadow = { blurRadius = 24, color = { white = 0, alpha = 0.35 }, offset = { h = -2, w = 0 } }
  c:appendElements(
    img and info[c].iw and { type = "image", image = img, imageScaling = "scaleToFit", imageAlignment = "center" }
      -- no picture (dynamic/aerial wallpaper): a deep macOS-like gradient instead
      or { type = "rectangle", action = "fill", fillGradient = "linear", fillGradientAngle = 60,
        fillGradientColors = { { red = 0.05, green = 0.07, blue = 0.20 }, { red = 0.24, green = 0.12, blue = 0.38 } } },
    { type = "rectangle", action = "fill", fillColor = { white = 0, alpha = 0.18 } },
    { type = "rectangle", action = "fill", frame = { x = 0, y = 0, w = f.w, h = f.h * 0.55 }, fillGradient = "linear", fillGradientAngle = 90,
      fillGradientColors = { { white = 0, alpha = 0.38 }, { white = 0, alpha = 0 } } },
    { type = "text", text = "", textFont = FONT_DATE, textSize = 26, textColor = { white = 1, alpha = 0.88 }, textAlignment = "center", withShadow = true, shadow = shadow },
    { type = "text", text = "", textFont = FONT_CLOCK, textSize = 180, textColor = { white = 1, alpha = 0.86 }, textAlignment = "center", withShadow = true, shadow = shadow }
  )
  if c[BG].type == "rectangle" then c[BG].frame = { x = 0, y = 0, w = f.w, h = f.h } end
  placePicture(c)
  layout(c)
  c:level(hs.canvas.windowLevels.screenSaver)
  c:behavior({ "canJoinAllSpaces", "stationary", "ignoresCycle", "fullScreenAuxiliary" })
  return c
end

local function each(fn) for _, c in ipairs(canvases) do fn(c) end end

local function tickClock()
  local t, d = os.date("%H:%M"), dateText()
  each(function(c) c[CLOCK].text = t; c[DATE].text = d end)
end

-- Wake on any key or click at once; the mouse has to travel WAKE_PX within a short burst, so a bumped
-- desk or a twitch of the trackpad does not wake it. Movement fades back if it stops for MOVE_GAP.
local WAKE_PX, MOVE_GAP = 320, 0.6
local travel, lastMove = 0, 0
local function onMove(dx, dy)
  local now = hs.timer.secondsSinceEpoch()
  if now - lastMove > MOVE_GAP then travel = 0 end
  lastMove = now
  travel = travel + math.sqrt(dx * dx + dy * dy)
  if travel >= WAKE_PX then M.stop() end
end

local ET = hs.eventtap.event.types
local P = hs.eventtap.event.properties
-- The hand that clicked the hub button is still on the mouse: ignore input for a moment after start.
local GRACE_SEC, startedAt = 1.0, 0
local function onEvent(e)
  local t = e:getType()
  if hs.timer.secondsSinceEpoch() - startedAt < GRACE_SEC then return t ~= ET.mouseMoved end
  if t == ET.mouseMoved or t == ET.leftMouseDragged or t == ET.rightMouseDragged then
    onMove(e:getProperty(P.mouseEventDeltaX), e:getProperty(P.mouseEventDeltaY))
    return false
  elseif t == ET.scrollWheel then
    onMove(e:getProperty(P.scrollWheelEventPointDeltaAxis2), e:getProperty(P.scrollWheelEventPointDeltaAxis1))
    return true
  end
  -- keys, modifiers and clicks: wake, and keep the event itself from reaching the app underneath
  M.stop()
  return true
end

local begin
function M.start()
  if M.active then return end
  M.active = true
  -- Never leave a half-built overlay on screen: on any error, tear down what exists.
  local ok, err = pcall(begin)
  if not ok then M.stop(); hs.alert.show("Ekran koruyucu açılamadı", 1.5); print("saver: " .. tostring(err)) end
end

begin = function()
  if not hs.caffeinate.get("systemIdle") then
    hs.caffeinate.set("systemIdle", true, true)
    tookSleepHold = true
  end
  drift, startedAt, travel = { x = 0, y = 0 }, hs.timer.secondsSinceEpoch(), 0
  canvases = {}
  for _, s in ipairs(hs.screen.allScreens()) do table.insert(canvases, build(s)) end
  tickClock()
  each(function(c) c:show(0.6) end)
  driftTimer = hs.timer.doEvery(0.1, function() phase = phase + 0.007; each(placePicture) end)
  tap = hs.eventtap.new({ ET.keyDown, ET.keyUp, ET.flagsChanged, ET.mouseMoved, ET.leftMouseDown, ET.leftMouseUp,
    ET.rightMouseDown, ET.rightMouseUp, ET.otherMouseDown, ET.otherMouseUp, ET.leftMouseDragged,
    ET.rightMouseDragged, ET.scrollWheel }, onEvent):start()
  local n = 0
  clockTimer = hs.timer.doEvery(5, function()
    tickClock()
    n = n + 1
    if n % 12 == 0 then -- once a minute, nudge the clock a little
      drift = { x = math.random(-60, 60), y = math.random(-30, 30) }
      each(layout)
    end
  end)
  -- macOS turns off an event tap whose callback stalls; turn it back on so waking keeps working.
  watchdog = hs.timer.doEvery(3, function() if tap and not tap:isEnabled() then tap:start() end end)
end

function M.stop()
  if not M.active then return end
  M.active = false
  for _, t in pairs({ clockTimer, watchdog, driftTimer }) do t:stop() end
  clockTimer, watchdog, driftTimer, travel = nil, nil, nil, 0
  if tap then tap:stop(); tap = nil end
  local old = canvases
  canvases, info = {}, {}
  -- a slow fade back to the desktop, like waking from the macOS saver
  for _, c in ipairs(old) do c:hide(0.7) end
  Keep.after(0.8, function() for _, c in ipairs(old) do c:delete() end end)
  if tookSleepHold then hs.caffeinate.set("systemIdle", false, true); tookSleepHold = false end
  if M.onStop then M.onStop() end
end

return M
