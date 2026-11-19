extends SceneTree
## The market tents (one per seller) and the trader walking the road with her pack.
func _initialize() -> void: call_deferred("run")
func shot(main: Node, at: Vector2, zoom: float, name: String) -> void:
	var camera = main.get_node("ObserverCamera")
	camera.position = at; camera.zoom = Vector2.ONE * zoom
	main.refresh_view()
	for i in range(8):
		main.get_node("WorldView").animate(0.05, false, 1)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/%s.png" % name)
func run() -> void:
	root.size = Vector2i(1600, 900)
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); main.set_process(false)
	var sim = main.simulation; var s: Dictionary = sim.state
	main.follow_player = false
	for t in range(6200): sim.step()
	s.weather = {"kind": "clear"}
	var store: Array = s.entities[str(s.settlements["1"].warehouse)].cell
	await shot(main, Vector2(store[0], store[1] + 13) * 24, 1.0, "market-tents")
	for trip in s.caravans.values():
		var at: Vector2 = main.get_node("WorldView").motion.actors.get(str(trip.id), {}).get("position", Vector2(s.entities[str(trip.id)].cell[0], s.entities[str(trip.id)].cell[1]) * 24)
		await shot(main, at, 2.2, "trader-on-the-road")
		break
	quit()
