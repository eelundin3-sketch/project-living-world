#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
GODOT_BIN=${GODOT_BIN:-godot}
"$GODOT_BIN" --headless --path . --editor --import --log-file /tmp/lw-import.log
for test in kernel_test world_test building_test village_test production_test economy_test regional_test society_test persistence_test interruptions_test smoke_test soak/full_game_test; do
  "$GODOT_BIN" --headless --path . --script "res://tests/$test.gd" --log-file /tmp/lw-test.log
done
