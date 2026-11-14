# Project Living World

A playable Godot desktop prototype of the supplied living-world blueprint. Walk
through two original frontier settlements while residents gather, haul, eat, rest,
produce planks, build homes and trade. Inspect the people and stocks to trace why
something happened. The same simulation runs without a scene or renderer.

## Play

On this Mac, open `builds/macos/LivingWorld-release.app`. Windows and Linux debug
and release builds are in `builds/windows/` and `builds/linux/`. Builds are local,
unsigned artifacts; macOS has been launch-tested. Windows/Linux execution has not
been verified on their target operating systems.

For development, import `project.godot` in **Godot 4.6 stable**, standard GDScript
edition, and press **F5**. The validated engine is `4.6.stable.official.89cea1439`.
Download: https://godotengine.org/download/archive/4.6-stable/

A portable engine is currently at `/private/tmp/living-world-engine/Godot.app`.
That temporary path is not a permanent installation. From the repository root:

```sh
GODOT_BIN=/private/tmp/living-world-engine/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --editor --path .
"$GODOT_BIN" --path .
```

## Controls and things to try

- **WASD:** walk the traveller. **Wheel:** zoom. **Click:** inspect an entity/path.
- **Space:** pause. **1 / 2 / 3:** 1× / 2× / 4× speed.
- **F5 / F9:** save/load. Saves preserve jobs, goods, needs, identities, RNG,
  pending commands and scheduled journeys. A `.bak` is retained for recovery.
- **Tab / Follow:** switch between following the player and panning the camera.
- **Walk to the other village:** follow a validated path to Reedbank/Alder Hollow.
- **Buy/Sell:** trade one item at the nearby store (within six cells). Ask/bid
  quotes are executable offers; the store inspector separately shows last trades.
- **F3 / Observer tools:** road closure, danger, treaty, batch cancellation,
  recipe loading and four movement-key rebinding buttons. Click a direction and
  press a new key; Esc cancels. **F2:** spawn a diagnostic entity by command.
- **Larger text:** increases inspector and event text. Buttons support keyboard
  focus; the sidebar scrolls when its content exceeds the available space.

Watch a worker harvest logs, carry them to storage, and the sawyer carry inputs to
work and planks back to storage. Housing shortages cause a builder to carry those
planks to a new home. Inspect a resident while they interrupt work to eat or rest.
Visit Reedbank to watch offscreen changes become visible. Close Moss Road to hold
cargo in transit, then reopen it. Sell supplies and inspect a resident's memory.

## What is implemented

- Deterministic 10 Hz kernel, stable IDs, dedicated RNG streams, ordered commands
  and events, canonical state hashes, pause and time speed controls.
- Seeded terrain/resources, negative-coordinate chunk mapping, deterministic local
  navigation, player movement, camera culling and interactive inspectors.
- Persistent residents, hunger/fatigue, exclusive job leases, recovery/retry reasons,
  capacity reservations and physical gather→carry→deposit logistics.
- Atomic recipe batches, actual worker labour, input/output hauling, construction
  planning and material-funded homes; data definitions also support warehouses.
- Integer-money markets, ordered bids/asks, scarcity-sensitive transaction prices,
  player trade and cargo-owning merchants between two self-sustaining towns.
- Detailed/coarse/aggregate work batches, deterministic chunks and exact resource
  summaries; no offscreen NPC scene nodes or duplicate inventory owners.
- Households, occupations/skills, bounded memories/relationships, policy changes,
  migration, factions/treaties, guards, risk avoidance and non-lethal incidents.
- Checksummed saves, backup recovery, v1→v2 migration, data-only recipe overrides,
  remappable movement, larger text, benchmarks, CI and desktop export presets.

The milestone evidence and scope limits are in `docs/IMPLEMENTATION_STATUS.md`.
This is an integrated prototype of the roadmap, not a finished commercial game:
placeholder graphics, a finite two-town region, three commodities and one recipe
chain. Named-agent aggregation is implemented; 50k anonymous population simulation,
unbounded procedural settlements, elaborate combat and distribution signing are
not claimed. The design pack itself places large population targets behind future
profiling and treats deeper conflict as optional emphasis.

## Tests

No test framework or gameplay plugin is required:

```sh
GODOT_BIN=/private/tmp/living-world-engine/Godot.app/Contents/MacOS/Godot scripts/test.sh
```

The runner imports the project, then executes 11 suites: kernel, world/inventory,
village, production, economy, regional simulation, society/risk, persistence/content,
1,000 interrupted jobs, UI smoke and the full seven-day scenario. Every suite exits
nonzero on failure. The kernel replays 100,000 ticks; recipes exercise 100,000
synthetic interruption/commit cycles. Both village and full-world tests compare
save/reload continuation through tick 100,800. CI uses the same pinned Godot on
Linux; the workflow is included but has not been run on a remote service.

Individual tests:

```sh
"$GODOT_BIN" --headless --path . --script res://tests/kernel_test.gd
"$GODOT_BIN" --headless --path . --script res://tests/soak/full_game_test.gd
"$GODOT_BIN" --headless --path . --script res://tests/benchmark/simulation_benchmark.gd
"$GODOT_BIN" --path . --script res://tests/benchmark/frame_benchmark.gd
"$GODOT_BIN" --path . --script res://tests/render_capture.gd
```

The last benchmark measures five real minutes after five seconds of warm-up.
JSON results are written into `docs/`. Render capture writes `docs/screenshots/game.png` after advancing the village
and selecting its sawmill. See `docs/VALIDATION.md` for results and limitations.

## Saves and recipes

Godot's `user://` directory holds `living_world.save` and `controls.cfg`. On macOS
it is `~/Library/Application Support/Godot/app_userdata/Project Living World/`.
Corrupt primary saves recover from their `.bak`; unsupported engine/schema versions
are rejected without replacing the running world.

Copy `content/recipes/example_mod.json` to `user://recipe.json`, then choose
**Observer tools → Load recipe.json**. Validated idle sawmills adopt the new recipe;
in-flight batches finish with their original recipe. Save files embed loaded
recipe definitions. Only known items and bounded positive integer quantities are
accepted; no external code is executed.

## Export

Download the official Godot **4.6 stable export templates** and use:

```sh
scripts/prepare_exports.sh /path/to/Godot_v4.6-stable_export_templates.tpz
GODOT_BIN=/path/to/godot scripts/export.sh
```

For macOS, also install the `.tpz` through **Editor → Manage Export Templates**.
The presets write six debug/release artifacts under ignored `builds/` folders.
The official macOS export documentation is at
https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_macos.html.

## Source map

`app/` composes the simulation and UI; `sim/core/` owns the tick/commands/snapshot.
Other `sim/` directories own world, resident, job, inventory, production, economy,
settlement, society and persistence services. `view/` only projects those records.
`content/` holds original data definitions. `tests/` contains runnable gates;
`docs/` preserves all four supplied documents plus decisions and validation.

Use typed GDScript where practical, stable IDs, explicit dependencies and small
services. Commit `.gd.uid` files; ignore `.godot/` and `builds/`. All art/code/content
here is original placeholder work; no source or assets were copied from the
inspiration game.

## Entering buildings

Buildings are now full-sized, permanently cutaway rooms. Walk through the open
**south-facing doorway** with WASD; there is no scene transition or interaction key.
The walls block movement and worker navigation. Rooms contain decorative beds,
tables, crates and workshop equipment. Earlier saves are upgraded with building
footprints on load, retaining people and goods. Construction checks the complete
footprint before choosing a site. The building suite adds door-entry, wall collision,
indoor save/reload and legacy-upgrade checks to the regression runner (12 suites).
