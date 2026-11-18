# Validation record

## Upright standing profile — 2026-11-16

The standing pose in `view/actors/drawn_character.gd` aligns the hip, knee and
ankle in profile. Character art checks both sides, with and without the shotgun
in hand. Player mobility, shotgun and live animation tests also passed.
Reproduce the [turnaround](../screenshots/character-design.png) by running
`godot --path . --script res://tests/captures/character_design_capture.gd`.

## Walking foot roll — 2026-11-16

The drawn character now rotates each boot around its heel or toe during the
walking cycle and blends ankle pitch as the pose changes. Character art tests
cover the heel-first, flat and toe-off phases and verify that rotating the boot
preserves the support point in the stride preview. The live animation, player
mobility and shotgun tests passed.

Godot rendered the action sheets from five headings. The side view was reviewed
and the [motion preview](../screenshots/character-motion.gif) was regenerated with
`tests/captures/character_motion_capture.gd`.

## Walking stride — 2026-11-16

The walking pose in `view/actors/drawn_character.gd` keeps the foot tied to
distance travelled during contact. The artistic change is a shorter forward
reach and a longer push-off behind the hips. The character art test checks
the rear knee and foot, the opposite foot's landing, heel lift and continuity
at the step boundaries. Player mobility, live animation and shotgun controls
also passed in Godot 4.6.

Reviewed side and diagonal walk cycles with `tests/captures/anim_sheet_capture.gd`
using `LW_HEADING=0` and `LW_HEADING=45`. Regenerated the
[motion preview](../screenshots/character-motion.gif) with
`tests/captures/character_motion_capture.gd` and rebuilt both Mac apps.

## Shotgun carry and aim — 2026-11-16

Godot 4.6 headless import, shotgun controls, character art, player mobility,
live animation and hotbar checks passed. The shotgun test drives the game's
mouse handlers while moving, checks the carry and aim poses, and verifies that
a left press while aiming consumes one shell. The art test checks the 25% length
reduction and aim between the body's drawn directions.

The graphical character detail and turnaround captures were refreshed. Run
`godot --path . --script res://tests/captures/character_detail_capture.gd` for the carry
preview. Both macOS exports rebuilt and the release app passed a launch check.

The separate `unarmed_test` pointer and ready-pose assertions also failed on
an isolated copy of the unchanged branch. The weapon tests passed.

## Neck and running follow-up — 2026-11-16

`character_art_test`, `player_mobility_test`, `animation_live_test`, and
`player_panels_test` passed for the revised art and movement. New checks verify a
backward heel extension after toe-off, a knee behind the hip, raised heel recovery,
continuous foot positions at lift-off/recovery/cycle wrap, and selectable neck health
region. Side and diagonal sprint contact sheets and the revised detail sheet were
visually reviewed. The motion, turnaround, gameplay and health captures were refreshed.

Run this for the side sheet; use `LW_HEADING=45` for the diagonal:

```sh
LW_HEADING=0 LW_SHEET_DIR=/tmp/lw-running "$GODOT_BIN" --path . --script res://tests/captures/run_sheet_capture.gd
```

## Drawn character redesign — 2026-11-16

Godot 4.6 stable (`89cea1439`) headless editor import passed. These checks passed:
`character_art_test`, `player_mobility_test`, `animation_live_test`, `loot_test`,
`player_panels_test`, `shotgun_test`, `animation_test`, `player_health_test`,
`depth_order_test`, and `smoke_test`.

The new character-art check covers 24 actions at 12 phases in eight directions:
finite joints, valid cloth triangulation, connected silhouettes, grounded resting
feet, relaxed hand clearance and selectable health regions. The graphical action
sheets rendered 20 actions at eight phases in eight directions (40 sheets), with
no Godot drawing or script errors. The detail sheet, turnaround, actual village
close-up and health screen were visually inspected. The 135-frame motion preview
was regenerated with the sprint blend enabled. macOS release/debug builds were
regenerated; the release app also passed a 90-frame headless launch check.
Windows/Linux builds were not.

**Existing failure:** `brawl_test.gd` fails its repeated-punch knockout assertion,
then accesses a missing `knock` key at line 54. The identical failure was reproduced
from an isolated `git archive HEAD` copy before the character changes. No combat
simulation files were changed here. This broader suite is not fully green.

Reproduce the focused check and visual demonstration:

```sh
"$GODOT_BIN" --headless --path . --script res://tests/view/character_art_test.gd
"$GODOT_BIN" --path . --script res://tests/captures/character_detail_capture.gd
"$GODOT_BIN" --path . --script res://tests/captures/character_design_capture.gd
```


Host: Apple M4, macOS. Engine: Godot `4.6.stable.official.89cea1439`.
The original documents describe a proposed Windows reference machine; these are
measurements on the actual development host, not claims about that reference.

## Current handoff — 2026-11-16

See the [current game guide](../status/CURRENT_GAME.md) for gameplay and data locations.
The checks below cover the updated furniture, workshop, and marketplace.

| Check | Evidence |
|---|---|
| Layout and depth | Doorways and rooms remain reachable. Furniture, saws, racks, and counters block their recorded cells and leave open approaches. |
| Production and trade | The 100,000-cycle recipe test and live bulk production test pass. A worker stocks the workshop, runs multiple batches, and delivers planks to the timber stall. The player buys from that stock. |
| Construction | One 385-tile build completes with 385 material pickups and 385 returns. Partial walls remain walkable until finished, and carried materials and work progress survive save and restore. |
| Housing growth | The 20-resident economy stress case completes three full-size homes within an 80,000-tick limit. Starter expansion plots are reserved during terrain generation. |
| Save and controls | Persistence and content, player interactions, and UI smoke tests pass. Market stock round-trips exactly, and installing stalls into a pre-stall save keeps its population, goods, and funds. |
| Visual demonstration | [The live market capture](../screenshots/market-stalls.png) was rendered in Godot after the sawyer's first delivery. |
| Desktop export | The macOS release was rebuilt with the pinned Godot 4.6 executable and launched headlessly for 25 frames. Windows and Linux builds were not refreshed for this revision. |

Focused checks use `--headless --path . --script res://tests/<name>.gd`.
The complete runner is `scripts/test.sh`. Some sandboxed Mac sessions report a
system CA or editor-settings error before tests run. A focused test with
`--log-file /tmp/lw-test.log` can run without writing a log to the app data folder.
The earlier entries below are dated observations and may describe retired
graphics, controls, or scenario sizes.

## Regression gates

Executed from the repository root:

```sh
GODOT_BIN=/private/tmp/living-world-engine/Godot.app/Contents/MacOS/Godot scripts/test.sh
```

Exit status **0**. Headless import completed without parser errors. All 11 suites
passed; the final full-suite log contained no `ERROR`, `WARNING`, or `FAIL` lines.

```text
Kernel: PASS (100k replay, IDs, events, frame cadence, pause)
World/inventory: PASS
Village: PASS; tick=100800, deliveries=275, hash=dacf41f26af90c9dfbb66964ca2127e7c0cfb6ef3438f01995c988e06940fee0
Production: PASS (100k cycles + live supply chain)
Economy: PASS; completed homes=3
Regional: PASS; caravan deliveries=1
Society/risk: PASS
Persistence/content: PASS
Interruptions: PASS; 1000 completed jobs
UI smoke: PASS
Full game seven-day soak: PASS; tick=100800; deliveries=397; buildings=3; hash=ab04ee83ba7ef356c30b7e774de074648433bf3b8561a555f1dfc173126e6bd3
```

The final UI smoke was additionally rerun after increasing inspector height and
adding an actual mapped-key movement check. It passed. The population benchmark
was rerun after keeping all 300 starting residents inside walkable map bounds.

Coverage includes all material and currency invariants, exclusive leases,
interruption/path-failure/removal recovery, frame-cadence-independent ticks,
once-only events/recipes/conflicts, migrating identities, corrupt-save recovery,
v1 migration, data recipes and full-game deterministic save continuation.

## Simulation benchmark

```sh
"$GODOT_BIN" --headless --path . --script res://tests/benchmark/simulation_benchmark.gd
```

Seed 417. Each population runs 1,000 warm-up ticks and 6,000 measured ticks.
These are seeded village workloads with finite jobs/resources, not a claim that
all residents are simultaneously running worst-case navigation. All final
invariants passed. Budget: 100 ms per authoritative tick at 10 Hz.

| Residents | p50 ms | p95 ms | p99 ms | Max ms | Save ms |
|---|---:|---:|---:|---:|---:|
| 20 | 0.086 | 0.140 | 0.147 | 0.643 | 6.72 |
| 100 | 0.566 | 0.644 | 0.908 | 1.783 | 10.53 |
| 300 | 1.730 | 2.024 | 4.075 | 15.844 | 21.33 |

Raw results, memory and save sizes: `simulation_benchmark.json`.

## Five-minute native graphics benchmark

```sh
"$GODOT_BIN" --path . --script res://tests/benchmark/frame_benchmark.gd
```

Five seconds of warm-up followed by 300 measured seconds, Apple M4 OpenGL
Compatibility renderer, 1280×720. 35,536 measured frames:

- Frame p50: **8.535 ms**; p95: **12.115 ms**; p99: **14.076 ms**.
- Maximum observed frame: **69.864 ms**. There were outliers; this does not promise every frame meets 16.67 ms.
- Simulation p95 in the graphical run: **3.891 ms**.
- 69 scene nodes; 44 stored chunks; Godot static allocation about 34.5 MiB (not total process/GPU memory).

This run measured the integrated game before the final recipe/schema hardening
and inspector sizing pass. Final source then passed regression, native capture
and the simulation benchmark. Raw graphics results: `frame_benchmark.json`.
No 1080p Windows performance or 50k-population measurement is asserted.

## Render and desktop builds

`tests/captures/render_capture.gd` loads the actual Main scene, advances the world 1,600
ticks, selects a sawmill, and captures its viewport. `screenshots/game.png` was
visually checked for the world, stores, completed homes, player, inspector,
trading controls and event history.

```sh
GODOT_BIN=/private/tmp/living-world-engine/Godot.app/Contents/MacOS/Godot scripts/export.sh
```

Debug and release exports were generated for Windows x86_64, Linux x86_64 and
universal macOS. Both macOS executables were launched with `--headless
--quit-after 30`; native graphics was exercised through the editor/runtime capture
and five-minute run. Final export logs contained no errors or warnings. Both final macOS launch
checks completed successfully with clean runtime logs. An earlier attempt was
not executed because automatic approval review reached a usage limit; after the
user requested continuation, the checks were retried and passed.
Windows and Linux binaries were not executed on their target operating systems.

Early sandboxed engine invocations reported macOS certificate/cache-access errors;
the full regression/import was rerun with normal Godot access and was clean. These
sandbox messages were not parser/gameplay failures. All build artifacts are local,
unsigned/not notarized. Git excludes generated caches and desktop binaries.

## Map/interior update verification

The updated map passed all 12 regression suites, including the new building
entry, solid-wall, navigation, indoor persistence and legacy-save checks.
The seven-day full-game replay still matches its save/reload continuation.
Native captures verify both the map and the player entering a house through its
doorway. Screenshots: `screenshots/game.png` and `screenshots/interior.png`.
The earlier frame benchmark describes the previous graphics revision, not this
new artwork. Debug/release desktop exports were rebuilt for this update.

## Forest, animation and sound update — 2026-11-15

Ran `scripts/test.sh` with Godot 4.6 stable: all 14 suites passed, including
animation/audio unit checks and the actual Main scene integration. The latter
observed walk, chop, pickup, carry, drop, saw and build actions, and matching step,
chop, pickup, drop and saw cues. Tests verify presentation does not mutate the
simulation, pause freezes it, and material transfers occur at handling boundaries.
The final seven-day replay passed at tick 100800 with 477 deliveries and 3 buildings;
its save/reload hash was
`3f586caacf77281aaf4580ec080ba91d9d55714263ed23552977f222b26627f4`.

Native `tests/captures/render_capture.gd` successfully captured both the updated settlement
and the player indoors; both images were visually inspected. Original WAV resources
load successfully. Native playback was exercised without runtime errors; no claim
of a human listening review is made. Headless runs suppress audio playback while
still testing audio resources and event cues.

`tests/benchmark/animation_frame_benchmark.gd` is a runnable 30-second native
animation demonstration/measurement after five seconds of warm-up. Current results
are stored separately in `animation_frame_benchmark.json`; earlier performance
figures above describe older revisions. Final tree rendering collects building
footprints once per frame rather than scanning all entities for each visible tree.

All six desktop exports were regenerated. macOS debug and release headless launch
checks passed. Windows/Linux execution remains unverified on their target systems;
builds remain unsigned. Sound on/off persists, while reduced motion is session-only.

The current native sample on Apple M4 at 1280×720 measured 667 frames in 30 seconds
(about 22 fps): p50 45.378 ms, p95 54.665 ms, p99 64.918 ms, maximum 126.549 ms;
simulation p95 6.816 ms. Dense animated vector drawing remains a performance
limitation; this update does not meet a 60 fps target on this measured run.

## Reference-inspired texture pass

Native 30-second sample: 1844 frames (~61 fps), median 15.687 ms, p95 21.451 ms,
p99 29.896 ms, max 31.173 ms. This supersedes the preceding 22 fps scenery sample;
not every frame meets 16.67 ms. Original imported canopy textures replace repeated
polygon generation. Animation unit and live integration tests passed. Updated map
capture was visually inspected. A native capture emitted an ObjectDB shutdown-leak
warning; no rendering/parser error occurred. This shutdown cleanup warning remains
under investigation. Desktop exports were regenerated.

## Village streetscape pass

Executed `tests/sim/building_test.gd` and `tests/view/animation_live_test.gd` headlessly:
both passed. Native `tests/captures/village_design_capture.gd` captured the redesigned
village without UI panels; `screenshots/village-design.png` was visually inspected.
This pass changes presentation, furnishing and frontages; existing building
footprints, positions, doors and authoritative inventories are retained. Decorative
chairs/lamps/porches do not add collision or interactive furniture behavior.

## Comprehensive architecture/art pass — 2026-11-15

The architecture suite checks every walkable interior cell from each doorway,
solid partition cells, nonoverlapping initial buildings, exact snapshot roundtrip,
and inventory-preserving/idempotent legacy reflow. It passed. Final UI smoke and
actual-scene animation integration passed after the artwork changes. Native
character, room and mature-village captures were visually inspected; face contrast,
label placement and overlapping furnishings were corrected. Final capture logs
were clean after allowing the audio device to release streams before test shutdown.

Native 1280×720 / Apple M4 sample: 1788 frames over 30 seconds (~59.6 fps), median
16.896 ms, p95 25.3 ms, p99 30.295 ms, max 78.838 ms, simulation p95 9.937 ms.
These numbers describe the expanded architecture/scenery pass; no locked 60 fps
or target-platform Windows/Linux performance is claimed. Minor subsequent figure
outline/proportion adjustments were verified by capture and integration tests.

Known scope: furnishings remain decorative, while both outer and inner walls are
solid. Lamp halos and time-of-day tinting are stylized presentation, not dynamic
shadow-casting lights. The fixed two-town world remains finite; screenshots supplied
as inspiration do not add combat, wildfire or a new river simulation to this pass.

Final complete `scripts/test.sh` run: all **15 suites passed**, including the
architecture suite and seven-day replay. Final replay: tick 100800, 475 deliveries,
3 completed buildings, hash
`e8b1d097adabd2d476c3bb10a454d7f7b1287e9969fd535778d0eaab901bc1f6`.
The final test log contains no ERROR, WARNING or FAIL lines.
Final macOS debug/release headless launch checks and a native release launch
(`--quit-after 120`) exited 0 with clean logs. All six exports completed successfully.
Windows and Linux artifacts were built but not executed on their target systems.

## Physical machines and stockpiles

The fixture suite passed checks for solid footprint cells, reachable operator
stances, player movement blocked by a stockpile, exact inventory deposits, a single
transfer animation per commit, no historic transfer playback, pause immutability,
legacy upgrade conservation/idempotence, 3000 ticks with no worker inside a blocked
cell, actual machine rotation during attended work, and stopping disabled machines.
`tests/captures/fixture_capture.gd` runs the actual simulation until attended sawing and a
log-handling event occur. Both were captured and visually inspected in
`screenshots/working-machine.png` and `screenshots/stockpile-handling.png`.

Changed areas: `sim/world/fixtures.gd`, world collision/upgrade, production/job/need
movement targets and bounded inventory transfer observations; `view/world/fixture_*`
for machine/pile/item projection; character poses and collision-safe interpolation.
These fixtures share the existing building inventories. No additional inventory
owner or free goods are introduced. Other decorative furniture remains non-solid;
this change provides grid collision and interaction stances, not rigid-body dynamics.

Final fixture regression run: all **16 suites passed**, runner exit 0, no ERROR,
WARNING or FAIL lines. Seven-day replay: tick 100800, 476 deliveries, 3 completed
buildings, hash `23cc5e4d24edd07c35c90aa5e71f783eb6866c7fad8be0767b1e2382dc76e0cd`.
The final worker operating-pose guard was additionally checked with the actual-scene
animation suite. All six desktop artifacts were rebuilt. macOS debug/release
headless launches and a native release launch completed cleanly; Windows/Linux
execution remains unverified on those operating systems.
One short debug headless launch intermittently reported an exit-time ObjectDB/resource
cleanup warning. A verbose 60-frame debug rerun exited cleanly; release headless and
native checks were also clean. The warning was not reproduced in the sixteen-suite
run, but its intermittent shutdown cause is not claimed fixed.

## Player controls, zoom and body health — 2026-11-15

Added authoritative player inventory/interaction, injuries and treatment, stamina,
and sprint state. WASD movement, Shift sprint drain/recovery, wheel zoom and
trackpad magnification (including while the I/H panels are open) passed dedicated
headless tests. Health and inventory UI construction passed its suite. Interaction
tests cover pickup/drop, person trade, sawmill inputs/operation/output, and keeping
the player out of machine/stockpile cells. All 20 project suites passed when run as
individual headless checks, including the 100800-tick save/load replay (476
deliveries, 3 buildings, hash `16ccb5572d78cc78ffc6af363a957c14bc050fe8ca887123be455ab8042c894b`).

The bundled `scripts/test.sh` runner reaches and passes the first 14 suites, then
its import-output guard sees host sandbox errors when Godot tries to read system
certificates/save editor settings. The remaining six suites were run directly and
passed. Godot exports debug and release artifacts for all three desktop platforms;
the macOS debug build exited 0 under a 120-frame headless launch. The macOS
certificate-store diagnostic is emitted by this restricted host and did not prevent
tests, exports, or the app launch. Windows/Linux builds were not executed on target
operating systems. Headless UI screenshot capture was attempted but did not finish
within the session and was stopped; existing panel captures predate the stamina
bar.

## Metric tiles, phased construction and compact HUD — 2026-11-15

World data asserts a 1 m/cell scale (24 rendered px at default zoom); the initial
world bounds are 384 m × 256 m with 64 m chunks. The build-stage test validates a
167-tile home layout, its floor → wall → doorway → roof order, one tile per work
interval, flooring that stays walkable, wall collision added per tile, an open doorway,
centralized material delivery, and exact save/load while the walls are in progress.
Economy and seven-day tests confirm resource conservation and long-run determinism.

The compact HUD smoke test checks pause, visible stamina, hidden-on-start observer
tools, stock/status display and 3× clock advancement. The animation integration suite
continues to observe walk, carry, gather, saw and build actions; the drawing pass now
uses larger alternating foot/knee lift and opposing arm motion. Character and tree
ground ellipses and the selection ring were removed in code/assets. All 21 headless
suites passed across the final runs, including village and full-game replay at tick
100800 (472 deliveries, 3 completed buildings, hash
`f74e80eb6171ddc75816790600e78652691287a96e5750217fe860ec0b9a0f9f`). The macOS
certificate/editor-settings diagnostics remain host restrictions during import and
launch; they did not prevent tests or exports.

## Local combat encounter — 2026-11-15

The encounter test exercises NPC target selection, travel on walkable cells,
attack poses, projectiles, damage, wall impacts, save/load and inventory/job
invariants. It passed, together with animation, live animation, fixtures, 1000-job
interruptions, persistence and UI smoke suites. All six desktop exports completed;
the macOS debug app exited successfully after 120 headless frames. Godot emitted the
host certificate-store diagnostic. Combat poses have not been visually reviewed in
a native gameplay capture. The encounter is manually triggered through Tools;
automatic raids, player combat and treatment/recovery of incapacitated NPCs remain.

## Cursor-facing characters — 2026-11-15

Player mobility checks cover cursor-facing angles across all quadrants, right-button
press and release, and unchanged simulation hashes during turning. Existing
animation/audio, local combat and UI smoke tests passed. The code-native figure
changes its projected body width and face visibility between front, side and back;
it is not a set of fully authored 360-degree sprite frames. Native visual capture
of the complete turn has not been performed. All desktop exports were regenerated.

## Volumetric character rigs — 2026-11-15

The player mobility suite checks that the actual Node3D model follows cursor headings
through all quadrants while simulation state stays unchanged. Live animation, local
combat and UI smoke suites also passed. A native macOS release build was opened and
inspected at two zoom levels; the figures rendered with volumetric bodies. All six
desktop exports were rebuilt. The rig consists of procedural primitive meshes, and
each visible character uses its own 3D viewport: GPU performance at large crowds is
not yet profiled. Character sprites are composited above the world drawing, so their
depth ordering against trees and furniture is not fully resolved. Godot emitted the
host certificate-store diagnostic during headless checks.

## Running speed and gait — 2026-11-15

The movement suite compares equal-duration walking and sprinting (three versus six
cells), checks stamina is not spent against a wall, verifies knee bending and torso
lean, and covers mouse-facing angles. Building collision, player health, player
interaction, local combat, travel rerouting, persistence, live animation and UI
smoke suites passed. All desktop exports completed and the macOS debug export ran
for 120 headless frames. Godot emitted a host certificate-store diagnostic. The
new gait has not yet been visually reviewed during a native gameplay run.

## Physical construction work cycle — 2026-11-15

The construction test observes material transfer to the builder, loaded travel,
work adjacent to the target tile, return travel, wall collision and a snapshot
while material is carried. Conservation and reload checks passed. The extended
economy test completed three homes; the seven-day replay passed at tick 100800
(474 deliveries, three buildings, hash
`31e1f1b4c3f68a40fb4410ffd51f22956391e43dcd35ac33db2c997d57880916`).
Live animation, fixtures, player interactions, local combat, persistence and UI
smoke checks passed. All six desktop exports rebuilt and the macOS debug export
launched for 120 headless frames. Godot emitted the host certificate-store
diagnostic. The revised 3D work poses have not been reviewed in a native gameplay
capture; a builder waiting on an occupied or unreachable target waits for access.

## Ink-styled character pass — 2026-11-15

Movement/360-degree facing, live animation, local combat and UI smoke checks
passed. The macOS release export was opened and visually inspected at two zoom
levels: outlined, shaded 3D figures and clothing were visible in the village.
All six desktop exports were rebuilt. Headless runs reported the host certificate
diagnostic. The added outline pass has not been profiled with a large crowd.

## Taller walls and scenery depth — 2026-11-15

The depth-order test checks that actors, walls, furnishings, fixtures and dropped
items share the same Y-sorted parent, and that a wall's depth uses its ground edge.
Building navigation, architecture, fixtures, character movement, live animation and
UI smoke checks passed. A separate macOS preview was opened and visually inspected,
including movement through a doorway. Ground tiles and wall collision were not
changed. Godot emitted a host certificate-store diagnostic during headless checks.
Decorative porch trim remains background artwork and does not occlude characters;
the new scenery nodes have not been profiled in a large-crowd stress test.

## Clearer cutaway houses — 2026-11-15

Depth ordering, architecture reachability, staged construction, fixtures and UI
smoke tests passed. A native macOS preview was opened and the connected wall trim,
plank floors, room partitions and furnishings were visually inspected. All six
desktop exports were rebuilt. Headless runs emitted the host certificate-store
diagnostic. No simulation geometry or building inventories changed.

## Greener landscape and dense groves — 2026-11-15

Forest tests verify deterministic generation, unique tree cells, road clearance,
inventory accounting, preservation of construction plots and idempotent save
migration. World, animation, architecture, persistence and UI smoke checks passed;
the extended economy scenario completed three homes. The seven-day simulation
passed at tick 100800 (474 deliveries and three buildings, hash
`ef5e0cd36e7dff5c1542dc81fcf74f6a27bcdd6a1f5812e943c7a6087baa2a93`), prior to
the final migration-only plot protection. A native preview showed the greener
terrain; the grove view could not be inspected because the automation surface lost
its window. All six desktop exports were regenerated. Headless checks emitted the
host certificate-store diagnostic; GPU performance in denser woodland is unprofiled.

## Walking continuity — 2026-11-15

The movement suite drives the actual input, clock, simulation and visual director
at 60 FPS for two seconds; it checks sustained frame-to-frame motion and the five
cells per second walking cadence. Sprint speed, wall collision, health, fixtures,
live animation, local combat and UI smoke checks also passed. Godot emitted the
host certificate-store diagnostic. The changed timing has not been visually
reviewed in a native gameplay capture.

## Unarmed controls — 2026-11-15

The unarmed suite checks the pointer and ready state, right-plus-left punch command,
Space shove, P pause, delayed impact, direction/range, cooldown, damage, knockback,
wall collision, worker job release, inventory invariants and snapshot restore.
Movement, health, interactions, local combat, staged construction and UI smoke
suites passed alongside it. Godot emitted the host certificate-store diagnostic.
The new character poses have not yet been visually reviewed in native gameplay.
