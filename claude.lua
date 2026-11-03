-- Claude usage for the status menu: plan limits and open Claude Code sessions, read from the files
-- Claude Code itself keeps up to date (~/.claude.json → cachedUsageUtilization, ~/.claude/sessions/*.json).
-- Read-only, local, no network. Parsing is cached by file modification time.
local M = {}

local HOME = os.getenv("HOME")
local STATE = HOME .. "/.claude.json"
local SESSIONS = HOME .. "/.claude/sessions"

local cache = { mtime = nil, data = nil }

local function parseTime(iso)
  if type(iso) ~= "string" then return nil end
  local y, mo, d, h, mi, s = iso:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not y then return nil end
  -- The timestamps are UTC; os.time() reads a table as local time, so correct by the UTC offset.
  local t = os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = tonumber(mi), sec = tonumber(s) })
  local now = os.time()
  local offset = os.time(os.date("*t", now)) - os.time(os.date("!*t", now))
  return t + offset
end

local DAYS = { "Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi" }

-- "Bugün 14:00", "Yarın 09:00", "Cumartesi 12:00"
function M.when(t)
  if not t then return "" end
  local d, today = os.date("*t", t), os.date("*t")
  local hm = string.format("%02d:%02d", d.hour, d.min)
  local days = math.floor((os.time({ year = d.year, month = d.month, day = d.day, hour = 12 }) -
    os.time({ year = today.year, month = today.month, day = today.day, hour = 12 })) / 86400 + 0.5)
  if days == 0 then return "Bugün " .. hm end
  if days == 1 then return "Yarın " .. hm end
  return DAYS[d.wday] .. " " .. hm
end

local function readState()
  local a = hs.fs.attributes(STATE)
  if not a then return nil end
  if cache.mtime == a.modification and cache.data then return cache.data end
  local ok, d = pcall(hs.json.read, STATE)
  if not ok or type(d) ~= "table" then return cache.data end
  cache.mtime, cache.data = a.modification, d
  return d
end

-- { plan, fetchedAt, limits = { { label, percent, resetsAt, severity } } } or nil
function M.usage()
  local d = readState()
  if not d then return nil end
  local u = d.cachedUsageUtilization
  local acc = d.oauthAccount or {}
  local out = { plan = acc.planDisplayName, limits = {}, fetchedAt = u and u.fetchedAtMs and math.floor(u.fetchedAtMs / 1000) }
  local util = u and u.utilization or {}
  local fh = util.five_hour
  if type(fh) == "table" and fh.utilization then
    table.insert(out.limits, { label = "5 Saatlik Limit", percent = fh.utilization, resetsAt = parseTime(fh.resets_at) })
  end
  for _, l in ipairs(util.limits or {}) do
    if type(l) == "table" and l.percent and (l.is_active or l.percent > 0) then
      local label = l.kind == "weekly_all" and "Haftalık Limit" or "Haftalık"
      local model = l.scope and l.scope.model and l.scope.model.display_name
      if l.kind ~= "weekly_all" and model then label = "Haftalık · " .. model end
      table.insert(out.limits, { label = label, percent = l.percent, resetsAt = parseTime(l.resets_at), severity = l.severity })
    end
  end
  if #out.limits == 0 and type(util.seven_day) == "table" and util.seven_day.utilization then
    table.insert(out.limits, { label = "Haftalık Limit", percent = util.seven_day.utilization, resetsAt = parseTime(util.seven_day.resets_at) })
  end
  return out
end

-- Highest current percent across limits (for the menu bar warning), or nil.
function M.peak()
  local u = M.usage()
  if not u then return nil end
  local best
  for _, l in ipairs(u.limits) do if not best or l.percent > best then best = l.percent end end
  return best
end

-- Open Claude Code sessions (processes that are still alive), busy ones first.
function M.sessions()
  local list, pids = {}, {}
  local ok, iter, dirObj = pcall(hs.fs.dir, SESSIONS)
  if not ok or not iter then return list end
  for f in iter, dirObj do
    if f:match("^%d+%.json$") then
      local okj, s = pcall(hs.json.read, SESSIONS .. "/" .. f)
      if okj and type(s) == "table" and s.pid then
        table.insert(list, s)
        table.insert(pids, tostring(math.floor(s.pid)))
      end
    end
  end
  if #list == 0 then return list end
  -- One ps call tells which of them are still running (session files of crashed processes linger).
  local out = hs.execute("/bin/ps -o pid= -p " .. table.concat(pids, ",")) or ""
  local alive = {}
  for pid in out:gmatch("%d+") do alive[pid] = true end
  local res = {}
  for _, s in ipairs(list) do
    if alive[tostring(math.floor(s.pid))] then
      table.insert(res, {
        name = s.name or ("oturum " .. s.pid),
        busy = s.status == "busy",
        cwd = s.cwd,
        url = s.bridgeSessionId and ("https://claude.ai/code/" .. s.bridgeSessionId) or nil,
        updated = s.statusUpdatedAt and math.floor(s.statusUpdatedAt / 1000) or nil,
      })
    end
  end
  table.sort(res, function(a, b)
    if a.busy ~= b.busy then return a.busy end
    return (a.updated or 0) > (b.updated or 0)
  end)
  return res
end

return M
