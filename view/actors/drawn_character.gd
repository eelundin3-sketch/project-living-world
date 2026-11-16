extends Node2D
## A vector cutout puppet. Direction changes the silhouette, linework and layer
## order; each piece is drawn directly in the same canvas as the world.
const Props = preload("res://view/world/prop_art.gd")
const Director = preload("res://view/actors/animation_director.gd")
const INK := Color("292016")
const PANTS := Color("b58c54")
const BOOT := Color("694722")
const HAIR := Color("543824")
const CLOTH := [Color("d7d0ad"), Color("c8b086"), Color("a5ab8c"), Color("d5bc91")]
const VESTS := [Color("968057"), Color("887b57"), Color("a07551"), Color("8c9371")]

var actor_id: int
var is_player: bool
var is_raider: bool
var heading := PI / 2.0
var forward := Vector2.DOWN
var across := Vector2.RIGHT
var pose: Dictionary = {}
var frame: Dictionary = {}
var blend_from: Dictionary = {}
var blend_elapsed := 0.0
var blend_duration := 0.0

func setup(id: int, player: bool, raider: bool) -> void:
	actor_id = id
	is_player = player
	is_raider = raider

func set_pose(value: Dictionary, delta: float = -1.0) -> void:
	var next_position: Vector2 = value.get("position", Vector2.ZERO)
	var snap := delta < 0.0 or frame.is_empty() or position.distance_to(next_position) > 96.0
	var changed: bool = pose.get("action") != value.get("action") or pose.get("ready", false) != value.get("ready", false)
	if not snap and not changed and blend_from.is_empty() and pose == value: return
	if snap:
		blend_from.clear()
	elif changed:
		blend_from = frame.duplicate(true)
		blend_elapsed = 0.0
		var action: String = value.get("action", "idle")
		blend_duration = 0.18 if action in ["rest", "down", "idle"] else 0.13
		if action in ["hit", "stagger"]: blend_duration = 0.08
		if action == "shoot": blend_duration = 0.045
	else:
		blend_elapsed += maxf(0.0, delta)
	position = next_position
	heading = float(value.get("heading", PI / 2.0))
	forward = Vector2.from_angle(heading)
	across = Vector2(forward.y, -forward.x)
	pose = value.duplicate()
	frame = _build_frame()
	if not blend_from.is_empty():
		var weight := smoothstep(0.0, blend_duration, blend_elapsed)
		if weight >= 1.0: blend_from.clear()
		else: _blend_frame(weight)
	queue_redraw()

func _blend_frame(weight: float) -> void:
	for part in ["hip", "chest", "head", "origin"]:
		frame[part] = (blend_from[part] as Vector2).lerp(frame[part], weight)
	for part in ["left_arm", "right_arm", "left_leg", "right_leg"]:
		var start: PackedVector2Array = blend_from[part]
		var target: PackedVector2Array = frame[part]
		for joint in range(target.size()):
			target[joint] = start[joint].lerp(target[joint], weight)
		frame[part] = target
	if frame.carrying and blend_from.carrying:
		frame.cargo = (blend_from.cargo as Vector2).lerp(frame.cargo, weight)
	if frame.armed:
		if blend_from.armed:
			frame.stock = (blend_from.stock as Vector2).lerp(frame.stock, weight)
			frame.muzzle = (blend_from.muzzle as Vector2).lerp(frame.muzzle, weight)
		else:
			var grip: Vector2 = (frame.left_arm[2] + frame.right_arm[2]) * 0.5
			var barrel: Vector2 = frame.muzzle - frame.stock
			frame.stock = grip - barrel * 0.475
			frame.muzzle = frame.stock + barrel
	frame.tilt = lerp_angle(blend_from.tilt, frame.tilt, weight)
	frame.impact = lerpf(blend_from.impact, frame.impact, weight)

func _joint(width: float, reach: float, height: float) -> Vector2:
	var ground := across * width + forward * reach
	return Vector2(ground.x, ground.y * 0.48 - height)

func _shape(points: PackedVector2Array, color: Color, width: float = 1.45) -> void:
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, INK, width, true)

func _oval(center: Vector2, radius: Vector2, color: Color, angle: float = 0.0, edge: float = 1.35) -> void:
	var points := PackedVector2Array()
	for i in range(20):
		var f := TAU * i / 20.0
		points.append(center + (Vector2.from_angle(f) * radius).rotated(angle))
	if edge > 0: _shape(points, color, edge)
	else: draw_colored_polygon(points, color)

func _segment(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var delta := b - a
	_oval(a.lerp(b, 0.5), Vector2(width, delta.length() * 0.5 + width * 0.6), color, delta.angle() - PI / 2.0)

func _build_frame() -> Dictionary:
	var action: String = pose.get("action", "idle")
	var phase: float = pose.get("phase", 0.0)
	var gait: float = float(pose.get("gait_phase", 0.0)) * TAU
	var moving: bool = pose.get("moving", false)
	var run := action == "run" and moving
	var work := sin(phase * TAU)
	var impact := smoothstep(0.17, 0.45, phase) * (1.0 - smoothstep(0.53, 0.93, phase))
	var crouch := 0.0
	if action in ["pickup", "drop", "harvest"]:
		var reach_phase := 1.0 - phase if action == "drop" else phase
		crouch = smoothstep(0.02, 0.36, reach_phase) * (1.0 - smoothstep(0.44, 0.96, reach_phase))
	var bob := 0.0
	if moving and not pose.get("reduced_motion", false):
		bob = pow(sin(gait - TAU * 0.09), 2.0) * 3.5 if run else pow(sin(gait), 2.0) * 1.15
	var fold := (8.0 if run else 0.0) + crouch * 12.0
	if action in ["stagger", "hit"]: fold = -5.0 * sin(phase * PI)
	if action in ["chop", "build", "punch", "shove"]: fold += impact * 5.0
	if action == "build" and pose.get("build_kind", "") == "floor":
		crouch = 0.55 + impact * 0.32
		fold += 7.0
	var hip := _joint(0, 0, 23 + bob - crouch * 5)
	var chest := _joint(0, fold, 45 + bob - crouch * 14)
	var head := _joint(0, fold * 1.22, 55 + bob - crouch * 18)
	var item: String = pose.get("cargo_item", "")
	var quantity: int = pose.get("cargo_quantity", 0)
	if quantity == 0 and action == "pickup":
		item = pose.get("expected_item", "")
		quantity = pose.get("expected_quantity", 0)
	if quantity == 0 and action == "drop":
		item = pose.get("last_item", "")
		quantity = pose.get("last_quantity", 0)
	var carrying := quantity > 0 and action not in ["build", "hit", "down", "rest", "punch", "shove", "stagger"]
	var lift := 1.0
	if action == "pickup": lift = smoothstep(0.33, 0.91, phase)
	elif action == "drop": lift = smoothstep(0.33, 0.91, 1.0 - phase)
	var cargo_center := _joint(0, 9 + fold * 0.5, 5 + 24 * lift)
	var show_cargo := carrying
	if action == "pickup" and pose.get("cargo_quantity", 0) == 0: show_cargo = carrying and phase >= 0.33
	if action == "drop" and pose.get("cargo_quantity", 0) == 0: show_cargo = carrying and phase < 0.67
	var armed := action in ["aim", "shoot"]
	var recoil := 4.2 * smoothstep(0.0, 0.10, phase) * (1.0 - smoothstep(0.12, 0.52, phase)) if action == "shoot" else 0.0
	var stock := head + _joint(0, 3 - recoil, -8)
	var muzzle := stock + _joint(0, 41, 0)
	var arms: Dictionary = {}
	for side in [-1, 1]:
		var limb_cycle := gait + (PI if side > 0 else 0.0)
		var bounce := -cos(limb_cycle) if moving else 0.0
		var shoulder := chest + _joint(side * 8.5, 0, 0)
		var elbow := shoulder + _joint(side * 2.8, bounce * 4.5, -9)
		var hand := elbow + _joint(side * 0.8, bounce * 5.0, -9)
		if not moving:
			elbow = shoulder + _joint(side * 3.2, 2.0, -12)
			hand = hip + _joint(side * 2.5, 8.5, 2)
		if carrying:
			var grip_weight := 1.0
			if action == "pickup": grip_weight = smoothstep(0.0, 0.33, phase)
			elif action == "drop": grip_weight = 1.0 - smoothstep(0.67, 1.0, phase)
			elbow = elbow.lerp(shoulder + _joint(side * 3, 4, -11), grip_weight)
			hand = hand.lerp(cargo_center + _joint(side * 9, 0, -2), grip_weight)
		elif armed:
			hand = stock.lerp(muzzle, 0.31 if side > 0 else 0.64)
			elbow = shoulder.lerp(hand, 0.45) + _joint(side * 2, -1, -7)
		elif action in ["punch", "shove", "melee", "ready"] or pose.get("ready", false):
			var extension := impact if side > 0 or action == "shove" else 0.0
			hand = chest + _joint(side * 5, 9 + extension * 23, 1 - extension * 3)
			elbow = shoulder.lerp(hand, 0.50) + _joint(side * 3, 0, -8)
		elif action in ["chop", "build", "saw", "eat", "harvest"]:
			hand = _work_hand(side, action, chest, work, impact)
			elbow = shoulder.lerp(hand, 0.45) + _joint(side * 4, -2, -7)
		elif run:
			elbow = shoulder + _joint(side * 2, bounce * 10.5 - 3.0, -11)
			hand = elbow + _joint(side * 0.5, 10.0 + bounce * 2.5, 7.0 + bounce * 3.5)
		arms[side] = PackedVector2Array([shoulder, elbow, hand])
	var tilt := 0.0
	var origin := Vector2.ZERO
	if action in ["down", "rest"]:
		tilt = PI / 2.0
		origin = Vector2(-30, 1)
	elif action in ["stagger", "hit"]:
		tilt = sin(phase * PI) * (0.32 if action == "stagger" else 0.14) * signf(forward.x + 0.01)
	return {
		"hip": hip, "chest": chest, "head": head, "cargo": cargo_center, "stock": stock, "muzzle": muzzle,
		"left_arm": arms[-1], "right_arm": arms[1],
		"left_leg": leg_joints(-1, hip, gait, moving, run), "right_leg": leg_joints(1, hip, gait, moving, run),
		"origin": origin, "tilt": tilt, "item": item, "quantity": quantity, "carrying": carrying,
		"armed": armed, "impact": impact, "show_cargo": show_cargo,
	}

func _draw() -> void:
	if frame.is_empty(): return
	var action: String = pose.get("action", "idle")
	var gait: float = float(pose.get("gait_phase", 0.0)) * TAU
	var moving: bool = pose.get("moving", false)
	var front := forward.y
	var width := lerpf(8.0, 12.0, absf(front))
	var complexion := [Color("efdb9f"), Color("d9b27c"), Color("b9885e")]
	var skin: Color = complexion[posmod(actor_id, complexion.size())]
	var shirt: Color = Color("d6bf89") if is_player else CLOTH[posmod(actor_id, CLOTH.size())]
	var vest: Color = Color("b49a63") if is_player else VESTS[posmod(actor_id, VESTS.size())]
	if is_raider: vest = Color("8b5944")
	var near_side := -1 if across.y < 0 else 1
	var arms: Dictionary = {-1: frame.left_arm, 1: frame.right_arm}
	var legs: Dictionary = {-1: frame.left_leg, 1: frame.right_leg}
	draw_set_transform(frame.origin, frame.tilt)

	var leading := near_side
	if moving:
		var stride_direction: Vector2 = pose.get("move_direction", forward)
		var first_stride := sin(gait) * stride_direction.y - across.y * 5.0
		leading = -1 if first_stride > 0.0 else 1
	_draw_leg(-leading, legs[-leading])
	_draw_leg(leading, legs[leading])

	var object_behind := front < -0.08
	var far_arm_in_front := front > 0.52
	var both_arms_behind := front < -0.72
	if not far_arm_in_front:
		_draw_arm(arms[-near_side], shirt.darkened(0.10), skin)
	if both_arms_behind:
		_draw_arm(arms[near_side], shirt, skin)
	if object_behind:
		if frame.show_cargo: _draw_cargo(frame.item, frame.quantity, frame.cargo)
		if frame.armed: _draw_rifle(frame.stock, frame.muzzle)
	_draw_coat(frame.chest, frame.hip, width, vest, shirt)
	_draw_head(frame.head, skin)
	if not object_behind:
		if frame.show_cargo: _draw_cargo(frame.item, frame.quantity, frame.cargo)
		if frame.armed: _draw_rifle(frame.stock, frame.muzzle)
	if action in ["chop", "build", "saw"] and not pose.get("machine_work", false):
		_draw_tool(action, arms[1][2], frame.impact)
	if far_arm_in_front:
		_draw_arm(arms[-near_side], shirt, skin)
	if not both_arms_behind:
		_draw_arm(arms[near_side], shirt, skin)
	draw_set_transform(Vector2.ZERO)

func leg_joints(side: int, hip: Vector2, gait: float, moving: bool, run: bool) -> PackedVector2Array:
	var cycle := fposmod(gait / TAU + (0.5 if side > 0 else 0.0), 1.0)
	var direction: Vector2 = pose.get("move_direction", forward)
	var stance := 0.43 if run else 0.57
	var cycle_distance := Director.CELL * (Director.RUN_CYCLE_METERS if run else Director.WALK_CYCLE_METERS)
	var reach := cycle_distance * stance * 0.5
	var stride := 0.0
	var lift := 0.0
	if moving:
		# During stance the foot travels backwards at a constant rate, matching
		# forward travel. Swing brings it forwards on a curved, lifted path.
		if cycle < stance:
			stride = lerpf(reach, -reach, cycle / stance)
		else:
			var swing := (cycle - stance) / (1.0 - stance)
			stride = lerpf(-reach, reach, smoothstep(0.0, 1.0, swing))
			lift = pow(sin(swing * PI), 1.35) * (11.7 if run else 5.3)
	var travel := Vector2(direction.x, direction.y * 0.49)
	var foot := _joint(side * 5.4, 1.5, 3.0 + lift) + travel * stride
	var top := hip + _joint(side * 5.3, 0, 0)
	var knee := top.lerp(foot, 0.54) + travel * (lift * 0.35 + 2.5)
	return PackedVector2Array([top, knee, foot])

func _draw_leg(side: int, points: PackedVector2Array) -> void:
	var top := points[0]
	var knee := points[1]
	var foot := points[2]
	var tone := PANTS.darkened(0.13) if across.y * side < -0.02 else PANTS
	_segment(top, knee, 4.9, tone)
	_segment(knee, foot, 3.8, tone.lightened(0.11))
	_oval(foot + _joint(0, 1.5, 0), Vector2(3.8 + absf(forward.x) * 1.9, 2.9), BOOT, forward.x * 0.14)

func _draw_arm(joints: PackedVector2Array, color: Color, skin: Color) -> void:
	_segment(joints[0], joints[1], 4.25, color)
	_segment(joints[1], joints[2], 3.6, color.lightened(0.08))
	_oval(joints[2], Vector2(3.0, 3.4), skin)

func _draw_coat(chest: Vector2, hip: Vector2, width: float, vest: Color, shirt: Color) -> void:
	var center := chest.lerp(hip, 0.5)
	_shape(PackedVector2Array([
		chest + Vector2(-width * 0.55, -4), chest + Vector2(width * 0.55, -4),
		chest + Vector2(width * 0.87, 0), center + Vector2(width * 0.82, 0),
		hip + Vector2(width * 0.66, 0), hip + Vector2(width * 0.35, 3),
		hip + Vector2(-width * 0.48, 3), hip + Vector2(-width * 0.70, 0),
		center + Vector2(-width * 0.83, 0), chest + Vector2(-width * 0.87, 0),
	]), vest, 1.7)
	var seam_top := chest + Vector2(forward.x * width * 0.58, -1)
	var seam_low := hip + Vector2(forward.x * width * 0.47, 0)
	if forward.y >= -0.08:
		draw_line(seam_top, seam_low, INK, 2.6, true)
		draw_line(seam_top, seam_low, shirt.lightened(0.18), 1.1, true)
		for side in [-1, 1]:
			var lapel_width := maxf(0.15, absf(forward.y)) * width * 0.58
			_shape(PackedVector2Array([seam_top, seam_top + Vector2(side * lapel_width, -3),
				seam_top + Vector2(side * minf(lapel_width * 0.47, 2.2), 6)]),
				vest.lightened(0.17), 1.0)
		for t in [0.44, 0.65, 0.84]:
			draw_circle(seam_top.lerp(seam_low, t) + Vector2(-2.6 * maxf(0.2, forward.y), 0), 0.95, INK, true, -1, true)
	else:
		draw_line(chest + Vector2(forward.x * -3, 2), hip + Vector2(forward.x * -3, -1), vest.darkened(0.24), 1.0, true)
		draw_line(chest + Vector2(-width * 0.55, 3), chest + Vector2(width * 0.55, 3), vest.lightened(0.13), 1.0, true)

func _draw_head(head: Vector2, skin: Color) -> void:
	_oval(head + Vector2(0, 7.0), Vector2(4.6, 4.0), skin.darkened(0.10))
	_oval(head + Vector2(-forward.x * 1.8, -1), Vector2(7.5, 8.4), HAIR)
	var show_face := smoothstep(-0.62, -0.04, forward.y)
	if show_face > 0.01:
		var face := head + Vector2(forward.x * (3.5 + 3.1 * (1.0 - show_face)), 0)
		var w := lerpf(1.05, 6.5, show_face)
		_shape(PackedVector2Array([
			face + Vector2(-w * 0.93, -6), face + Vector2(w * 0.93, -6),
			face + Vector2(w, -1), face + Vector2(w * 0.72, 3.4),
			face + Vector2(w * 0.26, 7.3), face + Vector2(-w * 0.38, 7.1),
			face + Vector2(-w * 0.86, 3.4),
		]), skin)
		if absf(forward.x) > 0.49 and show_face > 0.65:
			var edge := face + Vector2(signf(forward.x) * w * 0.77, 0)
			_shape(PackedVector2Array([edge + Vector2(0, -2), edge + Vector2(signf(forward.x) * 2, 1), edge + Vector2(0, 2.2)]), skin, 0.85)
		for side in [-1, 1]:
			var visibility := smoothstep(-0.12, 0.36, forward.y + side * forward.x * 0.44)
			if visibility < 0.04 or show_face < 0.42: continue
			var eye := face + Vector2(side * 2.7 * maxf(0.3, forward.y) + forward.x * 0.9, -0.8)
			_oval(eye, Vector2(1.5 * visibility, 0.95), Color("faf0d0"), 0, 0.7)
			_oval(eye + Vector2(forward.x * 0.25, 0), Vector2(0.48, 0.64), Color("4f7b74"), 0, 0.0)
		if show_face > 0.65:
			var mouth := face + Vector2(forward.x * 1.8, 4.0)
			draw_line(mouth - Vector2(1.9 - absf(forward.x), 0), mouth + Vector2(1.9 - absf(forward.x), 0), INK, 1.1, true)
	if not is_player and posmod(actor_id, 4) == 1:
		var top := head + Vector2(-forward.x * 1.3, -6.0)
		_shape(PackedVector2Array([top + Vector2(-7, 2), top + Vector2(-6, -3),
			top + Vector2(-2, -5), top + Vector2(4, -4), top + Vector2(8, -1),
			top + Vector2(6, 3), top + Vector2(0, 1), top + Vector2(-4, 3)]), HAIR)
		return
	var hat := Color("bd9050") if is_player else Color("a58250")
	var brim := head + Vector2(forward.x * 0.8, -6.8)
	_oval(brim, Vector2(12.6, 3.7), hat, -forward.x * 0.09, 1.6)
	var crown := brim + Vector2(-forward.x * 1.35, -3.8)
	_shape(PackedVector2Array([crown + Vector2(-5.9, -1.5), crown + Vector2(5.8, -1.5),
		crown + Vector2(6.2, 3.1), crown + Vector2(2.7, 4.4),
		crown + Vector2(-3.1, 4.2), crown + Vector2(-6.2, 2.8)]), hat.darkened(0.19))
	_oval(crown + Vector2(0, -1.6), Vector2(5.8, 1.9), hat.lightened(0.14), 0, 1.1)

func _work_hand(side: int, action: String, chest: Vector2, wave: float, impact: float) -> Vector2:
	match action:
		"build":
			var height: float = 8.0 - impact * 19.0
			match pose.get("build_kind", ""):
				"floor": height -= 7.0
				"roof": height += 10.0
			return chest + _joint(side * 4, 7 + impact * 16, height if side > 0 else height - 5.0)
		"chop":
			return chest + _joint(side * 3, 5 + impact * 16, (12.0 if side > 0 else 5.0) - impact * 23)
		"saw":
			return chest + _joint(side * 6, 10.0 + wave * 5, -8)
		"eat":
			return chest + _joint(side * (4 if side > 0 else 8), 7, 1 + wave * 3 if side > 0 else -13)
		_:
			return chest + _joint(side * 6, 11, -15)

func _draw_tool(action: String, hand: Vector2, impact: float) -> void:
	if action == "saw":
		var tip := hand + _joint(0, 23, 0)
		var normal := hand.direction_to(tip).orthogonal()
		var blade := PackedVector2Array([hand - normal * 2.1, tip - normal * 1.5, tip + normal * 0.5])
		for i in range(7, 0, -1):
			var edge := hand.lerp(tip, i / 8.0)
			blade.append(edge + normal * 1.6)
			blade.append(edge + normal * 0.65 - hand.direction_to(tip))
		blade.append(hand + normal * 2.1)
		Props.polygon(self, blade, Color("c4c5b5"))
		_oval(hand, Vector2(2.3, 3.2), Color("82593b"), (tip - hand).angle(), 0.8)
		return
	var tip := hand + _joint(0, 3 + impact * 13, 15 - impact * 21)
	var axis := hand.direction_to(tip)
	if axis.is_zero_approx(): axis = Vector2.UP
	var side := axis.orthogonal()
	_segment(hand, tip, 1.65, Color("966740"))
	draw_line(hand.lerp(tip, 0.20) - side * 0.45, tip - side * 0.45, Color("c09460"), 0.55, true)
	if action == "chop":
		Props.polygon(self, PackedVector2Array([tip - side * 2.7 - axis * 1.5,
			tip + side * 2.9 - axis * 3.4, tip + side * 5.2 - axis * 2.9,
			tip + side * 5.2 + axis * 3.5, tip + side * 2.9 + axis * 3.8,
			tip - side * 2.7 + axis * 1.7]), Color("909c94"))
		draw_line(tip + side * 4.2 - axis * 2.5, tip + side * 4.2 + axis * 3.0, Color("d1d3bc"), 0.72, true)
	else:
		Props.polygon(self, PackedVector2Array([tip - side * 4 - axis * 1.6,
			tip + side * 4.4 - axis * 1.6, tip + side * 4.4 + axis * 1.8,
			tip - side * 4 + axis * 1.8]), Color("8b9691"))
		draw_line(tip - side * 3.4 + axis * 0.9, tip + side * 3.8 + axis * 0.9, Color("bfc7b7"), 0.6, true)

func _draw_rifle(stock: Vector2, muzzle: Vector2) -> void:
	var axis := (muzzle - stock).normalized()
	var normal := axis.orthogonal()
	var grip := stock.lerp(muzzle, 0.49)
	_shape(PackedVector2Array([
		stock - normal * 2.2, grip - normal * 1.2,
		grip + normal * 1.6, stock + axis * 5 + normal * 3.1,
		stock + normal * 2.8,
	]), Color("a37743"), 1.15)
	_shape(PackedVector2Array([
		grip - normal, muzzle - normal,
		muzzle + normal, grip + normal,
	]), Color("77786c"), 1.05)
	draw_line(stock + axis * 4, grip - axis * 3, Color("c49967"), 0.56, true)
	Props.nail(self, grip - axis * 2, 0.75)
	draw_line(grip + axis * 2 - normal * 0.35, muzzle - axis - normal * 0.35, Color("b9b9a7"), 0.55, true)
	draw_line(muzzle - axis * 2 - normal, muzzle - axis * 2 - normal * 2.2, INK, 0.9, true)

func _draw_cargo(item: String, quantity: int, center: Vector2) -> void:
	if item not in ["log", "plank"]:
		Props.supply(self, center + Vector2(0, 3), item, 0.83)
		return
	var span := _joint(12, 4.5, 0)
	if across.y < 0: span = -span
	for index in range(mini(3, quantity)):
		var strip := center - Vector2(0, index * 3.35)
		if item == "log": Props.log_piece(self, strip - span, strip + span, 2.8)
		else: Props.plank(self, strip - span, strip + span, 2.3)
