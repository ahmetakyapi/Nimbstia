-- Small productivity tools: app hotkeys, OCR, text transforms, snippets (⌃⌥S), Jira opener.
-- Call M.start() once from init.lua; every hotkey is listed in M.HELP (shown in the status menu).
local Keep = require("keep")
local PB = require("pb")
local UI = require("ui")
local Config = require("config")
local M = {}

local HOME = os.getenv("HOME")
local BIN = HOME .. "/.hammerspoon/bin"
local TMP = HOME .. "/.hammerspoon/clipdata"
local PY = "/usr/bin/python3"
local HYPER = { "ctrl", "alt", "cmd" }
local MOD = { "ctrl", "alt" }

M.HELP = {}
local function bind(mods, key, label, fn)
  hs.hotkey.bind(mods, key, fn)
  local names = { cmd = "⌘", ctrl = "⌃", alt = "⌥", shift = "⇧" }
  local order, s = { "ctrl", "alt", "shift", "cmd" }, ""
  for _, m in ipairs(order) do for _, x in ipairs(mods) do if x == m then s = s .. names[m] end end end
  table.insert(M.HELP, { keys = s .. (key:len() == 1 and key:upper() or key), label = label })
end

local function pausedClip(sec) if Clip and Clip.pause then Clip.pause(sec) end end

-- Read the current selection by sending ⌘C; the pasteboard is restored afterwards and the
-- temporary copy stays out of the clipboard history. Slow apps (Teams, Outlook, Electron) answer
-- ⌘C late, so the change is polled instead of checked once. cb(selectionOrNil, clipboardTextOrNil);
-- the clipboard text is nil when it holds a password-manager secret.
local function withSelection(cb)
  local before = hs.pasteboard.changeCount()
  local saved = PB.save()
  pausedClip(1.5)
  hs.eventtap.keyStroke({ "cmd" }, "c", 0)
  PB.waitChange(before, 0.6, function(changed)
    local sel = nil
    if changed then
      sel = (not PB.currentIsSecret()) and hs.pasteboard.getContents() or nil
      pausedClip(0.5)
      PB.restore(saved)
    end
    if sel == "" then sel = nil end
    local clip = (not saved.secret) and hs.pasteboard.getContents() or nil
    cb(sel, clip)
  end)
end

-- ---------------------------------------------------------------- app hotkeys (⌃⌥⌘ + letter)

M.APPS = {
  { key = "v", bid = "com.microsoft.VSCode",           name = "VS Code" },
  { key = "c", bid = "com.google.Chrome",              name = "Chrome" },
  { key = "a", bid = "com.anthropic.claudefordesktop", name = "Claude" },
  { key = "t", bid = "com.microsoft.teams2",           name = "Teams" },
  { key = "x", bid = "com.apple.Terminal",             name = "Terminal" },
  { key = "o", bid = "com.microsoft.Outlook",          name = "Outlook" },
  { key = "w", bid = "net.whatsapp.WhatsApp",          name = "WhatsApp" },
  { key = "g", bid = "com.github.GitHubClient",        name = "GitHub Desktop" },
  { key = "f", bid = "com.apple.finder",               name = "Finder" },
}

-- First press brings the app forward; pressing again while it is in front cycles its windows.
local function focusApp(a)
  return function()
    local app = hs.application.get(a.bid)
    if not app then hs.application.launchOrFocusByBundleID(a.bid); return end
    local wins = {}
    for _, w in ipairs(app:allWindows()) do if w:isStandard() then table.insert(wins, w) end end
    table.sort(wins, function(x, y) return x:id() < y:id() end)
    local front = hs.application.frontmostApplication()
    if front and front:bundleID() == a.bid and #wins > 1 then
      local cur = hs.window.focusedWindow()
      local i = 1
      for k, w in ipairs(wins) do if cur and w:id() == cur:id() then i = k end end
      local nextWin = wins[i % #wins + 1]
      if nextWin:isMinimized() then nextWin:unminimize() end
      nextWin:focus()
    else
      app:unhide()
      app:activate(true)
      if #wins == 0 then hs.application.launchOrFocusByBundleID(a.bid) end
    end
  end
end

-- ---------------------------------------------------------------- OCR (⌃⇧O)

local function ocr()
  local img = TMP .. "/ocr-" .. os.time() .. ".png"
  Keep.task("/usr/sbin/screencapture", function()
    if not hs.fs.attributes(img) then return end -- selection cancelled
    hs.alert.show("Metin okunuyor…", 0.6)
    Keep.task("/usr/bin/osascript", function(code, out)
      os.remove(img)
      local text = (out or ""):gsub("%s+$", "")
      if code ~= 0 or text == "" then hs.alert.show("Seçilen alanda metin bulunamadı", 1.2); return end
      hs.pasteboard.setContents(text)
      local lines = select(2, text:gsub("\n", "")) + 1
      local first = text:match("[^\n]*"):sub(1, 60)
      hs.alert.show("Metin kopyalandı · " .. lines .. " satır\n" .. first, 1.6)
    end, { "-l", "JavaScript", BIN .. "/ocr.js", img })
  end, { "-i", "-x", img })
end

-- ---------------------------------------------------------------- text transforms (⌃⌥T)

local chooser
local transformCtx = {}

local function oneLine(s)
  s = s:gsub("%s+", " ")
  if utf8.len(s) and utf8.len(s) > 90 then s = s:sub(1, utf8.offset(s, 90) - 1) .. "…" end
  return s
end

local function applyTransform(choice)
  if not choice then return end
  local result = choice.result
  local cmdHeld = hs.eventtap.checkKeyboardModifiers().cmd
  if transformCtx.fromSelection and not cmdHeld then
    hs.pasteboard.setContents(result)
    -- The chooser hands focus back to the previous app first; paste only after that.
    Keep.after(0.15, function() hs.eventtap.keyStroke({ "cmd" }, "v", 0) end)
  else
    hs.pasteboard.setContents(result)
    hs.alert.show("Sonuç panoda: " .. oneLine(result), 1.2)
  end
end

local function transform()
  withSelection(function(sel, clip)
    local input = sel or clip or ""
    transformCtx = { fromSelection = sel ~= nil }
    local inFile = TMP .. "/transform-in.txt"
    local f = io.open(inFile, "wb")
    if not f then hs.alert.show("Dönüştürücü çalışmadı", 1); return end
    f:write(input); f:close()
    Keep.task(PY, function(code, out, err)
      os.remove(inFile) -- the input may be sensitive; never leave it on disk
      if code ~= 0 then hs.alert.show("Dönüştürücü çalışmadı", 1); print(err); return end
      local ok, list = pcall(hs.json.decode, out)
      if not ok or type(list) ~= "table" then return end
      local choices = {}
      for _, x in ipairs(list) do
        table.insert(choices, { text = x.label, subText = oneLine(x.result), result = x.result, id = x.id })
      end
      chooser:choices(choices)
      -- Only the size of the input is shown, never its content.
      local size = (utf8.len(input) or #input) .. " karakter"
      chooser:placeholderText(sel and ("Seçili metin · " .. size) or
        (input ~= "" and ("Panodaki metin · " .. size) or "Üretici seç…"))
      UI.styleChooser(chooser):show()
    end, { BIN .. "/transform.py", TMP .. "/transform-in.txt" })
  end)
end

-- ---------------------------------------------------------------- snippets (";key" + ⌃⌥;)

local snippets = {}
-- Invalid entries (typos in the user-edited file) are skipped instead of breaking expansion.
local function loadSnippets()
  local ok, list = pcall(dofile, HOME .. "/.hammerspoon/snippets.lua")
  snippets = {}
  if not ok or type(list) ~= "table" then
    if not ok then hs.alert.show("snippets.lua okunamadı: " .. tostring(list):sub(1, 80), 3) end
    return
  end
  for _, s in ipairs(list) do
    if type(s) == "table" and type(s.key) == "string" and #s.key > 1 and
       (type(s.text) == "string" or type(s.text) == "function") then
      s.label = type(s.label) == "string" and s.label or s.key
      table.insert(snippets, s)
    end
  end
end
-- Returns the snippet text or nil (a text() function that fails or returns a non-string).
local function snippetText(s)
  if type(s.text) ~= "function" then return s.text end
  local ok, v = pcall(s.text)
  return (ok and type(v) == "string") and v or nil
end

local expanding = false
-- Paste `text` through the pasteboard, then put the previous contents back. The restore waits
-- long enough for slow apps to have read the pasteboard.
local function insertText(text)
  local saved = PB.save()
  pausedClip(2)
  hs.pasteboard.setContents(text)
  hs.eventtap.keyStroke({ "cmd" }, "v", 0)
  Keep.after(0.8, function() pausedClip(0.5); PB.restore(saved); expanding = false end)
end

local buffer = ""
local RESET_KEYS = { ["return"] = true, tab = true, escape = true, left = true, right = true, up = true, down = true,
  home = true, ["end"] = true, pageup = true, pagedown = true, padenter = true }

local T = hs.eventtap.event.types
M.snipTap = hs.eventtap.new({ T.keyDown, T.leftMouseDown, T.rightMouseDown }, function(e)
  if e:getType() ~= T.keyDown then buffer = ""; return false end -- a click moves the caret elsewhere
  if expanding then return false end
  local f = e:getFlags()
  if f.cmd or f.ctrl then buffer = ""; return false end
  local key = hs.keycodes.map[e:getKeyCode()]
  if key == "delete" then buffer = buffer:sub(1, -2); return false end
  if RESET_KEYS[key] then buffer = ""; return false end
  local ch = e:getCharacters()
  if not ch or ch == "" then return false end
  buffer = (buffer .. ch):sub(-40)
  for _, s in ipairs(snippets) do
    if buffer:sub(-#s.key) == s.key then
      buffer = ""
      local text = snippetText(s)
      if not text then return false end -- broken snippet: let the key through, change nothing
      expanding = true
      local n = (utf8.len(s.key) or #s.key) - 1 -- the last character has not been typed yet; we swallow it
      Keep.after(0, function()
        for _ = 1, n do hs.eventtap.keyStroke({}, "delete", 0) end
        insertText(text)
      end)
      return true
    end
  end
  return false
end)

local snipChooser
local function pickSnippet()
  loadSnippets()
  local choices = {}
  for _, s in ipairs(snippets) do
    table.insert(choices, { text = s.label .. "   " .. s.key, subText = oneLine(snippetText(s) or "(hatalı şablon)"), key = s.key })
  end
  snipChooser:choices(choices)
  UI.styleChooser(snipChooser):show()
end

-- ---------------------------------------------------------------- Jira (⌃⌥J)

local JIRA = Config.jiraBase
-- Look-alikes that are not issue keys (UTF-8, ISO-8859, SHA-256…). With config.jiraProjects
-- (e.g. { "ABC", "OPS" }) only those prefixes count.
local NOT_KEYS = { UTF = true, ISO = true, SHA = true, RFC = true, HTTP = true, TLS = true, SSL = true,
  MD = true, IPV = true, ES = true, WIN = true, X = true, A = true, B = true }
local function findIssueKey(text)
  local allow
  if type(Config.jiraProjects) == "table" then
    allow = {}
    for _, p in ipairs(Config.jiraProjects) do allow[p:upper()] = true end
  end
  for prefix, num in text:upper():gmatch("%f[%w]([A-Z][A-Z0-9]+)%-(%d+)%f[^%w]") do
    if (allow and allow[prefix]) or (not allow and not NOT_KEYS[prefix]) then return prefix .. "-" .. num end
  end
  return nil
end
local function openJira()
  if not JIRA then hs.alert.show("Jira adresi ayarlı değil: config.local.lua → jiraBase", 2); return end
  withSelection(function(sel, clip)
    local key = findIssueKey((sel or "") .. " " .. (clip or ""))
    if key then hs.urlevent.openURL(JIRA .. key); hs.alert.show("Jira: " .. key, 0.8)
    else hs.alert.show("Seçimde ya da panoda Jira anahtarı yok", 1) end
  end)
end

-- ---------------------------------------------------------------- start

function M.start()
  hs.fs.mkdir(TMP) -- OCR and transforms use it even when the clipboard module is not loaded
  loadSnippets()
  chooser = hs.chooser.new(applyTransform)
    :searchSubText(true):rows(10):width(36)
  snipChooser = hs.chooser.new(function(c)
    if not c then return end
    for _, s in ipairs(snippets) do
      if s.key == c.key then
        local text = snippetText(s)
        if not text then hs.alert.show("Bu şablon hatalı: snippets.lua", 1.5); break end
        expanding = true
        Keep.after(0.15, function() insertText(text) end)
        break
      end
    end
  end):searchSubText(true):rows(10):width(36):placeholderText("Şablon seç…")

  for _, a in ipairs(M.APPS) do bind(HYPER, a.key, "Hopstia · " .. a.name, focusApp(a)) end
  bind({ "ctrl", "shift" }, "o", "Lexstia · Ekrandan Metin Oku", ocr)
  bind(MOD, "t", "Twistia · Metni Dönüştür (JSON, Base64, Tarih…)", transform)
  bind(MOD, "s", "Snipstia · Şablon Seç (ya da ;anahtar)", pickSnippet)
  bind(MOD, "j", "Jira Anahtarını Aç", openJira)
  M.snipTap:start()
end

M.reloadSnippets = loadSnippets
M.ocr = ocr
M._findIssueKey = findIssueKey -- exposed for tests
return M
