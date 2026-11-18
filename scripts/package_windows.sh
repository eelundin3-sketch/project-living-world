#!/bin/sh
# Builds a Windows 11 (64-bit) release of the game and zips it for sharing.
#   GODOT_BIN=/path/to/Godot scripts/package_windows.sh
# Needs the Godot 4.6 Windows export templates in .godot/export_templates
# (see scripts/prepare_exports.sh). Writes dist/LivingWorld-Windows.zip.
set -eu
cd "$(dirname "$0")/.."
GODOT_BIN=${GODOT_BIN:-godot}
OUT=dist/LivingWorld-Windows
rm -rf "$OUT" dist/LivingWorld-Windows.zip
mkdir -p "$OUT"
# Import first so a fresh checkout has its resource cache.
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT_BIN" --headless --path . --export-release 'Windows Desktop' "$OUT/LivingWorld.exe"
rm -f "$OUT"/LivingWorld.console.exe        # the plain exe is enough for players
[ -s "$OUT/LivingWorld.exe" ] || { echo "Export failed: no LivingWorld.exe" >&2; exit 1; }
cat > "$OUT/README-WINDOWS.txt" <<'TXT'
Project Living World - Windows 11 (64-bit)

1. Unzip this folder anywhere (do not run it from inside the zip).
2. Double-click LivingWorld.exe.
3. Windows may say "Windows protected your PC" because the game is not code-signed.
   Click "More info", then "Run anyway".
4. Click Start Game on the title screen.

Saves are stored in %APPDATA%\Godot\app_userdata\Project Living World\
Controls are in the project README: https://github.com/eelundin3-sketch/project-living-world#download-and-play
TXT
( cd dist && zip -qr LivingWorld-Windows.zip LivingWorld-Windows )
ls -lh dist/LivingWorld-Windows.zip
