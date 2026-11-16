extends SceneTree
## Screenshots of the health window: injuries listed, and mid-bandage.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); main.set_process(false)
	var sim = main.simulation; var s: Dictionary = sim.state
	for t in range(30): sim.step()
	var Health = load("res://sim/player/body_health.gd")
	Health.injure(s, "left_forearm", 26, "cut")
	Health.injure(s, "head", 22, "bruise")
	Health.injure(s, "upper_torso", 18, "bruise")
	Health.injure(s, "right_shin", 14, "sprain")
	s.player_health.parts.right_shin.bandage = "dirty"
	main.player_panels.show_mode("health")
	main.player_panels.select_part("left_forearm")
	main.refresh_view()
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/health-window.png")
	main.player_panels.health_window.press_action("bandage")
	for t in range(16): sim.step()
	main.refresh_view()
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/health-window-bandaging.png")
	quit()
