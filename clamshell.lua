-- Battery clamshell: macOS only keeps a closed MacBook awake for an external display while it is on
-- AC power. This module turns `pmset disablesleep` on while an external display is connected and off
-- again as soon as it is unplugged, so the Mac still sleeps normally in a bag.
--
-- pmset needs root; scripts/clamshell-setup.sh installs a sudoers rule that allows exactly
-- `pmset disablesleep 0|1` without a password. Opt in with `batteryClamshell = true` in config.local.lua.
local Keep = require("keep")
local Config = require("config")

local M = { enabled = false, applied = nil, ready = true }

local PMSET = "/usr/bin/pmset"
-- NSScreen names are localized; anything that is not the built-in panel counts as external.
local BUILTIN = { "Built%-in", "Yerleşik", "Dahili" }

local function isBuiltin(screen)
  local name = screen:name() or ""
  for _, p in ipairs(BUILTIN) do
    if name:find(p) then return true end
  end
  return false
end

function M.hasExternal()
  for _, s in ipairs(hs.screen.allScreens()) do
    if not isBuiltin(s) then return true end
  end
  return false
end

local function readFlag()
  local out = hs.execute(PMSET .. " -g") or ""
  return out:match("SleepDisabled%s+1") ~= nil
end

local function setFlag(on, cb)
  local v = on and "1" or "0"
  Keep.task("/usr/bin/sudo", function(code, _, err)
    if code == 0 then
      M.applied = on
      M.ready = true
    elseif M.ready then
      M.ready = false -- report once, not on every display change
      print("clamshell: sudo pmset failed (run scripts/clamshell-setup.sh): " .. tostring(err))
      hs.alert.show("Pilde kapalı kapak için kurulum gerekli: scripts/clamshell-setup.sh", 3)
    end
    if cb then cb(code == 0) end
  end, { "-n", PMSET, "disablesleep", v })
end

function M.sync()
  local want = M.enabled and M.hasExternal()
  if want == M.applied then return end
  setFlag(want, function(ok)
    -- Display unplugged with the lid already closed: nothing is left to show, so sleep now
    -- instead of waiting for the next lid event.
    if ok and not want and #hs.screen.allScreens() == 0 then hs.caffeinate.systemSleep() end
  end)
end

function M.start()
  M.enabled = Config.batteryClamshell == true
  M.applied = readFlag()
  -- Displays reconfigure in bursts (connect, mode change, arrangement); act once they settle.
  local pending
  M.watcher = hs.screen.watcher.new(function()
    if pending then pending:stop() end
    pending = Keep.after(1, M.sync)
  end):start()
  M.sync()
end

-- Never leave sleep disabled after Hammerspoon quits or reloads; start() turns it back on if needed.
function M.stop()
  if M.applied then hs.execute("/usr/bin/sudo -n " .. PMSET .. " disablesleep 0") end
  M.applied = false
end

return M
