#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
GODOT_BIN=${GODOT_BIN:-godot}
mkdir -p builds/windows builds/macos builds/linux
for mode in debug release; do
  "$GODOT_BIN" --headless --path . "--export-$mode" 'Windows Desktop' "builds/windows/LivingWorld-$mode.exe"
  "$GODOT_BIN" --headless --path . "--export-$mode" macOS "builds/macos/LivingWorld-$mode.app"
  "$GODOT_BIN" --headless --path . "--export-$mode" Linux "builds/linux/LivingWorld-$mode.x86_64"
done
