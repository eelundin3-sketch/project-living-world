extends SceneTree
const Clock = preload("res://sim/core/sim_clock.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check(Engine.get_version_info().major == 4 and Engine.get_version_info().minor == 6 and Engine.get_version_info().patch == 0 and Engine.get_version_info().status == "stable", "Pinned engine build")
	var main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	check(main.simulation.state.residents.size() == 30, "Both towns initialize")
	check(main.get_node("DebugHUD").heading.text.contains("ALDER"), "HUD displays world")
	check(main.get_node("WorldView").simulation == main.simulation, "View projects authoritative sim")
	var before: String = main.simulation.state_hash()
	main.handle_action("pause")
	main.clock.advance(5, main.simulation)
	check(main.simulation.state_hash() == before, "Pause leaves world unchanged")
	main.handle_action("speed4")
	check(main.clock.speed == 4, "Speed UI")
	main.handle_action("pause")
	main.clock.advance(0.1, main.simulation)
	check(main.simulation.state.tick >= 4, "4x simulation ticks")
	main.save_path = OS.get_temp_dir().path_join("lw-ui-save.dat")
	main.handle_action("save")
	var saved_hash: String = main.simulation.state_hash()
	main.simulation.step()
	main.handle_action("load")
	check(main.simulation.state_hash() == saved_hash, "Save/load UI restores authoritative state")
	var camera = main.get_node("ObserverCamera")
	camera.adjust_zoom(100)
	check(is_equal_approx(camera.zoom.x, 2.5), "Zoom upper bound")
	camera.adjust_zoom(0.001)
	check(is_equal_approx(camera.zoom.x, 0.4), "Zoom lower bound")
	main.clock.speed = 1
	var old_cell: Array = main.simulation.state.entities[str(main.simulation.state.player)].cell.duplicate()
	Input.action_press("walk_right")
	main._process(0.1)
	Input.action_release("walk_right")
	check(main.simulation.state.entities[str(main.simulation.state.player)].cell[0] == old_cell[0] + 1, "Mapped keyboard input moves authoritative player")
	main.handle_action("travel")
	main.simulation.step()
	check(not main.simulation.state.player_path.is_empty(), "Travel submits a path command")
	main.queue_free()
	await process_frame
	print("UI smoke: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
