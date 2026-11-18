extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main)
	await process_frame
	main.set_process(false)
	main.simulation.state.tick = 14400 + 600 * 10
	main.toggle_map()
	main.get_node("ObserverCamera").zoom = Vector2.ONE * 0.14
	main.get_node("ObserverCamera").position = Vector2(125, 120) * 24
	main.map_overlay.set_waypoint(Vector2(364, 55) * 24)
	main.refresh_view()
	for i in range(8):
		main.get_node("WorldView").animate(0.1, true, 1)
		main.map_overlay.state = main.simulation.state; main.map_overlay.active = true; main.map_overlay.zoom = 0.14
		main.map_overlay.player_world = Vector2(64, 49) * 24
		main.map_overlay.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/map-screen.png")
	quit()
