extends SceneTree
## A close-up review of the actual in-game drawing, with real clothing and action poses.
const Character = preload("res://view/actors/drawn_character.gd")
const Outfits = preload("res://sim/entities/outfits.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var bg := ColorRect.new()
	bg.color = Color("e1d4b8")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	_label("THE FRONTIER TRAVELLER", Vector2(38, 27), 26)
	_label("Character detail  /  drawn directly by the game", Vector2(40, 64), 16)
	var divider := ColorRect.new()
	divider.color = Color("c4b18b")
	divider.position = Vector2(620, 117)
	divider.size = Vector2(1, 540)
	root.add_child(divider)
	_figure(Vector2(170, 620), PI / 2, "idle", 5.7, "Front", 0)
	_figure(Vector2(450, 620), PI / 4, "idle", 5.7, "Three-quarter", 0)
	_figure(Vector2(785, 355), 0.0, "run", 2.9, "Sprint", 0)
	_figure(Vector2(1080, 355), PI / 4, "gun_carry", 2.9, "Shotgun carried low", 0)
	_figure(Vector2(785, 645), PI / 4, "carry", 2.9, "Villager / carry", 1)
	_figure(Vector2(1080, 645), PI / 4, "chop", 2.9, "Villager / work", 2)
	await process_frame
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("SOLO_CHARACTER_DETAIL")
	if path.is_empty(): path = "res://docs/screenshots/character-detail.png"
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		quit(result)
		return
	for child in root.get_children(): child.queue_free()
	await process_frame
	var main := (load("res://app/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	main.set_process(false)
	main.world_audio.enabled = false
	main.get_node("DebugHUD").hide()
	for tick in range(4600): main.simulation.step()
	main.refresh_view()
	var world := main.get_node("WorldView")
	world.snap_visuals()
	world.animate(0, true, 1)
	var player: Dictionary = world.motion.actors[str(main.simulation.state.player)]
	var camera := main.get_node("ObserverCamera") as Camera2D
	camera.zoom = Vector2.ONE * 3.0
	camera.position = player.position + Vector2(0, -18)
	camera.force_update_scroll()
	world.animate(0, true, 1)
	await process_frame
	await RenderingServer.frame_post_draw
	result = root.get_texture().get_image().save_png("res://docs/screenshots/character-gameplay.png")
	main.queue_free()
	await process_frame
	quit(result)

func _figure(at: Vector2, angle: float, action: String, magnification: float, title: String, id: int) -> void:
	var figure := Character.new()
	root.add_child(figure)
	figure.setup(id, id == 0, false)
	figure.scale = Vector2.ONE * magnification
	figure.set_pose({"position": at, "heading": angle, "action": action, "phase": 0.43,
		"moving": action in ["run", "carry", "gun_carry"], "gait_phase": 0.48 if action == "run" else 0.17,
		"run_blend": 1.0 if action == "run" else 0.0, "outfit": Outfits.default_for(id, id == 0),
		"cargo_item": "log", "cargo_quantity": 3 if action == "carry" else 0})
	_label(title, at + Vector2(-75, 23), 16)

func _label(value: String, at: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("574730"))
	root.add_child(label)
