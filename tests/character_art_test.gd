extends SceneTree
## The new silhouette must stay readable, planted and usable by the health UI.
const Character = preload("res://view/actors/drawn_character.gd")
const Diagram = preload("res://view/ui/body_diagram.gd")
const Outfits = preload("res://sim/entities/outfits.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var figure := Character.new()
	root.add_child(figure)
	figure.setup(0, true, false)
	var anchor := Vector2(140, 130)
	figure.set_pose({"position": anchor, "heading": PI / 2, "action": "idle"})
	var f: Dictionary = figure.frame
	check(-f.hip.y > f.hip.y - f.chest.y, "Legs are longer than the torso, not compressed underneath it")
	check(f.chest.y - f.head.y >= 10 and f.chest.y - f.head.y <= 12, "Short neck keeps the head close to the collar")
	check(f.left_arm[2].x < -11 and f.right_arm[2].x > 11, "Relaxed hands leave the front of the body readable")
	check(f.left_leg[2].x < -4 and f.right_leg[2].x > 4, "Standing feet have a distinct gap")
	for heading in [0.0, PI]:
		for action in ["idle", "gun_carry"]:
			figure.set_pose({"heading": heading, "action": action, "moving": false})
			var standing: Dictionary = figure.frame
			check(is_equal_approx(standing.head.x, standing.hip.x) and is_equal_approx(standing.chest.x, standing.hip.x), "Standing profile keeps the upper body over the hips")
			for limb in [standing.left_leg, standing.right_leg]:
				check(is_equal_approx(limb[0].x, limb[1].x) and is_equal_approx(limb[1].x, limb[2].x), "Standing knee and ankle sit below the hip")
	for heading in range(8):
		for action in ["idle", "walk", "run", "carry", "pickup", "drop", "chop", "mine", "build", "saw", "harvest", "eat", "ready", "gun_carry", "aim", "shoot", "reload", "punch", "shove", "hit", "stagger", "fall", "down", "getup", "rest"]:
			for index in range(12):
				var phase := float(index) / 12
				figure.set_pose({"position": anchor, "heading": heading * PI / 4, "action": action,
					"phase": phase, "gait_phase": phase, "moving": action in ["walk", "run", "carry", "gun_carry"],
					"run_blend": 1.0 if action == "run" else 0.0, "cargo_item": "log", "cargo_quantity": 2 if action in ["carry", "pickup", "drop"] else 0})
				check(figure.position == anchor, "Drawing a pose never moves the world anchor")
				for limb in ["left_arm", "right_arm", "left_leg", "right_leg"]:
					var chain: PackedVector2Array = figure.frame[limb]
					var widths := Vector3(3.8, 3.1, 2.2) if limb.ends_with("arm") else Vector3(4.2, 3.4, 2.7)
					var panels := figure.limb_panels(chain, widths)
					for panel in panels:
						check(not Geometry2D.triangulate_polygon(panel).is_empty(), "Cloth can be drawn at every phase: " + action)
					check(Geometry2D.merge_polygons(panels[0], panels[1]).size() == 1, "Cloth keeps one joined silhouette: " + action)
					for point in chain:
						check(point.is_finite() and point.length() < 160, "Finite, bounded joints: " + action)
			figure.set_pose({"position": anchor, "heading": heading * PI / 4, "action": "idle"})
			check(absf(figure.frame.left_leg[2].y) < 8 and absf(figure.frame.right_leg[2].y) < 8, "Idle feet remain at ground level after " + action)
	var hip := Vector2(0, -Character.HIP_HEIGHT)
	# Side and diagonal views expose whether the trailing knee follows its foot.
	for direction in [Vector2.RIGHT, Vector2(1, 1).normalized(), Vector2.LEFT]:
		figure.set_pose({"heading": direction.angle(), "move_direction": direction, "action": "walk"})
		var travel := Vector2(direction.x, direction.y * 0.48).normalized()
		var trailing := figure.leg_joints(-1, hip, TAU * 0.60, true)
		var other := figure.leg_joints(1, hip, TAU * 0.60, true)
		check((trailing[2].x - trailing[0].x) / direction.x < -13 and (trailing[1].x - trailing[0].x) / direction.x < -5, "Walking knee and foot extend behind the hip at push-off")
		check((other[2].x - other[0].x) / direction.x > 5, "Opposite foot lands ahead while the rear foot pushes off")
		var planted := figure.leg_joints(-1, hip, TAU * 0.35, true)
		check(trailing[2].y < planted[2].y + (trailing[2].x - planted[2].x) * travel.y / travel.x - 2, "Heel rises during walking push-off")
	# Compare the same part of the sole before and after it pivots, in world space.
	figure.set_pose({"heading": 0.0, "action": "walk"})
	check(figure.walking_foot_pitch(-1, 0) < -0.2, "Toes lift for heel-first contact")
	check(is_zero_approx(figure.walking_foot_pitch(-1, TAU * 0.30)), "Boot is flat under load")
	check(figure.walking_foot_pitch(-1, TAU * 0.60) > 0.45, "Heel rolls up over the toes before swing")
	for phases in [Vector2(0, 0.12), Vector2(0.41, 0.58)]:
		var first := Vector2.ZERO
		for phase in [phases.x, phases.y]:
			var pitch := figure.walking_foot_pitch(-1, phase * TAU)
			var joints := figure.leg_joints(-1, hip, phase * TAU, true)
			var sole: Vector2 = joints[2] + figure.boot_roll(pitch) * figure.boot_contact(pitch)
			sole.x += 48.0 * phase
			if phase == phases.x: first = sole
			else: check(first.distance_to(sole) < 0.01, "Grounded heel or toe stays planted during boot roll")
	for boundary in [0.0, 0.60]:
		var before := figure.leg_joints(-1, hip, (boundary - 0.00001) * TAU, true)
		var after := figure.leg_joints(-1, hip, (boundary + 0.00001) * TAU, true)
		check(before[2].distance_to(after[2]) < 0.01, "Walking foot stays continuous at toe-off and landing")
	figure.set_pose({"heading": 0.0, "action": "run", "moving": true, "run_blend": 1.0})
	var toe_off := figure.leg_joints(-1, hip, TAU * 0.36, true, 1.0)
	var kick_back := figure.leg_joints(-1, hip, TAU * (0.36 + 0.64 * 0.28), true, 1.0)
	check(kick_back[2].x < toe_off[2].x - 7, "Heel continues backwards after toe-off")
	check(kick_back[1].x < hip.x, "Trailing knee extends behind the hip during the kick")
	check(kick_back[2].y < toe_off[2].y - 12, "Trailing heel folds upwards during recovery")
	for boundary in [0.0, 0.36, 0.36 + 0.64 * 0.28]:
		var before := figure.leg_joints(-1, hip, (boundary - 0.00001) * TAU, true, 1.0)
		var after := figure.leg_joints(-1, hip, (boundary + 0.00001) * TAU, true, 1.0)
		check(before[2].distance_to(after[2]) < 0.01, "Foot path has no jump at stance, recovery or cycle wrap")
	var aim_heading := 0.24
	figure.set_pose({"heading": aim_heading, "action": "aim", "aiming": true})
	var aimed_span: Vector2 = figure.frame.muzzle - figure.frame.stock
	var unprojected := Vector2(aimed_span.x, aimed_span.y / 0.48)
	check(is_equal_approx(unprojected.length(), 42.0), "Shotgun is 25% shorter than its original 56 px length")
	check(absf(angle_difference(unprojected.angle(), aim_heading)) < 0.001, "Muzzle follows aim between body directions")
	figure.set_pose({"heading": 0.0, "action": "gun_carry", "moving": true})
	check(figure.frame.armed and figure.frame.muzzle.y > figure.frame.stock.y + 10, "Walking holds the muzzle below the stock")
	var diagram := Diagram.new()
	diagram.size = Vector2(190, 340)
	diagram.outfit = Outfits.default_for(0, true)
	root.add_child(diagram)
	diagram._layout()
	check(diagram.zones.size() == 17, "All health regions remain available")
	for part in diagram.zones:
		var zone: Rect2 = diagram.zones[part]
		check(Rect2(Vector2.ZERO, diagram.size).encloses(zone), "Health region fits the panel: " + part)
	for part in ["neck", "right_hand", "left_hand", "right_foot", "left_foot"]:
		check(diagram._part_at(diagram.zones[part].get_center()) == part, "Health region selects the correct limb: " + part)
	figure.queue_free()
	diagram.queue_free()
	await process_frame
	print("Character art and health layout: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
