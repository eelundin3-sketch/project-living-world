# Decisions and their reasons

Last updated 2026-11-20. This is a **reading guide to the decisions**, written for a new session. The full running log is `docs/design/DECISIONS.md` (D001-D028 from the first build, then dated entries; the last two entries, 2026-11-19, are the most recent). Add new decisions **there** (the contributor rules in `AGENTS.md` require it) and add a line here only if a new session should know it first.

How to read the tags: **[owner]** the owner decided or asked for it; **[code]** verifiable in the code or git history; **[inferred]** my reasoning at the time, not a recorded instruction. Reasons are taken from commit messages and the conversation; where I can't recover a reason, it says so.

## A. Process decisions (the owner's standing rules)

| Decision | Why | Source |
|---|---|---|
| **Commit locally; do not push, open PRs or merge until the owner asks for "the big push".** (On 2026-11-20 the owner asked for the PR: #14, stacked on #13. Merging is still theirs to ask for.) To see what is unpushed, compare with git (`git fetch`, `git rev-list <branch> --not --remotes`). No tracking file or hook. | The owner wants to collect many changes and publish them together much later, and keep GitHub tidy meanwhile. | [owner], saved as a memory file |
| **`Project Solo.app` must be the very first item in the downloaded folder; names on GitHub must be right.** Hence PR #13: all game files moved into `source/`, the launcher at the root, workflows run in `source/`. | Players download the repo and must find the app at once. | [owner], PR #13 |
| **Never add a root-level file whose name sorts before "Project Solo.app".** (`CLAUDE.md` at the root would sort first, so the main one lives in `source/CLAUDE.md` and the root only has `.claude/CLAUDE.md`.) | Same reason as above. | [inferred] from the owner's rule |
| **Show the plan, then build; build in milestones and stop between them.** The owner asked "show me the plan without doing them" and answered "Not now" to starting milestone 5. | The owner wants control over order and scope. | [owner] |
| **Idea lists live outside the game** (a Desktop text file, later copied to `docs/ROADMAP.md`); the owner said "nothing added to the game" while ideas were being gathered. | Keep brainstorming separate from the build. | [owner] |
| **Big push order:** PR #13 (layout) first, then the feature branches. | They were built on the layout commit; the 45-minute CI limit is only on PR #13's branch. | [code] |

## B. Performance (PR #10, 2026-11-19)

Starting point: below 10-30 FPS with multi-second freezes. The cause was a few loops that walked all ~6,300 entities every frame or tick, a slow pathfinder, and a clock that let one slow tick snowball. Results (M4, windowed): zoom 2 from 28 to 76-80 FPS; worst headless tick from 2,775 ms to 12 ms. **Nothing was removed; screenshots before and after match.**

- **Measure first**: the F4 tab shows per-system cost; `full_game_benchmark.gd` and `view_benchmark.gd` exist so every later change can be compared. [code]
- **Derived lookups** (`DerivedCache`: by kind, buildings, trees by cell, walk grids) replace entity scans; never saved, rebuilt when the world changes. Reason: save/load must not depend on caches. [code]
- **Pathfinding** uses Godot's C++ `AStarGrid2D` on a derived grid, rebuilt only when walkability changes; a route is recomputed only when one of its own cells is blocked. [code]
- **Clock cap**: at most 10 ms of simulation per frame and a clamped backlog, so one slow tick cannot snowball; tick count stays the authority so results are unchanged. [code]
- **View culling and caching**: people from the resident list, depth objects from 16-cell chunk indexes, static shadows painted once until the sun moves, UI repaints only on change, map figures repaint 1 frame in 4. [code]
- **The drawn map is painted once per opening** (not the live world zoomed out): about 120 FPS instead of 26. [owner asked for the drawn medieval map; the once-per-press rule is theirs: "updated whenever I press M again"]
- **Budgets for every later feature**: at least 60 FPS at zoom 2 and on the map, p95 frame time at most 20 ms, sim tick at most 4 ms average and 15 ms worst. `docs/ROADMAP.md` section 6. [owner: "make sure the game still runs smoothly with high fps"]

## C. Features from PR #12 and the people/trade work

- **Roads**: shared trunks that fork, bent around obstacles, signposts at forks, built first Alder Hollow-Reedbank then Dustvale's joining it. [owner chose "shared trunks that fork"]
- **Walking faster on roads** (about 15% streets, 30% link roads) using integer maths with a carried fraction so it stays deterministic. [owner]
- **Traders follow roads**: a travel grid weights open country 3, a road edge 1.5, a road centre 1; traders carry a per-cell schedule so the view places them exactly (no stop-and-go). [code]
- **Sleep fast-forwards** the clock 8x until rested, 06:00, hurt, or any key. [owner chose "fast-forward until rested"]
- **Click what you press** inside buildings: a bed offers Sleep, the weapon rack a gun, plain floor nothing. [owner]
- **Wind loop removed**: its loop end was wrong for the compressed import, so under a second repeated with a click. Policy since: no single continuous ambient loop. [code]
- **Stall keepers hurry over** and you wait for them before trading; haggling once per visit. [owner]
- **Families live together** with a shared purse and professions that earn money and feed them. [owner]
- **Sheriffs advance cover to cover**, slowly, one at a time, only while the gunman is quiet or reloading; they bandage themselves. **Bleeding costs health until treated**, for everyone. [owner]
- **Cover rules**: take cover only when crouched or in combat; high things (walls) cover standing, low things (beds, chests) only if you crouch. [owner]
- **No sun shadows indoors.** [owner]
- **A designed trade/conversation window** (parchment ledger). [owner: "much better design"]

## D. Steps 1-4 (2026-11-19, this stretch)

Mostly recorded in the last two entries of `docs/design/DECISIONS.md`; the reasoning in brief:

- **Extend `Society.remember` instead of writing a new memory store.** A memory system with 16 memories and trust already existed but nothing used it. Memories gained weights that fade over days (a killed relative never fades); repeats deepen one memory; the faintest is evicted first. [code, my decision after reading the code; the first plan wrongly proposed a new file]
- **The event record is `s.chronicle`, not `s.events`** (that name is the simulation's own scheduled-event queue). Witnesses are computed once when the event is recorded, capped at 200 entries, to keep cost flat. [code]
- **Reputation is computed, not scored by hand**: recomputed daily from what each town knows (witnessed there or reached by gossip). Reason: it stays consistent with the chronicle and needs no extra bookkeeping. [inferred]
- **Witnesses are townspeople.** Murder and theft are no longer "reported out of thin air": someone must see, and run to a sheriff; stop them and it never is. Wanted records remember how you are known (face or described clothes). [owner: asked for witnesses and reporting]
- **Town laws must not use the field `town.policy`** (the economy planner already uses it). Planned name: `town.laws` / `town.mood`. [code]
- **Trespass, look, body carrying, hit reactions** were the owner's "chosen nine" ideas; each is its own small module with its own test.
- **Item weights live in code** (`encumbrance.gd`, tenths of a unit, integer maths) because `content/items/core.json` lists only 8 items; moving all tuning tables into `content/` is a planned technical task. A body always counts as an overload. [inferred]
- **Saves run on a background thread**: a save costs about 340 ms (checksum, write, verify); only the 12 ms state copy runs on the main thread. Autosave rotates two files at 06:00 and writes a small `.info` file so the title screen can offer Continue without verifying a whole save. [code]
- **Signposts measure their roads once** (`ensure_ways`), on the travel grid, so the boards agree with the road auto-travel walks. [code]
- **The rifle is the main gun** [owner]. The gun module became a weapon table (`Shotgun.WEAPONS`) with each gun's range, strength, speed and earshot, so the shotgun still works and new guns are table entries. The state key stays `s.shotgun` (with a `kind`) so old saves load unchanged. [inferred, to avoid a save migration]
- **Gunshots are loud**: a town reacts only if the shot is within earshot of the town (or a sheriff); out in the wilds nobody official does; only people who see the shooter can name them. This replaced "anything within 70 cells of a storehouse". [owner]
- **Silent takedown** is a crime only when seen; a sheriff counts as a witness only with line of sight for silent crimes. [owner]
- **Talk is judged by temper + opinion + luck**; bribes never work for murder; a refused bribe is a new crime. [inferred; the owner chose "persuade, bribe or intimidate"]
- **The conversation window lists what `sim/player/dialogue.gd` offers**; new talk options need no window change. [inferred; keeps the sim authoritative]
- **Daily updates run at 12:00** (`Households.daily`, tick 7200) because that is where the earlier family code put them; new daily systems joined it. Not a deliberate "morning" choice despite some comments. [code]

## E. Things we decided not to do (so you don't redo them)

- **No new `memory.gd`** (extend `society.gd` instead).
- **No second prices system**: `market.quote` already follows supply; the roadmap only adds trend arrows.
- **No second life-cycle system**: pairing, births and growing up already exist in `households.gd`; the roadmap adds ageing, weddings, funerals and inheritance on top.
- **The 128 x 96 map size in older notes is wrong**; the map is 582 x 420 cells.
- **No pushing** of anything from this stretch until the owner says.

## F. Reasons that could not be recovered

The conversation before the last context compaction survives only as a written summary plus commit messages and the existing docs. Detailed reasoning for PRs #10-#13 beyond their commit messages and the owner's requests was not available. The raw transcript is at `~/.claude/projects/-Users-eriklundin-Documents/7bcda031-ff92-4254-9efc-fbf51763496c.jsonl` (large; search it rather than reading it).
