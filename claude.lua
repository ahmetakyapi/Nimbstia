-- Claude usage for the status menu: plan limits and open Claude Code sessions, read from the files
-- Claude Code itself keeps up to date (~/.claude.json → cachedUsageUtilization, ~/.claude/sessions/*.json).
-- Read-only, local, no network. Parsing is cached by file modification time.
local M = {}

local HOME = os.getenv("HOME")
local STATE = HOME .. "/.claude.json"
local SESSIONS = HOME .. "/.claude/sessions"
-- Newer Claude Code no longer caches usage in ~/.claude.json; the status line receives it as
-- `rate_limits` and ~/.claude/hooks/statusline.sh saves it here as { fetchedAt, rate_limits }.
local RATE_LIMITS = HOME .. "/.claude/cache/rate-limits.json"

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

-- A percentage from any of the shapes Claude Code has written so far ("utilization", "percent",
-- "used_percent"; 0-100). nil when the entry carries none.
local function pct(t)
  if type(t) ~= "table" then return nil end
  for _, k in ipairs({ "utilization", "percent", "used_percentage", "used_percent", "usedPercent", "percentUsed" }) do
    local v = tonumber(t[k])
    if v then return v end
  end
  return nil
end
local function resets(t)
  if type(t) ~= "table" then return nil end
  local r = t.resets_at or t.resetsAt
  if type(r) == "number" then return r > 1e11 and math.floor(r / 1000) or math.floor(r) end -- epoch s or ms
  return parseTime(r)
end

local function readRateLimits()
  if not hs.fs.attributes(RATE_LIMITS) then return nil end
  local ok, d = pcall(hs.json.read, RATE_LIMITS)
  if ok and type(d) == "table" and type(d.rate_limits) == "table" then return d end
  return nil
end

-- { plan, fetchedAt, limits = { { label, percent, resetsAt, severity, weekly } } } or nil
function M.usage()
  local d = readState()
  if not d then return nil end
  local u = d.cachedUsageUtilization or d.cachedUsage or d.usageUtilization
  if type(u) ~= "table" then
    local rl = readRateLimits()
    if rl then u = { utilization = rl.rate_limits, fetchedAtMs = tonumber(rl.fetchedAt) and rl.fetchedAt * 1000 } end
  end
  local acc = d.oauthAccount or {}
  local out = { plan = acc.planDisplayName, limits = {},
    fetchedAt = type(u) == "table" and tonumber(u.fetchedAtMs or u.fetched_at_ms) and math.floor(tonumber(u.fetchedAtMs or u.fetched_at_ms) / 1000) or nil }
  local util = type(u) == "table" and (u.utilization or u) or {}
  -- the rolling session window first, then the weekly limits
  local fh = util.five_hour or util.fiveHour
  if pct(fh) then table.insert(out.limits, { label = "Oturum Limiti", percent = pct(fh), resetsAt = resets(fh) }) end
  local weeklySeen = false
  for _, l in ipairs(type(util.limits) == "table" and util.limits or {}) do
    local p = pct(l)
    if p and (l.is_active ~= false or p > 0) then
      local all = l.kind == nil or l.kind == "weekly_all" or l.kind == "seven_day"
      local model = type(l.scope) == "table" and type(l.scope.model) == "table" and l.scope.model.display_name
      local label = all and "Haftalık Limit" or (model and ("Haftalık · " .. model) or "Haftalık")
      table.insert(out.limits, { label = label, percent = p, resetsAt = resets(l), severity = l.severity, weekly = all })
      weeklySeen = weeklySeen or all
    end
  end
  if not weeklySeen and pct(util.seven_day or util.sevenDay) then
    local sd = util.seven_day or util.sevenDay
    table.insert(out.limits, { label = "Haftalık Limit", percent = pct(sd), resetsAt = resets(sd), weekly = true })
  end
  for key, name in pairs({ seven_day_opus = "Opus", seven_day_sonnet = "Sonnet" }) do
    if pct(util[key]) then table.insert(out.limits, { label = "Haftalık · " .. name, percent = pct(util[key]), resetsAt = resets(util[key]) }) end
  end
  -- Weekly first in the hub (outer ring), the session window second (inner ring).
  table.sort(out.limits, function(x, y)
    local rx, ry = x.weekly and 0 or (x.label == "Oturum Limiti" and 1 or 2), y.weekly and 0 or (y.label == "Oturum Limiti" and 1 or 2)
    return rx < ry
  end)
  return out
end

-- Shape of the usage block, for bug reports: key names and value types only, never values.
--   hs -c 'return require("claude").debug()'
function M.debug()
  local d = readState()
  if not d then return "~/.claude.json okunamadı" end
  local function shape(t, depth)
    if type(t) ~= "table" then return type(t) end
    if depth > 3 then return "{…}" end
    local parts = {}
    for k, v in pairs(t) do table.insert(parts, tostring(k) .. "=" .. shape(v, depth + 1)) end
    table.sort(parts)
    return "{" .. table.concat(parts, ", ") .. "}"
  end
  local keys = {}
  for k in pairs(d) do if tostring(k):lower():match("usage") or tostring(k):lower():match("limit") then table.insert(keys, k) end end
  table.sort(keys)
  local out = { "plan: " .. tostring((d.oauthAccount or {}).planDisplayName) }
  for _, k in ipairs(keys) do table.insert(out, k .. ": " .. shape(d[k], 0)) end
  local rl = readRateLimits()
  table.insert(out, "rate-limits.json: " .. (rl and shape(rl, 0) or "yok"))
  if #keys == 0 and not rl then table.insert(out, "kullanım alanı yok (Claude Code henüz yazmamış)") end
  return table.concat(out, "\n")
end

-- ---------------------------------------------------------------- today's share of the weekly limit
-- Claude Code only stores the current percentage, so every new reading is logged locally
-- (hs.settings, 14 days). Today's use = latest reading minus the last reading before midnight.
local LOG_KEY = "nimbstia.claudeLog"

local function midnight()
  local t = os.date("*t")
  return os.time({ year = t.year, month = t.month, day = t.day, hour = 0 })
end

function M.record(percent, fetchedAt)
  if not percent or not fetchedAt then return end
  local log = hs.settings.get(LOG_KEY) or {}
  local last = log[#log]
  if last and last.t == fetchedAt then return end
  table.insert(log, { t = fetchedAt, p = percent })
  local keep, cutoff = {}, os.time() - 14 * 86400
  for _, e in ipairs(log) do if e.t >= cutoff then table.insert(keep, e) end end
  hs.settings.set(LOG_KEY, keep)
end

-- Percentage points of the weekly limit used today, or nil while there is no baseline yet.
function M.today(current)
  local log = hs.settings.get(LOG_KEY) or {}
  if not current or #log == 0 then return nil end
  -- Only a reading from before midnight is a true baseline; without one "today" is unknown
  -- (using today's first reading would undercount), so the badge stays hidden until then.
  local m0, base = midnight(), nil
  for _, e in ipairs(log) do
    if e.t < m0 then base = e.p end
  end
  if not base then return nil end
  local d = current - base
  if d < 0 then d = current end -- the weekly window reset today
  return d
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
