extends SceneTree
## Capture the same vector characters drawn in the live world.
const Character = preload("res://view/actors/drawn_character.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var background := ColorRect.new()
	background.color = Color("bd9e69")
	background.size = Vector2(1280, 720)
	root.add_child(background)
	var headings: Array[float] = [PI / 2.0, PI / 4.0, 0.0, -PI / 4.0, -PI / 2.0, -3.0 * PI / 4.0, PI, 3.0 * PI / 4.0]
	var names := ["Down", "Down + right", "Right", "Up + right", "Up", "Up + left", "Left", "Down + left"]
	for i in range(headings.size()):
		_add_figure(Vector2(78 + i * 160, 306), headings[i], "idle", names[i])
	var actions := ["walk", "run", "aim", "chop", "carry", "punch", "down"]
	for i in range(actions.size()):
		var anchor := Vector2(95 + i * 181, 625)
		if actions[i] == "down": anchor += Vector2(-63, -27)
		_add_figure(anchor, 0.0 if i % 2 == 0 else 0.6, actions[i], actions[i].capitalize())
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("SOLO_CHARACTER_CAPTURE")
	if path.is_empty():
		path = "res://docs/screenshots/character-design.png"
	quit(root.get_texture().get_image().save_png(path))

func _add_figure(anchor: Vector2, angle: float, action: String, caption: String) -> void:
	var figure := Character.new()
	root.add_child(figure)
	figure.setup(0, true, false)
	figure.scale = Vector2.ONE * 3.0
	figure.set_pose({
		"position": anchor, "heading": angle, "action": action,
		"moving": action in ["walk", "run", "carry"], "gait_phase": 0.17,
		"phase": 0.43, "run_blend": 1.0 if action == "run" else 0.0, "cargo_item": "log" if action == "carry" else "",
		"cargo_quantity": 3 if action == "carry" else 0,
	})
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = anchor + Vector2(-76, 50 if action == "down" else 23)
	label.size.x = 152
	label.add_theme_color_override("font_color", Color("392b1d"))
	label.add_theme_font_size_override("font_size", 13)
	root.add_child(label)
