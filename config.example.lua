-- Copy to config.local.lua (git-ignored) and fill in what you use. Every key is optional.
return {
  -- ⌃⌥J opens the Jira issue key found in the selection or clipboard (e.g. ABC-123).
  -- jiraBase = "https://your-company.atlassian.net/browse/",
  -- jiraProjects = { "ABC", "OPS" },   -- optional: only these key prefixes count

  -- Status menu shows VPN + a reachability check for one host (TCP connect).
  -- devCheck = { name = "DEV", title = "Office VPN", host = "10.0.0.10", port = 22 },  -- title: card heading (optional)

  -- Optional launcher item in the status menu.
  -- launcher = { title = "Start dev stack", path = os.getenv("HOME") .. "/Desktop/start.command" },

  -- Only count commits and PRs from one GitHub organisation in the hub and Repostia (work only).
  -- githubOrg = "your-org",

  -- screenshotDir = os.getenv("HOME") .. "/Documents/Screenshots",
}
