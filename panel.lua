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

local function readFile(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local d = f:read("a"); f:close()
  return d
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
  self.wv:html(readFile(opts.html) or ("<body>" .. opts.html .. " missing</body>"))
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
  if self.ready then self:_present() else self.pendingOpen = true end
end

function Panel:hide(restoreFocus)
  if not self.visible then return end
  self.visible = false
  self.pendingOpen = false
  self:js("window.Panel && Panel.close && Panel.close()")
  self.wv:hide()
  if restoreFocus then
    if self.prevWin and self.prevWin:application() then self.prevWin:focus()
    elseif self.prevApp then self.prevApp:activate() end
  end
end

function Panel:toggle()
  if self.visible then self:hide(true) else self:show() end
end

return Panel
