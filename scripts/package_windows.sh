#!/bin/sh
# Builds a Windows 11 (64-bit) release of the game and zips it for sharing.
#   GODOT_BIN=/path/to/Godot scripts/package_windows.sh
# Needs the Godot 4.6 Windows export templates in .godot/export_templates
# (see tools/prepare_exports.sh). Writes dist/Project-Solo-Windows.zip.
set -eu
cd "$(dirname "$0")/.."
GODOT_BIN=${GODOT_BIN:-godot}
OUT=dist/Project-Solo-Windows
rm -rf "$OUT" dist/Project-Solo-Windows.zip
mkdir -p "$OUT"
# Import first so a fresh checkout has its resource cache.
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT_BIN" --headless --path . --export-release 'Windows Desktop' "$OUT/ProjectSolo.exe"
rm -f "$OUT"/ProjectSolo.console.exe        # the plain exe is enough for players
[ -s "$OUT/ProjectSolo.exe" ] || { echo "Export failed: no ProjectSolo.exe" >&2; exit 1; }
cat > "$OUT/README-WINDOWS.txt" <<'TXT'
Project Solo - Windows 11 (64-bit)

1. Unzip this folder anywhere (do not run it from inside the zip).
2. Double-click ProjectSolo.exe.
3. Windows may say "Windows protected your PC" because the game is not code-signed.
   Click "More info", then "Run anyway".
4. Click Start Game on the title screen.

Saves are stored in %APPDATA%\Godot\app_userdata\Project Solo\
Controls are in the project README: https://github.com/eelundin3-sketch/project-solo#download-and-play
TXT
( cd dist && zip -qr Project-Solo-Windows.zip Project-Solo-Windows )
ls -lh dist/Project-Solo-Windows.zip
