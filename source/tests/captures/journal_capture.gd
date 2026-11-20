extends SceneTree
## The Talk tab with its tones and favours, and the journal's People page. Writes talk_tones.png
## and journal.png to SOLO_SHEET_DIR.
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
	s.tick = 14400 + 10 * 600
	var npc: Dictionary = {}
	for candidate in s.residents.values():
		if candidate.occupation not in ["Sheriff", "Child", "Trader"]: npc = candidate; break
	npc.sleeping = {}
	s.entities[str(s.player)].cell = [s.entities[str(npc.id)].cell[0] + 1, s.entities[str(npc.id)].cell[1]]
	var Context = load("res://sim/player/context_actions.gd")
	Context.perform(sim, int(npc.id), "talk")
	Context.perform(sim, int(npc.id), "say_friendly")
	for settle in range(12): await process_frame
	main.clock.paused = true
	for settle in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("talk_tones.png"))
	main.player_panels.show_mode("")
	Context.perform(sim, int(npc.id), "ask_news")
	main.journal.toggle()
	for settle in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("journal.png"))
	quit(0)
