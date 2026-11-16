extends SceneTree
## Build animation review sheet: one tile's work for walls, floors and roof (phase 0 to 0.95).
const Character = preload("res://view/actors/drawn_character.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var holder := Node2D.new(); root.add_child(holder)
	var bg := ColorRect.new(); bg.color = Color("bd9e69"); bg.size = Vector2(1280, 720); holder.add_child(bg)
	var kinds := ["walls", "floor", "roof"]
	for r in range(kinds.size()):
		for i in range(10):
			var phase: float = float(i) / 10.0 + 0.02
			var figure := Character.new(); holder.add_child(figure); figure.setup(0, true, false)
			figure.scale = Vector2.ONE * 2.1
			figure.set_pose({"position": Vector2(60 + i * 122, 190 + r * 225), "heading": 0.0, "action": "build", "moving": false, "phase": phase, "build_kind": "wall" if r == 0 else kinds[r].trim_suffix("s")})
			var label := Label.new(); label.text = "%.2f" % phase; label.position = Vector2(48 + i * 122, 196 + r * 225); label.add_theme_color_override("font_color", Color("2a1d12")); holder.add_child(label)
		var title := Label.new(); title.text = "Build: " + kinds[r]; title.position = Vector2(8, 50 + r * 225); title.add_theme_color_override("font_color", Color("2a1d12")); holder.add_child(title)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/animation-building.png")
	quit()
