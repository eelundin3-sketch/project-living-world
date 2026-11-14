# Project Living World — Layer-by-Layer Development Roadmap v0.1

**Rule:** every milestone leaves a runnable, testable Godot game. Do not implement the entire simulation in parallel. Each milestone has a visible demonstration and a correctness gate. No date estimates are assumed.

## A. Dependency chain

```
M0 Project/tooling
        ↓
M1 Simulation core / deterministic tick
        ↓
M2 Tiny world + interaction/debug UI
        ↓
M3 NPC state + hunger + rest
        ↓
M4 Job board + local movement
        ↓
M5 Gathering + inventories + hauling
        ↓
M6 Save/load + scripted soak tests  ← FIRST PLAYABLE VERTICAL SLICE
        ↓
M7 Recipes + local manufacturing
        ↓
M8 Construction + settlement planning
        ↓
M9 Player commerce + local market
        ↓
M10 Second settlement + regional trade
        ↓
M11 Fidelity LOD + streamed world / remote NPCs
        ↓
M12 Personality, relationships, events, factions
        ↓
M13 Danger/conflict + deeper simulation
        ↓
M14 Performance, mod data, compatibility, polish
```

**Parallel side tracks:** Simple art/UI readability accompanies M2 onward; invariants and metrics accompany every milestone, not just M14.

## B. Detailed milestones and acceptance tests

### M0 — The runnable foundation

**Build:** Godot 4.x desktop project, one main scene with camera and placeholder ground, repository conventions, tests folder, lint/style conventions, headless test runner, developer debug overlay.

**Show:** open executable/window; move a camera; view project/version/debug labels.

**Gate:** project imports in headless Godot; no parser errors; test runner exits success; exact engine version and run/test commands documented.

### M1 — Authoritative simulation kernel

**Build:** `SimulationState`, `SimClock` at fixed 10 Hz, commands queued with stable order, 64-bit entity IDs, deterministic RNG wrapper, event queue, canonical state serialization/hash for reproducibility.

**Show:** simulation tick advancing; pause, 1×/2×/4× speed; debug console can spawn a test entity using a command.

**Gate:** 100,000 ticks replayed from same seed + ordered commands produce same hash on the same engine build; replay doesn't depend on render FPS.

### M2 — Small physical world

**Build:** integer cell coordinates, single initial map (e.g. 128×128 cells), walls/trees/warehouse positions, simple chunk data abstraction, blocked cells, interaction inspector, basic path requests.

**Show:** player walks; clicks a tree and sees entity ID, available logs and location; click warehouse and see stock.

**Gate:** regenerated seeded map is identical; negative-coord chunk mapping tested; visible state is read from `SimulationState` not duplicated.

### M3 — Residents and needs

**Build:** 10 stable NPCs, hunger/fatigue, finite need rates, eat/rest goals, need inspector; named identity independent of view node.

**Show:** workers have statuses: hungry, resting, available.

**Gate:** no NPC has impossible need values; seven simulated days complete with no irrecoverable state; NPC state is stable across pause/resume.

### M4 — Jobs and local navigation

**Build:** `JobBoard`, job states, claim leases, resource reservations, action-state executors, navigation-service abstraction, failure/retry reason codes.

**Show:** an idle NPC claims a reachable job, walks to a target and completes a placeholder task.

**Gate:** 20 NPCs cannot double-claim one exclusive target; jobs recover after worker removal, path failure, cancellation or lease expiry.

### M5 — Real material flow

**Build:** log item definition, tree deposits, capacity-limited inventories, stockpiles, authoritative transfer method, gather/haul/deposit action chain.

**Show:** tree loses 5 logs, carrier gains 5, carrier delivers 5, warehouse grows by 5. Total quantity conserved, accounting for explicitly harvested world resource.

**Gate:** 1,000 repeated jobs, interruptions and retries preserve item totals; all quantities nonnegative; each item held by one inventory at a time.

### M6 — First playable vertical slice

**Build:** save/load snapshot, 20-NPC configurable scenario, player controls, needs + jobs + movement + goods, inspectable inventory/job logs, automatic scenario tests.

**Show:** player watches the small village for a full in-game day, leaves the game, reloads and sees the same world continue.

**Gate:** seven simulated days unattended; state hashes match across an uninterrupted run vs save/reload; no perpetual reservation or permanently blocked NPC without a readable error.

**Release marker: `prototype-v0.1`**. Every later layer should build on this stable proof of life.

### M7 — Local production

**Build:** plank item, sawmill, data-driven recipe `2 logs → 6 planks + labor`, input reservations, batch progress and output transfer.

**Show:** log shortages stop planks; log deliveries resume production.

**Gate:** repeated interruptions never duplicate output; recipe invariants hold under 100k synthetic cycles.

### M8 — Settlement building loop

**Build:** building definitions, demand ledger, site scoring, construction plan, material hauling and worker-time requirements; start with warehouse and house.

**Show:** homes become crowded → planner proposes a house → workers deliver planks → home completes.

**Gate:** site must be buildable; all inputs accounted for; no instant free buildings; long-run construction avoids placement deadlocks.

### M9 — A market worth playing

**Build:** local money accounts, item buyers/sellers, order matching, last traded price vs estimated price distinction, merchant/player transactions.

**Show:** removing supply increases the willingness to pay; a player sells logs and receives money from a real buyer.

**Gate:** trades transfer exact goods and currency; no negative balances; price bounds enforceable; low-stock scenario produces interpretable market history.

### M10 — Regional trade

**Build:** second self-sustaining settlement, road graph, stock surpluses/shortages, merchant contracts, event-based travel/cargo custody.

**Show:** caravans buy cheaply, travel, arrive and alter town stock and market prices. Blocking a route impacts trade.

**Gate:** cargo cannot exist in two settlements simultaneously; routes have valid departure and arrival; money/items conserved across deliveries.

### M11 — Larger persistent world

**Build:** deterministic macro-world, data chunks and view streaming, detailed/coarse/aggregate simulation LOD, remote resource pools, conversion invariants.

**Show:** leave a settlement, revisit later, see changed stores, completed production and consistent residents.

**Gate:** remote→local→remote state round-trip preserves goods, people, commitments; offscreen abstract residents require no live character nodes; no chunk streaming stutter beyond agreed budget in benchmark.

### M12 — Meaningful society

**Build:** occupations, bounded memories, sparse relationship edges, households, settlement policies, simple factions and event propagation.

**Show:** an NPC remembers a helpful trade; a settlement changes priorities after shortage; a treaty shifts trade patterns.

**Gate:** same event produces same recorded consequences on deterministic replay; memory counts bounded; relation references always valid.

### M13 — Danger and conflict (optional later emphasis)

**Build:** risk signals, guards, avoidance, basic local/remote contest resolver and loss accounting (non-graphic).

**Show:** traders may avoid a risky route and towns respond by protecting routes.

**Gate:** one actor participates in only one combat fidelity at a time; consequences update the same authoritative entities and ledgers.

### M14 — Scale, ergonomics and content framework

**Build:** profiling benchmark suite, performance optimizations, save migrations, crash recovery, content definitions with stable IDs, remappable input, accessibility, UI polish, desktop builds.

**Show:** reproducible benchmark results on named reference hardware; older save version loads; external recipe definition works without changing sim code.

**Gate:** measured frame-time and memory budgets met for approved scenario; stress tests and major invariants pass; debug and production builds both run.

## C. Engineering policies

- **Every Codex task is bounded.** One system or one integration seam per change, with tests and a visible proof.
- **No silent rewrites.** Codex proposes architectural changes, explains tradeoffs and documents the new interface before editing multiple modules.
- **TDD for invariants.** Build the failing test first where practical: item duplication, lease expiry, save/reload and determinism.
- **Headless-first core.** A simulation system should run without any loaded player scene, sprites or audio.
- **One source of truth.** Never store inventory, money or NPC needs separately in a Sprite/CharacterBody and simulation record.
- **Version all gameplay content.** IDs such as `core:item/log` stay stable; display names can change.
- **Profile before changing language.** GDScript may be sufficient for substantial portions of the game; move only confirmed hot paths to C#/GDExtension.
- **Use placeholder visuals without apology.** Good-looking screenshots do not replace a functioning causal chain.

## D. Test suite matrix

| Test level | Example test | Trigger |
|---|---|---|
| Unit | transfer rejects negative quantity | every commit |
| Unit | expired job lease becomes reclaimable | every commit |
| Unit | world chunk mapping handles negative x/y | every commit |
| Integration | one NPC gets logs into warehouse | every commit |
| Integration | 20 NPCs competing for 5 trees | after M4 |
| Determinism | repeat scenario seed + command log | after M1 |
| Save/reload | 50k ticks + save + 50k ticks vs uninterrupted 100k | after M6 |
| Soak | seven in-game days / repeated market shocks | each major simulation layer |
| Performance | 20/100/300 detailed NPC scenarios | after M6, then M11/M14 |
| Property/invariant | conserved goods on every transfer/recipe | every commit where affected |

## E. What to build first (the next three tasks)

**Task 001 — Bootstrap project:** create the Godot repository and runnable `Main` scene, pinned version, debug UI, headless smoke test.

**Task 002 — Simulation clock:** headless `SimulationState`, fixed ticks, commands, deterministic RNG, stable IDs, test 100k-step replay.

**Task 003 — Visible tiny world:** placeholder terrain, single warehouse and tree, `WorldDB` and `View` separation, inspectable entities; no NPC AI yet.

After those are green, Task 004 adds the first NPC with hunger/rest, and Task 005 introduces job claims. Resist skipping ahead to markets or factions before the inventory and job transaction loop is correct.
