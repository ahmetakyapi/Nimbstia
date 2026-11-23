-- Copy to config.local.lua (git-ignored) and fill in what you use. Every key is optional.
return {
  -- language = "en",  -- interface language: "tr" (default) or "en"

  -- ⌃⌥J opens the Jira issue key found in the selection or clipboard (e.g. ABC-123).
  -- jiraBase = "https://your-company.atlassian.net/browse/",
  -- jiraProjects = { "ABC", "OPS" },   -- optional: only these key prefixes count

  -- Status menu shows VPN + a reachability check for one host (TCP connect).
  -- devCheck = { name = "DEV", title = "Office VPN", host = "10.0.0.10", port = 22 },  -- title: card heading (optional)

  -- Only count commits and PRs from one GitHub organisation in the hub and Repostia (work only).
  -- githubOrg = "your-org",

  -- screenshotDir = os.getenv("HOME") .. "/Documents/Screenshots",

  -- The hub offers a one-click update when origin/main has new commits (checked every 6 hours).
  -- updateCheck = false,   -- switch the check and the banner off

  -- Start the screen saver (Ekran Koruyucu) by itself after this many idle minutes. It stays away
  -- while a video, a call or Her Zaman Uyanık keeps the display awake.
  -- saverIdleMinutes = 10,

  -- Lid closed + external display on battery (macOS allows it only on AC). Run scripts/clamshell-setup.sh once;
  -- the same rule lets Her Zaman Uyanık keep a closed Mac running.
  -- batteryClamshell = true,

  -- While Her Zaman Uyanık is on, a notification asks every this many hours whether it is still needed
  -- (every 30 minutes on battery with the lid closed and no display). 0 = never.
  -- awakeRemindHours = 2,

  -- Her Zaman Uyanık switches itself off at this battery percentage when unplugged (default 20, 5-50);
  -- a notification warns 5 points earlier.
  -- awakeBatteryFloor = 20,

  -- Optional time limit: switch Her Zaman Uyanık off after this many hours (warns 10 minutes before). 0 = no limit.
  -- awakeMaxHours = 8,
}
