extends SceneTree
## Capture normal gameplay after observing each action in the live simulation.
const Director = preload("res://view/actors/animation_director.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const World = preload("res://sim/world/world_db.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main := (load("res://app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	root.size = Vector2i(1280, 720)
	main.set_process(false)
	main.get_node("DebugHUD").hide()
	var sim: RefCounted = main.simulation
	var state: Dictionary = sim.state
	var stall: int = state.settlements["1"].stalls[0]
	var captured := {}
	for tick in range(11500):
		sim.step()
		if state.tick < 4600: continue
		if not captured.has("forest-harvest"):
			for npc in state.residents.values():
				if npc.settlement != 1 or npc.job == 0: continue
				var actor: Dictionary = state.entities[str(npc.id)]
				var action := Director.action_for(state, actor)
				if action.action != "chop": continue
				var tree: Dictionary = state.entities[str(action.target)]
				if actor.cell[1] != tree.cell[1] and state.tick < 8500: continue
				var center := Vector2(tree.cell[0], tree.cell[1]) * 24 - Vector2(0, 34)
				captured["forest-harvest"] = await _capture(main, "forest-harvest", center, 1.85, 0.33)
				break
		if not captured.has("workshop-production"):
			for shop in state.workshops.values():
				if shop.settlement != 1 or not shop.active or shop.progress < 6: continue
				var mill: Dictionary = state.entities[str(shop.id)]
				var saw: Array = mill.fixtures[0].rect
				var center := Vector2(saw[0] + 1.6, saw[1] + 3) * 24
				captured["workshop-production"] = await _capture(main, "workshop-production", center, 1.6, 0.28)
				break
		if not captured.has("market-trading") and Inventory.amount(state, stall, "plank") > 0:
			var approach := World.Fixtures.interaction_cell(state, stall)
			state.entities[str(state.player)].cell = approach.duplicate()
			sim.submit("interact", {"target": stall})
			sim.step()
			main.refresh_view()
			if main.player_panels.visible and main.player_panels.target == stall:
				captured["market-trading"] = await _capture(main, "market-trading", Vector2(64, 45) * 24, 0.72)
			main.player_panels.show_mode("")
		if captured.size() == 3: break
	main.queue_free()
	await process_frame
	print("Gameplay screenshots: ", captured)
	quit(0 if captured.size() == 3 and not captured.values().has(false) else 1)

func _capture(main: Node, file_name: String, center: Vector2, zoom: float, animation_seconds: float = 0.0) -> bool:
	var camera := main.get_node("ObserverCamera") as Camera2D
	camera.position = center
	camera.zoom = Vector2.ONE * zoom
	camera.force_update_scroll()
	var view := main.get_node("WorldView")
	view.selected_id = 0
	view.snap_visuals()
	view.animate(0.0, true, 1)
	for i in range(roundi(animation_seconds * 60)):
		view.animate(1.0 / 60.0, false, 1)
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png("res://docs/screenshots/%s.png" % file_name) == OK
