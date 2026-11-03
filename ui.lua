-- Native surfaces that are not webview panels, styled to match them: the hs.alert toasts used by
-- every tool and the hs.chooser pickers (Twistia, Snipstia). Call UI.start() once from init.lua.
local Panel = require("panel")
local UI = {}

local FONT = ".AppleSystemUIFont"

-- One calm HUD style for every toast: rounded, SF, translucent, quick fades, no border.
function UI.start()
  hs.alert.defaultStyle = {
    strokeWidth = 0,
    strokeColor = { white = 1, alpha = 0 },
    fillColor = { red = 0.07, green = 0.08, blue = 0.11, alpha = 0.92 },
    textColor = { white = 1, alpha = 0.96 },
    textFont = FONT,
    textSize = 15,
    radius = 14,
    padding = 16,
    atScreenEdge = 0,
    fadeInDuration = 0.12,
    fadeOutDuration = 0.22,
    textStyle = { paragraphStyle = { alignment = "center", lineSpacing = 3 } },
  }
end

local function isDark()
  local t = Panel.theme()
  if t == "auto" then return hs.host.interfaceStyle() == "Dark" end
  return t == "dark"
end

-- Theme a chooser right before it is shown, so it follows the light/dark switch.
function UI.styleChooser(ch)
  if not ch then return ch end
  local dark = isDark()
  ch:bgDark(dark)
  ch:fgColor(dark and { white = 0.96 } or { red = 0.06, green = 0.07, blue = 0.13 })
  ch:subTextColor(dark and { white = 0.62 } or { red = 0.29, green = 0.31, blue = 0.41 })
  return ch
end

return UI
