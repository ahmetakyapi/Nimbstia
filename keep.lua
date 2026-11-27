-- Hammerspoon can garbage-collect timers and tasks that nothing references, so a fire-and-forget
-- hs.timer.doAfter / hs.task may silently never run. These helpers keep each one alive until it finishes.
local K = { live = {} }

function K.after(sec, fn)
  local t
  t = hs.timer.doAfter(sec, function()
    K.live[t] = nil
    fn()
  end)
  K.live[t] = true
  return t
end

-- Starts the task and returns it (or nil if it could not start).
-- stream = true reads stdout/stderr while the task runs and hands the whole output to cb at the end. Use it
-- for helpers that print more than a pipe buffer (64 KB): without it the child blocks on write, never exits,
-- and cb never runs.
function K.task(path, cb, args, stream)
  local t
  local out, err = {}, {}
  local function done(code, o, e)
    K.live[t] = nil
    if stream then
      table.insert(out, o or ""); table.insert(err, e or "")
      o, e = table.concat(out), table.concat(err)
    end
    if cb then return cb(code, o, e) end
  end
  if stream then
    t = hs.task.new(path, done, function(_, o, e)
      if o and o ~= "" then table.insert(out, o) end
      if e and e ~= "" then table.insert(err, e) end
      return true
    end, args)
  else
    t = hs.task.new(path, done, args)
  end
  if not t then return nil end -- e.g. the executable does not exist
  K.live[t] = true
  if not t:start() then K.live[t] = nil; return nil end
  return t
end

return K
