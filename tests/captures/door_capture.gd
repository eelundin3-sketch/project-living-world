extends SceneTree
## Houses turned four ways with their doors shut, and one with someone at the door.
const Housing = preload("res://sim/settlement/housing.gd")
const World = preload("res://sim/world/world_db.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); main.set_process(false)
	var sim = main.simulation; var s: Dictionary = sim.state
	s.tick = 14400 + 600 * 11
	s.world.bounds = [-2000, -2000, 2000, 2000]
	var entry: Dictionary = Housing.type_by_id("two_room")
	var entries: Array = [Housing.type_by_id("cottage"), Housing.type_by_id("farmhouse"), Housing.type_by_id("saltbox"), Housing.type_by_id("two_room")]
	for i in range(4):
		var cell: Array = [600 + i * 22, 640]
		World.add_entity(sim, "home", "House %d" % i, cell, 1, Housing.placed_fields(entries[i], cell, i))
	# A villager stands at the door of the first.
	var walker: Dictionary = {}
	for npc in s.residents.values(): walker = npc; break
	s.entities[str(walker.id)].cell = [600, 642]
	s.entities[str(s.player)].cell = [680, 660]
	main.follow_player = false
	var camera = main.get_node("ObserverCamera")
	camera.position = Vector2(633, 636) * 24; camera.zoom = Vector2.ONE * 0.62
	main.refresh_view()
	for i in range(14):
		main.get_node("WorldView").animate(0.1, true, 1)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/doors.png")
	quit()
