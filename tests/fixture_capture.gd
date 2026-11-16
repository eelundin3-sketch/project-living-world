extends SceneTree
const Art = preload("res://view/world/fixture_art.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	root.size=Vector2i(1280,720)
	main.set_process(false)
	main.get_node("DebugHUD").hide()
	var view = main.get_node("WorldView")
	var camera = main.get_node("ObserverCamera")
	view.selected_id=0
	view.snap_visuals()
	var captured: bool = false
	for tick in range(6000):
		main.simulation.step()
		view.animate(0.1,false,1)
		var s: Dictionary = main.simulation.state
		for workshop in s.workshops.values():
			if workshop.settlement==1 and view.fixture_motion.running.get(str(workshop.id),false):
				var e: Dictionary=s.entities[str(workshop.id)]
				var saw: Array = e.fixtures[0].rect
				camera.position = Vector2(saw[0] + 2, saw[1] + 4) * 24
				camera.zoom = Vector2.ONE * 1.8
				camera.force_update_scroll()
				view._sync_depth_objects()
				view.background.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://docs/screenshots/working-machine.png")
				captured=true
				break
		if captured: break
	var piled: bool = false
	for tick in range(6000):
		main.simulation.step()
		view.animate(0.1,false,1)
		var s: Dictionary=main.simulation.state
		var store: Dictionary=s.entities[str(s.warehouse)]
		for flight in view.fixture_motion.flights:
			if flight.item == "log" and flight.to.is_equal_approx(Art.slot(store, "log")):
				camera.position = Art.slot(store, "log") + Vector2(26, 35)
				camera.zoom = Vector2.ONE * 1.8
				camera.force_update_scroll()
				view._sync_depth_objects()
				view.background.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://docs/screenshots/stockpile-handling.png")
				piled=true
				break
		if piled: break
	print("Fixture demonstration: machine=%s, handling=%s" % [captured,piled])
	main.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	quit(0 if captured and piled else 1)
