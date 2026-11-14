# Validation record — 2026-11-14

Host: Apple M4, macOS. Engine: Godot `4.6.stable.official.89cea1439`.
The original documents describe a proposed Windows reference machine; these are
measurements on the actual development host, not claims about that reference.

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

`tests/render_capture.gd` loads the actual Main scene, advances the world 1,600
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
