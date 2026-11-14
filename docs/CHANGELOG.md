# Changelog

## M0 / Task 001 — 2026-11-14

- Added Godot project and Main scene with placeholder ground, observer camera,
  WASD movement, bounded wheel zoom and diagnostic HUD.
- Pinned Godot 4.6 stable and verified official build `89cea1439`.
- Copied all four supplied blueprint documents and adopted contributor rules.
- Established application, simulation, view, content and test directories.
- Added dependency-free headless smoke tests, Git ignores, README and decisions.
- Validation: headless import and smoke tests passed (exit 0); graphical renderer
  initialized without startup errors. Visual inspection timed out; manual
  appearance/physical keyboard verification remains pending.
- M1 and later simulation/gameplay milestones are not implemented.

## Integrated prototype — 2026-11-14

- Implemented the deterministic kernel and seeded physical world, then resident
  needs, job reservations, local navigation, inventory transactions and save/load.
- Added real sawmill labour and input/output hauling, material-funded housing,
  local trade, a second settlement and scheduled cargo-owning merchants.
- Added chunk/fidelity handling, batched distant work, households, bounded social
  memories, policy/treaty changes, migration, guards and non-lethal danger.
- Replaced the bootstrap view with an inspectable game, player movement, trade
  controls, travel, observer tools, larger text and remappable movement.
- Added checksummed saves and backup recovery, v1 migration, external recipe data,
  11 regression suites, benchmarks, CI and six desktop export configurations.
- Actual validation and remaining platform/scale limits are recorded in
  VALIDATION.md and IMPLEMENTATION_STATUS.md; supplied design documents are intact.

## Character graphics update — 2026-11-14

- Replaced resident/player dots with original outlined frontier figures inspired
  by the supplied visual reference: earthy clothing, hats, faces, boots and skin
  tone variations, plus walking poses, carried goods and occupation details.
- Kept character artwork in a presentation-only drawing helper; simulation data
  and saved identities are unchanged. Character picking follows the taller art.
- Verified native rendered screenshot and UI smoke test; rebuilt desktop exports.

## Map art and enterable buildings — 2026-11-14

- Restyled ground, paths, trees/stumps, rocks, farms/crops, storage crates, barrels,
  carts, construction sites and all buildings in the characters' outlined earth palette.
- Replaced building icons with multi-cell cutaway rooms: homes have beds/tables,
  stores have supplies, and sawmills have workbenches. Furnishings are decorative.
- Added authoritative solid perimeter walls and open south-facing door cells.
  Player and NPC navigation respects walls; footprints persist in save snapshots.
- Construction reserves a full footprint and a clearance margin. Initial villages
  have more space between buildings; earlier saves gain missing building layouts
  while retaining entity identities and inventories.
- Added building entry/wall/navigation/save-upgrade tests and an actual indoor
  player capture at docs/screenshots/interior.png. The regression runner now has
  12 suites. Desktop builds are regenerated for this update.
