extends SceneTree
## The player carrying a knocked-out villager over the shoulder. Writes carry_body.png to SOLO_SHEET_DIR.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var out := OS.get_environment("SOLO_SHEET_DIR")
	if out.is_empty(): out = OS.get_temp_dir()
	var main: Node = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	for warm in range(5): await process_frame
	main.menu_active = false
	if main.menu != null: main.menu.visible = false
	var sim = main.simulation
	var s: Dictionary = sim.state
	s.tick = 14400 + 12 * 600
	var victim: Dictionary = {}
	for npc in s.residents.values():
		if npc.settlement == 1 and npc.occupation not in ["Sheriff", "Child", "Trader"]: victim = npc; break
	victim.sleeping = {}
	var cell: Array = s.entities[str(s.player)].cell
	s.entities[str(victim.id)].cell = [cell[0] + 1, cell[1]]
	load("res://sim/combat/brawl.gd").knockdown(s, victim, s.entities[str(victim.id)].cell, "ko")
	load("res://sim/player/carrying.gd").pick_up(s, int(victim.id))
	sim.submit("move_player", {"direction": [1, 0]}); sim.step(); sim.step(); sim.step()
	main.get_node("ObserverCamera").zoom = Vector2.ONE * 3.0
	for settle in range(20): await process_frame
	main.clock.paused = true
	for settle in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("carry_body.png"))
	quit(0)
