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
	s.world.bounds = [-2000, -2000, 2000, 2000]
	var x := 500
	var row := 0
	var placed := 0
	for entry in Housing.TYPES.slice(0, 21):
		# Each type is shown turned a different way, so every door side appears.
		var side: int = (placed + row) % 4
		var span: int = maxi(int(entry.size[0]), int(entry.size[1]))
		var cell: Array = [x + span / 2, 600 + row * 26 + span / 2]
		if side == 0: cell = [x + span / 2, 600 + row * 26]
		World.add_entity(sim, "home", entry.name, cell, 1, Housing.placed_fields(entry, cell, side))
		x += span + 4
		placed += 1
		if placed == 7:
			x = 500
			row += 1
			placed = 0
	main.follow_player = false
	var camera = main.get_node("ObserverCamera")
	camera.position = Vector2(575, 628) * 24; camera.zoom = Vector2.ONE * 0.42
	main.refresh_view()
	for i in range(8):
		main.get_node("WorldView").animate(0.1, true, 1)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/house-types.png")
	quit()
