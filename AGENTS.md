# Project Living World — Contributor Rules

- Target: Godot 4.x (version pinned in README), GDScript, 2D desktop, single-player.
- Read docs/01_GAME_FOUNDATION.md, docs/02_TECHNICAL_LAYERS.md and docs/03_BUILD_ROADMAP.md before implementing systems.
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
