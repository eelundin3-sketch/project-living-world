extends SceneTree
## Run cycle review sheet: start, steady sprint, slowing to a walk, braking to a stop.
const Character = preload("res://view/actors/drawn_character.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var heading_deg := float(OS.get_environment("SOLO_HEADING")) if OS.get_environment("SOLO_HEADING") != "" else 0.0
	var holder := Node2D.new(); root.add_child(holder)
	var bg := ColorRect.new(); bg.color = Color("bd9e69"); bg.size = Vector2(1280, 720); holder.add_child(bg)
	var rows := [["Start sprint", true, 0.0, 1.0, 1.0], ["Steady sprint", true, 1.0, 1.0, 0.0], ["Slowing to a walk", true, 1.0, 0.0, -1.0], ["Braking to a stop", false, 1.0, 0.0, -1.0]]
	for r in range(rows.size()):
		var row: Array = rows[r]
		for i in range(8):
			var t: float = float(i) / 7.0
			var figure := Character.new(); holder.add_child(figure); figure.setup(0, true, false)
			figure.scale = Vector2.ONE * 2.1
			var blend: float = lerpf(row[2], row[3], t)
			figure.set_pose({"position": Vector2(75 + i * 150, 165 + r * 175), "heading": deg_to_rad(heading_deg), "action": "run" if blend > 0.5 else "walk", "moving": row[1],
				"gait_phase": float(i) / 8.0 if r == 1 else fposmod(0.1 + t * (0.55 if r != 3 else 0.2), 1.0), "phase": 0.0, "run_blend": blend, "run_trend": row[4]})
		var label := Label.new(); label.text = row[0]; label.position = Vector2(8, 28 + r * 175); label.add_theme_color_override("font_color", Color("2a1d12")); holder.add_child(label)
	await process_frame; await RenderingServer.frame_post_draw
	var folder := OS.get_environment("SOLO_SHEET_DIR")
	if folder.is_empty(): folder = "user://character-review"
	DirAccess.make_dir_recursive_absolute(folder)
	quit(root.get_texture().get_image().save_png(folder.path_join("run_sheet_h%d.png" % int(heading_deg))))
