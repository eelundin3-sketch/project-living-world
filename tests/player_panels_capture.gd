extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main=load("res://app/main.tscn").instantiate(); root.add_child(main); root.size=Vector2i(1280,720); main.set_process(false)
	main.simulation.submit("debug_injury",{"part":"right_forearm","damage":32,"kind":"cut"}); main.simulation.step()
	main.simulation.submit("treat_body",{"part":"right_forearm","action":"bandage"}); main.simulation.step()
	for tick in range(1350): main.simulation.step()
	main.simulation.submit("debug_injury",{"part":"left_hand","damage":20,"kind":"cut"}); main.simulation.step()
	main.simulation.submit("debug_injury",{"part":"left_shin","damage":28,"kind":"sprain"}); main.simulation.step()
	main.simulation.submit("treat_body",{"part":"left_hand","action":"bandage"}); main.simulation.step()
	for tick in range(35): main.simulation.step()
	main.get_node("WorldView").snap_visuals(); main.refresh_view()
	main.player_panels.show_mode("health"); main.player_panels.select_part("right_forearm")
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/player-health.png")
	main.player_panels.show_mode("inventory")
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/player-inventory.png")
	main.queue_free(); await process_frame; await create_timer(0.2).timeout; quit()
