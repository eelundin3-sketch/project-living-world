# Decisions — Task 001 / M0

## D001 — Pin Godot 4.6 stable, standard edition

Reason: a stable Godot 4 release matching the design pack's API baseline. No engine
was found on PATH or in standard application locations; the official universal
macOS build was downloaded into `/private/tmp` for validation. Actual build:
`4.6.stable.official.89cea1439`.
Alternative: another stable 4.x release. Reversible with an explicit pin update
and rerun of import/tests. Validation: version output and passing smoke pin check.

## D002 — Compatibility renderer and presentation-only scene

Reason: simple desktop 2D needs no advanced rendering. Main composes a drawn grid,
Camera2D and CanvasLayer HUD. Ground is an original procedural drawing, not world
generation. No persistent simulation state exists in these Nodes.
Alternative: imported textures/TileMapLayer, deferred until a world model exists.
Reversibility: views can be replaced independently. Validation: scene smoke test
and native graphical startup; visual UI inspection unavailable due to tool timeout.

## D003 — Dependency-free SceneTree smoke runner

Reason: exercise actual Godot scene loading and return reliable CI exit status
without frameworks/plugins. Seeded pure-data samples live only in tests.
Alternative: third-party test framework, unnecessary for M0. Reversible later.
Validation: headless import and smoke command both exited 0. Initial sandboxed
import reported blocked user/cache writes; rerun with normal directory access
completed cleanly. See README for exact commands.

## D004 — Scope and camera controls

Reason: implement the hand-off's first bounded task, M0. Reserve future folders
with `.gitkeep` instead of speculative interfaces. Physical WASD moves an observer
camera at a zoom-adjusted rate; wheel zoom is bounded; pan stays near the grid.
Alternative: configurable InputMap/player controls, deferred until gameplay.
Reversibility: camera input can change without simulation migrations.
Validation: pan distance, wheel handling and both zoom bounds pass automated tests.
M1 and later work remain pending; no automatic commit or release tag was made.

## D005 — Full-roadmap implementation authorized

The follow-up request authorizes continuing beyond M0. Work proceeds sequentially,
with executable gates at each integration seam. The initial implementation uses
plain serializable dictionaries, integer cells/quantities, and RefCounted services.
Simulation owns the snapshot; services receive it explicitly through public entry
points. Render Nodes hold only selection, camera and UI state. This favors clear
save/replay contracts over a framework or premature packed-array optimization.
Canonical snapshots include commands, events, RNG streams and content version.

## D006 — Physical custody, transactions and inspectable work

InventoryStore owns stack changes and capacity promises. Gathering jobs lease
exclusive targets and warehouse capacity; interrupted carriers keep their goods.
Removed workers become recoverable stashes. Sawmill inputs travel in the sawyer's
inventory; outputs travel back the same way. Builders carry planks to a site and
consume them only at completion. Recipes consume/produce at one validated commit
point. The accounting ledger records explicit initial stocks, growth, consumption,
recipe conversion and incident losses. Markets move the same stacks and integer
currency. No rendered object owns these values.

## D007 — Regional simulation and fidelity

The first complete scenario has two settlements and a bounded 384×256-cell region.
Chunks are 64×64 and generated on demand by seed/version; rendering culls to the
camera bounds and does not spawn a Node for each offscreen actor. Residents keep
one identity and inventory across detailed (2-tick actions), coarse (10-tick
batches), and aggregate (100-tick batches) simulation. Batched travel and labour
advance arithmetically across transaction boundaries rather than executing each
intermediate cell. Town population/stocks/resource summaries are derived views,
not independent owners of goods. Visible resources plus hidden residuals equal
the exact source records. All initial citizens remain named; anonymous population
expansion at tens of thousands of residents is not part of this prototype.

Caravans own cargo throughout a scheduled journey. A blocked road reschedules the
same commitment; a matching event ID makes arrivals once-only. New departures
respect treaties and risk. Distant movement is a commitment, not a hidden sprite.

## D008 — Society and non-graphic danger

Households group named residents, sparse relationships cap at 32 edges, memories
at 16 entries. Selling supplies creates a memory and trust change. Shortages change
work priorities; excess population can migrate to spare housing. Migration removes
a worker from local assignment until arrival. Guard assignment reduces incident
risk. Conflict uses one resolver and an actor's current fidelity, records losses
through InventoryStore, and never resolves the same incident twice. Injury stops
at one health in this initial non-lethal conflict model.

## D009 — Persistence, external content and reproducible checks

Save envelope v2 contains a checksum, pinned engine version and explicit state.
Temporary-write/readback/backup/rename prevents replacing a valid save with an
invalid write. Loading validates schema, quantities and invariants before swapping
state, recovers a backup on corruption, and migrates v1 metadata. This migration
supports this project's v1 snapshot schema; it is not a generic importer.

Recipe JSON is data-only, capacity-bounded, with namespaced mod IDs. A loaded
recipe is embedded in the authoritative snapshot. External recipe data is validated and embedded in the queued command at
submission, so command replay does not reread a mutable external file. Active
batches retain a frozen recipe until commit or cancellation. Controls live in a separate user settings file and do not enter the
simulation hash. No external gameplay framework/plugin was introduced.

## D010 — Build and performance scope

Official 4.6 export templates produce Windows x86_64, Linux x86_64, and universal
macOS debug/release artifacts. Local macOS binaries are launch-tested. Windows and
Linux exports require testing on those operating systems before distribution.
Builds are unsigned and not notarized. macOS export requires ETC2/ASTC import enabled
and its template installed in Godot's standard export-template directory.

Performance is measured on the actual Apple M4 host, not the hypothetical Windows
reference in the design pack. Simulation budget is 100 ms/tick at 10 Hz. Results
for 20/100/300 residents and a five-minute graphical run are recorded separately.
No language change or multithreading is justified by the current measurements.
