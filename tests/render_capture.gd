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
	main.refresh_view()
	for frame in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("res://docs/screenshots/game.png")
	print("Render capture: ", error)
	main.queue_free()
	await process_frame
	quit(error)
