extends SceneTree
## Fall review sheet: each lying style from the fall, through lying down, to getting back up.
const Character = preload("res://view/actors/drawn_character.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var holder := Node2D.new(); root.add_child(holder)
	var bg := ColorRect.new(); bg.color = Color("a8905f"); bg.size = Vector2(1280, 720); holder.add_child(bg)
	var styles := ["back", "front", "side", "sprawl", "curled", "slump"]
	var steps := [["fall", 0.2], ["fall", 0.55], ["fall", 0.95], ["down", 0.0], ["getup", 0.25], ["getup", 0.55], ["getup", 0.85]]
	for r in range(styles.size()):
		var title := Label.new(); title.text = styles[r]; title.position = Vector2(6, 30 + r * 118); title.add_theme_color_override("font_color", Color("2a1d12")); holder.add_child(title)
		for i in range(steps.size()):
			var figure := Character.new(); holder.add_child(figure); figure.setup(0, r % 2 == 0, false)
			figure.scale = Vector2.ONE * 1.5
			figure.set_pose({"position": Vector2(120 + i * 165, 88 + r * 118), "heading": PI / 2.0, "action": steps[i][0], "phase": steps[i][1], "moving": false, "fall_style": styles[r], "fall_side": 1 if r % 2 == 0 else -1})
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/animation-falls.png")
	quit()
