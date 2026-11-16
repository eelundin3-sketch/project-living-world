extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var scene := load("res://app/main.tscn") as PackedScene
	var main := scene.instantiate()
	root.add_child(main)
	root.size = Vector2i(1280, 720)
	main.set_process(false)
	for tick in range(1600):
		main.simulation.step()
	main.selected_id = main.simulation.state.workshops.values()[0].id
	main.get_node("WorldView").snap_visuals()
	main.refresh_view()
	for frame in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("res://docs/screenshots/game.png")
	print("Render capture: ", error)
	var Nav = preload("res://sim/movement/navigation.gd")
	var s: Dictionary = main.simulation.state
	var house: Dictionary = s.entities[str(s.home)]
	var route: Dictionary = Nav.request_path(s, s.entities[str(s.player)].cell, [house.cell[0], house.cell[1] - 2])
	if route.ok:
		for cell in route.path:
			var current: Array = s.entities[str(s.player)].cell
			main.simulation.submit("move_player", {"direction": [cell[0] - current[0], cell[1] - current[1]]})
			main.simulation.step()
		main.get_node("WorldView").snap_visuals()
		main.selected_id = s.home
		main.get_node("ObserverCamera").position = Vector2(house.cell[0], house.cell[1] - 1) * 24
		main.get_node("ObserverCamera").zoom = Vector2.ONE * 1.3
		main.refresh_view()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/screenshots/interior.png")
	main.queue_free()
	await process_frame
	quit(error)
