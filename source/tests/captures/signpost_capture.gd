extends SceneTree
## A fork in the road with its signpost, close up: the boards point down the roads they name.
## Writes signpost_ways.png to SOLO_SHEET_DIR.
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
	var post: Dictionary = load("res://sim/world/world_db.gd").of_kind(s, "signpost")[0]
	s.entities[str(s.player)].cell = [post.cell[0] - 3, post.cell[1] + 2]
	main.get_node("ObserverCamera").zoom = Vector2.ONE * 3.0
	main.get_node("WorldView").snap_visuals()
	main.clock.paused = true
	for settle in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("signpost_ways.png"))
	print(post.directions)
	quit(0)
