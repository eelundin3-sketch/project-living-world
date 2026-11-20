# Project Solo: instructions for Claude Code

A single-player 2D frontier life sandbox in **Godot 4.6, GDScript**. Three towns (Alder Hollow, Reedbank, Dustvale) on one big map; families, trade, a sheriff, guns and cover, and a consequence layer (witnesses, memory, gossip, reputation). A deterministic simulation (`sim/`) is separate from everything drawn (`view/`, `app/`).

**State on 2026-11-20:** branch `feature/quick-wins`, everything committed locally, **nothing pushed**. 77 tests pass, about 79 FPS at normal zoom. The owner has not yet hand-played the latest work. A master plan with briefs exists in `docs/ROADMAP.md` (milestones 5-14). **The owner asked to pause building: do not start a milestone until they say so.**

## Read order (load only what you need)

1. This file. 2. `docs/HANDOVER.md` (how to start, commands, gotchas). 3. `docs/DEVELOPMENT_STATUS.md` (built / partly built / broken).
Then only when needed: `docs/ARCHITECTURE.md` (how systems fit), `docs/GAME_DESIGN.md` (how the game should behave), `docs/DECISIONS.md` (why; the full log is `docs/design/DECISIONS.md`), `docs/ROADMAP.md` (**never read whole**: `grep -n '^## MILESTONE\|^### [A-Z][0-9]*\.' docs/ROADMAP.md`). Original design pack: `docs/design/01-03`. Contributor rules: `AGENTS.md`.

## Commands (run from this folder, `source/`)

```sh
G=/private/tmp/living-world-engine/Godot.app/Contents/MacOS/Godot     # Godot 4.6; in /tmp, may vanish (see HANDOVER)
GODOT_BIN=$G sh scripts/play.sh                                        # play
perl -e 'alarm 300; exec @ARGV' $G --headless --path . --script res://tests/sim/<name>_test.gd 2>&1 | grep -E 'FAIL|PASS|ERROR'   # one test (macOS has no `timeout`)
GODOT_BIN=$G sh scripts/test.sh                                        # all 77 tests, about 13 min
python3 tools/check_layout.py                                          # CI also runs this
```
Benchmarks and screenshot scripts: `docs/HANDOVER.md` section 4.

## Rules that must hold

- **Simulation is authoritative.** `sim/` never references `view/` or `app/`. Views read state and call `simulation.submit(...)`; they never own money, goods, needs or world state.
- **Deterministic.** No global random; use `sim.random_int("stream", lo, hi)` with a stream name per feature. Integer maths. Same seed + commands = same `state_hash()`.
- **Saves.** New state fields default via `.get()`. Save, load, continue must give the same hash; `restore()` must still load old saves. Caches are never saved.
- **Money and goods are conserved** (`sim/diagnostics/invariants.gd`). Nothing appears from nothing.
- **Tests.** Every feature gets a test; every `*_test.gd` is listed in `scripts/test.sh`. Run the full suite before calling a milestone done.
- **Performance.** At least 60 FPS at normal zoom and on the map; no per-tick loops over all ~6,300 entities (use `DerivedCache`/`Spatial`); cap every list. Benchmark before and after (`docs/HANDOVER.md` section 5). The owner asked for high FPS explicitly.
- **Decisions.** Record changes to core contracts in `docs/design/DECISIONS.md`. Original content only; no external plugins.
- **Don't rebuild what exists.** Memories (`sim/factions/society.gd`), the chronicle (`sim/world/chronicle.gd`), reputation, gossip, witnesses, the Talk window and the journal are foundations: extend them. `town.policy` is already the economy planner's field; use another name.

## The owner's standing instructions

- **Commit locally. Do not push, open PRs or merge until the owner asks for "the big push".** To see what is unpushed, compare with git (`git fetch`, `git rev-list <branch> --not --remotes`). The big-push order is in `docs/HANDOVER.md` section 6.
- **`Project Solo.app` must stay the first item in the repo root**; do not add root files that sort before it (hence this file is in `source/`).
- **Show a plan before building; build milestone by milestone and stop between them.** Ask before starting the next one.
- Keep the game fast (above). Keep reports plain: what is done, what is not, what was not verified. (Observed style of the owner's questions, not a stated rule.)

## Repo hygiene (important)

- **Never `git add -A` or `git add .`.** About 680 untracked Finder duplicates ("name 2.gd", "Project Solo 2.app") sit in the working folder. Add files by name. `check_layout.py` fails if any get tracked.
- Commit the `.uid` file Godot makes for each new script, and any benchmark JSON you want kept.
- Don't edit source while the full suite runs.

## Gotchas

`a and b or c` in GDScript returns a bool, not a value. Avoid cyclic `preload`s (use `load()` inside functions). Daily systems run at **12:00** (`Households.daily`), not morning. The map is **582 by 420** cells. The active gun's state key is `s.shotgun` (rifle or shotgun, field `kind`). More in `docs/HANDOVER.md` section 8.
