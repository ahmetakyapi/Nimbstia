#!/usr/bin/env bash
# Builds Nimbstia.app: a tiny launcher (Applications / Dock) that starts Hammerspoon if needed and
# opens the Nimbstia hub through hammerspoon://nimbstia. Usage: scripts/build-app.sh [destination dir]
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
DEST_DIR="${1:-/Applications}"
[[ -w "$DEST_DIR" ]] || DEST_DIR="$HOME/Applications"
mkdir -p "$DEST_DIR"
APP="$DEST_DIR/Nimbstia.app"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Icon: render the SVG logo once at 1024 px on a transparent canvas with the standard macOS icon
# margin (Apple's grid: an 824 px body in 1024, so 9.8% on each side and the icon is the same size as
# its neighbours in the Dock), then every size iconutil wants. (qlmanage would paint a white background.)
SRC="$WORK/logo1024.png"
osascript -l JavaScript "$HERE/scripts/svg2png.js" "$HERE/assets/logo.svg" "$SRC" 1024 0.098 >/dev/null
[[ -f "$SRC" ]] || { echo "could not render assets/logo.svg" >&2; exit 1; }
ICONSET="$WORK/Nimbstia.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$SRC" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$SRC" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$WORK/Nimbstia.icns"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$WORK/Nimbstia.icns" "$APP/Contents/Resources/Nimbstia.icns"

cat > "$APP/Contents/MacOS/Nimbstia" <<'SH'
#!/bin/bash
# Start Hammerspoon in the background if it is not running, then ask it to show the hub.
if ! pgrep -x Hammerspoon >/dev/null; then
  open -g -a Hammerspoon
  for _ in $(seq 1 40); do pgrep -x Hammerspoon >/dev/null && break; sleep 0.25; done
  sleep 2
fi
open -g "hammerspoon://nimbstia"
SH
chmod +x "$APP/Contents/MacOS/Nimbstia"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Nimbstia</string>
  <key>CFBundleDisplayName</key><string>Nimbstia</string>
  <key>CFBundleIdentifier</key><string>io.github.ahmetakyapi.nimbstia</string>
  <key>CFBundleExecutable</key><string>Nimbstia</string>
  <key>CFBundleIconFile</key><string>Nimbstia</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# macOS 26 (Tahoe) shrinks a bundled .icns onto a grey plate unless the app ships an Icon Composer
# asset (needs Xcode). An icon set on the bundle itself, as Finder's Get Info does, is shown as drawn,
# on every macOS version. Best effort: the bundled .icns stays as the fallback.
osascript -l JavaScript -e 'ObjC.import("AppKit"); function run(a) { var img = $.NSImage.alloc.initWithContentsOfFile(a[0]); return img.isNil() ? false : $.NSWorkspace.sharedWorkspace.setIconForFileOptions(img, a[1], 0); }' \
  "$APP/Contents/Resources/Nimbstia.icns" "$APP" >/dev/null 2>&1 || true

touch "$APP"   # refresh the Finder/Dock icon cache for this bundle
echo "$APP"
