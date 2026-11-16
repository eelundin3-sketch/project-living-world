#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
GODOT_BIN=${GODOT_BIN:-godot}
TEST_OUTPUT=$(mktemp /tmp/lw-test-output.XXXXXX)
trap 'rm -f "$TEST_OUTPUT"' EXIT
run_checked() {
  if "$GODOT_BIN" "$@" > "$TEST_OUTPUT" 2>&1; then
    cat "$TEST_OUTPUT"
  else
    cat "$TEST_OUTPUT"
    return 1
  fi
  # Some SceneTree scripts can quit(0) after a runtime error: reject that too.
  if grep -Eq '^(SCRIPT ERROR:|ERROR:|FAIL:)' "$TEST_OUTPUT"; then return 1; fi
}
run_checked --headless --path . --editor --import --log-file /tmp/lw-import.log
for test in loot_test context_test sleep_test brawl_test hotbar_test diagonal_names_test needs_test crops_test households_test placement_test shotgun_test kernel_test world_test forest_groves_test weather_test travel_reroute_test local_combat_test unarmed_test building_test construction_stages_test architecture_test depth_order_test fixtures_test player_health_test player_interaction_test player_panels_test player_mobility_test animation_test animation_live_test village_test production_test economy_test regional_test society_test persistence_test interruptions_test smoke_test soak/full_game_test; do
  run_checked --headless --path . --script "res://tests/$test.gd" --log-file /tmp/lw-test.log
done
