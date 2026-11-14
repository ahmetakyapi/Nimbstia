-- Settings with safe defaults. Put your own values in config.local.lua (git-ignored):
--
--   return {
--     jiraBase = "https://your-company.atlassian.net/browse/",
--     devCheck = { name = "DEV", host = "10.0.0.10", port = 22 },
--   }
--
-- Every key is optional; features that need a missing value hide themselves.
local HOME = os.getenv("HOME")

local C = {
  -- Interface language of the panels and the hub: "tr" (default) or "en".
  language = "tr",
  -- ⌃⌥J opens "<jiraBase><KEY-123>". nil = the shortcut tells you to set it.
  jiraBase = nil,
  -- Status menu reachability check over the VPN: { name, host, port }. nil = no VPN/DEV indicator.
  devCheck = nil,
  -- Where screenshots (⌘.) are saved; the clipboard panel lists this folder too.
  screenshotDir = HOME .. "/Documents/Screenshots",
  -- Keep a closed MacBook driving the external display on battery too (needs scripts/clamshell-setup.sh).
  batteryClamshell = false,
  -- Start the screen saver by itself after this many idle minutes. nil = only from the hub.
  saverIdleMinutes = nil,
}

local path = HOME .. "/.hammerspoon/config.local.lua"
if hs.fs.attributes(path) then
  local ok, local_ = pcall(dofile, path)
  if ok and type(local_) == "table" then
    for k, v in pairs(local_) do C[k] = v end
  else
    print("config.local.lua could not be loaded: " .. tostring(local_))
  end
end

return C
