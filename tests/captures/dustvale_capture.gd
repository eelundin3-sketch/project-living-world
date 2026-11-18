extends SceneTree
func _initialize() -> void: call_deferred("run")
func shot(main: Node, name: String, center: Vector2, zoom: float) -> void:
	var camera: Camera2D = main.get_node("ObserverCamera")
	camera.position = center; camera.zoom = Vector2(zoom, zoom)
	main.get_node("WorldView").snap_visuals(); main.refresh_view()
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/%s.png" % name)
func run() -> void:
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); root.size = Vector2i(1280, 720); main.set_process(false)
	var sim = main.simulation; var s: Dictionary = sim.state
	for tick in range(2500): sim.step()
	await shot(main, "dustvale-town", Vector2(122, 124) * 24.0, 0.8)
	await shot(main, "dustvale-street", Vector2(118, 130) * 24.0, 1.6)
	var lodge: Dictionary = s.entities[str(s.settlements["3"].home)]
	await shot(main, "dustvale-lodge", Vector2(lodge.cell[0], lodge.cell[1] - 6) * 24.0, 1.6)
	main.toggle_map()
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/map-three-towns.png")
	quit()
