-- Regenerates the README screenshots in assets/screens/ using DEMO DATA ONLY
-- (no real clipboard history, projects or screen content ends up in the images).
--   hs -c 'dofile(os.getenv("HOME") .. "/.hammerspoon/scripts/readme-shots.lua")'
-- Panels are patched in memory to ignore live updates while capturing; the script reloads
-- Hammerspoon when it is done, which restores everything.
local Keep = require("keep")
local Panel = require("panel")

local HOME = os.getenv("HOME")
local OUT = HOME .. "/.hammerspoon/assets/screens/"
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
  textItem("d2", "https://github.com/ahmetakyapi/Nimbstia", 260, "Google Chrome", true),
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
  dev = { name = "DEV", title = "Ofis VPN", host = "10.0.0.10", status = "Bağlı · 18 ms", checkedAgo = "az önce" },
  vpn = { connected = true },
  github = { commits = 12, added = 1840, deleted = 412, prsToday = 2, updatedAgo = "1 dk önce", org = "acme",
    opened = {
      { owner = "acme", repo = "api-server", number = 233, title = "feat: audit log for token refresh", author = "ahmetakyapi", url = "https://github.com" },
      { owner = "acme", repo = "website", number = 91, title = "fix: hero image on small screens", author = "ahmetakyapi", url = "https://github.com" } },
    commitList = {
      { sha = "4f2c9e1", subject = "feat: menu bar status with VPN check", repo = "api-server", added = 214, deleted = 38, t = now - 600, url = "https://github.com" },
      { sha = "b17a0c4", subject = "fix: newest-first sort in clipboard history", repo = "website", added = 46, deleted = 12, t = now - 7200, url = "https://github.com" } },
    reviewCount = 5, review = {
      { owner = "acme", repo = "api-server", number = 231, title = "fix: rotate refresh tokens", author = "selin", url = "https://github.com" },
      { owner = "acme", repo = "design-system", number = 57, title = "feat: new focus ring tokens", author = "mert", url = "https://github.com" },
      { owner = "acme", repo = "mobile-app", number = 412, title = "chore: bump SDK to 51", author = "deniz", url = "https://github.com" } },
    openCount = 2, open = {
      { owner = "ahmetakyapi", repo = "Nimbstia", number = 14, title = "feat: control center hub", author = "ahmetakyapi", url = "https://github.com" },
      { owner = "acme", repo = "website", number = 88, title = "docs: refresh landing copy", author = "ahmetakyapi", url = "https://github.com", draft = true } } },
  forti = false, launcher = nil,
  claude = { plan = "Max", updatedAgo = "2 dk önce",
    limits = { { label = "Haftalık Limit", percent = 33, resets = "Cumartesi 12:00" } },
    sessions = { { name = "nimbstia-docs", busy = true, url = "https://claude.ai" },
                 { name = "api-server", busy = true, url = "https://claude.ai" },
                 { name = "website", busy = false, url = "https://claude.ai" } } },
  tools = { { id = "clip", name = "Pastia", what = "Pano", keys = "⌃V" },
            { id = "shot", name = "Clipstia", what = "Ekran Al", keys = "⌃." },
            { id = "layout", name = "Panestia", what = "Düzen", keys = "⌃Space" },
            { id = "repo", name = "Repostia", what = "Projeler", keys = "⌃⇧P" },
            { id = "text", name = "Lexstia", what = "Metin Oku", keys = "⌃⇧O" } },
  toggles = { awake = true, mic = false, meetings = false },
  system = { battery = { pct = 82, charging = false }, mem = 58, disk = 412, diskUsed = 57 },
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
    Projects.panel:js("window.__gh=window.__gh||Projects.setGitHub;__gh(" .. hs.json.encode(POP.github) .. ");Projects.setGitHub=function(){};")
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
  local function R(x, y, w, h, col, r, extra)
    local e = { type = "rectangle", action = "fill", fillColor = type(col) == "string" and { hex = col } or col,
      roundedRectRadii = { xRadius = r or 0, yRadius = r or 0 }, frame = { x = x, y = y, w = w, h = h } }
    for k, v in pairs(extra or {}) do e[k] = v end
    c[#c + 1] = e
  end
  local function T(x, y, w, str, size, col, weight)
    c[#c + 1] = { type = "text", frame = { x = x, y = y, w = w, h = size * 1.6 },
      text = hs.styledtext.new(str, { font = { name = weight or ".AppleSystemUIFont", size = size }, color = { hex = col } }) }
  end
  -- wallpaper: vivid diagonal blend
  R(0, 0, f.w, f.h, "#000000", 0, { fillGradient = "linear", fillGradientAngle = 300,
    fillGradientColors = { { hex = "#2b1d6b" }, { hex = "#3a6df0" }, { hex = "#7fd3ff" } } })
  -- app window
  local wx, wy, ww, wh = f.w * .17, f.h * .12, f.w * .66, f.h * .72
  R(wx, wy, ww, wh, "#ffffff", 14, { withShadow = true, shadow = { blurRadius = 50, color = { alpha = .45 }, offset = { h = -18, w = 0 } } })
  local side = 210
  R(wx, wy, side, wh, "#f4f6fb", 14)
  R(wx + side - 14, wy, 14, wh, "#f4f6fb", 0)
  for k, col in ipairs({ "#ff5f57", "#febc2e", "#28c840" }) do
    c[#c + 1] = { type = "circle", action = "fill", fillColor = { hex = col }, center = { x = wx + 22 + (k - 1) * 20, y = wy + 22 }, radius = 6 }
  end
  local items = { { "Genel Bakış", "#2563ff" }, { "Satışlar", "#7c3aed" }, { "Müşteriler", "#16a34a" }, { "Raporlar", "#d97706" }, { "Ayarlar", "#64748b" } }
  for k, it in ipairs(items) do
    local y = wy + 64 + (k - 1) * 40
    if k == 1 then R(wx + 12, y - 6, side - 24, 32, "#e8efff", 8) end
    R(wx + 26, y + 4, 12, 12, it[2], 3)
    T(wx + 48, y - 1, 140, it[1], 13.5, k == 1 and "#1d4fe0" or "#334155")
  end
  local cx = wx + side + 36
  T(cx, wy + 30, 400, "Haftalık Rapor", 24, "#0f1222", ".AppleSystemUIFontBold")
  T(cx, wy + 66, 400, "27 Ekim – 2 Kasım", 13, "#64748b")
  -- KPI cards
  local kw = (ww - side - 36 * 2 - 32) / 3
  local kpis = { { "Gelir", "₺184.320", "+12,4%", "#16a34a" }, { "Yeni Müşteri", "1.248", "+8,1%", "#2563ff" }, { "Dönüşüm", "%3,9", "−0,3%", "#e11d48" } }
  for k, kp in ipairs(kpis) do
    local x = cx + (k - 1) * (kw + 16)
    R(x, wy + 110, kw, 96, "#f8fafc", 12, { strokeColor = { hex = "#e2e8f0" }, strokeWidth = 1, action = "strokeAndFill" })
    T(x + 18, wy + 124, kw - 30, kp[1], 12.5, "#64748b")
    T(x + 18, wy + 146, kw - 30, kp[2], 24, "#0f1222", ".AppleSystemUIFontBold")
    T(x + kw - 90, wy + 128, 76, kp[3], 12, kp[4], ".AppleSystemUIFontBold")
  end
  -- bar chart card
  local bx, by, bw, bh = cx, wy + 228, ww - side - 72, wh - 228 - 36
  R(bx, by, bw, bh, "#f8fafc", 12, { strokeColor = { hex = "#e2e8f0" }, strokeWidth = 1, action = "strokeAndFill" })
  T(bx + 18, by + 14, 300, "Günlük Gelir", 14, "#0f1222", ".AppleSystemUIFontBold")
  local bars = { .42, .58, .36, .74, .52, .96, .66 }
  local days = { "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz" }
  local slot = (bw - 60) / #bars
  for k, v in ipairs(bars) do
    local hgt = (bh - 90) * v
    local x = bx + 30 + (k - 1) * slot + slot * .22
    R(x, by + bh - 34 - hgt, slot * .56, hgt, "#000000", 7, { fillGradient = "linear", fillGradientAngle = 90,
      fillGradientColors = k == 6 and { { hex = "#1d4fe0" }, { hex = "#60a5fa" } } or { { hex = "#bcd3ff" }, { hex = "#dbe7ff" } } })
    T(x - 4, by + bh - 28, slot * .7, days[k], 11.5, "#64748b")
  end
  -- The demo desktop is shown as a full-screen window above every app (just below the overlay), so
  -- the frozen screen IS the demo: the real screen can never end up in the image.
  c:level(hs.drawing.windowLevels.screenSaver - 1)
  c:behavior(hs.drawing.windowBehaviors.canJoinAllSpaces)
  c:show()
  M_demo = c
  hs.settings.set("shot.hintCount", 99)
end)
add(0.4, function() Shot.start() end)
add(1.4, function() end)
add(0.8, function()
  local f = hs.screen.mainScreen():fullFrame()
  -- Select the whole demo report window and mark two things on it, positioned from the same
  -- geometry the demo desktop was drawn with.
  local wx, wy, ww, wh = f.w * .17, f.h * .12, f.w * .66, f.h * .72
  local side = 210
  local cx = wx + side + 36
  local kw = (ww - side - 36 * 2 - 32) / 3
  local bx, by, bw, bh = cx, wy + 228, ww - side - 72, wh - 228 - 36
  local slot = (bw - 60) / 7
  local x6 = bx + 30 + 5 * slot + slot * .22
  local top6 = by + bh - 34 - (bh - 90) * .96
  local function rel(x, y) return { (x - wx) / ww, (y - wy) / wh } end
  local r = { x = math.floor(wx), y = math.floor(wy), w = math.floor(ww), h = math.floor(wh) }
  local objs = {
    { t = "rect", a = rel(cx - 8, wy + 102), b = rel(cx + kw + 8, wy + 214), color = "#ff3b30", w = 4 },
    { t = "num", at = rel(cx - 8, wy + 102), n = 1, color = "#ff3b30", r = 14 },
    { t = "rect", a = rel(x6 - 12, top6 - 14), b = rel(x6 + slot * .56 + 12, by + bh - 24), color = "#ff3b30", w = 4 },
    { t = "num", at = rel(x6 - 12, top6 - 14), n = 2, color = "#ff3b30", r = 14 },
    { t = "text", at = rel(bx + 60, by + 64), text = "Rekor gün: Cumartesi", color = "#ff3b30", fs = 24 },
    { t = "arrow", a = rel(bx + 330, by + 82), b = rel(x6 - 20, top6 + 30), color = "#ff3b30", w = 4 },
  }
  Shot.webview:evaluateJavaScript("Shot.test(" .. hs.json.encode(r) .. ",{objs:" .. hs.json.encode(objs) .. "})")
  M_shotRect = r
end)
add(0.6, function()
  local f = hs.screen.mainScreen():fullFrame()
  -- capture the whole demo window plus a margin of wallpaper, so the context is complete
  local x, y = math.floor(f.w * .17 - 40), math.floor(f.h * .12 - 40)
  local w, h = math.floor(f.w * .66 + 80 + 60), math.floor(f.h * .72 + 80 + 40)
  if not (Shot.visible and M_demo) then print("readme-shots: overlay or demo desktop missing, screenshot skipped"); return end
  hs.execute(string.format("/usr/sbin/screencapture -x -R %d,%d,%d,%d '%s'", x, y, w, h, OUT .. "screenshot-dark.png"))
end)
add(0.1, function() Shot.webview:evaluateJavaScript("document.documentElement.dataset.theme='light'") end)
add(0.5, function()
  if not (Shot.visible and M_demo) then return end
  local f = hs.screen.mainScreen():fullFrame()
  local x, y = math.floor(f.w * .17 - 40), math.floor(f.h * .12 - 40)
  local w, h = math.floor(f.w * .66 + 80 + 60), math.floor(f.h * .72 + 80 + 40)
  hs.execute(string.format("/usr/sbin/screencapture -x -R %d,%d,%d,%d '%s'", x, y, w, h, OUT .. "screenshot-light.png"))
end)
add(0.2, function()
  Shot.close(true); hs.settings.set("shot.hintCount", nil)
  if M_demo then M_demo:delete(); M_demo = nil end
end)
add(0.3, function() Panel.setTheme("auto") end)
add(0.5, function() hs.reload() end)

run()
