extends SceneTree
## The roads between the towns: planned around what is in the way, joined into one network with a
## signpost at every fork, and the same every time for the same world.
const Sim = preload("res://sim/core/simulation.gd")
const World = preload("res://sim/world/world_db.gd")
const TownLayout = preload("res://sim/world/town_layout.gd")
const Nav = preload("res://sim/movement/navigation.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)

## Cells of the road network reachable from `start` without leaving it.
func reach_on_road(cells: Dictionary, start: Array) -> Dictionary:
	var seen: Dictionary = {"%d,%d" % [start[0], start[1]]: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var c: Array = queue.pop_back()
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var key := "%d,%d" % [c[0] + d[0], c[1] + d[1]]
			if cells.has(key) and not seen.has(key):
				seen[key] = true
				queue.append([c[0] + d[0], c[1] + d[1]])
	return seen

func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	var links: Array = TownLayout.segments(s).filter(func(seg): return seg.kind == "link")
	check(links.size() >= 2, "There are roads between the towns (%d)" % links.size())
	# One network: from Alder Hollow's square every town's square can be reached along the roads.
	var cells := TownLayout.road_cells(s)
	var squares: Array = []
	for key in ["1", "2", "3"]:
		var store: Array = s.entities[str(s.settlements[key].warehouse)].cell
		squares.append([store[0], store[1] + 2])
	var network := reach_on_road(cells, squares[0])
	for index in range(1, squares.size()):
		check(network.has("%d,%d" % [squares[index][0], squares[index][1]]), "%s is joined to Alder Hollow by road" % s.settlements[str(index + 1)].name)
	# The middle of every link road is open ground: nothing solid stands on it.
	var blocked_on_line := 0
	for seg in links:
		for p in seg.points:
			if not World.walkable(s, [roundi(p[0]), roundi(p[1])]): blocked_on_line += 1
	check(blocked_on_line == 0, "No rock, wall or fixture stands on a road's centre line (%d)" % blocked_on_line)
	# Forks have signposts, each naming the way to every town.
	var junctions: Array = s.world.roads.get("junctions", [])
	var posts: Array = World.of_kind(s, "signpost")
	check(junctions.size() >= 1 and posts.size() == junctions.size(), "Every fork has a signpost (%d forks, %d posts)" % [junctions.size(), posts.size()])
	for post in posts:
		check(String(post.get("directions", "")).contains("Reedbank") and String(post.directions).contains("Dustvale"), "A signpost names the towns: " + str(post.get("directions", "")))
	# The way from Reedbank to Dustvale does not go round by Alder Hollow.
	var reedbank: Array = squares[1]
	var dustvale: Array = squares[2]
	var route := Nav.request_path(s, reedbank, dustvale)
	var west_most: int = 100000
	for cell in route.path: west_most = mini(west_most, int(cell[0]))
	check(route.ok and west_most > int(s.entities[str(s.warehouse)].cell[0]) + 40, "Reedbank to Dustvale is a road of its own, not round by Alder Hollow")
	# The same world twice gives the same roads.
	var again := Sim.new(); again.start_game()
	check(JSON.stringify(again.state.world.roads) == JSON.stringify(s.world.roads), "Road planning is deterministic")
	print("Road network: %s; %d link roads, %d forks" % ["PASS" if failures == 0 else "FAIL", links.size(), junctions.size()])
	quit(failures)
