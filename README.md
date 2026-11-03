<p align="center">
  <img src="assets/logo.svg" width="128" height="128" alt="Nimbstia logo">
</p>

<h1 align="center">Nimbstia</h1>

<p align="center">
  A keyboard-first workbench for macOS: clipboard history, window layouts, a Lightshot-style screenshot tool,<br>
  a project opener and a calm status popover — all in one Hammerspoon config, native on Apple Silicon.
</p>

<p align="center">
  <img alt="macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-111?logo=apple&logoColor=white">
  <img alt="Apple Silicon native" src="https://img.shields.io/badge/Apple%20Silicon-native-0a6cff">
  <img alt="Hammerspoon 1.0+" src="https://img.shields.io/badge/Hammerspoon-1.0%2B-f5a623">
  <img alt="MIT license" src="https://img.shields.io/badge/license-MIT-2ea44f">
  <a href="README.tr.md"><img alt="Türkçe" src="https://img.shields.io/badge/README-T%C3%BCrk%C3%A7e-e30a17"></a>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/screens/clipboard-dark.png">
    <img src="assets/screens/clipboard-light.png" width="880" alt="Clipboard history panel">
  </picture>
</p>

> The interface speaks Turkish today (the author's daily language). Every string lives next to the code that uses it, so a translation is a small, focused change — PRs welcome.

## Why

macOS is great, but a few everyday moves cost too many clicks: finding something you copied an hour ago, putting two windows side by side, grabbing a marked-up screenshot, jumping into the right repository. Nimbstia turns each of those into one shortcut and a panel that gets out of your way.

- **Native and light.** No Electron, no background app of its own — it is plain Lua + small HTML panels running inside [Hammerspoon](https://www.hammerspoon.org). Idle CPU is ~0 %.
- **Private by default.** Everything stays on your Mac. No network calls except the optional VPN/host check you configure. Password-manager copies are never recorded.
- **Calm UI.** One accent colour, real light and dark themes, only the hints you need, everything reachable from the keyboard.

## Features

| | Shortcut | What it does |
|---|---|---|
| **Pastia** · clipboard | <kbd>⌃</kbd> <kbd>V</kbd> | Text, links, colours, copied images and your screenshots folder, newest first, grouped by day. Filters by kind and time, fuzzy search, pin, edit, copy without closing (<kbd>⌘</kbd> <kbd>C</kbd>), paste (<kbd>↩</kbd>). |
| **Clipstia** · screenshots | <kbd>⌘</kbd> <kbd>.</kbd> | Freezes the screen. Drag a region or click a window, then annotate: pen, line, arrow, box, ellipse, marker, text, blur, numbered steps. <kbd>⌃</kbd> <kbd>C</kbd> / <kbd>⌘</kbd> <kbd>C</kbd> / <kbd>↩</kbd> saves **and** copies, <kbd>⌘</kbd> <kbd>S</kbd> saves only. |
| **Panestia** · layouts | <kbd>⌃</kbd> <kbd>Space</kbd> | One-key multi-app layouts (code + browser, meeting, focus…), "last two windows side by side", adjustable split, undo. |
| **Snapping** | <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>←</kbd> <kbd>→</kbd> | Halves; press again for ⅓ → ⅔. <kbd>↑</kbd> <kbd>↓</kbd> top/bottom, <kbd>↩</kbd> full, <kbd>C</kbd> centre, <kbd>Z</kbd> undo, <kbd>⌘</kbd> + arrows: other display. |
| **Repostia** · projects | <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>P</kbd> | Every repo in `~/Projects` with branch, dirty files, ahead/behind and recent commits. Opens in VS Code, Terminal, GitHub Desktop or Finder. |
| **Inkstia** · text from screen | <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>O</kbd> | Select an area, its text (Turkish + English) lands on the clipboard. |
| **Twistia** · transform text | <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>T</kbd> | JSON pretty/minify, JWT decode, Base64, URL, timestamps ↔ dates, case, sort/unique lines, SQL `IN` list, UUID… replaces the selection. |
| **Snipstia** · snippets | `;key` · <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>S</kbd> | Type `;tarih`, `;daily`, `;pr`… and it expands. Edit them in `snippets.lua`. |
| **Hopstia** · app switching | <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>⌘</kbd> + letter | V VS Code · C Chrome · A Claude · T Teams · X Terminal · O Outlook · W WhatsApp · G GitHub Desktop · F Finder. Press again to cycle its windows. |
| **Pulstia** · status popover | menu bar icon | VPN + host reachability (green dot when all is well), Claude plan usage and open sessions, keep awake (<kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>K</kbd>), microphone mute (<kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>M</kbd>), opt-in meeting alerts, theme, every shortcut. |
| **Jira** | <kbd>⌃</kbd> <kbd>⌥</kbd> <kbd>J</kbd> | Opens the issue key found in the selection or clipboard (`ABC-123`). |

<table>
  <tr>
    <td width="50%">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="assets/screens/layouts-dark.png">
        <img src="assets/screens/layouts-light.png" alt="Window layouts panel">
      </picture>
    </td>
    <td width="50%">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="assets/screens/projects-dark.png">
        <img src="assets/screens/projects-light.png" alt="Project opener panel">
      </picture>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="assets/screens/screenshot-dark.png">
        <img src="assets/screens/screenshot-light.png" alt="Clipstia screenshot tool with annotations">
      </picture>
    </td>
    <td width="50%" align="center">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="assets/screens/popover-dark.png">
        <img src="assets/screens/popover-light.png" width="300" alt="Pulstia status popover">
      </picture>
    </td>
  </tr>
</table>

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ahmetakyapi/nimbstia/main/install.sh | bash
```

The script installs Hammerspoon with Homebrew if it is missing, backs up an existing `~/.hammerspoon` (to `~/.hammerspoon.backup-<date>`), clones Nimbstia there and starts it. Prefer to look first? Clone it yourself:

```bash
git clone https://github.com/ahmetakyapi/nimbstia.git ~/.hammerspoon
cp ~/.hammerspoon/config.example.lua ~/.hammerspoon/config.local.lua
open -a Hammerspoon
```

Then give Hammerspoon two permissions in **System Settings › Privacy & Security**:

- **Accessibility** — hotkeys, moving windows, snippets.
- **Screen Recording** — the screenshot tool and text recognition.

Nimbstia starts with your Mac (`hs.autoLaunch`). Click the Nimbstia mark in the menu bar for the status popover; everything else is one shortcut away.

## Configure

Personal values live in `config.local.lua` (git-ignored). Every key is optional — features that need a missing value hide themselves.

```lua
return {
  jiraBase = "https://your-company.atlassian.net/browse/",          -- ⌃⌥J
  devCheck = { name = "DEV", host = "10.0.0.10", port = 22 },          -- popover connection card
  launcher = { title = "Start dev stack", path = os.getenv("HOME") .. "/Desktop/start.command" },
  screenshotDir = os.getenv("HOME") .. "/Documents/Screenshots",
}
```

- **Snippets:** `snippets.lua` — a plain list of `{ key, label, text }`; `text` may be a function (dates).
- **Layouts and apps:** the tables at the top of `layouts.lua` and `tools.lua`.
- **Theme:** the switch at the bottom of the popover (system, light, dark).
- **Shortcut clashes:** <kbd>⌃</kbd> <kbd>V</kbd> replaces Vim's visual-block key and <kbd>⌃</kbd> <kbd>Space</kbd> replaces macOS "previous input source" (System Settings › Keyboard › Keyboard Shortcuts › Input Sources). Change the bindings in `init.lua` if you rely on them.
- **Jira prefixes:** add `jiraProjects = { "ABC", "OPS" }` to only match your projects' keys.

## Privacy

- Clipboard history is stored locally in Hammerspoon's settings; copied images and thumbnails in `clipdata/` (git-ignored).
- Items marked by password managers (`org.nspasteboard.ConcealedType`, 1Password…) are never stored.
- Claude usage and sessions are read from the files Claude Code keeps on your Mac (`~/.claude.json`, `~/.claude/sessions`); nothing is sent anywhere.
- The only network traffic is the optional TCP check to the host you configure. Meeting alerts read the macOS Calendar locally and only after you turn them on.

## Project layout

```
init.lua            entry point: loads every module safely and binds the global shortcuts
config.lua          defaults + config.local.lua override
panel.lua           shared floating webview panel (focus, theme)
keep.lua            keeps fire-and-forget timers/tasks alive until they finish
pb.lua              pasteboard helpers: secret detection, safe save/restore
clipboard.lua/.html Pastia: clipboard history
shot.lua/.html      Clipstia: screenshot overlay and annotation editor
layouts.lua/.html   Panestia: window layouts
projects.lua/.html  Repostia: project opener (+ bin/projects-scan.py)
tools.lua           Hopstia app keys, Inkstia OCR, Twistia transforms, Snipstia snippets, Jira
status.lua          Pulstia: menu bar icon + status popover (pulstia.html)
claude.lua          Claude plan usage and open Claude Code sessions (read-only)
bin/                small helpers (OCR and Calendar via JavaScript for Automation, transforms)
scripts/            maintenance (README screenshots with demo data)
```

## Uninstall

Quit Hammerspoon, delete `~/.hammerspoon` (or restore your backup) and, if you like, Hammerspoon itself.

## License

[MIT](LICENSE) © Ahmet Akyapı
