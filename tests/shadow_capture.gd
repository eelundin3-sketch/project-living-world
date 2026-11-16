extends SceneTree
## Shadows through the day: the same corner of Alder Hollow at 07:00, 10:00, 12:30, 15:00 and 17:30.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); main.set_process(false)
	var sim = main.simulation; var s: Dictionary = sim.state
	for hour in [7.0, 10.0, 12.5, 15.0, 17.5]:
		s.tick = int(hour * 600.0) + 14400
		s.weather = {"kind": "clear"}
		main.refresh_view()
		main.get_node("WorldView").animate(0.016, true, 1)
		for i in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/screenshots/shadows-%02dh%02d.png" % [int(hour), int(fmod(hour, 1.0) * 60)])
	quit()
