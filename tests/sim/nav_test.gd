extends SceneTree
## Pathfinding on the derived grid: shortest paths, blocked and unreachable goals, a grid that
## follows changes in both directions (a cell blocked, then cleared again), a route kept when the
## world changes elsewhere, and two worlds side by side not mixing their grids.
const Sim = preload("res://sim/core/simulation.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const World = preload("res://sim/world/world_db.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	var a := Sim.new(41)
	a.start_village(5)
	var s: Dictionary = a.state
	var start: Array = [40, 70]
	var goal: Array = [52, 70]
	for x in range(36, 58):
		for y in range(64, 77):
			s.world.blocked.erase("%d,%d" % [x, y])
	s.world.nav_revision += 1
	var direct := Nav.request_path(s, start, goal)
	check(direct.ok and direct.path.size() == 12 and direct.path.back() == goal, "Straight path is shortest and ends on the goal")
	# A wall across the way: the path goes round it, still four-neighbour steps.
	for y in range(66, 75): World.apply_mutation(s, [46, y], true)
	var around := Nav.request_path(s, start, goal)
	var steps_ok := true
	var previous: Array = start
	for cell in around.path:
		if absi(cell[0] - previous[0]) + absi(cell[1] - previous[1]) != 1 or not World.walkable(s, cell): steps_ok = false
		previous = cell
	check(around.ok and around.path.size() > 12 and steps_ok, "Detours round a new wall in single walkable steps")
	# Clearing the wall again must clear it in the grid too.
	for y in range(66, 75): World.apply_mutation(s, [46, y], false)
	var again := Nav.request_path(s, start, goal)
	check(again.ok and again.path.size() == 12, "A cleared wall is walkable again for the pathfinder")
	# Unreachable: a goal boxed in on all sides.
	for offset in [[0, -1], [1, 0], [0, 1], [-1, 0]]: World.apply_mutation(s, [goal[0] + offset[0], goal[1] + offset[1]], true)
	check(Nav.request_path(s, start, goal).error_code == "UNREACHABLE", "A boxed-in goal is unreachable")
	check(Nav.request_path(s, start, [goal[0], goal[1] - 1]).error_code == "BLOCKED_ENDPOINT", "A blocked goal is rejected")
	for offset in [[0, -1], [1, 0], [0, 1], [-1, 0]]: World.apply_mutation(s, [goal[0] + offset[0], goal[1] + offset[1]], false)
	# A route is only recomputed when one of its own cells is blocked.
	var route: Array = Nav.request_path(s, start, goal).path
	World.apply_mutation(s, [20, 20], true)
	check(Nav.still_clear(s, route), "A change elsewhere leaves the route clear")
	World.apply_mutation(s, route[3], true)
	check(not Nav.still_clear(s, route), "A wall on the route is noticed")
	# Two worlds: each pathfinds on its own grid.
	var b := Sim.new(41)
	b.start_village(5)
	for x in range(36, 58):
		for y in range(64, 77):
			b.state.world.blocked.erase("%d,%d" % [x, y])
	b.state.world.nav_revision += 1
	var in_b := Nav.request_path(b.state, start, goal)
	var in_a := Nav.request_path(s, start, goal)
	check(in_b.ok and in_b.path.size() == 12, "Second world has its own open grid")
	check(in_a.ok and in_a.path.size() > 12, "First world still sees its wall")
	print("Navigation: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
