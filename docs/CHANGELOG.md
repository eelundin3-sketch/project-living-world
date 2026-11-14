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
