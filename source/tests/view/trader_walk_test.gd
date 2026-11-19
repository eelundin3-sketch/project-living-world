extends SceneTree
## A trader on the road walks steadily on screen: no stop-and-go between cells, and the walk
## (or carry) animation holds for the whole trip.
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main)
	await process_frame
	main.set_process(false)
	main.menu_active = false
	var s: Dictionary = main.simulation.state
	var key: String = s.caravans.keys()[0]
	var trip: Dictionary = s.caravans[key]
	for i in range(4000):
		main.simulation.step()
		if trip.in_transit and s.tick - int(trip.depart_tick) > 40: break
	check(trip.in_transit, "The trader is on the road")
	var world = main.get_node("WorldView")
	main.follow_player = false
	main.get_node("ObserverCamera").position = Vector2(s.entities[key].cell[0], s.entities[key].cell[1]) * 24.0
	world.snap_visuals()
	var steps: Array = []
	var actions: Dictionary = {}
	var previous: Vector2 = world.motion.actors[key].position
	for frame in range(150):
		main._process(1.0 / 60.0)
		var pose: Dictionary = world.motion.actors[key]
		if frame >= 10:
			steps.append(pose.position.distance_to(previous))
			actions[str(pose.action)] = true
		previous = pose.position
	var total := 0.0
	for d in steps: total += d
	var mean: float = total / steps.size()
	var still := 0
	var uneven := 0
	for d in steps:
		if d < 0.05: still += 1
		if absf(d - mean) > mean * 0.35: uneven += 1
	check(mean > 0.5, "The trader moves (%.2f px a frame)" % mean)
	check(still == 0, "No frame where the walking trader stands still (%d)" % still)
	check(uneven <= steps.size() / 10, "An even pace: %d of %d frames off the average by more than a third" % [uneven, steps.size()])
	check(not actions.has("idle"), "The walk never drops to idle mid-trip: " + str(actions.keys()))
	print("Trader walk: %s; %.2f px/frame" % ["PASS" if failures == 0 else "FAIL", mean]); quit(failures)
