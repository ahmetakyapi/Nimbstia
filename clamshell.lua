-- Closed-lid control. macOS sleeps a closed MacBook unless it is on AC power with an external display.
-- This module owns `pmset disablesleep` and turns it on while either
--   * Her Zaman Uyanık is on (status.lua): the Mac keeps running with the lid closed, with or without a
--     display, on AC and on battery, so Remote Control, the VPN and long jobs survive a closed lid; or
--   * batteryClamshell = true and an external display is connected: the closed Mac keeps driving it on battery.
-- Otherwise sleep is enabled, so the Mac still sleeps normally in a bag.
--
-- pmset needs root; scripts/clamshell-setup.sh installs a sudoers rule that allows exactly
-- `pmset disablesleep 0|1` without a password. scripts/sleep-guard.sh turns sleep back on if Hammerspoon
-- quits or crashes while the flag is set, and leaves it alone across a reload.
local Keep = require("keep")
local Config = require("config")

local M = { enabled = false, applied = nil, ready = true }

local PMSET = "/usr/bin/pmset"
local AWAKE_KEY = "nimbstia.awake" -- written by status.lua
local GUARD = os.getenv("HOME") .. "/.hammerspoon/scripts/sleep-guard.sh"
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

function M.lidClosed()
  local out = hs.execute("/usr/sbin/ioreg -r -k AppleClamshellState -d 1") or ""
  return out:match('"AppleClamshellState" = Yes') ~= nil
end

local function awakeWanted() return hs.settings.get(AWAKE_KEY) == true end

local function readFlag()
  local out = hs.execute(PMSET .. " -g") or ""
  return out:match("SleepDisabled%s+1") ~= nil
end

local GUARD_RUNNING = "/usr/bin/pgrep -f 'nimbstia-sleep-guar[d]'"
local function ensureGuard()
  if not hs.fs.attributes(GUARD) then return end
  -- The marker is split in the command line so pgrep does not match the shell that runs this line.
  -- The whole list is detached with its output closed, or hs.execute would wait for the guard to end.
  hs.execute("(" .. GUARD_RUNNING .. " || /usr/bin/nohup /bin/sh '" .. GUARD
    .. "' nimbstia-sleep-gu''ard) </dev/null >/dev/null 2>&1 &")
end

local function setFlag(on, cb)
  local v = on and "1" or "0"
  Keep.task("/usr/bin/sudo", function(code, _, err)
    if code == 0 then
      M.applied = on
      M.ready = true
      if on then ensureGuard() end
    elseif M.ready then
      M.ready = false -- report once, not on every display change
      print("clamshell: sudo pmset failed (run scripts/clamshell-setup.sh): " .. tostring(err))
      hs.alert.show("Kapak kapalıyken çalışmak için kurulum gerekli: scripts/clamshell-setup.sh", 3)
    end
    if cb then cb(code == 0) end
  end, { "-n", PMSET, "disablesleep", v })
end

function M.wanted()
  return awakeWanted() or (M.enabled and M.hasExternal())
end

function M.sync()
  local want = M.wanted()
  if want == M.applied then return end
  setFlag(want, function(ok)
    -- Nothing keeps the closed Mac up any more (display unplugged, Her Zaman Uyanık switched off):
    -- sleep now instead of waiting for the next lid event.
    if ok and not want and M.lidClosed() and not M.hasExternal() then hs.caffeinate.systemSleep() end
  end)
end

-- A USB-C → DisplayPort adapter shows up as a USB "Billboard" device before the display is configured.
-- When the Mac has been idle with the lid closed the display pipeline may be asleep and the new display
-- is only picked up after the lid opens. Declaring user activity wakes it so the display is probed now.
local function nudgeDisplays()
  local before = #hs.screen.allScreens()
  for _, delay in ipairs({ 1, 3, 6 }) do
    Keep.after(delay, function()
      if #hs.screen.allScreens() > before then return end
      hs.caffeinate.declareUserActivity()
    end)
  end
end

function M.start()
  M.enabled = Config.batteryClamshell == true
  M.applied = readFlag()
  if M.applied then ensureGuard() end
  -- Displays reconfigure in bursts (connect, mode change, arrangement); act once they settle. Turning
  -- the flag on is not delayed: a lid closed right after plugging the cable must not win the race.
  local pending
  M.watcher = hs.screen.watcher.new(function()
    if pending then pending:stop() end
    if M.wanted() and not M.applied then M.sync() end
    pending = Keep.after(1, M.sync)
  end):start()
  M.usb = hs.usb.watcher.new(function(dev)
    if dev.eventType == "added" then nudgeDisplays() end
  end):start()
  -- After a wake (lid opened, key pressed) re-check; macOS may have reset nothing, but displays may have changed.
  M.wake = hs.caffeinate.watcher.new(function(ev)
    if ev == hs.caffeinate.watcher.systemDidWake then Keep.after(2, M.sync) end
  end):start()
  M.sync()
end

-- Quit or reload: sleep-guard.sh turns sleep back on once Hammerspoon is gone and leaves the flag alone
-- across a reload (same process), where start() takes it over again. Without the guard, release now.
function M.stop()
  if not M.applied then return end
  ensureGuard()
  local running = hs.execute(GUARD_RUNNING) or ""
  if running == "" then hs.execute("/usr/bin/sudo -n " .. PMSET .. " disablesleep 0"); M.applied = false end
end

return M
