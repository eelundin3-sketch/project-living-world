# Project Solo — Technical Architecture and Layers v0.1

This document is a proposed implementation for a **Godot 4 single-player desktop** game. It does not assert that *Another Dead World* uses any of the algorithms below.

## 1. The governing architecture

**One authoritative, headless-capable simulation state; render scenes are projections of that state.**

```
┌─────────────────────────────────────────────────────────────┐
│ Desktop presentation: Camera, TileMapLayer, NPC sprites, UI │
│ (reads snapshots / sends validated player commands)         │
└───────────────────────────┬─────────────────────────────────┘
                            │ commands / view data
┌───────────────────────────▼─────────────────────────────────┐
│ Application orchestration                                  │
│ SimClock · CommandQueue · EventQueue · SystemScheduler      │
├─────────────────────────────────────────────────────────────┤
│ Authoritative simulation stores                            │
│ Entities · Positions · Needs · Inventories · Jobs           │
│ Production · Settlements · Markets · Social · Factions      │
├─────────────────────────────────────────────────────────────┤
│ World services                                              │
│ Spatial index · Chunks · Navigation · Regional routes       │
│ Resource regeneration · Detailed/coarse/aggregate LOD      │
├─────────────────────────────────────────────────────────────┤
│ Infrastructure                                              │
│ Deterministic RNG · Save/Load · Validation · Profiling      │
└─────────────────────────────────────────────────────────────┘
```

**Dependency direction:** interface → application commands → simulation systems → data stores. Stores may publish domain events; they must not depend on UI. Rendering must not own persistent inventories, NPC identity or economic truth.

## 2. System layers — ordered build sequence

| Layer | Owns | Update cadence / method | Inputs → outputs | Gate to next layer |
|---|---|---|---|---|
| **L0 Platform/tooling** | Godot setup, Git, test runner, debug panel, CI-friendly CLI | on build/run | project → reproducible tests | Clean headless import and scripted tests |
| **L1 Simulation kernel** | IDs, fixed clock, command order, RNG streams, scheduler, event queue | 10 authoritative ticks/sec at 1× | commands → state transitions/events | Same seed + commands = same final hash |
| **L2 World/spatial** | Integer positions, 64×64 data chunks, walkability, spatial queries, deterministic local map | load/generate on demand | seed/coord → terrain/resource records | Stable map across reload, no duplicate entities |
| **L3 Entity/needs** | NPC records, hunger, fatigue, identity, schedules | needs every in-game 10 min; AI staggered | world state → need-driven goals | Idle residents eventually eat/rest |
| **L4 Jobs/AI** | Utility goal scoring, job board, leases, action state machines | staggered decision windows | goals + jobs → claims/actions | Interrupted jobs release correctly |
| **L5 Movement/logistics** | local paths, travel, trees/containers, item transfers, stockpiles | detailed movement each tick | claimed actions → changed positions/inventories | Gather→carry→deposit works repeatedly |
| **L6 Production** | items, recipes, labor, workshops, input/output commitments | on work/event completion | reserved inputs + labour → outputs | No duplicate/lost goods across cancellation |
| **L7 Needs of towns** | household demand, housing, occupations, building plan and construction | hourly/day-scale | shortages, capacity → construction jobs | New buildings require physical resources |
| **L8 Market/economy** | bids, asks, price history, purchases, money, shortage signals | every 30 in-game min | inventories + desires → trades/prices | Shortage alters actual transaction prices |
| **L9 Regional simulation** | distant towns, coarse agents, trade routes, materialization | event-driven; settlement aggregates daily | production/route events → remote state | Leaving/returning preserves population/goods |
| **L10 Society/world events** | relationships, sparse memories, factions, migration, diplomatic shocks | event-driven/hourly/daily | events → policy/behavior changes | Effects survive save/reload and propagate |
| **L11 Risk/conflict** | safety, simple local/remote conflict, defensive decisions | on events | danger → changed people/resources/relations | No actor is resolved in two fidelities simultaneously |
| **L12 Presentation** | player movement, map, inspector, logs, trade/settlement overlays | render frame | sim snapshots → legible world | Player can trace causal chain |
| **L13 Persistence/performance** | snapshots, migrations, batching, profiling, automated soak tests | autosave/checkpoint; build/test | state → durable file and budgets | Repeated long-run simulation remains consistent |

**Cross-cutting from day one:** L12 includes a basic debug view; L13 includes a basic serializer and tests. Their advanced versions come later. Don't build L0–L11 invisibly before adding a UI.

## 3. Core design decisions

### 3.1 Coordinates and streaming

- Canonical `world_cell: Vector2i`, never a rendered Node position. Visual positions are derived/interpolated.
- `CHUNK_SIDE = 64` logical cells; storage chunk `(floor_div(x,64), floor_div(y,64))` must work for negative coordinates.
- Each chunk has base generation seed/version plus mutations, resource entities, building/entity references and navigation revision.
- A 5×5 view window is a *starting point*, adjustable based on profiling. View chunks are not world-database chunks.
- Initial MVP uses one fixed region; implement the coordinate abstraction before procedural generation.
- Data: `WorldDB.get_chunk`, `WorldDB.get_cell`, `WorldDB.apply_mutation`. Render: `ChunkView.attach/detach`. Navigation: `RouteService.get_path`.

### 3.2 Three simulation fidelities

| Fidelity | Authority and representation | Simulation | Promotion/demotion |
|---|---|---|---|
| **Detailed** | NPC record + exact grid/continuous-local position, inventory, action executor; optional visible sprite | movement each tick, interactions, local danger | convert from coarse using location/action progress |
| **Coarse** | named NPC with settlement position, needs, work task and exact owned inventory or ledger share | periodic state advances, scheduled completion | preserve ID, money, health, goods, obligations |
| **Aggregate** | settlement/household population and inventories, sparse named NPC identities, production commitments | discrete event queue and population/production equations | expand only relevant people and quantities; record residuals |

**No double ownership:** each actor belongs to exactly one simulation fidelity at any tick. A transition is a transaction with validation, not two independent simulation copies.

**Resource conservation:** when converting remote resource amounts into visible trees, the sum of visible amounts plus the hidden residual equals the authoritative amount.

### 3.3 Time and deterministic order

Proposed clock: **10 simulation ticks per real second at 1×**; one in-game minute = 10 ticks; one in-game day = 14,400 ticks (24 real-time minutes at 1×). These are tuning constants, stored in saves. Render target 60+ FPS independently of simulation.

At each tick:

1. Validate and apply queued player/system commands in stable order.
2. Resolve due events (sorted by due tick and tie-breaking event ID).
3. Update needs due at this tick.
4. Evaluate due AI decisions in ascending stable NPC ID order.
5. Claim/release jobs and targets.
6. Advance movement, gathering, hauling and production progress.
7. Apply completed inventory transactions atomically.
8. Clear markets / run settlement planning only on their assigned schedule.
9. Emit domain events and materialize view changes.
10. Check critical invariants in debug builds; optionally hash world state.

**RNG:** seed independent streams per system/entity/event; never use global `randi()` in simulation code. **Important:** strict cross-platform bitwise determinism requires controlling numeric operations and serialization; the initial target is replay determinism under the same pinned engine/build, not a promise of bitwise equality across all OS/CPUs.

### 3.4 Data stores and service contracts

Start with simple typed records and dictionaries keyed by stable integer IDs; only switch hot loops to packed arrays/SoA after profiling. Avoid a `CharacterBody2D` for every offscreen NPC.

```text
Simulation.step(tick: int) -> void
WorldDB.get_chunk(chunk_coord: Vector2i) -> ChunkData
EntityStore.get(id: int) -> EntityRecord
EntityStore.exists(id: int) -> bool
JobBoard.query_candidates(npc_id: int) -> Array[JobId]
JobBoard.try_claim(job_id: int, npc_id: int, tick: int) -> bool
JobBoard.release(job_id: int, npc_id: int) -> void
InventoryStore.transfer(src_id, dst_id, item_id, quantity) -> Result
NavigationService.request_path(start, goal, nav_revision) -> PathResult
RecipeSystem.start(recipe_id, workstation_id, worker_id) -> Result
MarketSystem.clear_market(settlement_id: int, tick: int) -> TradeBatch
SaveManager.capture_state() -> SerializableSnapshot
```

**`Result` contract:** `{ ok: bool, error_code: StringName, changed_ids: Array[int] }` initially. No subsystem mutates another system's private collections without calling its public method or submitting a command.

### 3.5 Job state machine and reservations

```text
OPEN → CLAIMED → MOVING_TO_SOURCE → WORKING → MOVING_TO_DEST → COMMITTING → DONE
          ↓                  ↓                 ↓
        FAILED / CANCELLED / LEASE_EXPIRED → OPEN or ARCHIVED
```

A claimed job is leased to `(npc_id, expires_tick)`. The worker refreshes the lease; expired leases are reclaimed. Resource targets and stockpile capacity also support reservations. Jobs carry `id`, `kind`, `priority`, `target_id`, `destination_id`, `item_id`, `quantity`, `owner_id`, `state`, `lease_until_tick` and `retry_count`.

For the vertical slice, an NPC chooses a job based on:

`utility = priority + need_fit + skill_fit − travel_cost − danger − switch_penalty`.

Do not implement an expensive general-purpose planner or full GOAP initially. Use explicit finite action executors with understandable failure codes.

### 3.6 Inventory and recipe guarantees

- `Inventory`: exact physical item stacks on actors, trees, workshops, containers.
- `Stockpile`: location + allowed item filters + capacity + reserved capacity.
- `SettlementLedger`: derived or deliberately aggregate stock; *not* a second independent source of physical items.
- All quantities and prices use integer units. Money uses minor units (cents).
- `transfer()` validates source amount and destination capacity, updates both in one authoritative operation, and emits a transaction event.
- A recipe reserves required inputs, consumes at a specified commit point, and produces outputs **once**. A cancellation cannot mint or duplicate items.

### 3.7 Navigation

Two-level solution now, three-level later:

- MVP: tile-based local pathfinding behind `NavigationService`; a Godot `AStarGrid2D` backend is acceptable for simple deterministic map tests.
- After village growth: local regions/reachability filter plus `NavigationServer2D` or optimized A* backend, subject to benchmarks.
- Regional: graph routing between settlements; remote travel by scheduled arrival events rather than moving invisible sprites.
- Path caches keyed by `(start_region, destination_region, nav_revision)`; obstacle edits invalidate affected regions.

**Don't tie job decisions to concrete pathfinder classes.** Jobs request reachability/path and tolerate a failed result.

### 3.8 Market and remote logistics

At a settlement's market session, buyers publish `(item, quantity, max_price)` and sellers publish `(item, quantity, min_price)`. Match bids high-to-low and asks low-to-high; transactions transfer goods/money, updating an exponentially smoothed displayed price. If no deals occur, display the last transaction price plus a transparent scarcity estimate; do not pretend an estimate is an executed trade.

Traders evaluate expected margin minus travel time, fees and route risk. Cargo is removed from the origin when a caravan departs and appears at the destination only after a scheduled arrival, preserving ownership during transit. Remote town supply and production use aggregate ledgers with explicit production and consumption events.

### 3.9 Society, faction, settlement planner

- NPC relationships are sparse edges (`trust`, `affinity`, `fear`, `last_interaction`), not a global N×N matrix.
- Salient memories are bounded event records (`kind`, `subject_id`, `place`, `tick`, `strength`); store 16–32 notable memories per NPC as an initial limit.
- Factions own treaties, policies, treasury and strategic objectives; NPCs own their personal experience.
- Settlement planner periodically evaluates deficits (food, housing, job capacity, defense, storage) and emits **construction plans**. Local plans require material deliveries and worker time.
- Ecology: named local tree entities; aggregate resource pools with capacity/regeneration remotely. Conversions conserve quantity.

### 3.10 Saving, threading, optimization

- Initial development saves may use `FileAccess.store_var()` for explicit data dictionaries (`full_objects=false`) and typed version field. Production needs documented binary sections, checksums, migrations and crash-safe writes.
- Store: save header (`format_version`, `world_seed`, `sim_tick`, `engine/content_version`), global stores, chunk deltas, event queue and all RNG stream states.
- Save a snapshot to a temporary file, verify/close, preserve backup, replace current save; never use scenes themselves as the canonical persistence format.
- **Main thread authoritative commit**; workers only operate on immutable snapshots (generation, compression, later expensive searches). Godot SceneTree changes stay on main thread.
- No premature multithreading, GDExtension, complex ECS framework or custom renderer until a measured bottleneck justifies it.

## 4. Folder structure

```text
res://
  app/                      # main scene and the controller that wires input, sim and view together
  sim/                      # the simulation: authoritative, headless, never reads view/ or app/
    core/                   # clock, stable ids, RNG, commands, events, hashes
    world/                  # chunks, terrain, roads and town layouts, buildings, fixtures
    entities/               # residents, needs, households, speech, fear, outfits
    jobs/  movement/  inventory/  production/  economy/  farming/
    settlement/             # town planning, housing, professions
    law/                    # sheriffs, crimes, arrests, booking and jail
    combat/                 # fists, shotgun, wounds, cover, gunfire, body health, local combat
    player/                 # player actions, looting, hotbar, context menu, door assist
    factions/  persistence/  diagnostics/
  view/                     # everything drawn or heard: actors/ world/ ui/ audio/
  content/                  # art, audio and data definitions (items, recipes, buildings)
  tests/
    sim/                    # headless tests of the simulation
    view/                   # tests that touch view/ or app/ (still headless)
    captures/               # scripts that render screenshots (need a display)
    soak/  benchmark/       # long runs and measurements
  tools/                    # asset generators, export template preparation, the layout checker
  scripts/                  # test runner, exports, play, packaging
  docs/
    design/                 # the blueprint (01-04) and DECISIONS
    status/                 # CHANGELOG, IMPLEMENTATION_STATUS, CURRENT_GAME
    validation/             # VALIDATION and benchmark results
    screenshots/            # screenshots (SCREENSHOTS.md is the gallery)
```

`tools/check_layout.py` runs first in `scripts/test.sh` and in CI. It fails on a dangling `res://` path
or markdown link, a `*_test.gd` that is not listed in `scripts/test.sh`, and any file under `sim/` that
reaches into `view/` or `app/`.

## 5. Desktop performance — hypotheses to validate

**Initial reference:** Windows desktop, 6-core CPU, 16 GB RAM, 1080p. Rendering target 60 FPS (16.67 ms/frame); simulation tick target 10 Hz. **Aspirations**, not engine guarantees: 20 detailed NPCs without hitches for vertical slice; 100 detailed after job/navigation profiling; ~300 detailed + thousands of remote agents for later scalability testing; 50k abstract population only after LOD and long-run correctness tests.

Test five-minute stable runs after warm-up and capture frame-time p50/p95/p99, main-thread spikes, `sim_tick_ms`, per-system duration, path requests, active nodes, loaded chunks, memory, save time/size. First optimize correctness, then measure allocation pressure, then optimize hot loops.

## 6. Invariants (assert in tests/debug builds)

1. Entity IDs unique; no dangling authoritative references.
2. NPC lives in one world location and one simulation fidelity at a time.
3. Item quantities and money never go negative.
4. A transfer conserves source + destination inventory totals.
5. No more than one valid lease on exclusive job/target at a tick.
6. Each recipe consumes reserved inputs and creates output once.
7. Remote→detailed transitions preserve goods, identity, commitments and health.
8. Scheduled events process at most once.
9. Save→load recreates the same authoritative snapshot/hash.
10. Unreachable jobs fail clearly and become eligible for reassignment/review.

## 7. Source inspirations (not implementation claims)

- Another Dead World, official feature ambitions: https://store.steampowered.com/app/4417350/Another_Dead_World/
- RimWorld creator on reachability before expensive pathfinding: https://ludeon.com/blog/2013/07/reachability-at-last/
- Factorio on pathfinding optimizations: https://www.factorio.com/blog/post/fff-121
- Cataclysm: DDA overmap/local-map source separation: https://github.com/CleverRaven/Cataclysm-DDA/blob/master/src/overmapbuffer.cpp
- Godot thread-safety boundaries: https://docs.godotengine.org/en/4.6/tutorials/performance/thread_safe_apis.html
- Godot TileMapLayer reference: https://docs.godotengine.org/en/4.6/classes/class_tilemaplayer.html
- OpenTTD save format and migrations inspiration: https://github.com/OpenTTD/OpenTTD/blob/master/docs/savegame_format.md
