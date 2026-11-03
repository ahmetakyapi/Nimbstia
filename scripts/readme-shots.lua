-- Regenerates the README screenshots in assets/screens/ using DEMO DATA ONLY
-- (no real clipboard history, projects or screen content ends up in the images).
--   hs -c 'dofile(os.getenv("HOME") .. "/.hammerspoon/scripts/readme-shots.lua")'
-- Panels are patched in memory to ignore live updates while capturing; the script reloads
-- Hammerspoon when it is done, which restores everything.
local Keep = require("keep")
local Panel = require("panel")

local HOME = os.getenv("HOME")
local OUT = HOME .. "/.hammerspoon/assets/screens/"
local DEMO_BG = HOME .. "/.hammerspoon/clipdata/demo-desktop.png"
hs.fs.mkdir(HOME .. "/.hammerspoon/assets")
hs.fs.mkdir(OUT)

local now = os.time()
local DAY = 86400

local function textItem(id, text, ago, app, pinned)
  return { id = id, kind = "text", text = text, t = now - ago, app = app, pinned = pinned or false,
    len = utf8.len(text), lines = select(2, text:gsub("\n", "")) + 1, words = select(2, text:gsub("%S+", "")) }
end

local CLIP = { now = now, items = {
  textItem("d1", "const total = cart.items.reduce((sum, item) => sum + item.price, 0);\nconsole.log(`Toplam: ${total} ₺`);", 40, "Visual Studio Code"),
  textItem("d2", "https://github.com/ahmetakyapi/nimbstia", 260, "Google Chrome", true),
  textItem("d3", "#0A84FF", 950, "Figma"),
  textItem("d4", "Sürüm notu: pano geçmişi artık en yeni öğeyi her zaman en üstte gösteriyor.", 2500, "Notlar"),
  textItem("d5", "~/Projects/nimbstia/README.md", 5600, "Terminal"),
  textItem("d6", "merhaba@ornek.com", DAY + 3000, "Mail"),
  textItem("d7", "{\n  \"name\": \"nimbstia\",\n  \"version\": \"1.0.0\",\n  \"license\": \"MIT\"\n}", DAY + 9000, "Visual Studio Code"),
  textItem("d8", "42.195", 2 * DAY + 400, "Numbers"),
  textItem("d9", "Cuma 14:00 · tasarım gözden geçirme", 3 * DAY, "Takvim"),
} }

local P = HOME .. "/Projects/"
local function proj(name, o)
  o.name, o.path = name, P .. name
  o.mtime = o.mtime or o.ct
  return o
end
local PROJECTS = { scanning = false, items = {
  proj("nimbstia",         { branch = "main", sha = "4f2c9e1", ct = now - 600, subject = "feat: menu bar status with VPN check", dirty = 2, ahead = 1, behind = 0 }),
  proj("website",        { branch = "main", sha = "a91b3d0", ct = now - 5400, subject = "docs: refresh landing copy", dirty = 0, ahead = 0, behind = 0 }),
  proj("api-server",     { branch = "feature/auth-refresh", sha = "77de210", ct = now - 9000, subject = "fix: rotate refresh tokens", dirty = 5, ahead = 2, behind = 3 }),
  proj("mobile-app",     { branch = "develop", sha = "c03f8aa", ct = now - DAY - 4000, subject = "chore: bump SDK to 51", dirty = 0, ahead = 0, behind = 0 }),
  proj("design-system",  { branch = "main", sha = "e5a7712", ct = now - DAY - 9000, subject = "feat: new focus ring tokens", dirty = 1, ahead = 0, behind = 0 }),
  proj("api-server-pr42", { branch = nil, sha = "9b0c4f2", ct = now - 3 * DAY, subject = "review: pagination cursor", dirty = 0, worktree = true }),
  proj("data-pipeline",  { branch = "main", sha = "1d6e9ab", ct = now - 9 * DAY, subject = "perf: batch writes", dirty = 0, ahead = 0, behind = 12 }),
  proj("docs",           { branch = "main", sha = "f88a103", ct = now - 20 * DAY, subject = "docs: install guide", dirty = 0, ahead = 0, behind = 0 }),
} }
local LOG = {
  { sha = "4f2c9e1", subject = "feat: menu bar status with VPN check", author = "Ahmet", t = now - 600 },
  { sha = "b17a0c4", subject = "fix: newest-first sort in clipboard history", author = "Ahmet", t = now - 7200 },
  { sha = "0e92d5b", subject = "feat: screenshot overlay with annotations", author = "Ahmet", t = now - DAY },
  { sha = "6ac3f10", subject = "refactor: shared panel wrapper", author = "Ahmet", t = now - 2 * DAY },
  { sha = "d2b8e77", subject = "chore: initial commit", author = "Ahmet", t = now - 3 * DAY },
}

local function snap(panel, name)
  local w = panel.wv:hswindow()
  if w then w:snapshot():saveToFile(OUT .. name .. ".png") end
end

-- Show a panel without its "hide on focus loss" behaviour (a scripted capture does not own focus).
local function show(panel)
  panel.wv:windowCallback(nil)
  panel:show()
end

local steps, i = {}, 0
local function add(delay, fn) table.insert(steps, { delay, fn }) end
local function run()
  i = i + 1
  local s = steps[i]
  if not s then return end
  Keep.after(s[1], function()
    local ok, err = pcall(s[2])
    if not ok then print("readme-shots: " .. tostring(err)) end
    run()
  end)
end

local POP = {
  health = "ok", status = { text = "Her Şey Yolunda", tone = "ok" },
  dev = { name = "DEV", host = "10.0.0.10", status = "Bağlı · 18 ms", checkedAgo = "az önce" },
  forti = false, launcher = { title = "Geliştirme Ortamını Başlat" },
  claude = { plan = "Max", updatedAgo = "2 dk önce",
    limits = { { label = "Haftalık Limit", percent = 33, resets = "Cumartesi 12:00" } },
    sessions = { { name = "nimbstia-docs", busy = true, url = "https://claude.ai" },
                 { name = "api-server", busy = true, url = "https://claude.ai" },
                 { name = "website", busy = false, url = "https://claude.ai" } } },
  tools = { { id = "clip", name = "Pastia", what = "Pano Geçmişi", keys = "⌃V" },
            { id = "shot", name = "Clipstia", what = "Ekran Görüntüsü", keys = "⌘." },
            { id = "layout", name = "Panestia", what = "Pencere Düzenleri", keys = "⌃Space" },
            { id = "repo", name = "Repostia", what = "Projeler", keys = "⌃⌥P" },
            { id = "text", name = "Inkstia", what = "Ekrandan Metin", keys = "⌃⌥O" } },
  toggles = { awake = true, mic = false, meetings = false },
  theme = "auto", shortcuts = {}, errors = {},
}

for _, theme in ipairs({ "light", "dark" }) do
  add(0.3, function() Panel.setTheme(theme) end)
  -- clipboard
  add(0.1, function() show(Clip.panel) end)
  add(0.6, function()
    Clip.panel:js("Clip.setItems(" .. hs.json.encode(CLIP) .. ");Clip.setItems=function(){};")
  end)
  add(0.5, function() snap(Clip.panel, "clipboard-" .. theme) end)
  add(0.1, function() Clip.panel:hide(false) end)
  -- projects
  add(0.3, function() show(Projects.panel) end)
  add(0.6, function()
    -- hs.json.encode only takes tables: wrap the path and strip the brackets.
    local pathJS = hs.json.encode({ P .. "nimbstia" }):sub(2, -2)
    Projects.panel:js("Projects.setItems(" .. hs.json.encode(PROJECTS) .. ");Projects.log(" ..
      pathJS .. ",'4f2c9e1'," .. hs.json.encode(LOG) .. ");Projects.setItems=function(){};Projects.log=function(){};")
  end)
  add(0.5, function() snap(Projects.panel, "projects-" .. theme) end)
  add(0.1, function() Projects.panel:hide(false) end)
  -- layouts
  add(0.3, function() show(Layouts.panel) end)
  add(0.6, function()
    Layouts.panel:js("document.getElementById('target').innerHTML='<span>Visual Studio Code — nimbstia</span>'")
  end)
  add(0.4, function() snap(Layouts.panel, "layouts-" .. theme) end)
  add(0.1, function() Layouts.panel:hide(false) end)
  -- status popover
  add(0.3, function() show(Status.popover) end)
  add(0.6, function()
    POP.theme = theme
    -- Keep the real setter so the second theme pass can still render its own data.
    Status.popover:js("window.__set=window.__set||Pulse.set;__set(" .. hs.json.encode(POP) .. ");Pulse.set=function(){};")
  end)
  add(0.5, function() snap(Status.popover, "popover-" .. theme) end)
  add(0.1, function() Status.popover:hide(false) end)
end

-- Screenshot overlay on a drawn demo desktop (never the real screen).
add(0.3, function()
  local f = hs.screen.mainScreen():fullFrame()
  local c = hs.canvas.new({ x = 0, y = 0, w = f.w, h = f.h })
  c[1] = { type = "rectangle", action = "fill", fillGradient = "linear", fillGradientAngle = 315,
    fillGradientColors = { { hex = "#1b2550" }, { hex = "#5b3c8c" }, { hex = "#d9776a" } } }
  local wx, wy, ww, wh = f.w * .2, f.h * .14, f.w * .6, f.h * .66
  c[2] = { type = "rectangle", action = "fill", fillColor = { hex = "#ffffff", alpha = .97 },
    roundedRectRadii = { xRadius = 14, yRadius = 14 }, frame = { x = wx, y = wy, w = ww, h = wh },
    withShadow = true, shadow = { blurRadius = 40, color = { alpha = .45 }, offset = { h = -16, w = 0 } } }
  c[3] = { type = "rectangle", action = "fill", fillColor = { hex = "#f2f2f5" }, frame = { x = wx, y = wy + 14, w = ww, h = 38 } }
  for k, col in ipairs({ "#ff5f57", "#febc2e", "#28c840" }) do
    c[#c + 1] = { type = "circle", action = "fill", fillColor = { hex = col }, center = { x = wx + 20 + (k - 1) * 20, y = wy + 24 }, radius = 6 }
  end
  -- headline + text lines
  c[#c + 1] = { type = "rectangle", action = "fill", fillColor = { hex = "#1d1d1f" }, frame = { x = wx + 48, y = wy + 90, w = ww * .34, h = 22 }, roundedRectRadii = { xRadius = 6, yRadius = 6 } }
  for k = 0, 3 do
    c[#c + 1] = { type = "rectangle", action = "fill", fillColor = { hex = "#c7c7cc" }, frame = { x = wx + 48, y = wy + 136 + k * 26, w = ww * (.5 - k * .07), h = 11 }, roundedRectRadii = { xRadius = 5, yRadius = 5 } }
  end
  -- bar chart card
  local cx, cy, cw, ch = wx + 48, wy + 270, ww * .55, wh * .5
  c[#c + 1] = { type = "rectangle", action = "fill", fillColor = { hex = "#f5f5f7" }, frame = { x = cx, y = cy, w = cw, h = ch }, roundedRectRadii = { xRadius = 12, yRadius = 12 } }
  local bars = { .45, .62, .38, .8, .55, .92, .7 }
  for k, v in ipairs(bars) do
    local bw = cw / (#bars * 1.8)
    c[#c + 1] = { type = "rectangle", action = "fill", fillColor = { hex = k == 6 and "#0a84ff" or "#9ecbff" },
      frame = { x = cx + 30 + (k - 1) * bw * 1.8, y = cy + ch - 24 - (ch - 60) * v, w = bw, h = (ch - 60) * v }, roundedRectRadii = { xRadius = 5, yRadius = 5 } }
  end
  -- side cards
  for k = 0, 2 do
    c[#c + 1] = { type = "rectangle", action = "fill", fillColor = { hex = "#f5f5f7" }, frame = { x = cx + cw + 32, y = cy + k * (ch / 3 + 8), w = ww - cw - 128, h = ch / 3 - 8 }, roundedRectRadii = { xRadius = 12, yRadius = 12 } }
  end
  c:imageFromCanvas():saveToFile(DEMO_BG)
  c:delete()
  hs.settings.set("shot.hintCount", 99)
  Shot.start()
end)
add(1.4, function() Shot.webview:evaluateJavaScript("Shot.setSrc('file://" .. DEMO_BG .. "?" .. now .. "')") end)
add(0.8, function()
  local f = hs.screen.mainScreen():fullFrame()
  local r = { x = math.floor(f.w * .2 + 30), y = math.floor(f.h * .14 + 250), w = math.floor(f.w * .6 * .55 + 40), h = math.floor(f.h * .66 * .5 + 40) }
  local objs = {
    { t = "rect", a = { .62, .06 }, b = { .9, .62 }, color = "#ff453a", w = 4 },
    { t = "arrow", a = { .34, .86 }, b = { .6, .5 }, color = "#ff453a", w = 4 },
    { t = "num", at = { .66, .13 }, n = 1, color = "#ff453a", r = 14 },
    { t = "text", at = { .1, .82 }, text = "Rekor hafta", color = "#ff453a", fs = 26 },
  }
  Shot.webview:evaluateJavaScript("Shot.test(" .. hs.json.encode(r) .. ",{objs:" .. hs.json.encode(objs) .. "})")
  M_shotRect = r
end)
add(0.6, function()
  local f = hs.screen.mainScreen():fullFrame()
  local pad = 90
  local r = M_shotRect
  local x, y = math.max(0, r.x - pad), math.max(0, r.y - pad)
  local w, h = math.min(f.w - x, r.w + pad * 2 + 60), math.min(f.h - y, r.h + pad * 2 + 70)
  if not Shot.visible then print("readme-shots: overlay not open, screenshot skipped"); return end
  hs.execute(string.format("/usr/sbin/screencapture -x -R %d,%d,%d,%d '%s'", x, y, w, h, OUT .. "screenshot-dark.png"))
end)
add(0.1, function() Shot.webview:evaluateJavaScript("document.documentElement.dataset.theme='light'") end)
add(0.5, function()
  if not Shot.visible then return end
  local f = hs.screen.mainScreen():fullFrame()
  local r, pad = M_shotRect, 90
  local x, y = math.max(0, r.x - pad), math.max(0, r.y - pad)
  local w, h = math.min(f.w - x, r.w + pad * 2 + 60), math.min(f.h - y, r.h + pad * 2 + 70)
  hs.execute(string.format("/usr/sbin/screencapture -x -R %d,%d,%d,%d '%s'", x, y, w, h, OUT .. "screenshot-light.png"))
end)
add(0.2, function() Shot.close(true); hs.settings.set("shot.hintCount", nil); os.remove(DEMO_BG) end)
add(0.3, function() Panel.setTheme("auto") end)
add(0.5, function() hs.reload() end)

run()
