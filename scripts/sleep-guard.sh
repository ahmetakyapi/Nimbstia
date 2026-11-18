#!/bin/sh
# Started by clamshell.lua while `pmset disablesleep 1` is set. If Hammerspoon quits or crashes, it turns
# sleep back on so a closed Mac in a bag does not stay awake. A reload keeps the same Hammerspoon process,
# so the flag is left alone. Exits by itself once sleep is enabled again.
# The first argument is only a marker for pgrep (nimbstia-sleep-guard).
while /usr/bin/pgrep -x Hammerspoon >/dev/null; do
  /bin/sleep 15
  /usr/bin/pmset -g | /usr/bin/grep -q 'SleepDisabled[[:space:]]*1' || exit 0
done
/usr/bin/pmset -g | /usr/bin/grep -q 'SleepDisabled[[:space:]]*1' && /usr/bin/sudo -n /usr/bin/pmset disablesleep 0
exit 0
