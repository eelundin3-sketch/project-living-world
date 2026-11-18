extends RefCounted
const World = preload("res://sim/world/world_db.gd")
const Probe = preload("res://sim/diagnostics/perf_probe.gd")
## Deterministic four-neighbour A*. Cached by the caller with a navigation revision.
static func request_path(state: Dictionary, start: Array, goal: Array) -> Dictionary:
	if not World.walkable(state, start) or not World.walkable(state, goal):
		return {"ok": false, "error_code": "BLOCKED_ENDPOINT", "path": []}
	if start == goal:
		return {"ok": true, "error_code": "", "path": []}
	Probe.count("astar_calls")
	var frontier: Array = [start]
	var costs: Dictionary = {World.cell_key(start): 0}
	var parents: Dictionary = {}
	var cells: Dictionary = {World.cell_key(start): start}
	var goal_key := World.cell_key(goal)
	while not frontier.is_empty():
		var best: int = 0
		var best_score: int = 2147483647
		for index in range(frontier.size()):
			var c: Array = frontier[index]
			var score: int = int(costs[World.cell_key(c)]) + absi(c[0] - goal[0]) + absi(c[1] - goal[1])
			if score < best_score:
				best = index
				best_score = score
		var current: Array = frontier.pop_at(best)
		Probe.count("astar_nodes")
		var key := World.cell_key(current)
		if key == goal_key:
			var path: Array = []
			while key != World.cell_key(start):
				path.push_front(cells[key])
				key = parents[key]
			return {"ok": true, "error_code": "", "path": path}
		for direction in [[0, -1], [-1, 0], [1, 0], [0, 1]]:
			var next: Array = [current[0] + direction[0], current[1] + direction[1]]
			var next_key := World.cell_key(next)
			var cost: int = int(costs[key]) + 1
			if World.walkable(state, next) and (not costs.has(next_key) or cost < costs[next_key]):
				costs[next_key] = cost
				parents[next_key] = key
				cells[next_key] = next
				frontier.append(next)
	return {"ok": false, "error_code": "UNREACHABLE", "path": []}
