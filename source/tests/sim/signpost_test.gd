extends SceneTree
## Signposts know how far each town is along the roads and which way that road leaves the post;
## older saves learn it on load, and the numbers agree with the route auto-travel would walk.
const Sim = preload("res://sim/core/simulation.gd")
const World = preload("res://sim/world/world_db.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const RoadPlanner = preload("res://sim/world/road_planner.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)

func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	var posts: Array = World.of_kind(s, "signpost")
	check(not posts.is_empty(), "The world has signposts")
	for post in posts:
		var ways: Array = post.get("ways", [])
		check(ways.size() == s.settlements.size(), "Signpost %d points to every town (%d ways)" % [post.id, ways.size()])
		for index in range(ways.size()):
			var way: Dictionary = ways[index]
			var town: Dictionary = s.settlements[str(way.town)]
			var route: Dictionary = Nav.request_travel_path(s, post.cell, RoadPlanner.town_gate(s, town))
			check(route.ok and int(way.paces) == route.path.size() - 1, "%s: %d paces matches the road route" % [way.name, way.paces])
			check(Vector2(way.dir[0], way.dir[1]).length() > 900.0, "...with a direction")
			if index > 0: check(int(way.paces) >= int(ways[index - 1].paces), "Nearest town first")
		check(str(post.get("directions", "")).contains("paces"), "Look at reads the distances: %s" % post.get("directions", ""))
	# Same world, same numbers.
	var twin := Sim.new(); twin.start_game()
	check(str(World.of_kind(twin.state, "signpost").map(func(p): return p.ways)) == str(posts.map(func(p): return p.ways)), "Deterministic")
	# An older save (signposts without distances) learns them on load, the same as a new world.
	var old: Dictionary = sim.snapshot()
	for post in World.of_kind(old, "signpost"): post.erase("ways"); post.directions = "the old text"
	var started := Time.get_ticks_usec()
	var loaded := Sim.new(); loaded.restore(old)
	print("measuring every signpost on load: %.1f ms" % (float(Time.get_ticks_usec() - started) / 1000.0))
	check(str(World.of_kind(loaded.state, "signpost").map(func(p): return p.ways)) == str(posts.map(func(p): return p.ways)), "An old save's signposts are measured on load")
	# Save, load and continue: same world.
	var copy := Sim.new(); copy.restore(sim.snapshot())
	for i in range(60): sim.step(); copy.step()
	check(sim.state_hash() == copy.state_hash(), "Save, load and continue gives the same world")
	print("Signposts: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
