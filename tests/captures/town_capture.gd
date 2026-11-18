extends SceneTree
## Towns with varied houses, and the bigger, forested map.
func _initialize() -> void: call_deferred("run")
func view(main: Node, at: Vector2, zoom: float, name: String) -> void:
	printerr("VIEW ", name)
	var camera = main.get_node("ObserverCamera")
	camera.position = at; camera.zoom = Vector2.ONE * zoom
	main.refresh_view()
	var hide: String = OS.get_environment("HIDE")
	for i in range(6):
		for child in main.get_node("WorldView").get_children():
			var cls: String = str(child.get_script().get_global_name()) if child.get_script() != null else child.get_class()
			if hide == "chars" and child.get_script() != null and str(child.get_script().resource_path).ends_with("drawn_character.gd"): child.visible = false
			if hide == "depth" and child.has_method("_draw") and "object_kind" in child: child.visible = false
			if hide.begins_with("kind:") and "object_kind" in child and child.object_kind == hide.substr(5): child.visible = false
			if hide == "decor" and "painter" in child: child.visible = false
		main.get_node("WorldView").animate(0.05, true, 1)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/%s.png" % name)
func run() -> void:
	root.size = Vector2i(1600, 900)
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); main.set_process(false)
	var s: Dictionary = main.simulation.state
	var tag: String = OS.get_environment("TAG")
	s.tick = 14400 + 600 * 10
	s.weather = {"kind": "clear"}
	main.follow_player = false
	if OS.get_environment("NO_SHADOWS") == "1": main.get_node("WorldView").shadows.visible = false
	for key in ["1", "2", "3"]:
		var store: Array = s.entities[str(s.settlements[key].warehouse)].cell
		await view(main, Vector2(store[0], store[1] + 22) * 24, 0.42, "town-%s%s" % [s.settlements[key].name.to_lower().replace(" ", "-"), tag])
	await view(main, Vector2(195, 140) * 24, 0.12, "world-big-map" + tag)
	quit()
