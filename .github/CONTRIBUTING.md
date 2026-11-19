# Contributing to Project Solo

Use the standard edition of Godot 4.6 stable. Import `project.godot` and use
the [current game guide](../source/docs/status/CURRENT_GAME.md) for controls, data locations and
example scenarios. See [AGENTS.md](../source/AGENTS.md) for the repository's contributor rules.

The simulation owns positions, jobs, inventory and money. Put changes to those
rules in `sim/`; keep rendering and sound in `view/`. Preserve deterministic
iteration and use the simulation's seeded random streams. Include relevant
`.gd.uid` files and original project assets. Game saves and local builds belong
outside version control.

Run the focused suites for your change and use the full regression runner
before submitting a change that spans systems.

```sh
cd source
GODOT_BIN=/path/to/Godot scripts/test.sh
```

When reporting a bug, include your operating system, commit or version, steps
to reproduce it, expected and actual behavior, and any relevant error text.
Use the [validation record](../source/docs/validation/VALIDATION.md) to find existing reproducible
scenarios and capture scripts.
