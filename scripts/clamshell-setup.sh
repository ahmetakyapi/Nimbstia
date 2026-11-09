#!/bin/bash
# Lets Nimbstia (clamshell.lua) toggle `pmset disablesleep` without a password prompt.
# The rule allows only these two exact commands for the current user. Remove: --uninstall
set -euo pipefail

RULE=/etc/sudoers.d/nimbstia-pmset

if [[ "${1:-}" == "--uninstall" ]]; then
  sudo /usr/bin/pmset disablesleep 0
  sudo rm -f "$RULE"
  echo "Removed $RULE and re-enabled sleep."
  exit 0
fi

USER_NAME="$(id -un)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
printf '%s ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 0, /usr/bin/pmset disablesleep 1\n' "$USER_NAME" > "$TMP"

sudo /usr/sbin/visudo -cf "$TMP" >/dev/null
sudo install -m 0440 -o root -g wheel "$TMP" "$RULE"
echo "Installed $RULE. Set batteryClamshell = true in config.local.lua and reload Hammerspoon."
