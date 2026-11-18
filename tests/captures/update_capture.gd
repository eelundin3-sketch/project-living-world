extends SceneTree
## Captures the features of this update from the running game.
func _initialize() -> void: call_deferred("run")
func shot(main: Node, name: String, center: Vector2, zoom: float) -> void:
	var camera: Camera2D = main.get_node("ObserverCamera")
	camera.position = center
	camera.zoom = Vector2(zoom, zoom)
	main.get_node("WorldView").snap_visuals(); main.refresh_view()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/%s.png" % name)
func run() -> void:
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); root.size = Vector2i(1280, 720); main.set_process(false)
	var sim = main.simulation; var s: Dictionary = sim.state
	for tick in range(14400 + 3000): sim.step()
	var store: Array = s.entities[str(s.warehouse)].cell
	await shot(main, "market-plaza", Vector2(store[0], 53) * 24.0, 1.0)
	var farm: Array = s.entities[str(s.farm)].cell
	await shot(main, "rye-field-in-village", Vector2(farm[0], farm[1]) * 24.0, 1.3)
	var lodge: Dictionary = s.entities[str(s.home)]
	var garden: Dictionary = {}
	for plot in s.crops.values():
		if plot.kind == "garden" and plot.home == s.home: garden = plot
	await shot(main, "household-garden", Vector2(garden.rect[0] + garden.rect[2] / 2.0, garden.rect[1] + 2) * 24.0, 1.5)
	await shot(main, "lodge-beds", Vector2(lodge.cell[0], lodge.cell[1] - 5) * 24.0, 1.4)
	var office: Dictionary = {}
	for e in s.entities.values():
		if e.kind == "office" and e.settlement == 1: office = e
	await shot(main, "sheriff-office", Vector2(office.cell[0], office.cell[1] - 6) * 24.0, 1.4)
	var bakery: Dictionary = {}
	for e in s.entities.values():
		if e.kind == "bakery" and e.settlement == 1: bakery = e
	await shot(main, "bakery", Vector2(bakery.cell[0], bakery.cell[1] - 6) * 24.0, 1.4)
	# Shotgun: take it from the rack, ready it, load it and fire.
	var player: Dictionary = s.entities[str(s.player)]
	player.cell = [store[0] - 2, 58]
	sim.submit("interact", {"target": office.id})
	var Inv = load("res://sim/inventory/inventory_store.gd")
	Inv.transfer(s, office.id, s.player, "shotgun", 1); Inv.transfer(s, office.id, s.player, "shell", 10)
	sim.step()
	await shot(main, "shotgun-slung", Vector2(player.cell[0], player.cell[1]) * 24.0 + Vector2(0, -20), 2.2)
	sim.submit("shotgun_toggle"); sim.step()
	sim.submit("shotgun_reload")
	for i in range(40): sim.step()
	main.get_node("WorldView").motion.player_aiming = true
	main.get_node("WorldView").motion.player_aim_position = Vector2(player.cell[0] + 5, player.cell[1] + 2) * 24.0
	sim.step()
	await shot(main, "shotgun-reload", Vector2(player.cell[0], player.cell[1]) * 24.0 + Vector2(0, -20), 2.2)
	for i in range(60): sim.step()
	main.get_node("WorldView").motion.player_aiming = true
	sim.submit("shotgun_fire", {"direction": [1000, 150]}); sim.step(); sim.step(); sim.step()
	await shot(main, "shotgun-fire", Vector2(player.cell[0] + 3, player.cell[1]) * 24.0 + Vector2(0, -20), 2.0)
	main.queue_free(); await process_frame; await create_timer(0.2).timeout; quit()
