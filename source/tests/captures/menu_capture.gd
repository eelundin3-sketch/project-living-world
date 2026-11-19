extends SceneTree
## The title screen over the drifting map, the options placeholder, and the zoom onto the player.
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/%s.png" % name)
func run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://app/main.tscn")
	for i in range(40): await process_frame
	var main = current_scene
	print("menu active: ", main.menu_active)
	await shot("menu-title")
	main.menu.options_panel.visible = true
	for i in range(3): await process_frame
	await shot("menu-options")
	main.menu.options_panel.visible = false
	main.menu._on_pressed("start")
	for i in range(80): await process_frame
	await shot("menu-zooming")
	var deadline := Time.get_ticks_msec() + 9000
	while main.menu_active and Time.get_ticks_msec() < deadline: await process_frame
	for i in range(10): await process_frame
	print("menu active after intro: ", main.menu_active, " follow: ", main.follow_player)
	await shot("menu-landed")
	quit()
