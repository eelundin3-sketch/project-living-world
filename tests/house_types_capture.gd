extends SceneTree
## Every house type, built side by side in open ground, for review.
const Housing = preload("res://sim/settlement/housing.gd")
const World = preload("res://sim/world/world_db.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600, 900)
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); main.set_process(false)
	var sim = main.simulation; var s: Dictionary = sim.state
	s.tick = 14400 + 600 * 11
	s.weather = {"kind": "clear"}
	var x := -80
	var row := 0
	var placed := 0
	for entry in Housing.TYPES:
		var cell: Array = [x + int(entry.size[0]) / 2, -50 + row * 22]
		World.add_entity(sim, "home", entry.name, cell, 1, Housing.house_fields(entry))
		x += int(entry.size[0]) + 4
		placed += 1
		if placed == 7:
			x = -80
			row += 1
	main.follow_player = false
	var camera = main.get_node("ObserverCamera")
	camera.position = Vector2(-28, -52) * 24; camera.zoom = Vector2.ONE * 0.62
	main.refresh_view()
	for i in range(8):
		main.get_node("WorldView").animate(0.1, true, 1)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/house-types.png")
	quit()
