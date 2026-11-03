-- Project opener panel: every git working copy under ~/Projects with branch, dirtiness and recency,
-- plus one-keystroke actions (VS Code, Terminal, GitHub Desktop, Finder). Bind M.toggle to a hotkey.
--
-- Scanning is asynchronous: bin/projects-scan.py streams NDJSON through one hs.task. The last result is
-- cached in hs.settings so the panel opens instantly and then refreshes in the background.
local Keep = require("keep")
local M = {}

local HOME = os.getenv("HOME")
local BASE = HOME .. "/.hammerspoon"
local ROOT = HOME .. "/Projects"
local HTML_FILE = BASE .. "/projects.html"
local SCAN_SCRIPT = BASE .. "/bin/projects-scan.py"
local GIT = "/usr/bin/git"
local PYTHON = "/usr/bin/python3"
local OPEN = "/usr/bin/open"
local W, H = 1060, 660
local MIN_RESCAN_SEC = 20   -- opening the panel again within this window does not rescan
local SCAN_TIMEOUT = 90     -- hard stop for a runaway scan

local K_CACHE, K_OPENS, K_PINS = "projects.cache.v1", "projects.opens.v1", "projects.pins.v1"

-- ---------------------------------------------------------------- state

local function loadMap(key)
  local v = hs.settings.get(key)
  return type(v) == "table" and v or {}
end

local opens = loadMap(K_OPENS) -- path -> epoch of the last open from this panel
local pins = loadMap(K_PINS)   -- path -> true

local current = {}   -- path -> project record (what the page shows)
local order = {}     -- paths, for stable iteration
local lastScan = 0   -- epoch of the last completed scan
local scanning = false
local scanTask, scanTimeout

do
  local cache = hs.settings.get(K_CACHE)
  if type(cache) == "table" and type(cache.list) == "table" then
    lastScan = cache.t or 0
    for _, p in ipairs(cache.list) do
      if type(p) == "table" and p.path then current[p.path] = p; table.insert(order, p.path) end
    end
  end
end

local function saveCache()
  local list = {}
  for _, path in ipairs(order) do if current[path] then table.insert(list, current[path]) end end
  hs.settings.set(K_CACHE, { t = lastScan, list = list })
end

-- ---------------------------------------------------------------- panel plumbing

local Panel = require("panel")
local panel = _G.__projectsPanel -- survives dofile() so the usercontent handler is registered only once
local pushTimer

local function buildItems()
  local out = {}
  for _, path in ipairs(order) do
    local p = current[path]
    if p then
      local copy = {}
      for k, v in pairs(p) do copy[k] = v end
      copy.opened = opens[path]
      copy.pinned = pins[path] or nil
      table.insert(out, copy)
    end
  end
  return out
end

local function pushItems(andOpen)
  if not panel then return end
  local json = hs.json.encode({ items = buildItems(), scanning = scanning })
  panel:js("Projects.setItems(" .. json .. ")" .. (andOpen and ";Projects.open()" or ""))
end

-- Coalesce bursts of scan updates into one page update.
local function pushSoon()
  if pushTimer or not (panel and panel.visible) then return end
  pushTimer = hs.timer.doAfter(0.2, function() pushTimer = nil; pushItems(false) end)
end

-- ---------------------------------------------------------------- scanning

local function finishScan(ok)
  scanning = false
  if scanTimeout then scanTimeout:stop(); scanTimeout = nil end
  scanTask = nil
  if ok then lastScan = os.time(); saveCache() end
  if panel and panel.visible then pushItems(false) end
end

local function startScan(force)
  if scanning then return end
  if not force and os.time() - lastScan < MIN_RESCAN_SEC then return end
  scanning = true
  local fresh, freshOrder, gotDone = {}, {}, false
  local buf = ""

  local function handleLine(line)
    local ok, msg = pcall(hs.json.decode, line)
    if not ok or type(msg) ~= "table" then return end
    if msg.type == "base" and type(msg.p) == "table" then
      local p = msg.p
      local old = current[p.path]
      p.dirty = old and old.dirty or nil -- keep the cached count until the slow phase reports
      fresh[p.path] = p
      table.insert(freshOrder, p.path)
    elseif msg.type == "phase" then
      -- Cheap phase finished: swap in the fresh list (copies that vanished from disk drop out).
      current, order = fresh, freshOrder
      pushSoon()
    elseif msg.type == "dirty" then
      local p = current[msg.path]
      if p then p.dirty = msg.dirty end
      pushSoon()
    elseif msg.type == "done" then
      gotDone = true
    end
  end

  scanTask = hs.task.new(PYTHON, function(code)
    -- Flush a trailing line without newline, if any.
    if buf ~= "" then handleLine(buf); buf = "" end
    finishScan(gotDone and code == 0)
  end, function(_, out)
    buf = buf .. (out or "")
    while true do
      local nl = buf:find("\n", 1, true)
      if not nl then break end
      handleLine(buf:sub(1, nl - 1))
      buf = buf:sub(nl + 1)
    end
    return true
  end, { SCAN_SCRIPT, ROOT })

  if not scanTask or not scanTask:start() then
    scanning = false; scanTask = nil
    return
  end
  scanTimeout = hs.timer.doAfter(SCAN_TIMEOUT, function()
    if scanTask then scanTask:terminate() end
  end)
  if panel and panel.visible then panel:js("Projects.setScanning(true)") end
end

-- ---------------------------------------------------------------- per-project commit log

local logCache = {} -- path -> { sha = ..., commits = {...} }
local logBusy = {}

local function sendLog(path, sha, commits)
  panel:js(string.format("Projects.log(%s,%s,%s)", hs.json.encode({ path })  :sub(2, -2),
    hs.json.encode({ sha or "" }):sub(2, -2), #commits > 0 and hs.json.encode(commits) or "[]"))
end

local function fetchLog(path, sha)
  local c = logCache[path]
  if c and c.sha == sha then return sendLog(path, sha, c.commits) end
  if logBusy[path] then return end
  logBusy[path] = true
  local t = Keep.task(GIT, function(_, out)
    logBusy[path] = nil
    local commits = {}
    for line in (out or ""):gmatch("[^\n]+") do
      local h, ct, author, subject = line:match("^(.-)\31(.-)\31(.-)\31(.*)$")
      if h then table.insert(commits, { sha = h, t = tonumber(ct), author = author, subject = subject }) end
    end
    logCache[path] = { sha = sha, commits = commits }
    if panel then sendLog(path, sha, commits) end
  end, { "--no-optional-locks", "-C", path, "log", "-5", "--format=%h%x1f%ct%x1f%an%x1f%s" })
  if not t then logBusy[path] = nil end
end

-- ---------------------------------------------------------------- actions from the page

-- Only act on directories that really sit directly under ~/Projects.
local function validPath(path)
  if type(path) ~= "string" or path:sub(1, #ROOT + 1) ~= ROOT .. "/" then return false end
  if path:find("/", #ROOT + 2, true) or path:find("..", 1, true) then return false end
  local a = hs.fs.attributes(path)
  return a ~= nil and a.mode == "directory"
end

local function run(args)
  -- No print() here: async callbacks must not write to a possibly dead hs.ipc client.
  Keep.task(OPEN, nil, args)
end

local function recordOpen(path)
  opens[path] = os.time()
  hs.settings.set(K_OPENS, opens)
end

local function launch(p, path, args)
  recordOpen(path)
  p:hide(false)
  run(args)
end

local function handle(p, msg)
  local a, path = msg.action, msg.path
  if a == "refresh" then
    startScan(true)
    p:js("Projects.toast('Yenileniyor…')")
    return
  end
  if not validPath(path) then return end
  if a == "log" then
    fetchLog(path, msg.sha or "")
  elseif a == "vscode" then
    launch(p, path, { "-b", "com.microsoft.VSCode", path })
  elseif a == "terminal" then
    launch(p, path, { "-a", "Terminal", path })
  elseif a == "github" then
    launch(p, path, { "-a", "GitHub Desktop", path })
  elseif a == "reveal" then
    p:hide(false)
    run({ "-R", path })
  elseif a == "copy" then
    -- Goes through the normal pasteboard path on purpose: the path should land in clipboard history.
    hs.pasteboard.setContents(path)
    p:js("Projects.toast('Yol kopyalandı')")
  elseif a == "pin" then
    pins[path] = (not pins[path]) or nil
    hs.settings.set(K_PINS, pins)
    pushItems(false)
  end
end

-- ---------------------------------------------------------------- public API

local function onShow()
  pushItems(true)
  startScan(false)
end

if panel then
  -- Re-loaded module: reuse the existing webview, only rebind the callbacks (Panel reads opts at call time).
  panel.opts.onMessage = handle
  panel.opts.onShow = onShow
else
  panel = Panel.new({ name = "projects", html = HTML_FILE, w = W, h = H, onMessage = handle, onShow = onShow })
  _G.__projectsPanel = panel
end

M.panel = panel

function M.toggle() panel:toggle() end

-- Force a background rescan (e.g. from the console).
function M.refresh() startScan(true) end

return M
