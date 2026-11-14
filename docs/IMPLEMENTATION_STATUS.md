# Blueprint implementation status

This describes the actual prototype, separately from the supplied design proposal.
All M0–M14 areas have an integrated implementation. The scope is a small original
single-player sandbox; long-term scale and commercial polish are not implied by
these gates. Tests live alongside the implemented systems and can run headlessly.

| Milestone | Runnable implementation | Evidence / practical boundary |
|---|---|---|
| M0 | Main scene, engine pin, desktop renderer, test runner, HUD | Import and scene smoke test; actual rendered screenshots |
| M1 | Fixed clock, IDs, stream RNG, commands/events, hashes | 100k-tick replay, 100k unique IDs, equal-time event order, render-cadence and pause tests |
| M2 | Seeded map, cells/chunks, walkability, A*, player/inspector | Seed equality, negative chunk coordinates, shortest path and blocked endpoint tests |
| M3 | Persistent residents with hunger, fatigue, eat/rest goals | Seven-day bounds/invariant runs; paused state hash unchanged |
| M4 | Job board, exclusive targets, leases, explicit action phases/reasons | 20-way contention, cancellation, removal, lease expiry, changed/unreachable navigation recovery |
| M5 | Capacity-limited inventories and physical harvesting/hauling | 1,000 completed jobs with interruptions and conservation checked after every cycle |
| M6 | Configurable population, controls, inspectors, save/reload | 100,800-tick village and full-game runs; exact post-load continuation; UI save/load smoke |
| M7 | Data-driven sawmill, escrowed inputs, labour, physical output hauling | 100k synthetic recipe cycles; cancelled/double commits rejected; live planks reach store |
| M8 | Housing demand, site selection, builder hauling and work | Initial housing shortage builds three material-funded homes; warehouse definition/plan API included |
| M9 | Accounts, order matching, integer transfers, player commerce, price history | Goods/money conservation, affordability failures, shortage-sensitive bids and real matched transactions |
| M10 | Second settlement, road, merchant purchase/cargo/arrival/sale | Blocked arrival retains cargo; reopening delivers once; regional replay |
| M11 | Seeded chunk metadata, culled view, detailed/coarse/aggregate batches | Fidelity roundtrip keeps identity/goods/needs; full-world replay while visiting towns. Named actors are aggregated in batches; no 50k population claim |
| M12 | Occupations/skills, households, memories, relations, policies, factions, migration | Memory/edge bounds, migration ownership, treaty restrictions, deterministic social continuation |
| M13 | Road risk, guards, avoidance, shared once-only incident resolver | Fidelity guard and duplicate-resolution test; ledger-accounted losses and health changes. Non-lethal, no tactical combat UI |
| M14 | Benchmarks, v1 migration, backup recovery, JSON content, controls/accessibility, exports | Migration/corruption/mod tests; 20/100/300 simulation benchmark; five-minute frame report; debug/release artifacts |

## Scope choices requiring no hidden future implementation

The MVP map is finite (384×256 cells after regional expansion), with two towns.
Chunk data is deterministic and view loading is bounded; it does not create an
infinite authored world. Aggregate updates retain named resident records and
advance travel/work algebraically across transaction boundaries. Population/goods
summaries are derived from the same inventories. There is no second remote ledger
that silently creates or duplicates materials.

One representative recipe, three commodities, one caravan route, two factions and
housing-driven construction demonstrate the causal loops. Definitions/services can
support more content, but hundreds of professions or settlements are not asserted.
Warehouse construction is exposed by the planner API, while the initial scenario's
autonomous planner responds to housing pressure. Hunger and fatigue stop at bounded
values; risk produces non-lethal injury and explicit cargo loss.

## Remaining validation limits

- Windows/Linux artifacts are exported, but have not been executed on those OSes.
- The five-minute graphics run uses this Apple M4 and a 1280×720 window; it is not
  the design pack's hypothetical Windows/1080p reference hardware measurement.
- Saves migrate this prototype's v1 schema to v2, not arbitrary historical formats.
- Performance for thousands of remote identities / 50k abstract population is
  unmeasured. Those numbers in the blueprint are aspirations, not release claims.
- Builds are unsigned/not notarized; packaging for public distribution remains a
  separate release activity. The included CI workflow has not run remotely.
