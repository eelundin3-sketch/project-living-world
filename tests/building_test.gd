extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const World = preload("res://sim/world/world_db.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const Save = preload("res://sim/persistence/save_manager.gd")
const Planner = preload("res://sim/settlement/planner.gd")
const Orient = preload("res://sim/world/orient.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	var sim := Sim.new()
	sim.start_game()
	var s: Dictionary = sim.state
	for entity in s.entities.values():
		if not entity.has("footprint"):
			continue
		var r := World.building_rect(entity)
		var out := Orient.outward(int(entity.get("door_side", 2)))
		var interior: Array = [entity.cell[0] - out.x * 2, entity.cell[1] - out.y * 2]
		var outside: Array = [entity.cell[0] + out.x * 2, entity.cell[1] + out.y * 2]
		var route := Nav.request_path(s, outside, interior)
		check(route.ok and route.path.has(entity.door), "Interior is reachable through doorway")
		var wall_found := false
		for y in range(r.position.y, r.end.y):
			if World.building_contains(entity, [r.position.x, y]) and not World.walkable(s, [r.position.x, y]): wall_found = true
		check(wall_found, "Side wall blocks movement")
		check(not Planner.suitable(s, interior), "Construction cannot overlap existing room")
		for cell in route.path:
			check(World.walkable(s, cell), "Navigation never crosses wall")
	var house: Dictionary = s.entities[str(s.home)]
	s.entities[str(s.player)].cell = [house.cell[0], house.cell[1] + 1]
	for index in range(8):
		sim.submit("move_player", {"direction": [0, -1]})
		sim.step()
	check(World.inside_building(s, s.entities[str(s.player)].cell) == s.home, "Player walks inside")
	for index in range(20):
		sim.submit("move_player", {"direction": [-1, 0]})
		sim.step()
	var stopped: Array = s.entities[str(s.player)].cell
	# Beds and other furniture now stand along the walls, so the player may stop at a bed instead of the wall.
	check(not World.walkable(s, [stopped[0] - 1, stopped[1]]) and World.inside_building(s, stopped) == s.home, "Player stops at a solid wall or furniture and stays inside")
	var path := OS.get_temp_dir().path_join("lw-building.save")
	check(Save.save_state(sim, path).ok, "Interior save succeeds")
	var loaded := Sim.new()
	check(Save.load_into(loaded, path).ok and loaded.state_hash() == sim.state_hash(), "Interior position/walls survive reload")
	var legacy: Dictionary = sim.snapshot()
	legacy.world.erase("building_walls")
	for entity in legacy.entities.values():
		entity.erase("footprint")
		entity.erase("door")
	var inventory_before: Dictionary = legacy.inventories.duplicate(true)
	loaded.restore(legacy)
	check(loaded.state.world.has("building_walls"), "Legacy save gains building walls")
	check(loaded.state.inventories == inventory_before, "Legacy upgrade preserves every inventory")
	check(World.walkable(loaded.state, loaded.state.entities[str(loaded.state.player)].cell), "Legacy upgrade leaves player in a walkable cell")
	print("Buildings: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
