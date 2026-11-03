-- Renders assets/hero-{light,dark}.png from assets/hero.html (which composes the demo-data
-- screenshots). Run scripts/readme-shots.lua first, then:
--   hs -c 'dofile(os.getenv("HOME") .. "/.hammerspoon/scripts/readme-hero.lua")'
local Keep = require("keep")
local HOME = os.getenv("HOME")
local PAGE = HOME .. "/.hammerspoon/assets/hero.html"
local OUT = HOME .. "/.hammerspoon/assets/"
local W, H = 1600, 980

local screen = hs.screen.mainScreen():frame()
local wv = hs.webview.new({ x = screen.x + 20, y = screen.y + 20, w = W, h = H })
  :windowStyle({ "borderless" }):transparent(true):shadow(false)
  :level(hs.drawing.windowLevels.floating)

local themes, i = { "light", "dark" }, 0
local function nextTheme()
  i = i + 1
  local t = themes[i]
  if not t then wv:delete(); return end
  wv:url("file://" .. PAGE .. "?theme=" .. t)
  wv:show()
  -- Give the images time to decode, then capture the window itself (never the screen).
  Keep.after(2.2, function()
    local win = wv:hswindow()
    if win then win:snapshot():saveToFile(OUT .. "hero-" .. t .. ".png") end
    Keep.after(0.2, nextTheme)
  end)
end
nextTheme()
