extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); root.size = Vector2i(1280, 720); main.set_process(false)
	var sim = main.simulation; var s: Dictionary = sim.state
	for tick in range(14400 + 600): sim.step()
	var Inv = load("res://sim/inventory/inventory_store.gd")
	var office: int = 0
	for e in s.entities.values():
		if e.kind == "office" and e.settlement == 1: office = e.id
	Inv.transfer(s, office, s.player, "shotgun", 1); Inv.transfer(s, office, s.player, "shell", 12)
	sim.submit("hotbar_assign", {"slot": 0, "item": "shotgun"}); sim.submit("hotbar_assign", {"slot": 1, "item": "shell"}); sim.submit("hotbar_assign", {"slot": 2, "item": "food"}); sim.submit("hotbar_assign", {"slot": 3, "item": "bandage"})
	sim.step(); sim.submit("hotbar_use", {"slot": 0}); sim.step()
	var store: Array = s.entities[str(s.warehouse)].cell
	var cam: Camera2D = main.get_node("ObserverCamera"); cam.position = Vector2(store[0], 53) * 24.0; cam.zoom = Vector2(0.85, 0.85)
	main.get_node("WorldView").snap_visuals(); main.refresh_view(); main.bottom_bar.queue_redraw()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/bottom-bar.png")
	main.player_panels.show_mode("inventory")
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/inventory-hotbar.png")
	cam.zoom = Vector2(0.18, 0.18); main.player_panels.show_mode("")
	main.get_node("WorldView").snap_visuals()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/world-overview.png")
	main.queue_free(); await process_frame; await create_timer(0.2).timeout; quit()
