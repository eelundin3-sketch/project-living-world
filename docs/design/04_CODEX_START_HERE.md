# Project Solo — Codex Hand-off and First Task

## Instructions for using this pack

1. Make a fresh Godot 4 desktop project in a Git repository.
2. Copy `01_GAME_FOUNDATION.md`, `02_TECHNICAL_LAYERS.md`, and `03_BUILD_ROADMAP.md` into `docs/`.
3. Paste the task prompt below to Codex while it has access to the repository.
4. Review, run and commit each milestone before advancing to the next.
5. This document plans the work; it is **not** a claim that code has already been built or tested.

## Codex project rules (`AGENTS.md` starting text)

```markdown
# Project Solo — Contributor Rules

- Target: Godot 4.x (version pinned in README), GDScript, 2D desktop, single-player.
- Read docs/design/01_GAME_FOUNDATION.md, docs/design/02_TECHNICAL_LAYERS.md and docs/design/03_BUILD_ROADMAP.md before implementing systems.
- The simulation is authoritative and must run headlessly without rendering.
- Views read simulation data and submit commands; views never own authoritative NPC inventory, money, needs or world state.
- Prefer typed GDScript, small files, stable IDs, explicit dependencies and deterministic iteration.
- Never call global random functions inside simulation logic; use seeded dedicated RNG streams.
- Do not change core contracts or add frameworks without documenting why and updating decision log.
- No external plugins unless explicitly justified and approved.
- Every task must include tests (or a clear reason why a specific test isn't possible) and a runnable demonstration.
- Don't implement future milestones as part of a narrower task.
- Run Godot headless validation and applicable tests when Godot is installed. If not available, explicitly say tests were not run.
- Explain which files changed, how to run the result, exact validations performed, and any known issues.
- Keep original visual assets, names and content; do not copy assets or code from Another Dead World.
```

## Exact prompt for Codex — Task 001

```text
You are building Project Solo, an original top-down 2D desktop
single-player frontier sandbox in Godot 4 with GDScript.

Read all files in docs/, especially the foundation, technical architecture,
and roadmap. Implement ONLY milestone M0 (Task 001): runnable project
bootstrap and test infrastructure.

Requirements:
1. Pin and document the Godot 4 stable version used on this machine.
2. Produce a valid project.godot with a Main scene and a simple visible
   placeholder ground, a camera, and a small HUD showing project title,
   engine version, and a placeholder simulation tick label.
3. Support keyboard/mouse desktop input for camera movement (WASD)
   and zoom. Don't add detailed player, NPC AI, worldgen, trading,
   inventory or save logic yet.
4. Establish the folder structure that fits docs/design/02_TECHNICAL_LAYERS.md.
5. Add a dependency-free headless smoke-test script that exits nonzero on
   failure, with a documented run command. Test opening the Main scene
   and a minimal deterministic pure-data assertion.
6. Add README.md with: how to open in Godot, play, run tests, known limits.
7. Add docs/design/DECISIONS.md with the decisions actually made in Task 001.
8. Write docs/status/CHANGELOG.md with this milestone's deliverables.

Acceptance:
- Godot can import the project without parser errors.
- The Main scene launches and shows the placeholder world and HUD.
- WASD camera movement and zoom work.
- Tests can run headlessly and return success/failure status.
- No simulation authority has been implemented inside view Nodes.
- No future-layer gameplay code is introduced.

Run validation with the installed Godot executable if available.
Report the exact command and result. If unavailable, state it clearly.
Give a concise changed-file list and any unresolved issues.
```

## Exact prompt for Codex — Task 002 (only after Task 001 passes)

```text
Implement ONLY M1 from docs/design/03_BUILD_ROADMAP.md.
Create a headless-capable SimulationState with a 10 Hz fixed-step tick,
stable entity ID generator, deterministic seeded RNG stream abstraction,
ordered command queue, ordered event queue, and canonical test-state hash.
Expose pause and speed controls through existing HUD without placing
simulation truth in the HUD.

Tests: (a) same seed + same commands yields matching state hash after
100,000 ticks; (b) changing render-frame delta sequence does not change
the final hash for a fixed number of authoritative ticks; (c) events with
equal due tick run in ascending event ID; (d) IDs never repeat.

Keep the implementation minimal and readable; no NPC, resource or market
systems. Run the headless tests. Update README, DECISIONS and CHANGELOG.
```

## How to review Codex's work

- Is the demonstration *actually runnable* in Godot, not just plausible code?
- Are Godot 4 APIs used correctly, not Godot 3 names?
- Does the simulation work without a SceneTree?
- Are fixed ticks independent of rendering FPS?
- Does a test prove each asserted invariant?
- Does a failure surface a clear reason instead of silently proceeding?
- Did Codex implement only the requested milestone?

## When to revise the design

Keep a decision record: `ID / decision / reason / alternatives / reversibility / validation`. Revise an architectural decision only when a concrete test, gameplay need or performance profile demonstrates a better option. Treat creative choices (setting, art, player ownership powers) as provisional until playtesting confirms they serve the core game loop.
