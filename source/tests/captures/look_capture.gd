extends SceneTree
## The player clean and shaved beside the same player after a rough week: beard, dust and blood.
## Writes look_clean.png and look_rough.png to SOLO_SHEET_DIR.
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
	var s: Dictionary = main.simulation.state
	s.tick = 14400 + 12 * 600
	var start: Array = s.entities[str(s.player)].cell
	s.entities[str(s.player)].cell = [start[0] + 4, start[1] + 6]   # clear of the villagers at the lodge door
	main.get_node("WorldView").snap_visuals()
	main.get_node("ObserverCamera").zoom = Vector2.ONE * 4.0
	for settle in range(40): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("look_clean.png"))
	var look: Dictionary = load("res://sim/player/look.gd").of(s)
	look.beard = 80; look.dirt = 90; look.blood = 50
	for settle in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("look_rough.png"))
	quit(0)
