extends SceneTree
## Frame-by-frame contact sheets of every character action: scratch images for review.
const Character = preload("res://view/actors/drawn_character.gd")
const BATCHES := [["idle", "walk", "run", "carry"], ["pickup", "drop", "chop", "harvest"], ["saw", "build", "punch", "shove"], ["aim", "shoot", "reload", "hit"], ["stagger", "down", "rest", "eat"]]
var heading: float = PI / 4.0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var out := OS.get_environment("LW_SHEET_DIR")
	if out.is_empty(): out = "/private/tmp/claude-501"
	heading = deg_to_rad(float(OS.get_environment("LW_HEADING"))) if OS.get_environment("LW_HEADING") != "" else PI / 4.0
	for batch_index in range(BATCHES.size()):
		var holder := Node2D.new(); root.add_child(holder)
		var bg := ColorRect.new(); bg.color = Color("bd9e69"); bg.size = Vector2(1280, 720); holder.add_child(bg)
		var rows: Array = BATCHES[batch_index]
		for r in range(rows.size()):
			var action: String = rows[r]
			var moving: bool = action in ["walk", "run", "carry"]
			for i in range(8):
				var figure := Character.new(); holder.add_child(figure); figure.setup(0, true, false)
				figure.scale = Vector2.ONE * 2.1
				var anchor := Vector2(75 + i * 150, 165 + r * 175)
				if action in ["down", "rest"]: anchor += Vector2(-6, -14)
				var phase: float = float(i) / 8.0
				figure.set_pose({"position": anchor, "heading": heading, "action": action, "moving": moving, "run_blend": 1.0 if action == "run" else 0.0, "gait_phase": phase if moving else 0.0, "phase": phase,
					"cargo_item": "log" if action in ["carry", "pickup", "drop"] else "", "cargo_quantity": 2 if action in ["carry", "pickup", "drop"] else 0, "slung": action == "idle", "build_kind": "wall"})
			var label := Label.new(); label.text = rows[r].capitalize(); label.position = Vector2(8, 44 + r * 175); label.add_theme_color_override("font_color", Color("2a1d12")); holder.add_child(label)
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/anim_%d_h%d.png" % [out, batch_index, roundi(rad_to_deg(heading))])
		holder.queue_free()
	quit()
