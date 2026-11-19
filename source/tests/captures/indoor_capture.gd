extends SceneTree
## Inside the common lodge at noon, with the player standing in it: no sun shadows on the floor.
## Writes indoor_noon.png to SOLO_SHEET_DIR.
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
	var lodge: Dictionary = s.entities[str(s.home)]
	var World = load("res://sim/world/world_db.gd")
	var rect: Rect2i = World.building_rect(lodge)
	var inside: Array = []
	for y in range(rect.position.y + 2, rect.end.y - 2):
		for x in range(rect.position.x + 2, rect.end.x - 2):
			if inside.is_empty() and World.walkable(s, [x, y]): inside = [x, y]
	s.entities[str(s.player)].cell = inside
	main.get_node("ObserverCamera").zoom = Vector2.ONE * 2.0
	main.get_node("WorldView").snap_visuals()
	main.clock.paused = true
	for settle in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("indoor_noon.png"))
	quit(0)
