-- Project opener panel: every git working copy under ~/Projects with branch, dirtiness and recency,
-- plus one-keystroke actions (VS Code, Terminal, GitHub Desktop, Finder) and git sync: pull one repo,
-- pull every clean repo that is behind, fetch all remotes. Bind M.toggle to a hotkey.
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

local FETCH_TIMEOUT, FETCH_PARALLEL = 20, 4   -- per repo seconds / simultaneous `git fetch` processes
local PULL_TIMEOUT, PULL_PARALLEL = 60, 3     -- per repo seconds / simultaneous `git pull` processes

local K_CACHE, K_OPENS, K_PINS = "projects.cache.v1", "projects.opens.v1", "projects.pins.v1"
local K_FETCHED = "projects.fetched.v1"

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
local pendingRescan = false -- a pull / fetch finished while a scan was running: scan again afterwards

-- Git sync state shown by the page (buttons spin / read "Çekiliyor…").
local lastFetch = tonumber(hs.settings.get(K_FETCHED)) or 0 -- epoch of the last "Uzaktan Kontrol Et"
local fetching, pullAllBusy = false, false
local pullBusy = {} -- path -> true while a `git pull` runs in it

local function busyState()
  local pulling = {}
  for path in pairs(pullBusy) do table.insert(pulling, path) end
  return { fetching = fetching, pullAll = pullAllBusy, pulling = pulling, fetched = lastFetch }
end

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
  local json = hs.json.encode({ items = buildItems(), scanning = scanning, busy = busyState() })
  panel:js("Projects.setItems(" .. json .. ")" .. (andOpen and ";Projects.open()" or ""))
end

local function pushBusy()
  if panel then panel:js("Projects.setBusy(" .. hs.json.encode(busyState()) .. ")") end
end

-- Result toast; kind is "ok" or "err". Falls back to a system alert when the panel is closed.
local function toast(msg, kind)
  if panel and panel.visible then
    panel:js(string.format("Projects.toast(%s,%s)", hs.json.encode({ msg }):sub(2, -2), hs.json.encode({ kind or "ok" }):sub(2, -2)))
  else
    hs.alert.show(msg, 2.5)
  end
end

-- Coalesce bursts of scan updates into one page update.
local function pushSoon()
  if pushTimer or not (panel and panel.visible) then return end
  pushTimer = hs.timer.doAfter(0.2, function() pushTimer = nil; pushItems(false) end)
end

-- ---------------------------------------------------------------- scanning

local startScan

local function finishScan(ok)
  scanning = false
  if scanTimeout then scanTimeout:stop(); scanTimeout = nil end
  scanTask = nil
  if ok then lastScan = os.time(); saveCache() end
  if panel and panel.visible then pushItems(false) end
  if pendingRescan then pendingRescan = false; M.refresh() end
end

function startScan(force)
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

  scanTask = hs.task.new("/usr/bin/nice", function(code) -- low CPU priority
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
  end, { "-n", "10", PYTHON, SCAN_SCRIPT, ROOT })

  if not scanTask or not scanTask:start() then
    scanning = false; scanTask = nil
    return
  end
  scanTimeout = hs.timer.doAfter(SCAN_TIMEOUT, function()
    if scanTask then scanTask:terminate() end
  end)
  if panel and panel.visible then panel:js("Projects.setScanning(true)") end
end

-- Only act on directories that really sit directly under ~/Projects.
local function validPath(path)
  if type(path) ~= "string" or path:sub(1, #ROOT + 1) ~= ROOT .. "/" then return false end
  if path:find("/", #ROOT + 2, true) or path:find("..", 1, true) then return false end
  local a = hs.fs.attributes(path)
  return a ~= nil and a.mode == "directory"
end

local rescanTasks = {}

-- Rescan only some repos (after a pull) instead of the whole tree; results merge into the current list.
local function rescanRepos(paths)
  if scanning then pendingRescan = true; return end -- the full scan that follows covers them
  local args = { "-n", "10", PYTHON, SCAN_SCRIPT, ROOT }
  for _, path in ipairs(paths) do table.insert(args, (path:match("[^/]+$"))) end
  local buf = ""
  local function handleLine(line)
    local ok, msg = pcall(hs.json.decode, line)
    if not ok or type(msg) ~= "table" then return end
    if msg.type == "base" and type(msg.p) == "table" then
      local p = msg.p
      local old = current[p.path]
      p.dirty = old and old.dirty or nil -- keep the cached count until the slow phase reports
      if not old then table.insert(order, p.path) end
      current[p.path] = p
      pushSoon()
    elseif msg.type == "dirty" then
      local p = current[msg.path]
      if p then p.dirty = msg.dirty end
      pushSoon()
    end
  end
  local t
  t = hs.task.new("/usr/bin/nice", function()
    rescanTasks[t] = nil
    if buf ~= "" then handleLine(buf); buf = "" end
    saveCache()
    if panel and panel.visible then pushItems(false) end
  end, function(_, out)
    buf = buf .. (out or "")
    while true do
      local nl = buf:find("\n", 1, true)
      if not nl then break end
      handleLine(buf:sub(1, nl - 1))
      buf = buf:sub(nl + 1)
    end
    return true
  end, args)
  if not t then return end
  rescanTasks[t] = true -- keeps the task referenced until it exits
  if not t:start() then rescanTasks[t] = nil; return end
  Keep.after(SCAN_TIMEOUT, function() if t:isRunning() then t:terminate() end end)
end

local function rescanAll()
  if scanning then pendingRescan = true else startScan(true) end
end

-- ---------------------------------------------------------------- git sync (pull / fetch)

local function nameOf(path) return path:match("[^/]+$") or path end

-- Runs `git -C <path> <args>` without ever waiting on a credential prompt; kills it after `timeout` seconds.
-- cb(exitCode, stdout, stderr, timedOut). Returns false when the process could not be started.
local function gitTask(path, args, timeout, cb)
  local done, timedOut, t = false, false, nil
  local full = { "GIT_TERMINAL_PROMPT=0", GIT, "-C", path }
  for _, a in ipairs(args) do table.insert(full, a) end
  t = Keep.task("/usr/bin/env", function(code, out, err)
    done = true
    cb(code, out or "", err or "", timedOut)
  end, full)
  if not t then return false end
  Keep.after(timeout, function()
    if not done and t:isRunning() then timedOut = true; t:terminate() end
  end)
  return true
end

-- Short Turkish reason from git's stderr: known failures are translated, otherwise the first meaningful line.
local function gitError(stderr, code)
  local fallback
  for line in (stderr or ""):gmatch("[^\r\n]+") do
    local low = line:lower()
    if low:find("not possible to fast-forward", 1, true) or low:find("diverging branches", 1, true)
        or low:find("cannot fast-forward", 1, true) then
      return "ileri sarma mümkün değil (dallar ayrışmış)"
    elseif low:find("would be overwritten by merge", 1, true) or low:find("would be overwritten by checkout", 1, true) then
      return "yerel değişiklik çakışıyor"
    elseif low:find("no tracking information", 1, true) or low:find("no upstream", 1, true) then
      return "uzak dal tanımlı değil"
    end
    if not fallback and not low:match("^%s") and not low:match("^hint:") and not low:match("^from ")
        and not low:match("^remote:") and not low:match("^aborting") and not low:match("^please ") then
      fallback = line:gsub("^fatal:%s*", ""):gsub("^error:%s*", "")
    end
  end
  if not fallback or fallback == "" then return "git hata verdi (kod " .. tostring(code) .. ")" end
  local n = utf8.len(fallback)
  if n and n > 90 then fallback = fallback:sub(1, utf8.offset(fallback, 91) - 1) .. "…" end
  return fallback
end

-- Fast-forward-only pull; cb(ok, message, alreadyUpToDate).
local function pullRepo(path, cb)
  local started = gitTask(path, { "pull", "--ff-only", "--no-rebase" }, PULL_TIMEOUT, function(code, out, err, timedOut)
    if timedOut then return cb(false, "zaman aşımı") end
    if code ~= 0 then return cb(false, gitError(err ~= "" and err or out, code)) end
    cb(true, nil, out:find("Already up to date", 1, true) ~= nil or out:find("Already up-to-date", 1, true) ~= nil)
  end)
  if not started then cb(false, "git başlatılamadı") end
end

-- Runs worker(item, release) over items with at most `limit` in flight; every worker must call release() once.
local function runPool(items, limit, worker, onDone)
  local n, nextI, active, finished = #items, 0, 0, 0
  if n == 0 then return onDone() end
  local pump
  pump = function()
    while active < limit and nextI < n do
      nextI = nextI + 1
      active = active + 1
      local called = false
      local function release()
        if called then return end
        called = true
        active = active - 1
        finished = finished + 1
        if finished == n then onDone() else pump() end
      end
      if not pcall(worker, items[nextI], release) then release() end
    end
  end
  pump()
end

local function pullOne(path)
  if pullBusy[path] then return end
  pullBusy[path] = true
  pushBusy()
  local name = nameOf(path)
  pullRepo(path, function(ok, msg, upToDate)
    pullBusy[path] = nil
    pushBusy()
    if ok then
      toast(name .. (upToDate and " zaten güncel" or " güncellendi"), "ok")
      rescanRepos({ path })
    else
      toast(name .. ": " .. msg, "err")
    end
  end)
end

-- `git fetch --quiet --prune` in every repo, a few at a time, then a full rescan.
local function fetchAll()
  if fetching then return end
  local paths = {}
  for _, path in ipairs(order) do
    if current[path] and validPath(path) then table.insert(paths, path) end
  end
  fetching = true
  pushBusy()
  local failed = 0
  runPool(paths, FETCH_PARALLEL, function(path, release)
    local started = gitTask(path, { "fetch", "--quiet", "--prune" }, FETCH_TIMEOUT, function(code, _, _, timedOut)
      if code ~= 0 or timedOut then failed = failed + 1 end
      release()
    end)
    if not started then failed = failed + 1; release() end
  end, function()
    fetching = false
    lastFetch = os.time()
    hs.settings.set(K_FETCHED, lastFetch)
    pushBusy()
    if failed > 0 then
      toast("Kontrol tamamlandı, " .. failed .. " repo kontrol edilemedi", "err")
    else
      toast("Uzaktan kontrol tamamlandı", "ok")
    end
    rescanAll()
  end)
end

local SKIP_DIRTY, SKIP_AHEAD, SKIP_UNKNOWN = "commit’lenmemiş değişiklik var", "push edilmemiş commit var", "durumu henüz bilinmiyor"

-- Pulls every repo that is behind AND clean AND has nothing unpushed (so a fast-forward cannot conflict).
local function pullAll()
  if pullAllBusy then return end
  local todo, skipped, skipCount = {}, { [SKIP_UNKNOWN] = 0, [SKIP_DIRTY] = 0, [SKIP_AHEAD] = 0 }, 0
  local function skip(reason) skipped[reason] = skipped[reason] + 1; skipCount = skipCount + 1 end
  for _, path in ipairs(order) do
    local p = current[path]
    if p and (p.behind or 0) > 0 and not pullBusy[path] and validPath(path) then
      if p.dirty == nil then skip(SKIP_UNKNOWN)
      elseif p.dirty > 0 then skip(SKIP_DIRTY)
      elseif (p.ahead or 0) > 0 then skip(SKIP_AHEAD)
      else table.insert(todo, path) end
    end
  end
  local reasons = {}
  for _, r in ipairs({ SKIP_DIRTY, SKIP_AHEAD, SKIP_UNKNOWN }) do
    if skipped[r] > 0 then table.insert(reasons, r) end
  end
  local skipText = skipCount .. " atlandı: " .. table.concat(reasons, "; ")
  if #todo == 0 then
    if skipCount > 0 then toast("Çekilecek temiz repo yok, " .. skipText, "err") else toast("Güncellenecek repo yok", "ok") end
    return
  end
  pullAllBusy = true
  for _, path in ipairs(todo) do pullBusy[path] = true end
  pushBusy()
  local okCount, failures, updated = 0, {}, {}
  runPool(todo, PULL_PARALLEL, function(path, release)
    pullRepo(path, function(ok, msg)
      pullBusy[path] = nil
      if ok then okCount = okCount + 1; table.insert(updated, path)
      else table.insert(failures, nameOf(path) .. ": " .. msg) end
      pushBusy()
      release()
    end)
  end, function()
    pullAllBusy = false
    pushBusy()
    local parts = {}
    if okCount > 0 then table.insert(parts, okCount .. " repo güncellendi") end
    if skipCount > 0 then table.insert(parts, skipText) end
    if #failures > 0 then
      table.insert(parts, #failures .. " çekilemedi" .. (#failures == 1 and (" (" .. failures[1] .. ")") or ""))
    end
    toast(table.concat(parts, ", "), (#failures > 0 or okCount == 0) and "err" or "ok")
    if #updated > 0 then rescanRepos(updated) end
  end)
end

-- ---------------------------------------------------------------- per-project commit log

local LOG_COUNT = 8
local logCache = {} -- path -> { sha = ..., commits = {...} }
local logBusy = {}
local wtBusy = {}

local function sendLog(path, sha, commits)
  panel:js(string.format("Projects.log(%s,%s,%s)", hs.json.encode({ path })  :sub(2, -2),
    hs.json.encode({ sha or "" }):sub(2, -2), #commits > 0 and hs.json.encode(commits) or "[]"))
end

-- "3 files changed, 10 insertions(+), 2 deletions(-)"; either count is left out when it is zero.
local function shortstat(line)
  return {
    files = tonumber(line:match("(%d+) files? changed")) or 0,
    added = tonumber(line:match("(%d+) insertions?")) or 0,
    deleted = tonumber(line:match("(%d+) deletions?")) or 0,
  }
end

-- user.name / user.email of a repo (cached for ten minutes), used to mark the user's own commits.
local idCache = {}
local function identityOf(path, cb)
  local c = idCache[path]
  if c and os.time() - c.t < 600 then return cb(c) end
  local started = Keep.task(GIT, function(_, out)
    local id = { t = os.time(), name = "", email = "" }
    for line in (out or ""):gmatch("[^\n]+") do
      local k, v = line:match("^(%S+)%s+(.*)$")
      if k == "user.name" then id.name = v elseif k == "user.email" then id.email = v end
    end
    idCache[path] = id
    cb(id)
  end, { "-C", path, "config", "--get-regexp", "^user\\.(name|email)$" })
  if not started then cb({ t = 0, name = "", email = "" }) end
end

local function fetchLog(path, sha)
  local c = logCache[path]
  if c and c.sha == sha then return sendLog(path, sha, c.commits) end
  if logBusy[path] then return end
  logBusy[path] = true
  identityOf(path, function(id)
    -- Each record starts with \30; the --shortstat line follows it (missing for empty commits). Merge commits
    -- are left out on purpose: they would credit a whole merged PR (and its lines) to whoever pressed merge,
    -- so every listed commit shows its real author and its own lines.
    local t = Keep.task(GIT, function(_, out)
      logBusy[path] = nil
      local commits = {}
      local myEmail, myName = id.email:lower(), id.name
      for rec in (out or ""):gmatch("\30([^\30]*)") do
        local head, rest = rec:match("^([^\n]*)\n?(.*)$")
        local h, ct, author, email, subject = head:match("^(.-)\31(.-)\31(.-)\31(.-)\31(.*)$")
        if h then
          local c = { sha = h, t = tonumber(ct), author = author, subject = subject }
          if (myEmail ~= "" and email:lower() == myEmail) or (myName ~= "" and author == myName) then c.mine = true end
          local st = rest:match("[^\n]*changed[^\n]*")
          if st then local s = shortstat(st); c.files, c.added, c.deleted = s.files, s.added, s.deleted end
          table.insert(commits, c)
        end
      end
      logCache[path] = { sha = sha, commits = commits }
      if panel then sendLog(path, sha, commits) end
    end, { "--no-optional-locks", "-C", path, "log", "-" .. LOG_COUNT, "--shortstat", "--no-merges",
      "--format=%x1e%h%x1f%ct%x1f%an%x1f%ae%x1f%s" })
    if not t then logBusy[path] = nil end
  end)
end

-- Uncommitted lines against HEAD (staged + unstaged) and the untracked files next to them.
-- Not cached: it changes without HEAD moving, and the page only asks while the project is dirty.
local WT_SCRIPT = [[
"$0" -C "$1" --no-optional-locks diff HEAD --numstat 2>/dev/null
echo "--untracked--"
"$0" -C "$1" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null | /usr/bin/wc -l
]]
local function fetchWorktree(path)
  if wtBusy[path] then return end
  wtBusy[path] = true
  local t = Keep.task("/bin/sh", function(_, out)
    wtBusy[path] = nil
    local wt, tracked, untracked = { files = 0, added = 0, deleted = 0, binary = 0 }, true, 0
    for line in (out or ""):gmatch("[^\n]+") do
      if line == "--untracked--" then tracked = false
      elseif tracked then
        local a, d = line:match("^(%S+)\t(%S+)\t")
        if a then
          wt.files = wt.files + 1
          if a == "-" then wt.binary = wt.binary + 1
          else wt.added, wt.deleted = wt.added + (tonumber(a) or 0), wt.deleted + (tonumber(d) or 0) end
        end
      else untracked = tonumber(line:match("%d+")) or 0 end
    end
    wt.untracked = untracked
    if panel then
      panel:js(string.format("Projects.worktree(%s,%s)", hs.json.encode({ path }):sub(2, -2), hs.json.encode(wt)))
    end
  end, { "-c", WT_SCRIPT, GIT, path })
  if not t then wtBusy[path] = nil end
end

-- ---------------------------------------------------------------- actions from the page

local function shellQuote(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
-- An AppleScript string literal.
local function asString(s) return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"' end

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
  if msg.action == "url" then
    -- Only GitHub links from the "Bugün" strip are opened.
    if type(msg.url) == "string" and msg.url:match("^https://github%.com/") then p:hide(false); hs.urlevent.openURL(msg.url) end
    return
  end
  local a, path = msg.action, msg.path
  if a == "history" then
    -- Every commit of the last 90 days, written by bin/dev-stats.py; read only when the history opens.
    local f = io.open(HOME .. "/Library/Caches/nimbstia/dev-stats-history.json", "r")
    local raw = f and f:read("a") or nil
    if f then f:close() end
    local ok, d = pcall(hs.json.decode, raw or "")
    p:js("Projects.history(" .. ((ok and type(d) == "table") and raw or "null") .. ")") -- valid JSON is a JS literal
    return
  end
  if a == "refresh" then
    startScan(true)
    p:js("Projects.toast('Yenileniyor…')")
    return
  end
  if a == "fetch" then return fetchAll() end
  if a == "pullAll" then return pullAll() end
  if not validPath(path) then return end
  if a == "pull" then
    pullOne(path)
  elseif a == "log" then
    fetchLog(path, msg.sha or "")
    if msg.dirty then fetchWorktree(path) end
  elseif a == "vscode" then
    launch(p, path, { "-b", "com.microsoft.VSCode", path })
  elseif a == "claude" then
    -- a new Terminal window in the repo with Claude Code started in it
    recordOpen(path)
    p:hide(false)
    local cmd = "cd " .. shellQuote(path) .. " && claude"
    hs.osascript.applescript('tell application "Terminal"\n  activate\n  do script ' .. asString(cmd) .. '\nend tell')
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
  -- Today's GitHub numbers come from the Nimbstia hub (status.lua / bin/dev-stats.py).
  if Status and Status.githubData then
    local g = Status.githubData()
    if g then panel:js("Projects.setGitHub(" .. hs.json.encode(g) .. ")") end
    Status.fetchDevStats(false)
  end
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
