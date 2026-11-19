extends SceneTree
## Review sheet: hit and stagger reactions (feet planted, no whole-body pivot) and self-treatment.
const Character = preload("res://view/actors/drawn_character.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600, 900)
	var holder := Node2D.new(); root.add_child(holder)
	var bg := ColorRect.new(); bg.color = Color("a8905f"); bg.size = Vector2(1600, 900); holder.add_child(bg)
	var rows := [
		["stagger front", "stagger", PI / 2.0, {}], ["stagger side", "stagger", 0.0, {}], ["punched", "hit", PI / 4.0, {}],
		["bandage forearm", "treat", PI / 2.0, {"treat_part": "left_forearm", "treat_kind": "bandage"}],
		["bandage shin", "treat", PI / 4.0, {"treat_part": "right_shin", "treat_kind": "bandage"}],
		["bandage head", "treat", PI / 2.0, {"treat_part": "head", "treat_kind": "bandage"}],
		["clean ribs", "treat", 0.0, {"treat_part": "upper_torso", "treat_kind": "disinfect"}]]
	var phases := [0.0, 0.1, 0.2, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0]
	for r in range(rows.size()):
		var label := Label.new(); label.text = rows[r][0]; label.position = Vector2(8, 40 + r * 124); label.add_theme_color_override("font_color", Color("2a1d12")); holder.add_child(label)
		for i in range(phases.size()):
			var figure := Character.new(); holder.add_child(figure); figure.setup(0, true, false)
			figure.scale = Vector2.ONE * 1.25
			var pose := {"position": Vector2(200 + i * 150, 112 + r * 124), "heading": rows[r][2], "action": rows[r][1], "phase": phases[i], "moving": false}
			for k in rows[r][3]: pose[k] = rows[r][3][k]
			figure.set_pose(pose)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/animation-reactions.png")
	quit()
