#!/bin/sh
# Builds a standalone macOS app (universal: Apple silicon and Intel) and zips it for sharing.
#   GODOT_BIN=/path/to/Godot scripts/package_macos.sh
# Needs the Godot 4.6 macOS export template in .godot/export_templates (see tools/prepare_exports.sh).
# Writes dist/Project-Solo-macOS.zip, which holds "Project Solo.app" and a short README. The app is not
# notarized, so the first launch needs the step in README-MACOS.txt.
set -eu
cd "$(dirname "$0")/.."
GODOT_BIN=${GODOT_BIN:-godot}
OUT=dist/Project-Solo-macOS
rm -rf "$OUT" dist/Project-Solo-macOS.zip
mkdir -p "$OUT"
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
# Exporting to a .zip makes Godot write the app bundle inside it (works on any platform).
"$GODOT_BIN" --headless --path . --export-release macOS "$OUT/ProjectSolo.zip"
[ -s "$OUT/ProjectSolo.zip" ] || { echo "Export failed: no ProjectSolo.zip" >&2; exit 1; }
unzip -q "$OUT/ProjectSolo.zip" -d "$OUT" && rm "$OUT/ProjectSolo.zip"
[ -x "$OUT/Project Solo.app/Contents/MacOS/Project Solo" ] || { echo "Export failed: no app bundle" >&2; exit 1; }
cat > "$OUT/README-MACOS.txt" <<'TXT'
Project Solo - macOS (Apple silicon and Intel)

1. Unzip Project-Solo-macOS.zip anywhere.
2. Open "Project Solo.app".
3. macOS blocks apps it cannot check. The first time, either run this once in Terminal, in the folder
   that holds the app:
       xattr -cr "Project Solo.app"
   or try to open it, then go to System Settings > Privacy & Security and choose "Open Anyway".
   (On macOS 15 and later, right-click > Open no longer works.)
4. Click Start Game on the title screen.

Saves are stored in ~/Library/Application Support/Godot/app_userdata/Project Solo/
Controls are in the project README: https://github.com/eelundin3-sketch/project-solo#download-and-play
TXT
( cd dist && zip -qr Project-Solo-macOS.zip Project-Solo-macOS )
ls -lh dist/Project-Solo-macOS.zip
