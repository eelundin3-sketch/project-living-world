extends SceneTree
func _initialize() -> void: call_deferred("run")
func shot(main: Node, name: String, center: Vector2, zoom: float) -> void:
	var camera: Camera2D = main.get_node("ObserverCamera")
	camera.position = center; camera.zoom = Vector2(zoom, zoom)
	main.get_node("WorldView").snap_visuals(); main.refresh_view()
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/%s.png" % name)
func run() -> void:
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); root.size = Vector2i(1280, 720); main.set_process(false)
	var sim = main.simulation; var s: Dictionary = sim.state
	for tick in range(300): sim.step()
	var rock: Dictionary = {}
	for e in s.entities.values():
		if e.kind == "ore" and e.get("big", false): rock = e
	s.entities[str(s.player)].cell = [167, 131]
	main.get_node("WorldView").snap_visuals()
	await shot(main, "iron-rock", Vector2(171, 130) * 24.0, 1.5)
	main.selected_id = rock.id
	main._open_context_menu(rock.id, Vector2(760, 330))
	await shot(main, "context-menu-rock", Vector2(171, 130) * 24.0, 1.5)
	main.context_menu.close()
	# a knocked-out villager
	var npc: Dictionary = {}
	for n in s.residents.values():
		if n.settlement == 3: npc = n; break
	var Brawl = load("res://sim/combat/brawl.gd")
	s.entities[str(npc.id)].cell = [120, 133]; s.entities[str(s.player)].cell = [118, 133]
	Brawl.knockdown(s, npc, [120, 133], "ko", [1000, 0])
	for i in range(30): sim.step()
	main.get_node("WorldView").snap_visuals()
	main.selected_id = npc.id
	await shot(main, "context-menu-person", Vector2(120, 131) * 24.0, 2.2)
	main._open_context_menu(npc.id, Vector2(700, 300))
	await shot(main, "context-menu-person", Vector2(120, 131) * 24.0, 2.2)
	quit()
