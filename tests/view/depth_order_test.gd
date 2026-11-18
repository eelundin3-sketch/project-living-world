extends SceneTree
const World = preload("res://sim/world/world_db.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: " + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	# The checks below need the whole house in view, so test at the wider 1x framing.
	main.get_node("ObserverCamera").zoom = Vector2.ONE
	var world = main.get_node("WorldView")
	var sim = main.simulation
	world.snap_visuals()
	check(world.y_sort_enabled, "Actors and scenery share y-sort ordering")
	var player_key: String = str(main.simulation.state.player)
	check(world.character_models.has(player_key), "Player has a depth-sorted drawn character node")
	var actor = world.character_models[player_key]
	var fixture_count: int = 0
	var furniture_count: int = 0
	var wall_count: int = 0
	for key in world.depth_objects:
		var obj = world.depth_objects[key]
		check(obj.get_parent() == actor.get_parent(), "Depth objects share the actor's sort parent")
		if obj.object_kind == "fixture": fixture_count += 1
		elif obj.object_kind == "furniture": furniture_count += 1
		elif obj.object_kind == "wall": wall_count += 1
	check(fixture_count > 0 and furniture_count > 0 and wall_count > 0, "Walls, fixtures and furniture use depth-sorted nodes")
	var player_cell: Array = main.simulation.state.entities[player_key].cell
	var stash_id := World.add_entity(main.simulation, "stash", "Depth test supplies", [player_cell[0] + 1, player_cell[1]])
	Inventory.create(main.simulation.state, stash_id, 10)
	world._sync_depth_objects()
	check(world.depth_objects.has("stash:%d" % stash_id), "Dropped items share the same depth ordering")
	var house: Dictionary = main.simulation.state.entities[str(main.simulation.state.home)]
	var house_rect := World.building_rect(house)
	var step_corner := World.house_notch(house_rect) + Vector2i.LEFT
	var corner_wall = world.depth_objects.get("wall:%d,%d" % [step_corner.x, step_corner.y])
	check(corner_wall != null and corner_wall.wall_neighbours.north and corner_wall.wall_neighbours.east and not corner_wall.wall_neighbours.northeast, "Stepped corner exposes the inside bevel at the tile join")
	check(not world.depth_objects.has("wall:%d,%d" % [house.door[0], house.door[1]]), "Walkable doorway has no visible wall")
	var first_wall: Array = house.interior_walls[0]
	var wall_key := "wall:%d,%d" % [first_wall[0], first_wall[1]]
	check(world.depth_objects.has(wall_key), "Authoritative wall cell has a visible wall")
	if world.depth_objects.has(wall_key):
		var wall = world.depth_objects[wall_key]
		check(is_equal_approx(wall.position.y, first_wall[1] * 24.0 + 12.0), "Wall depth is based on its ground edge")
		var neighbour_key := "%d,%d" % [first_wall[0], first_wall[1] + 1]
		check(wall.wall_neighbours.south == (main.simulation.state.world.building_walls.get(neighbour_key, 0) == house.id), "Wall trim follows connected wall cells")
		actor.position = wall.position + Vector2(0, -24)
		check(actor.position.y < wall.position.y, "Actor behind wall sorts before it")
		actor.position = wall.position + Vector2(0, 24)
		check(actor.position.y > wall.position.y, "Actor in front sorts after the wall")
	# Sample across Alder Hollow's main street, away from the square, perpendicular to the road.
	var TL = load("res://sim/world/town_layout.gd")
	var main_street: Dictionary = {}
	for segment in TL.segments(sim.state): if segment.kind == "main" and int(segment.town) == 1: main_street = segment
	# Use the stretch of street that is farthest from every other road, so only this road shades the mask.
	var anchor: Array = main_street.points[0]
	var best_gap := -1.0
	for candidate in main_street.points:
		var gap := 1.0e9
		for other in TL.segments(sim.state):
			if int(other.id) == int(main_street.id): continue
			for q in other.points: gap = minf(gap, Vector2(float(candidate[0]) - float(q[0]), float(candidate[1]) - float(q[1])).length())
		for building in sim.state.entities.values():
			if building.has("footprint"): gap = minf(gap, Vector2(float(candidate[0]) - float(building.cell[0]), float(candidate[1]) - float(building.cell[1])).length())
		if gap > best_gap: best_gap = gap; anchor = candidate
	var near: Dictionary = TL.nearest_road_point(sim.state, Vector2(float(anchor[0]), float(anchor[1])))
	var across := Vector2(-near.tangent.y, near.tangent.x) * 24.0
	var centre: Vector2 = near.point * 24.0
	var road_x := 0.0
	var road_y := 0.0
	var middle: float = world.roads.coverage(centre)
	var shoulder: float = world.roads.coverage(centre + across * (15.0 / 24.0))
	var beyond: float = world.roads.coverage(centre + across * (45.0 / 24.0))
	check(middle > shoulder and shoulder > beyond and beyond == 0.0, "Road color feathers into neighboring terrain")
	main.queue_free()
	await process_frame
	print("Depth ordering: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
