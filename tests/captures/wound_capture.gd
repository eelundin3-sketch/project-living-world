extends SceneTree
## Crawling, limping and a dangling arm, drawn side by side.
const Character = preload("res://view/actors/drawn_character.gd")
func _initialize() -> void: call_deferred("run")
func put(holder: Node, at: Vector2, pose: Dictionary, label: String) -> void:
	var f := Character.new(); holder.add_child(f); f.setup(3, false, false); f.scale = Vector2.ONE * 1.4
	pose.position = at
	f.set_pose(pose)
	var l := Label.new(); l.text = label; l.position = at + Vector2(-50, 70); l.add_theme_color_override("font_color", Color("2a1d12")); holder.add_child(l)
func run() -> void:
	root.size = Vector2i(1280, 520)
	var holder := Node2D.new(); root.add_child(holder)
	var bg := ColorRect.new(); bg.color = Color("a8905f"); bg.size = Vector2(1280, 520); holder.add_child(bg)
	var headings := [PI / 2.0, PI / 4.0, 0.0]
	for i in range(3):
		put(holder, Vector2(120 + i * 140, 120), {"heading": headings[i], "action": "crawl", "moving": true, "gait_phase": 0.25 * i + 0.1, "age": 0.3 * i}, "crawl" if i == 0 else "")
	for i in range(3):
		put(holder, Vector2(120 + i * 140, 300), {"heading": headings[i], "action": "walk", "moving": true, "gait_phase": 0.2 + 0.25 * i, "limp": true, "limp_side": 1, "age": 0.3 * i}, "limp" if i == 0 else "")
	for i in range(3):
		put(holder, Vector2(700 + i * 140, 120), {"heading": headings[i], "action": "idle", "dead_arms": [-1], "age": 0.3 * i}, "right arm useless" if i == 0 else "")
		put(holder, Vector2(700 + i * 140, 300), {"heading": headings[i], "action": "idle", "dead_arms": [-1, 1], "age": 0.3 * i}, "both arms useless" if i == 0 else "")
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/wounds-poses.png")
	quit()
