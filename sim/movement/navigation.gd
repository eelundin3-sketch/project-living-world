extends RefCounted
const World = preload("res://sim/world/world_db.gd")
const Probe = preload("res://sim/diagnostics/perf_probe.gd")
const NavGrid = preload("res://sim/movement/nav_grid.gd")
## Deterministic four-neighbour shortest paths on the derived walkability grid (nav_grid.gd).
## The path excludes the start cell and ends on the goal.
static func request_path(state: Dictionary, start: Array, goal: Array) -> Dictionary:
	return _search(state, start, goal, false)

## A path for a long walk (a trader's trip, the player's travel to a town): it keeps to the roads,
## leaving them only where that saves a lot (nav_grid.gd travel_grid).
static func request_travel_path(state: Dictionary, start: Array, goal: Array) -> Dictionary:
	return _search(state, start, goal, true)

static func _search(state: Dictionary, start: Array, goal: Array, by_road: bool) -> Dictionary:
	if not World.walkable(state, start) or not World.walkable(state, goal):
		return {"ok": false, "error_code": "BLOCKED_ENDPOINT", "path": []}
	if start == goal:
		return {"ok": true, "error_code": "", "path": []}
	Probe.count("astar_calls")
	var grid := NavGrid.travel_grid(state) if by_road else NavGrid.grid(state)
	var cells: Array[Vector2i] = grid.get_id_path(Vector2i(start[0], start[1]), Vector2i(goal[0], goal[1]))
	if cells.size() < 2:
		return {"ok": false, "error_code": "UNREACHABLE", "path": []}
	var path: Array = []
	path.resize(cells.size() - 1)
	for index in range(1, cells.size()):
		path[index - 1] = [cells[index].x, cells[index].y]
	return {"ok": true, "error_code": "", "path": path}

## True when every cell left on a path can still be walked. A change somewhere else in the world
## (a builder's new wall across town) then leaves this route alone instead of recomputing it.
static func still_clear(state: Dictionary, path: Array) -> bool:
	for cell in path:
		if not World.walkable(state, cell): return false
	return true
