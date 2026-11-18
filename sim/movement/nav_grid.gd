extends RefCounted
## A derived walkability grid for pathfinding, built from the world's blocked cells, building
## walls and fixtures (exactly what World.walkable reads). It lives outside the game state: it is
## rebuilt whenever its source changes and never saved, so it cannot change an outcome.
## The search itself is Godot's built-in AStarGrid2D (C++), four-neighbour with Manhattan costs.
const World = preload("res://sim/world/world_db.gd")
const Probe = preload("res://sim/diagnostics/perf_probe.gd")

static var astar: AStarGrid2D
static var world_ref: Dictionary = {}
static var signature: Array = []

## What the grid was built from. Any write that changes walkability either bumps nav_revision or
## changes one of the three tables' sizes (or replaces a table), so this catches every change.
static func _signature(state: Dictionary) -> Array:
	var w: Dictionary = state.world
	return [w.get("bounds", [0, 0, World.WIDTH, World.HEIGHT]), int(w.get("nav_revision", 0)),
		w.blocked.size(), w.get("building_walls", {}).size(), w.get("fixture_cells", {}).size()]

static func _parse(key: String) -> Vector2i:
	var comma := key.find(",")
	return Vector2i(int(key.substr(0, comma)), int(key.substr(comma + 1)))

## The grid for this state, rebuilt only when the world's walkability has changed.
static func grid(state: Dictionary) -> AStarGrid2D:
	var sig := _signature(state)
	if astar != null and is_same(world_ref, state.world) and sig == signature:
		return astar
	var started := Time.get_ticks_usec()
	var bounds: Array = sig[0]
	if astar == null: astar = AStarGrid2D.new()
	var region := Rect2i(bounds[0], bounds[1], bounds[2] - bounds[0], bounds[3] - bounds[1])
	astar.region = region
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.jumping_enabled = false
	astar.update()
	for table in [state.world.blocked, state.world.get("building_walls", {}), state.world.get("fixture_cells", {})]:
		for key in table:
			var cell := _parse(key)
			if region.has_point(cell): astar.set_point_solid(cell, true)
	world_ref = state.world
	signature = sig
	Probe.add("nav_grid_rebuild", Time.get_ticks_usec() - started)
	Probe.count("nav_grid_rebuilds")
	return astar

## Forget the grid (tests that swap worlds in place can call this; normal play never needs to).
static func reset() -> void:
	astar = null
	world_ref = {}
	signature = []
