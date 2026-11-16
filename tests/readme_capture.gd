extends SceneTree
## README images: a daytime view of Alder Hollow, and a sheriff on his rounds.
func _initialize() -> void: call_deferred("run")
func frame_and_save(main: Node, name: String) -> void:
	main.refresh_view()
	for i in range(3):
		main.get_node("WorldView").animate(0.016, false, 1)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/%s.png" % name)
func run() -> void:
	root.size = Vector2i(1600, 900)
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); main.set_process(false)
	var sim = main.simulation; var s: Dictionary = sim.state
	for t in range(5800): sim.step()   # into the morning: people at work, low sun
	s.weather = {"kind": "clear"}
	main.follow_player = false
	var camera = main.get_node("ObserverCamera")
	camera.zoom = Vector2.ONE * 0.95
	camera.position = Vector2(64, 50) * 24
	for i in range(30): main.get_node("WorldView").animate(0.05, false, 1); await process_frame
	await frame_and_save(main, "hero-day")
	var sheriff: Dictionary = {}
	for npc in s.residents.values():
		if npc.occupation == "Sheriff" and npc.settlement == 1: sheriff = npc
	if not sheriff.is_empty():
		camera.zoom = Vector2.ONE * 2.4
		for i in range(10): main.get_node("WorldView").animate(0.05, false, 1); await process_frame
		camera.position = main.get_node("WorldView").motion.actors.get(str(sheriff.id), {}).get("position", Vector2(s.entities[str(sheriff.id)].cell[0], s.entities[str(sheriff.id)].cell[1]) * 24)
		await frame_and_save(main, "sheriff-in-town")
	quit()
