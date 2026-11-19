extends SceneTree
## Screenshots of the drawn map: the whole map as it opens, and zoomed in on Alder Hollow.
## Writes map_full.png and map_zoom.png to SOLO_SHEET_DIR.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var out := OS.get_environment("SOLO_SHEET_DIR")
	if out.is_empty(): out = OS.get_temp_dir()
	var main: Node = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	for warm in range(5): await process_frame
	main.menu_active = false
	if main.menu != null: main.menu.visible = false
	main.toggle_map()
	for settle in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("map_full.png"))
	var s: Dictionary = main.simulation.state
	var store: Array = s.entities[str(s.warehouse)].cell
	main.medieval_map.zoom_at(main.medieval_map.screen_of(Vector2(store[0], store[1]) * 24.0), 3.2)
	for settle in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("map_zoom.png"))
	quit(0)
