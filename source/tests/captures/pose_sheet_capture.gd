extends SceneTree
## Review sheet: low-ready rifle, sheriff, backpack rummage and pack-up, and getting into bed.
const Character = preload("res://view/actors/drawn_character.gd")
const Outfits = preload("res://sim/entities/outfits.gd")
func _initialize() -> void: call_deferred("run")
func put(holder: Node, at: Vector2, pose: Dictionary, player: bool = true, id: int = 0) -> void:
	var f := Character.new(); holder.add_child(f); f.setup(id, player, false); f.scale = Vector2.ONE * 1.35
	pose.position = at
	if not pose.has("moving"): pose.moving = false
	f.set_pose(pose)
func run() -> void:
	root.size = Vector2i(1600, 900)
	var holder := Node2D.new(); root.add_child(holder)
	var bg := ColorRect.new(); bg.color = Color("a8905f"); bg.size = Vector2(1600, 900); holder.add_child(bg)
	var x := 90.0
	for heading in [PI / 2.0, PI / 4.0, 0.0, -PI / 2.0]:
		put(holder, Vector2(x, 130), {"heading": heading, "action": "gun_carry", "backpack": true})
		x += 150
	for heading in [PI / 2.0, PI / 4.0, 0.0]:
		put(holder, Vector2(x, 130), {"heading": heading, "action": "idle", "outfit": Outfits.SHERIFF, "slung": true}, false, 5)
		x += 150
	var times := [0.15, 0.35, 0.6, 0.9, 1.3, 1.7]
	for r in range(2):
		var heading: float = PI / 2.0 if r == 0 else 0.0
		for i in range(times.size()):
			put(holder, Vector2(90 + i * 150, 330 + r * 170), {"heading": heading, "action": "rummage", "rummage_t": times[i], "backpack": true})
		for i in range(3):
			put(holder, Vector2(990 + i * 150, 330 + r * 170), {"heading": heading, "action": "pack_up", "pack_up_phase": [0.2, 0.55, 0.85][i], "backpack": true})
	for i in range(6):
		put(holder, Vector2(120 + i * 200, 800), {"heading": PI / 2.0, "action": "rest", "rest_rot": 3, "rest_blend": [0.0, 0.2, 0.45, 0.65, 0.85, 1.0][i]}, false, 3)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/animation-poses.png")
	quit()
