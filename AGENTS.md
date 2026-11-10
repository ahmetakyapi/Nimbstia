# Installing Nimbstia with an AI agent

This file is the runbook for coding agents (Claude Code, Codex, Cursor, Copilot agent mode, …) asked to
install Nimbstia on a user's Mac. Follow the steps in order, run every check, and stop to ask the user
where a step says so. Humans can follow it too.

## Ground rules

- **macOS only.** Stop if `uname -s` is not `Darwin`.
- **Never delete the user's existing `~/.hammerspoon`.** The installer moves it to
  `~/.hammerspoon.backup-<date>`. Tell the user where the backup is.
- **Ask before you write personal values** (Jira URL, VPN host) into `config.local.lua`. Every value is
  optional; an empty config is a valid install.
- **You cannot grant macOS privacy permissions.** Guide the user through them (step 4) and wait.
- Do not change hotkeys or code unless the user asks. Install first, customise after.

## 1. Check prerequisites

```bash
uname -s                                   # must print Darwin
sw_vers -productVersion                    # macOS 13.3 or newer (the panels need Safari 16.4 WebKit: @property, color-mix)
ls -d /Applications/Hammerspoon.app ~/Applications/Hammerspoon.app 2>/dev/null
command -v brew git                        # brew is only needed when Hammerspoon is missing
ls -A ~/.hammerspoon 2>/dev/null | head    # anything here will be backed up
```

If `~/.hammerspoon` already holds a config that is **not** Nimbstia, tell the user it will be backed up
and get a yes before continuing.

## 2. Run the installer

```bash
curl -fsSL https://raw.githubusercontent.com/ahmetakyapi/Nimbstia/main/install.sh | bash
```

It installs Hammerspoon with Homebrew if needed, backs up and clones into `~/.hammerspoon`, creates
`config.local.lua` from `config.example.lua`, builds `/Applications/Nimbstia.app` and restarts
Hammerspoon. Re-running it is safe: an existing Nimbstia checkout is updated with `git pull --ff-only`.

Prefer to read the script first? `curl -fsSL <same url> -o /tmp/nimbstia-install.sh`, show it to the user,
then `bash /tmp/nimbstia-install.sh`.

## 3. Optional settings (ask the user)

Open `~/.hammerspoon/config.local.lua` and uncomment only what the user wants:

| Key | Ask the user | Enables |
|---|---|---|
| `jiraBase`, `jiraProjects` | "Do you use Jira? What is the browse URL and which project keys?" | <kbd>Ctrl Opt J</kbd> opens an issue key |
| `devCheck = { name, title, host, port }` | "Is there a VPN host you want a connection card for?" | Connection card in the hub |
| `language = "en"` | "Turkish or English interface?" (default Turkish) | Panel language |
| `screenshotDir` | Only if they want screenshots somewhere other than `~/Documents/Screenshots` | Clipstia save folder |

Leave everything else commented. After editing, reload: `hs -c 'hs.reload()'` (or the menu bar icon ›
Yeniden Yükle).

## 4. Permissions (the user does this)

Tell the user, in their language, to open **System Settings › Privacy & Security** and switch on
**Hammerspoon** under:

1. **Accessibility**: hotkeys, window moves, snippets.
2. **Screen Recording**: screenshots (<kbd>Ctrl .</kbd>) and text recognition (<kbd>Ctrl Shift O</kbd>).
   macOS may ask to quit and reopen Hammerspoon; that is expected.

Shortcut to the right pane:
`open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"` and
`open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"`.

Then ask them to enable **Launch Hammerspoon at login** in Hammerspoon's preferences.

## 5. Verify

```bash
hs -c 'return #LOAD_ERRORS == 0 and "ok" or hs.inspect(LOAD_ERRORS)'   # expect: ok
ls /Applications/Nimbstia.app >/dev/null && echo app-ok
```

If `hs` is not found, the IPC CLI is not linked yet. Run
`/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs -c 'hs.ipc.cliInstall()'` once, or skip this
check and ask the user to look at the Hammerspoon console for red lines.

Ask the user to try:
- the **N** icon in the menu bar (the hub)
- <kbd>Ctrl V</kbd> (clipboard history)
- <kbd>Ctrl .</kbd> (screenshot)
- <kbd>Ctrl Space</kbd> (window layouts)
- <kbd>Ctrl Shift P</kbd> (projects)

## 6. Troubleshooting

| Symptom | Fix |
|---|---|
| Hotkeys do nothing | Accessibility is off, or Hammerspoon was not restarted after enabling it. |
| Screenshot shows only the wallpaper | Screen Recording is off; enable it, then quit and reopen Hammerspoon. |
| <kbd>Ctrl Space</kbd> switches the keyboard language | Turn off "Select the previous input source" in System Settings › Keyboard › Keyboard Shortcuts › Input Sources. |
| Repostia is empty | Projects are scanned under `~/Projects`; clone repositories there. |
| No PR numbers in the hub | Install and log in to the GitHub CLI: `brew install gh && gh auth login` (the user runs the login). |
| Claude card says "Kullanım verisi yok" | Claude Code has not written usage to `~/.claude.json` yet, or in a new shape. `hs -c 'return require("claude").debug()'` prints only the field names (no values); share that output in an issue. |
| Lightshot keeps opening | Nimbstia quits Lightshot on start; remove it from Login Items if it is still there. |

## Uninstall

Quit Hammerspoon, then `rm -rf ~/.hammerspoon /Applications/Nimbstia.app`. Restore the backup with
`mv ~/.hammerspoon.backup-<date> ~/.hammerspoon` if one was made. Confirm with the user before deleting.
