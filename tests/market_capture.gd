extends SceneTree
## Capture a live market after the sawyer's first physical delivery.
const Inventory = preload("res://sim/inventory/inventory_store.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main := (load("res://app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	main.set_process(false)
	main.get_node("DebugHUD").hide()
	var sim: RefCounted = main.simulation
	var state: Dictionary = sim.state
	var stall: int = state.settlements["1"].stalls[0]
	for step in range(8000):
		sim.step()
		if Inventory.amount(state, stall, "plank") > 0: break
	if Inventory.amount(state, stall, "plank") == 0:
		printerr("No delivery reached the timber stall.")
		quit(1)
		return
	var camera := main.get_node("ObserverCamera") as Camera2D
	camera.position = Vector2(66, 46) * 24
	camera.zoom = Vector2.ONE * 0.92
	camera.force_update_scroll()
	var view := main.get_node("WorldView")
	view.selected_id = 0
	view.snap_visuals()
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://docs/screenshots/market-stalls.png")
	main.queue_free()
	await process_frame
	quit(result)
