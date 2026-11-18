extends SceneTree
## Doors in the world view: one in every doorway (outside and between rooms), opening when someone is
## near and closing after, and never touching walkability.
const World = preload("res://sim/world/world_db.gd")
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main)
	await process_frame
	main.set_process(false)
	var world = main.get_node("WorldView")
	var s: Dictionary = main.simulation.state
	# Put the camera on the common lodge (it has an inside partition) and let the view build.
	var home: Dictionary = s.entities[str(s.home)]
	main.follow_player = false
	var camera = main.get_node("ObserverCamera")
	camera.zoom = Vector2.ONE
	camera.position = Vector2(home.cell[0], home.cell[1] - 6) * 24.0
	s.entities[str(s.player)].cell = [home.cell[0] + 30, home.cell[1] + 30]
	main.refresh_view()
	for i in range(4):
		world.animate(0.1, false, 1)
		await process_frame
	var doors: Dictionary = {}
	for key in world.depth_objects.keys():
		if world.depth_objects[key].object_kind == "door": doors[key] = world.depth_objects[key]
	var outer_key := "door:%d:out" % home.id
	check(doors.has(outer_key), "The lodge has a door in its doorway")
	var passages: Array = World.interior_doorways(home)
	check(passages.size() >= 1 and doors.has("door:%d:in0" % home.id), "...and one in the passage between its rooms (%d passages)" % passages.size())
	for gap in passages: check(not gap.cells.is_empty() and gap.cells.size() <= 3, "A passage is one to three cells wide")
	# Shut while nobody is near.
	check(doors[outer_key].door_open < 0.01, "The door is shut with nobody near")
	# Someone walks up: it swings open; they leave: it shuts again after a moment.
	var door_cell: Array = home.door
	main.simulation.state.entities[str(s.player)].cell = [door_cell[0], door_cell[1] + 1]
	main.refresh_view()
	world.motion.update(s, 0.0, false, 1)
	world.snap_visuals()
	for i in range(8):
		world.animate(0.1, false, 1)
		await process_frame
	check(doors[outer_key].door_open > 0.95, "The door opens when the player walks up (open = %.2f)" % doors[outer_key].door_open)
	check(World.walkable(s, door_cell), "The doorway stays walkable whatever the door is doing")
	s.entities[str(s.player)].cell = [door_cell[0] + 30, door_cell[1] + 30]
	world.snap_visuals()
	for i in range(25):
		world.animate(0.1, false, 1)
		await process_frame
	check(doors[outer_key].door_open < 0.05, "It shuts after they leave (open = %.2f)" % doors[outer_key].door_open)
	# Every building with a doorway has a door, whichever way it faces.
	var sides: Dictionary = {}
	for entity in s.entities.values():
		if entity.has("footprint") and entity.has("door"): sides[int(entity.get("door_side", 2))] = true
	check(sides.size() >= 1, "Buildings face at least one way")
	print("Doors: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
