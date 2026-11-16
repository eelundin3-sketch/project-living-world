extends SceneTree
## Crouch review sheet: crouching down, crouched, and the sneaking walk cycle in eight directions.
const Character = preload("res://view/actors/drawn_character.gd")
const DIRECTIONS := [["down", PI / 2.0], ["down-right", PI / 4.0], ["right", 0.0], ["up-right", -PI / 4.0], ["up", -PI / 2.0], ["up-left", -3.0 * PI / 4.0], ["left", PI], ["down-left", 3.0 * PI / 4.0]]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600, 900)
	var bg := ColorRect.new(); bg.color = Color("a8905f"); bg.size = Vector2(1600, 900); root.add_child(bg)
	var columns := [["idle", 0.0, 0.0], ["idle", 0.35, 0.0], ["idle", 0.7, 0.0], ["idle", 1.0, 0.0], ["walk", 1.0, 0.0], ["walk", 1.0, 0.25], ["walk", 1.0, 0.5], ["walk", 1.0, 0.75]]
	for r in range(DIRECTIONS.size()):
		var label := Label.new(); label.text = DIRECTIONS[r][0]; label.position = Vector2(8, 50 + r * 104); label.add_theme_color_override("font_color", Color("2a1d12")); root.add_child(label)
		for i in range(columns.size()):
			var f := Character.new(); root.add_child(f); f.setup(0, true, false); f.scale = Vector2.ONE * 1.05
			var moving: bool = columns[i][0] == "walk"
			f.set_pose({"position": Vector2(170 + i * 175, 92 + r * 104), "heading": DIRECTIONS[r][1], "action": columns[i][0], "moving": moving, "sneak": columns[i][1], "gait_phase": columns[i][2], "move_direction": Vector2.from_angle(DIRECTIONS[r][1]), "phase": 0.0})
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/animation-crouch.png")
	quit()
