extends RefCounted
## Storage for derived lookups (indexes, grids) that live outside the game state. Each cache keeps
## a few slots, one per world it has seen, matched by identity, so tests that run two worlds side
## by side (a save/load comparison) do not rebuild on every step. Nothing here is ever saved.
const SLOTS := 4

## The slot for `owner` (a dictionary of the state, such as state.entities), created empty on
## first use. Callers keep their own fields in it and their own signature to know when to rebuild.
static func slot(store: Array, owner: Dictionary) -> Dictionary:
	for entry in store:
		if is_same(entry.owner, owner): return entry
	var entry := {"owner": owner}
	store.push_front(entry)
	if store.size() > SLOTS: store.pop_back()
	return entry
