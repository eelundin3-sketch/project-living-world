extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); root.size = Vector2i(1280, 720); main.set_process(false)
	var s: Dictionary = main.simulation.state
	s.player_needs.hunger = 66; s.player_needs.thirst = 92; s.player_needs.fatigue = 58; s.player_needs.stress = 45
	main.simulation.submit("debug_injury", {"part": "left_shin", "damage": 45, "kind": "cut"})
	for tick in range(30): main.simulation.step()
	main.get_node("WorldView").snap_visuals(); main.refresh_view()
	for frame in range(30):
		main.moodles._process(0.05)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/needs-indicators.png")
	main.queue_free(); await process_frame; await create_timer(0.2).timeout; quit()
