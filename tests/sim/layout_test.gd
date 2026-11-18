extends SceneTree
## Town layouts: four archetypes, distinct per town, seeded; roads are connected data; every house
## faces a road, stands clear of it and can be walked to; links join all three towns; saves restore.
const Sim = preload("res://sim/core/simulation.gd")
const World = preload("res://sim/world/world_db.gd")
const TL = preload("res://sim/world/town_layout.gd")
const Orient = preload("res://sim/world/orient.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void:
	var seen: Dictionary = {}
	var sides: Dictionary = {}
	var shapes: Dictionary = {}
	for seed_value in [741, 5, 99, 12, 3141]:
		var sim := Sim.new(seed_value); sim.start_game(12)
		var s: Dictionary = sim.state
		check(s.world.has("roads") and s.world.has("layout"), "Roads and layout are simulation data (seed %d)" % seed_value)
		var archetypes: Dictionary = {}
		for key in ["1", "2", "3"]:
			var layout: Dictionary = s.world.layout[key]
			archetypes[layout.archetype] = true
			seen[layout.archetype] = true
			check(TL.ARCHETYPES.has(layout.archetype), "A known archetype")
			check(TL.lots(s, int(key)).size() >= 20, "Town %s has room along its lanes (%d lots)" % [key, TL.lots(s, int(key)).size()])
		check(archetypes.size() == 3, "The three towns have three different layouts (seed %d: %s)" % [seed_value, str(archetypes.keys())])
		# Links join every pair of towns.
		var links: int = 0
		for segment in TL.segments(s): if segment.kind == "link": links += 1
		check(links == 3, "Roads join all three towns (%d links)" % links)
		var same := Sim.new(seed_value); same.start_game(12)
		check(same.state_hash() == sim.state_hash(), "The same seed gives the same towns (seed %d)" % seed_value)
		# Every house faces a road, keeps off it, and its door can be walked to from the road.
		for entity in s.entities.values():
			if entity.kind != "home" or not entity.has("house_type"): continue
			sides[int(entity.get("door_side", 2))] = true
			shapes[entity.house_type] = true
			var near := TL.nearest_road_point(s, Vector2(entity.cell[0], entity.cell[1]))
			check(float(near.distance) < 24.0, "%s stands near a road (%.1f cells)" % [entity.name, near.distance])
			var out := Orient.outward(int(entity.door_side))
			# The door looks out towards a road: the spot a few cells outside it is no farther from the roads than the door.
			var ahead := TL.nearest_road_point(s, Vector2(entity.cell[0] + out.x * 4, entity.cell[1] + out.y * 4))
			check(float(ahead.distance) <= float(near.distance) + 1.5, "%s turns its door towards a road (%.1f -> %.1f)" % [entity.name, near.distance, ahead.distance])
			var inside := false
			for y in range(World.building_rect(entity).position.y, World.building_rect(entity).end.y):
				for x in range(World.building_rect(entity).position.x, World.building_rect(entity).end.x):
					if World.building_contains(entity, [x, y]) and TL.on_road(s, [x, y]): inside = true
			check(not inside, "%s keeps off the road" % entity.name)
			var store: Array = s.entities[str(s.settlements[str(entity.settlement)].warehouse)].cell
			check(Nav.request_path(s, [entity.door[0] + out.x, entity.door[1] + out.y], [store[0], store[1] + 2]).ok, "%s can be reached from the square" % entity.name)
		check(Checks.validate(s).is_empty(), "Invariants hold: " + str(Checks.validate(s)))
		var copy := Sim.new(); copy.restore(sim.snapshot())
		check(copy.state_hash() == sim.state_hash(), "Layouts survive a reload (seed %d)" % seed_value)
	check(seen.size() == 4, "All four archetypes appear across the seeds (%s)" % str(seen.keys()))
	check(sides.size() >= 3, "Doors face several directions (%s)" % str(sides.keys()))
	check(shapes.size() >= 6, "Many house types are used across the seeds (%d)" % shapes.size())
	# Old saves keep their old roads: dropping the road data falls back to the fixed layout.
	var legacy := Sim.new(741); legacy.start_game(12)
	var snap: Dictionary = legacy.snapshot()
	snap.world.erase("roads")
	var old := Sim.new(); old.restore(snap)
	check(TL.segments(old.state).size() >= 2 and TL.on_road(old.state, [100, 48]), "A save without road data uses the original roads")
	print("Layout: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
