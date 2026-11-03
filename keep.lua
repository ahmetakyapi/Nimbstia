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
function K.task(path, cb, args)
  local t
  t = hs.task.new(path, function(...)
    K.live[t] = nil
    if cb then return cb(...) end
  end, args)
  if not t then return nil end -- e.g. the executable does not exist
  K.live[t] = true
  if not t:start() then K.live[t] = nil; return nil end
  return t
end

return K
