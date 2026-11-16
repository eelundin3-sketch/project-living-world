# Changelog

## Current village, artwork, and handoff — 2026-11-16

- Alder Hollow now starts with ten residents. Reedbank remains a separate town.
- Furniture occupies real tiles along room edges. The saw and stock rack have
  separate approaches, and the sawyer works through a bulk input load before
  carrying finished stock to market or the warehouse.
- Timber and provisions stalls own their stock and funds. Press **F** at a
  counter to buy or sell. Older saves receive stalls once without duplicating
  stock or cash.
- New construction uses the larger measured plans. Builders stage supplies in
  the middle, build walls first, and return for material after every tile.
  Terrain generation reserves starter expansion plots for the larger homes.
- Regional terrain blends sand and gravel into the ground. The original props,
  2D characters, and cutaway rooms support close zoom. Character transitions
  blend between poses, including a separate sprint cycle.
- The health window now shows an injury silhouette and right-click treatment.
- The [current game guide](CURRENT_GAME.md) consolidates behavior, source locations,
  save and backup instructions, and runnable demonstrations.

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

## Forests, animation and audio — 2026-11-15

- Increased the initial forest from 78 to 420 spaced trees across both settlements,
  preserving road/building clearings and upgrading older saves once.
- Added distance-based walking, visible cargo, axe strikes, saw strokes, building
  motions, pickup/drop bends, wind sway and falling trees. Motion reads simulation
  state and pauses with it; movement and camera following are interpolated.
- Gathering now uses explicit pickup/deposit phases around atomic inventory
  transfers. Sawyers work inside their mill; other haulers pause to handle goods.
- Added ten original synthesized sounds, positional mixing, surface-dependent
  footsteps, contact-timed work cues, wind, saved sound toggle and reduced motion.
- Added animation unit and actual-scene integration tests (14 suites total), and
  made the runner reject runtime errors even when a test exits successfully.

## Reference-inspired scenery — 2026-11-15

- Added original seeded earth textures and four layered green canopy variants,
  warmer wooden floors and light timber walls, collar and belt details.
- Replaced per-frame canopy polygon construction with imported reusable textures;
  existing wind, harvesting, carrying and tree-fall presentation is retained.
- Assets are generated by scripts/generate_scenery.py; no screenshot assets copied.

## Village streetscape and figure redesign

- Replaced oval coats with outlined tailored silhouettes; enlarged figures, added
  paired eyes, hair, collar and belt details while preserving action-driven poses.
- Replaced flat wall strips with shaded beveled cutaway sections aligned to existing
  collision cells and doors. Added lamps, chairs, banded chests and boardwalk porches.
- Added open storehouse squares, edge benches and differentiated home/workplace
  frontages. Existing building positions and simulation ownership are retained.
- Added `tests/village_design_capture.gd`, a runnable unobstructed village preview.
  Building/navigation and live animation suites passed; native capture inspected.

## Comprehensive reference-led redesign — 2026-11-15

- Replanned the initial settlements and construction plots around a public lane,
  storehouse square, domestic plots and a separate workshop/farm side.
- Expanded homes to 11×9 cells, warehouses to 13×10 and mills to 13×8. Added
  authoritative internal walls and two-cell passages; every room is reachable.
- Rebuilt furnishings with beds, pillows, blankets, rugs, tables, place settings,
  shelves, stoves, saw benches, chairs, banded chests and shaded supply crates.
- Added original grain-textured planks, grassy verges, layered paths, lamp halos,
  and time-of-day tinting. F8 toggles compact HUD status hints; time/speed controls
  remain visible.
- Reworked figure proportions, segmented arms/legs, coat silhouettes, faces, hair,
  hats and boots, retaining tool and cargo animations.
- Older saves receive a one-time architecture reflow preserving goods and IDs.
  New architecture regression checks every room, wall, overlap and upgrade replay.
- New runnable close-up and mature-village captures live under tests/; no assets
  or source code were copied from the reference game.

## Physical machines and stock handling

- Added solid saw benches and stockpile footprints, reachable interaction positions,
  navigation-aware worker routing, and stockpiles for construction materials.
- Removed decorative stand-in logs and machines from work areas. Real building
  inventory drives rack quantities, machine input and finished planks on the outfeed.
- Added independent blade rotation, input feed and sawdust during attended work;
  disabled/interrupted machines stop and pause freezes machine/item animation.
- Actual committed transfers animate between worker hands and the relevant storage
  slot. Presentation cannot create goods; saves do not replay historic transfers.
- Existing saves gain fixtures once, preserving inventory and relocating any actor
  standing in a new solid footprint. Rendering avoids interpolating feet through
  solid cells at accelerated simulation speeds.
- Added fixtures_test.gd and fixture_capture.gd; the runner now has 16 suites.

## Player controls, health and movement

- Added I inventory, F contextual drop/pickup/gather/work/talk, and H body health.
  People trade their own inventories and real money; nearby stores use existing
  markets. Physical transfers, selected hand stack and medical supplies are saved.
- Added 17 selectable body parts, bleeding, pain, dirty/clean bandages, infection,
  timed bandaging/cleaning, natural recovery and movement/work effects from injury.
- Added Shift sprint with a distinct run gait, a visible stamina bar, deterministic
  stamina use per sprint step and regeneration after release.
- Mouse wheel and trackpad pinch zoom work across the entire window, including
  when inventory, health or interaction panels are open.

## Metric tiles, incremental building and compact HUD

- Defined each integer world cell as 1 m (24 px at default zoom). Ground, interior
  floors and walls now render as visible block/tile units on that measured grid.
- Construction collects deliveries at its central site fixture, then spends material
  and places floor, wall, door and roof tiles in sequence. Walls become collision
  cells as they are built; the doorway stays open until the structure is finished.
- Replaced the persistent inspection/sidebar/footer layout with a compact upper-left
  clock, stock and stamina strip. Pause, 1×, 2× and 3× buttons stay visible; tools
  open only when requested.
- Removed character ground shadows and the circular selection marker. Walking now
  has clearer alternating knees/feet, opposing arm swings, torso sway and bounce.
