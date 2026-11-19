extends SceneTree
## Captures an animation sequence with the live vector character renderer.
const Character = preload("res://view/actors/drawn_character.gd")
const Director = preload("res://view/actors/animation_director.gd")
const FPS := 30.0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var folder := OS.get_environment("SOLO_MOTION_FRAMES")
	if folder.is_empty():
		printerr("Set SOLO_MOTION_FRAMES to an output folder.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	var stage := SubViewport.new()
	stage.size = Vector2i(720, 320)
	stage.world_2d = World2D.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(stage)
	var background := ColorRect.new()
	background.color = Color("bda67d")
	background.size = Vector2(720, 320)
	stage.add_child(background)
	var runner := Character.new()
	var worker := Character.new()
	stage.add_child(runner)
	stage.add_child(worker)
	for row in [0, 1]:
		var guide := ColorRect.new()
		guide.position = Vector2(18, 145 + row * 154)
		guide.size = Vector2(684, 1)
		guide.color = Color("a48b62")
		stage.add_child(guide)
		var caption := Label.new()
		caption.text = "IDLE  /  WALK  /  SPRINT  /  WALK  /  IDLE" if row == 0 else "CHOP  /  PICK UP  /  CARRY  /  SET DOWN"
		caption.position = Vector2(18, 155 + row * 151)
		caption.add_theme_color_override("font_color", Color("584737"))
		caption.add_theme_font_size_override("font_size", 12)
		stage.add_child(caption)
	runner.setup(0, true, false)
	worker.setup(2, false, false)
	runner.scale = Vector2.ONE * 1.5
	worker.scale = Vector2.ONE * 1.5
	var x := 83.0
	var gait := 0.0
	var sprint := 0.0
	var speed := 0.0
	for index in range(135):
		var time := index / FPS
		var feet := "idle"
		if time >= 0.4 and time < 1.25 or time >= 2.50 and time < 3.20:
			feet = "walk"
		elif time >= 1.25 and time < 2.50:
			feet = "run"
		sprint = move_toward(sprint, 1.0 if feet == "run" else 0.0, 3.5 / FPS)
		speed = move_toward(speed, 10.0 if feet == "run" else (5.0 if feet == "walk" else 0.0), 20.0 / FPS)
		var meters_per_second := speed
		x += meters_per_second * Director.CELL / FPS
		gait += meters_per_second / FPS / lerpf(Director.WALK_CYCLE_METERS, Director.RUN_CYCLE_METERS, sprint)
		runner.set_pose({"position": Vector2(x, 130), "heading": 0.0, "moving": speed > 0.01, "run_blend": sprint,
			"action": feet, "gait_phase": fposmod(gait, 1.0), "move_direction": Vector2.RIGHT}, 1.0 / FPS)
		var job := "idle"
		var phase := 0.0
		if time >= 0.4 and time < 1.6:
			job = "chop"
			phase = (time - 0.4) / 1.2
		elif time >= 1.6 and time < 2.4:
			job = "pickup"
			phase = (time - 1.6) / 0.8
		elif time >= 2.4 and time < 3.2:
			job = "carry"
			phase = (time - 2.4) / 0.8
		elif time >= 3.2 and time < 4.0:
			job = "drop"
			phase = (time - 3.2) / 0.8
		var offset := clampf(time - 2.4, 0, 0.8) * 165.0
		worker.set_pose({"position": Vector2(122 + offset, 284), "heading": 0.16,
			"action": job, "phase": phase, "moving": job == "carry", "gait_phase": fposmod(offset / 48.0, 1.0),
			"cargo_item": "log", "cargo_quantity": 2 if job in ["pickup", "carry", "drop"] else 0}, 1.0 / FPS)
		await RenderingServer.frame_post_draw
		var result := stage.get_texture().get_image().save_png(folder.path_join("%03d.png" % index))
		if result != OK:
			quit(result)
			return
	quit()
