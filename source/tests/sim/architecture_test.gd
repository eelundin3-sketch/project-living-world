extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const World = preload("res://sim/world/world_db.gd")
const Nav = preload("res://sim/movement/navigation.gd")
var failures: int = 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + message)
func _initialize() -> void:
	var sim := Sim.new()
	sim.start_game()
	var s: Dictionary = sim.state
	var buildings: Array = s.entities.values().filter(func(e: Dictionary) -> bool: return e.has("footprint"))
	for building in buildings:
		var rect := World.building_rect(building)
		# The town buildings are full sized with rooms; house types (housing.gd) carry their own
		# size, and the small ones (a shack, a lean-to, a hut) are a single room.
		if not building.has("house_type"):
			check(rect.size.x >= 15 and rect.size.y >= 13, "Full-sized architecture")
			check(not building.interior_walls.is_empty(), "Rooms contain authoritative partitions")
		for wall in building.interior_walls:
			check(not World.walkable(s, wall), "Internal wall blocks movement")
		# Flood every interior walkable cell, including both sides of the partition.
		for y in range(rect.position.y+1, rect.end.y-1):
			for x in range(rect.position.x+1, rect.end.x-1):
				if World.walkable(s,[x,y]):
					check(Nav.request_path(s,building.door,[x,y]).ok,"Every room accessible from doorway")
		for other in buildings:
			if other.id != building.id:
				check(not rect.intersects(World.building_rect(other)),"Initial buildings do not overlap")
	var house: Dictionary = s.entities[str(s.home)]
	var house_rect := World.building_rect(house)
	var corner := World.house_notch(house_rect)
	var notch := [corner.x + 1, corner.y - 1]
	var step_wall := [corner.x + 1, corner.y]
	check(not World.building_contains(house, notch), "Stepped corner remains outside the home")
	check(World.exterior_wall(house, step_wall, "home") and not World.walkable(s, step_wall), "Stepped corner is a solid wall")
	var planned: Dictionary = {"cell": [30, 30], "layout_shape": "stepped_joined", "building_scale": 2}
	var stages := World.construction_stages(planned, "home")
	var planned_notch := World.house_notch(World.plot_rect(planned, "home"))
	check(not stages[0].tiles.has([planned_notch.x, planned_notch.y - 1]), "Construction leaves the notch open")
	for tile in stages[1].tiles:
		check(World.building_contains(planned, tile, "home"), "Built walls stay inside the stepped outline")
	var restored := Sim.new()
	restored.restore(sim.snapshot())
	check(restored.state_hash()==sim.state_hash(),"Architecture roundtrip preserves exact state")
	var legacy: Dictionary = sim.snapshot()
	legacy.world.erase("architecture_version")
	var goods: Dictionary = legacy.inventories.duplicate(true)
	restored.restore(legacy)
	check(restored.state.inventories==goods,"Legacy redesign preserves all goods")
	var upgraded: String = restored.state_hash()
	restored.restore(restored.snapshot())
	check(restored.state_hash()==upgraded,"Legacy redesign is applied only once")
	var old_house: Dictionary = sim.snapshot()
	old_house.world.erase("house_layout_version")
	var old_entity: Dictionary = old_house.entities[str(old_house.home)]
	old_entity.erase("layout_shape")
	for key in old_house.world.building_walls.keys():
		if old_house.world.building_walls[key] == old_entity.id: old_house.world.building_walls.erase(key)
	World.install_building(old_house, old_entity.id)
	restored.restore(old_house)
	check(restored.state.entities[str(old_house.home)].layout_shape == "stepped_joined", "Older houses upgrade to the stepped layout")
	check(not World.walkable(restored.state, step_wall), "Upgraded house has matching collision")
	var compact: Dictionary = sim.snapshot()
	compact.world.erase("building_scale_version")
	var small_home: Dictionary = compact.entities[str(compact.home)]
	small_home.erase("building_scale")
	for key in compact.world.building_walls.keys():
		if compact.world.building_walls[key] == small_home.id: compact.world.building_walls.erase(key)
	World.install_building(compact, small_home.id)
	restored.restore(compact)
	check(World.building_rect(restored.state.entities[str(compact.home)]).size == Vector2i(17, 14), "Compact saved lodge expands on restore")
	check(restored.state.inventories == compact.inventories, "Scaling saved buildings preserves items")
	print("Architecture: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
