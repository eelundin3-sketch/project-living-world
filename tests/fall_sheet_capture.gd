extends SceneTree
## Fall review sheets: falling forward and getting back up in each of the eight directions.
const Character = preload("res://view/actors/drawn_character.gd")
const DIRECTIONS := [["down", PI / 2.0], ["down-right", PI / 4.0], ["right", 0.0], ["up-right", -PI / 4.0], ["up", -PI / 2.0], ["up-left", -3.0 * PI / 4.0], ["left", PI], ["down-left", 3.0 * PI / 4.0]]
func _initialize() -> void: call_deferred("run")
func sheet(action_steps: Array, path: String, name: String) -> void:
	var holder := Node2D.new(); root.add_child(holder)
	var bg := ColorRect.new(); bg.color = Color("a8905f"); bg.size = Vector2(1600, 900); holder.add_child(bg)
	var title := Label.new(); title.text = name; title.position = Vector2(8, 4); title.add_theme_color_override("font_color", Color("2a1d12")); holder.add_child(title)
	for r in range(DIRECTIONS.size()):
		var label := Label.new(); label.text = DIRECTIONS[r][0]; label.position = Vector2(8, 50 + r * 104); label.add_theme_color_override("font_color", Color("2a1d12")); holder.add_child(label)
		for i in range(action_steps.size()):
			var figure := Character.new(); holder.add_child(figure); figure.setup(0, true, false)
			figure.scale = Vector2.ONE * 0.95
			figure.position = Vector2(140 + i * 150, 86 + r * 104)
			figure.set_pose({"position": figure.position, "heading": DIRECTIONS[r][1], "action": action_steps[i][0], "phase": action_steps[i][1], "moving": false, "fall_side": 1, "age": 0.0})
			figure.position = Vector2(140 + i * 150, 86 + r * 104)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	holder.queue_free()
	await process_frame
func run() -> void:
	root.size = Vector2i(1600, 900)
	await sheet([["fall", 0.0], ["fall", 0.14], ["fall", 0.28], ["fall", 0.42], ["fall", 0.52], ["fall", 0.62], ["fall", 0.72], ["fall", 0.85], ["down", 0.0]], "res://docs/screenshots/animation-falls.png", "FALL FORWARD")
	await sheet([["down", 0.0], ["getup", 0.14], ["getup", 0.3], ["getup", 0.46], ["getup", 0.6], ["getup", 0.74], ["getup", 0.88], ["getup", 1.0], ["getup", 0.95]], "res://docs/screenshots/animation-getup.png", "GET UP")
	quit()
