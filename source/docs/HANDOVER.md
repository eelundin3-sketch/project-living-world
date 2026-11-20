# Handover: continuing Project Solo in a fresh conversation

Written 2026-11-20 at the end of a very long session. Read `source/CLAUDE.md` first (short), then this file. Load other docs only when needed: `docs/DEVELOPMENT_STATUS.md` (what is built and broken), `docs/ARCHITECTURE.md` (how it fits together), `docs/GAME_DESIGN.md` (how it should behave), `docs/DECISIONS.md` (why), `docs/ROADMAP.md` (the plan, search it, do not read it whole).

## 1. Where things stand, in plain words

- The game is a deterministic frontier sandbox in Godot 4.6 with three towns, families, trade, a sheriff and a gun/cover/bleeding system. It has a real chain of consequences now: crimes have witnesses who run to the sheriff, people remember and gossip, towns hold a reputation of you, you can bribe or talk your way out of an arrest, carry bodies, be thrown out of homes, and your looks matter.
- **Branch `feature/quick-wins` (local only, 23 commits not on GitHub: 22 of work plus the handover docs commit)** holds everything: steps 1-4, the rifle as the main gun, gunshots heard by distance, and silent takedowns. 77 tests pass; about 79 FPS at normal zoom.
- **The owner has not yet hand-played steps 1-4.** The game was launched once at the end ("run the game"); no feedback came before this handover.
- The owner chose to **stop building for now** ("Not now" to starting milestone 5) and asked for this handover. The next step is the owner's call.
- A written master plan exists (`docs/ROADMAP.md`, also on the owner's Desktop as `Project_Solo_Plan.txt`): ten milestones (5-14), about 24-28 working sessions.

## 2. First 15 minutes of the new session

```sh
cd /Users/eriklundin/Documents/ChatGPT/lw-launcher/source
git branch --show-current                 # expect feature/quick-wins
git status --short | grep -v ' 2[."]' | grep -v '" 2'   # expect nothing (hides Finder duplicates)
git log --oneline -5
ls /private/tmp/living-world-engine/Godot.app   # the engine; see section 3 if missing
```

Then:
1. Read `docs/DEVELOPMENT_STATUS.md` sections 3 and 5 (gaps and problems).
2. Run one test to prove the toolchain works (command in section 4).
3. **Do not start building.** Tell the owner in plain words where things stand and let them choose (section 7). Do not push, open PRs or merge.

## 3. Environment facts (verified 2026-11-20)

- **Godot 4.6 stable** only at `/private/tmp/living-world-engine/Godot.app/Contents/MacOS/Godot`. It is in a temp folder: **if a reboot removed it, download Godot 4.6 stable (standard, not .NET) from godotengine.org/download/archive/4.6-stable and set `GODOT_BIN`**. Moving it to `/Applications/Godot.app` would also make `Project Solo.app` find it; the owner has not decided this yet.
- Platform: macOS (Apple M4). **There is no `timeout` command**; use `perl -e 'alarm 300; exec @ARGV' ...`. zsh aborts a whole command if a glob has no match, and `echo "====="` fails (it tries to expand `=`); use other separators.
- Project root for commands: `/Users/eriklundin/Documents/ChatGPT/lw-launcher/source`. The git repo root is one level up and also holds `Project Solo.app` and `README.md`.
- GitHub: `https://github.com/eelundin3-sketch/project-solo`; `gh` CLI is installed and logged in.
- The auto-mode command reviewer sometimes refuses a Bash call that starts with `cd ... &&` after the shell has moved, and asks for the identical call to be reissued; reissue it exactly as quoted.
- Scratch files from the last session (benchmark logs, screenshots) are in `/private/tmp/claude-501/...`; they can disappear. Nothing important lives only there: results are in `docs/validation/` and in this documentation.

## 4. The verified commands

```sh
cd /Users/eriklundin/Documents/ChatGPT/lw-launcher/source
G=/private/tmp/living-world-engine/Godot.app/Contents/MacOS/Godot

GODOT_BIN=$G sh scripts/play.sh                                   # play the game
perl -e 'alarm 300; exec @ARGV' $G --headless --path . --script res://tests/sim/talk_favours_test.gd 2>&1 | grep -E 'FAIL|PASS|ERROR'
GODOT_BIN=$G sh scripts/test.sh                                   # full suite: 77 tests, about 13 minutes, exit 0 = all pass
python3 tools/check_layout.py                                     # layout, links, test registration (CI runs it too)
$G --headless --path . --script res://tests/benchmark/full_game_benchmark.gd
SOLO_BENCH_LABEL=before_x $G --path . --script res://tests/benchmark/view_benchmark.gd   # windowed; writes docs/validation/view_benchmark_before_x.json
SOLO_SHEET_DIR=/some/dir $G --path . --script res://tests/captures/journal_capture.gd    # screenshots (needs a window)
```

A passing test prints `Name: PASS` and exits 0; a failing one prints `FAIL: ...` lines and exits non-zero.

## 5. The working loop for every feature

1. Read the brief in `docs/ROADMAP.md` (`grep -n '^### CODE\.' docs/ROADMAP.md`) and **the code it names**: briefs were written from verified code but code moves; the "Update after steps 1-4" notes at the top of briefs say what changed.
2. Show the owner a short plan (they review plans before building).
3. Run the benchmark first (`before_<feature>`), then build in small pieces.
4. Each piece: a new test in `tests/sim/` or `tests/view/`, **listed in `scripts/test.sh`**, using the standard checks (deterministic, save/load continues to the same hash, money conserved).
5. Run related tests, then the full suite, then the benchmark again (`after_<feature>`); any drop over 10% gets fixed first. Take a screenshot for anything visible and look at it.
6. New decision? Add an entry to `docs/design/DECISIONS.md`. Update `docs/DEVELOPMENT_STATUS.md`.
7. `python3 tools/check_layout.py`; commit **by file name** (never `git add -A`); include the `.uid` files for new scripts and the benchmark JSONs you want kept. Commit locally only.
8. Report in plain words: what is done, what is not, what was not verified.

## 6. The big push (only when the owner asks)

Nothing below is to be done unprompted.

1. Compare local with GitHub: `git fetch origin`, then for each local branch `git rev-list --count <branch> --not --remotes` and `git log --oneline <branch> --not --remotes`.
2. **PR #13 first** (`chore/app-first-layout`): check its CI (`gh pr checks 13`; the suite needs the 45-minute limit); merge only on the owner's word.
3. Then the feature branches (`feature/people-trade-families-sheriffs`, then `feature/quick-wins`), stacked on PR #13's branch until it merges, with benchmark tables in the PR description. Their CI file still says 20 minutes: take the 45-minute change from PR #13's branch (`fd8adbd`).
4. Before publishing: update `README.md` (rifle start kit, controls including J), `docs/status/CHANGELOG.md` (stops at 2026-11-18), and the two stale status pages (`CURRENT_GAME.md`, `IMPLEMENTATION_STATUS.md`); make sure `Project Solo.app` is still the first item in the folder.
5. Owner's open choices: publish a first GitHub Release (check the zip opens with `Project Solo.app` first); delete about 10 old merged branches on GitHub; install Godot outside `/tmp`.

## 7. What the owner may want next (ask, do not assume)

| Option | Notes |
|---|---|
| Hand-play steps 1-4 and report | the most valuable thing: nothing from this stretch has been seen by a person |
| Close the "hidden crimes never resolve" gap | small: a found body or discovered theft should surface the crime (`witness_reports.gd`, `carrying.gd`); see `DEVELOPMENT_STATUS.md` section 3 |
| Look at the render error at launch | `prop_art.gd:7` "Invalid polygon data"; 15 minutes to learn if it is new |
| **Milestone 5** (night lighting, per-town weather, mud and fog, seasons and harvest, seasonal colours, price trends) | the roadmap's recommended next step; show a plan first |
| Something else from `docs/ROADMAP.md` | each milestone lists its features in build order |

## 8. Gotchas learned the hard way

- **GDScript:** `a and b or c` returns a bool, not a value (broke a test helper). A static function named `log` was avoided because it shadows GDScript's built-in `log()` (not tested whether it would fail; `chronicle.gd` uses `entries`). Avoid cyclic `preload`s: modules that depend on each other call `load()` with the file path inside functions instead (see `sim/law/law.gd`).
- **Old saves:** every new field needs a default via `.get()`; every new system must keep `restore()` working on a save made before it existed (`tests/sim/persistence_test.gd` and the soak test check this).
- **Tests that put people in place:** NPCs follow routines, so tests re-set their cell each tick and pause them with `npc.impact_until = tick + 5` (see `tests/sim/trespass_test.gd`). A player standing inside a house can trigger trespass; inside a shop at night too.
- **Screenshots:** capture scripts must run in a real window. At the start position several villagers overlap the player; move the player to a clear cell or you will inspect the wrong figure. A tint applied to the parent node can be hidden by another figure; check with a vivid colour first.
- **Drawn characters repaint on pose change only;** anything that must update while standing still (the beard) needs an explicit `queue_redraw()`.
- **Tuning that depends on rounding:** a 10% price change on a 3-coin item rounds to nothing; tests should use a pricier item.
- **Do not edit source files while the full suite is running**; it reads them live.
- **Finder duplicates** ("name 2.gd") exist next to real files. When grepping, they show up as duplicate results; ignore them, never edit them, never stage them.

## 9. Information that lives outside the repo

- Owner's Desktop: `Project_Solo_Plan.txt` (same content as `docs/ROADMAP.md`, with the same corrections) and the folder `Project Solo – old plan files` (three superseded plan documents, kept for reference).
- Claude memory for this project: `~/.claude/projects/-Users-eriklundin-Documents/memory/` (`MEMORY.md` index, `project-solo-hold-pushes.md`).
- The full raw transcript of the long session: `~/.claude/projects/-Users-eriklundin-Documents/7bcda031-ff92-4254-9efc-fbf51763496c.jsonl` (huge; search it, e.g. with grep, only when a detail is missing).

## 10. What could not be preserved

- The first part of the long session (performance work PR #10, test fixes PR #11, features PR #12, the layout PR #13) is available only as a summary, the merged commits' messages and the existing docs. The reasoning is recorded to that extent in `docs/DECISIONS.md` section B-C; fuller reasoning from those conversations is gone.
- Hand-play impressions: none exist. Everything in `DEVELOPMENT_STATUS.md` sections 2-3 is verified by tests and screenshots, not by a person playing.

## 11. The message to send to start the next conversation

> Continue developing Project Solo. The project is at `/Users/eriklundin/Documents/ChatGPT/lw-launcher/source` on branch `feature/quick-wins`. First read `source/CLAUDE.md`, then `source/docs/HANDOVER.md` and `source/docs/DEVELOPMENT_STATUS.md`; load other docs only when needed. Do not push, open PRs or merge. Do not build anything yet: check `git status`, run one test to confirm the toolchain works, then tell me in plain words where things stand and what you recommend doing first. I will choose.
