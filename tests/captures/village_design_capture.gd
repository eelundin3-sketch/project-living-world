extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	root.size = Vector2i(1280, 720)
	main.set_process(false)
	for tick in range(5000): main.simulation.step()
	main.get_node("DebugHUD").hide()
	main.get_node("WorldView").selected_id = 0
	main.get_node("WorldView").snap_visuals()
	main.get_node("ObserverCamera").position = Vector2(65, 49) * 24
	main.get_node("ObserverCamera").zoom = Vector2.ONE * 0.65
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/village-design.png")
	var camera := main.get_node("ObserverCamera") as Camera2D
	camera.position = Vector2(120, 45) * 24
	camera.zoom = Vector2.ONE * 0.27
	camera.force_update_scroll()
	main.get_node("WorldView").snap_visuals()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/world-landscape.png")
	var s: Dictionary = main.simulation.state
	var house: Dictionary = s.entities[str(s.home)]
	s.entities[str(s.player)].cell = [house.cell[0],house.cell[1]-2]
	var footprint: Array = house.footprint
	camera.position = (Vector2(footprint[0], footprint[1]) + Vector2(footprint[2] - 1, footprint[3] - 1) * 0.5) * 24.0
	camera.zoom = Vector2.ONE * 1.72
	camera.force_update_scroll()
	main.get_node("WorldView").snap_visuals()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/room-design.png")
	main.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit()
