-- Native surfaces that are not webview panels, styled to match them: the hs.alert toasts used by
-- every tool and the hs.chooser pickers (Twistia, Snipstia). Call UI.start() once from init.lua.
local Panel = require("panel")
local UI = {}

local FONT = ".AppleSystemUIFont"

-- One calm HUD style for every toast, matching the panels' ink pill (theme.css --ink): near-black,
-- hairline rim, fully rounded, quick fades.
function UI.start()
  hs.alert.defaultStyle = {
    strokeWidth = 1,
    strokeColor = { white = 1, alpha = 0.12 },
    fillColor = { red = 0.043, green = 0.043, blue = 0.059, alpha = 0.94 },
    textColor = { white = 1, alpha = 0.96 },
    textFont = FONT,
    textSize = 14,
    radius = 22,
    padding = 14,
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
  ch:fgColor(dark and { white = 0.96 } or { red = 0.043, green = 0.043, blue = 0.059 })
  ch:subTextColor(dark and { red = 0.66, green = 0.66, blue = 0.70 } or { red = 0.31, green = 0.31, blue = 0.35 })
  return ch
end

return UI
