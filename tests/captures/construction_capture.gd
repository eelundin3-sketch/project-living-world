extends SceneTree
## Render the active construction site after real warehouse-to-site deliveries.
const Planner = preload("res://sim/settlement/planner.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const World = preload("res://sim/world/world_db.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := load("res://app/main.tscn") as PackedScene
	var main := scene.instantiate()
	root.add_child(main)
	root.size = Vector2i(1280, 720)
	main.set_process(false)
	main.get_node("DebugHUD").hide()
	var sim: RefCounted = main.simulation
	var s: Dictionary = sim.state
	var id := Planner.plan(sim, 1, "core:building/home")
	if id == 0:
		quit(1)
		return
	var site: Dictionary = s.construction[str(id)]
	Inventory.produce(s, s.warehouse, "plank", site.cost)
	for step in range(12000):
		sim.step()
		if site.built_tiles.walls.size() >= 8 and site.tile_work == 6: break
	if site.tile_work != 6:
		printerr("Construction capture did not reach a partial wall: ", site.status, " (", site.progress, " tiles)")
		quit(2)
		return
	var plot := World.plot_rect(s.entities[str(id)], "home")
	var camera := main.get_node("ObserverCamera") as Camera2D
	camera.position = (Vector2(plot.get_center()) + Vector2(0, -1.25)) * 24.0
	camera.zoom = Vector2.ONE * 1.4
	camera.force_update_scroll()
	var view := main.get_node("WorldView")
	view.selected_id = 0
	view.snap_visuals()
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://docs/screenshots/construction-progress.png")
	main.queue_free()
	await process_frame
	quit(result)
