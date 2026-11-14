extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const World = preload("res://sim/world/world_db.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const Save = preload("res://sim/persistence/save_manager.gd")
const Planner = preload("res://sim/settlement/planner.gd")
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
		var interior: Array = [entity.cell[0], entity.cell[1] - 2]
		var outside: Array = [entity.cell[0], entity.cell[1] + 2]
		var route := Nav.request_path(s, outside, interior)
		check(route.ok and route.path.has(entity.door), "Interior is reachable through doorway")
		check(not World.walkable(s, [r.position.x, r.position.y + 2]), "Side wall blocks movement")
		check(not Planner.suitable(s, interior), "Construction cannot overlap existing room")
		for cell in route.path:
			check(World.walkable(s, cell), "Navigation never crosses wall")
	var house: Dictionary = s.entities[str(s.home)]
	s.entities[str(s.player)].cell = [house.cell[0], house.cell[1] + 1]
	for index in range(4):
		sim.submit("move_player", {"direction": [0, -1]})
		sim.step()
	check(World.inside_building(s, s.entities[str(s.player)].cell) == s.home, "Player walks inside")
	for index in range(10):
		sim.submit("move_player", {"direction": [-1, 0]})
		sim.step()
	check(s.entities[str(s.player)].cell[0] == World.building_rect(house).position.x + 1, "Player stops at solid wall")
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
