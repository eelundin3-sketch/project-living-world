extends SceneTree
## Paused screenshots of the real game at fixed times of day and zoom levels, for comparing a
## change pixel by pixel ("does it still look the same?"). Writes parity_<hour>_<zoom>.png to
## SOLO_SHEET_DIR. The clock is paused, so sway and breathing are frozen and runs are repeatable.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var out := OS.get_environment("SOLO_SHEET_DIR")
	if out.is_empty(): out = OS.get_temp_dir()
	var main: Node = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	for warm in range(5): await process_frame
	main.clock.paused = true
	for hour in [9, 12, 16]:
		main.simulation.state.tick = hour * 600
		for zoom in [2.0, 1.0, 0.5]:
			main.get_node("ObserverCamera").zoom = Vector2.ONE * zoom
			for settle in range(12): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/parity_%d_%s.png" % [out, hour, str(zoom)])
	quit(0)
