-- Shared floating webview panel (Spotlight-style): opens on the screen of the focused window,
-- takes keyboard focus, hides when it loses focus and can hand focus back to the previous window.
local Panel = {}
Panel.__index = Panel

-- Theme for every panel: "auto" follows macOS, "light"/"dark" force it (status menu → Tema).
local THEME_KEY = "nimbstia.theme"
local all = {} -- every panel, so a theme change reaches all of them at once
function Panel.theme() return hs.settings.get(THEME_KEY) or "auto" end
function Panel.setTheme(t)
  hs.settings.set(THEME_KEY, t)
  for _, p in ipairs(all) do p:js(Panel.themeJS()) end
  if Panel.onThemeChange then pcall(Panel.onThemeChange, t) end
end

-- The header button flips between light and dark; "auto" resolves to what macOS shows right now.
function Panel.toggleTheme()
  local t = Panel.theme()
  if t == "auto" then t = (hs.host.interfaceStyle() == "Dark") and "dark" or "light" end
  Panel.setTheme(t == "dark" and "light" or "dark")
end
function Panel.themeJS()
  local t = Panel.theme()
  if t == "light" or t == "dark" then return "document.documentElement.dataset.theme='" .. t .. "'" end
  return "delete document.documentElement.dataset.theme"
end

-- Real app icons for the panels: the installed app's own icon as a data URI (64 px), cached per
-- bundle id for the session. nil when the app is not installed. Nothing is bundled with Nimbstia.
local iconCache = {}
function Panel.appIcon(bid)
  if type(bid) ~= "string" or bid == "" then return nil end
  if iconCache[bid] ~= nil then return iconCache[bid] or nil end
  local ok, img = pcall(hs.image.imageFromAppBundle, bid)
  local uri = ok and img and img:setSize({ w = 64, h = 64 }):encodeAsURLString() or false
  iconCache[bid] = uri
  return uri or nil
end

local function readFile(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local d = f:read("a"); f:close()
  return d
end

-- The shared design system (theme.css + Geist fonts). Panels load their HTML as a string, which has
-- no base URL, so the <link> to theme.css is replaced with the stylesheet itself and the fonts it
-- references become data URIs. Built once per load and reused by every panel.
local BASE = os.getenv("HOME") .. "/.hammerspoon/"
local themeCSS
function Panel.themeCSS()
  if themeCSS then return themeCSS end
  local css = readFile(BASE .. "theme.css") or ""
  css = css:gsub('url%("(assets/fonts/[^"]+%.woff2)"%)', function(rel)
    local data = readFile(BASE .. rel)
    if not data then return 'url("' .. rel .. '")' end
    return 'url("data:font/woff2;base64,' .. hs.base64.encode(data) .. '")'
  end)
  themeCSS = css
  return css
end
-- Interface language (config.language): "tr" (default) or "en". i18n.js translates the panels in place.
function Panel.lang()
  local ok, C = pcall(require, "config")
  local l = ok and type(C) == "table" and C.language or "tr"
  if type(l) ~= "string" or not l:match("^%a%a$") then return "tr" end
  return l:lower()
end
local i18nJS
function Panel.i18nJS()
  if i18nJS == nil then
    -- an inline script ends at the first "</script", so that sequence must not appear in the source
    i18nJS = (readFile(BASE .. "i18n.js") or ""):gsub("</script", "<\\/script")
  end
  return i18nJS
end

local motionJS
function Panel.motionJS()
  if motionJS == nil then
    motionJS = (readFile(BASE .. "motion.js") or ""):gsub("</script", "<\\/script")
  end
  return motionJS
end

function Panel.inline(html)
  html = html:gsub('<link rel="stylesheet" href="theme%.css">', function()
    return "<style>" .. Panel.themeCSS() .. "</style>"
  end, 1)
  -- The <script src> has no base URL to resolve against either: inline it, with the language first.
  html = html:gsub('<script src="i18n%.js"></script>', function()
    local js = Panel.i18nJS()
    local out = '<script>window.NB_LANG="' .. Panel.lang() .. '";</script>'
    if js ~= "" then out = out .. "<script>" .. js .. "</script>" end
    return out
  end, 1)
  -- motion.js (shared motion helpers) is inlined the same way; a missing file leaves the tag out.
  html = html:gsub('<script src="motion%.js"></script>', function()
    local js = Panel.motionJS()
    return js ~= "" and ("<script>" .. js .. "</script>") or ""
  end, 1)
  return html
end

-- opts: name (JS message handler), html (file path), w, h, onMessage(panel, body), onShow(panel),
--       position(panel, w, h) -> frame (optional; default: centred on the focused window's screen)
function Panel.new(opts)
  local self = setmetatable({ opts = opts, ready = false, visible = false, pendingOpen = false }, Panel)
  local uc = hs.webview.usercontent.new(opts.name)
  uc:setCallback(function(msg)
    local body = msg.body or {}
    if body.action == "ready" then
      self.ready = true
      if self.pendingOpen then self.pendingOpen = false; self:_present() end
      return
    elseif body.action == "close" then
      return self:hide(true)
    elseif body.action == "toggleTheme" then
      return Panel.toggleTheme()
    end
    local ok, err = pcall(opts.onMessage, self, body)
    if not ok then print(opts.name .. ": " .. tostring(err)) end
  end)
  self.uc = uc
  self.wv = hs.webview.new({ x = 0, y = 0, w = opts.w, h = opts.h }, { developerExtrasEnabled = false }, uc)
    :windowStyle({ "borderless" })
    :allowTextEntry(true)
    :transparent(true)
    :shadow(false)
    :closeOnEscape(false)
    :deleteOnClose(false)
    :level(hs.drawing.windowLevels.modalPanel)
    :windowCallback(function(action, _, state)
      if action == "focusChange" and state == false and self.visible then self:hide(false) end
    end)
  local page = readFile(opts.html)
  self.wv:html(page and Panel.inline(page) or ("<body>" .. opts.html .. " missing</body>"))
  table.insert(all, self)
  return self
end

function Panel:js(code)
  if self.ready then self.wv:evaluateJavaScript(code) end
end

function Panel:_frame(h)
  if self.opts.position then return self.opts.position(self, self.opts.w, h or self.opts.h) end
  local screen = (self.prevWin and self.prevWin:screen()) or hs.screen.mainScreen()
  local f = screen:frame()
  local w, hh = math.min(self.opts.w, f.w), math.min(h or self.opts.h, f.h)
  return { x = f.x + (f.w - w) / 2, y = f.y + math.max(0, (f.h - hh) * 0.36), w = w, h = hh }
end

-- Content-sized panels (the status popover) report their height; keep the top edge where it is.
function Panel:resize(h)
  self.opts.h = h
  if self.visible then self.wv:frame(self:_frame(h)) end
end

function Panel:_present()
  self.wv:frame(self:_frame())
  self.wv:evaluateJavaScript(Panel.themeJS())
  if self.opts.onShow then self.opts.onShow(self) end
  self.wv:show()
  self.wv:bringToFront(true)
  local win = self.wv:hswindow()
  if win then win:focus() end
end

function Panel:show()
  self.prevWin = hs.window.focusedWindow()
  self.prevApp = hs.application.frontmostApplication()
  self.visible = true
  self.hideSeq = (self.hideSeq or 0) + 1 -- cancels a pending delayed hide
  if self.ready then self:_present() else self.pendingOpen = true end
end

function Panel:hide(restoreFocus)
  if not self.visible then return end
  self.visible = false
  self.pendingOpen = false
  self:js("window.Panel && Panel.close && Panel.close()")
  -- Let the exit animation play (theme.css --dur-exit, 120 ms) before the window goes away. The
  -- sequence number cancels this hide when the panel is shown again in the meantime.
  self.hideSeq = (self.hideSeq or 0) + 1
  local seq = self.hideSeq
  self.hideTimer = hs.timer.doAfter(0.12, function()
    if self.hideSeq == seq and not self.visible then self.wv:hide() end
  end)
  if restoreFocus then
    if self.prevWin and self.prevWin:application() then self.prevWin:focus()
    elseif self.prevApp then self.prevApp:activate() end
  end
end

function Panel:toggle()
  if self.visible then self:hide(true) else self:show() end
end

return Panel
