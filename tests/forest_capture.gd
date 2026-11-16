extends SceneTree
## Wide views of the new woodland around Alder Hollow, morning and afternoon light.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); main.set_process(false)
	var sim = main.simulation; var s: Dictionary = sim.state
	main.get_node("ObserverCamera").adjust_zoom(0.42)
	for hour in [8.0, 16.0]:
		s.tick = int(hour * 600.0) + 14400
		s.weather = {"kind": "clear"}
		main.refresh_view()
		main.get_node("WorldView").animate(0.016, true, 1)
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/screenshots/forest-%02dh.png" % int(hour))
	main.get_node("ObserverCamera").adjust_zoom(0.55)
	main.refresh_view()
	main.get_node("WorldView").animate(0.016, true, 1)
	await process_frame
	main.get_node("WorldView").animate(0.016, true, 1)
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/forest-overview.png")
	quit()
