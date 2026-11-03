#!/usr/bin/env bash
# Install Nimbstia into ~/.hammerspoon. Safe to re-run: an existing, different config is backed up first.
set -euo pipefail

REPO="https://github.com/ahmetakyapi/Nimbstia.git"
DEST="$HOME/.hammerspoon"

say() { printf '\033[1m▸ %s\033[0m\n' "$*"; }

if [[ "$(uname -s)" != "Darwin" ]]; then echo "Nimbstia only runs on macOS." >&2; exit 1; fi

if [[ ! -d "/Applications/Hammerspoon.app" && ! -d "$HOME/Applications/Hammerspoon.app" ]]; then
  if command -v brew >/dev/null 2>&1; then
    say "Installing Hammerspoon (Homebrew cask)"
    brew install --cask hammerspoon
  else
    echo "Hammerspoon is required: https://www.hammerspoon.org (or install Homebrew and re-run)." >&2
    exit 1
  fi
fi

if [[ -d "$DEST/.git" ]] && git -C "$DEST" remote get-url origin 2>/dev/null | grep -qi "nimbstia"; then
  say "Updating existing Nimbstia checkout"
  git -C "$DEST" pull --ff-only
else
  if [[ -e "$DEST" ]]; then
    BACKUP="$DEST.backup-$(date +%Y%m%d-%H%M%S)"
    say "Backing up current ~/.hammerspoon to $BACKUP"
    mv "$DEST" "$BACKUP"
  fi
  say "Cloning Nimbstia"
  git clone --depth 1 "$REPO" "$DEST"
fi

if [[ ! -f "$DEST/config.local.lua" ]]; then
  cp "$DEST/config.example.lua" "$DEST/config.local.lua"
  say "Created config.local.lua — edit it to enable the Jira, VPN/DEV and launcher features"
fi

say "Building Nimbstia.app (Applications) — drag it to the Dock if you like"
"$DEST/scripts/build-app.sh" >/dev/null || echo "Could not build Nimbstia.app; the menu bar icon works without it."

say "Starting Hammerspoon"
# A running Hammerspoon keeps the old config: restart it so Nimbstia loads.
if pgrep -x Hammerspoon >/dev/null; then pkill -x Hammerspoon; sleep 1; fi
open -a Hammerspoon
cat <<'MSG'

Almost done. macOS will ask for two permissions for Hammerspoon:
  • Accessibility      (System Settings › Privacy & Security › Accessibility)  — hotkeys, window moves, snippets
  • Screen Recording   (System Settings › Privacy & Security › Screen Recording) — ⌃. screenshots, ⌃⇧O text recognition
Turn on "Launch Hammerspoon at login" in its preferences (Nimbstia also asks for it).
Click the Nimbstia icon in the menu bar for status, Claude usage, tools and every shortcut.
MSG
