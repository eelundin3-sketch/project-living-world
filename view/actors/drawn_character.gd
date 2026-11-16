extends Node2D
## A vector cutout puppet. Direction changes the silhouette, linework and layer
## order; each piece is drawn directly in the same canvas as the world.
const Props = preload("res://view/world/prop_art.gd")
const Director = preload("res://view/actors/animation_director.gd")
const BuildMotion = preload("res://view/actors/build_motion.gd")
const Outfits = preload("res://sim/entities/outfits.gd")
const INK := Color("3a2c22")
const PANTS := Color("b58c54")
const BOOT := Color("694722")
const HAIR := Color("543824")
## Hair colours chosen by id: chestnut, dark brown, auburn, fair, grey.
const HAIRS := [Color("6a4630"), Color("3b2c25"), Color("8a4f2c"), Color("b98d4e"), Color("8c857a")]
const EYES := [Color("4f7b74"), Color("5b6f8c"), Color("6b4d33"), Color("55684a")]
const CLOTH := [Color("d7d0ad"), Color("c8b086"), Color("a5ab8c"), Color("d5bc91")]
const VESTS := [Color("968057"), Color("887b57"), Color("a07551"), Color("8c9371")]

## How a body lies after a fall. Per style: hand, knee and foot offsets (left, right) in the
## upright figure's own pixels (x across, y down), measured from shoulder or hip, plus the head
## and chest shift and an extra twist of the whole body. Arms are flung well away from the torso.
const LYING_STYLES := {
	"back": {"hands": [Vector2(-18, -4), Vector2(12, -19)], "knees": [Vector2(-4, 11), Vector2(4, 11)], "feet": [Vector2(-9, 22), Vector2(8, 22)], "head": Vector2(0, 0), "chest": Vector2(0, 0), "twist": 0.0},
	"front": {"hands": [Vector2(-11, -20), Vector2(15, -12)], "knees": [Vector2(-2, 11), Vector2(3, 11)], "feet": [Vector2(-3, 22), Vector2(7, 21)], "head": Vector2(0, 1), "chest": Vector2(0, 0), "twist": 0.0},
	"side": {"hands": [Vector2(-6, -18), Vector2(15, 6)], "knees": [Vector2(-8, 8), Vector2(5, 11)], "feet": [Vector2(-3, 16), Vector2(-1, 21)], "head": Vector2(-2, 3), "chest": Vector2(-1, 1), "twist": -0.1},
	"sprawl": {"hands": [Vector2(-21, -10), Vector2(21, -8)], "knees": [Vector2(-9, 10), Vector2(9, 10)], "feet": [Vector2(-16, 20), Vector2(16, 19)], "head": Vector2(2, 0), "chest": Vector2(0, 0), "twist": 0.22},
	"curled": {"hands": [Vector2(-3, 8), Vector2(5, 9)], "knees": [Vector2(-8, 8), Vector2(8, 9)], "feet": [Vector2(-3, 14), Vector2(4, 15)], "head": Vector2(0, 6), "chest": Vector2(0, 3), "twist": 0.12},
	"slump": {"hands": [Vector2(-13, 12), Vector2(11, -3)], "knees": [Vector2(-3, 10), Vector2(7, 8)], "feet": [Vector2(-9, 19), Vector2(12, 15)], "head": Vector2(3, 5), "chest": Vector2(1, 2), "twist": -0.18},
	"rest": {"hands": [Vector2(-8, 12), Vector2(8, 12)], "knees": [Vector2(-3, 11), Vector2(3, 11)], "feet": [Vector2(-3, 22), Vector2(3, 22)], "head": Vector2(0, 0), "chest": Vector2(0, 0), "twist": 0.0}}

## Colours for the legs and feet, and the hat item, set each draw from what the person wears.
var pants_color: Color = PANTS
var boot_color: Color = BOOT
var hat_item: String = "<legacy>"

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
	# Characters face one of eight directions: up, down, left, right and the four diagonals.
	heading = snappedf(float(value.get("heading", PI / 2.0)), PI / 4.0)
	forward = Vector2.from_angle(heading)
	across = Vector2(forward.y, -forward.x)
	# Lying bodies show their face to the viewer, or the back of the head when they fell face-down.
	var lying_action: String = value.get("action", "idle")
	if lying_action == "rest" and int(value.get("rest_rot", -1)) >= 0:
		forward = Vector2.DOWN
		across = Vector2(forward.y, -forward.x)
	if lying_action in ["down", "fall", "getup"]:
		var lying_progress: float = float(value.get("phase", 0.0))
		if lying_action == "down" or (lying_action == "fall" and lying_progress > 0.35) or (lying_action == "getup" and lying_progress < 0.6):
			forward = Vector2.UP if value.get("fall_style", "back") == "front" else Vector2.DOWN
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

## Cartoon outline weight: every shape is inked this much heavier than its nominal width.
const OUTLINE := 0.52

func _shape(points: PackedVector2Array, color: Color, width: float = 1.45) -> void:
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, INK, width * OUTLINE, true)

func _ellipse(center: Vector2, radius: Vector2, angle: float, count: int = 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		points.append(center + (Vector2.from_angle(TAU * i / float(count)) * radius).rotated(angle))
	return points

## Shaded ellipse: a slightly darker rim, a lighter body pulled toward the light (up and left),
## and a small highlight, all under a thin outline. Edge 0 draws a flat fill.
func _oval(center: Vector2, radius: Vector2, color: Color, angle: float = 0.0, edge: float = 1.35) -> void:
	if edge <= 0:
		draw_colored_polygon(_ellipse(center, radius, angle), color)
		return
	_shape(_ellipse(center, radius, angle), color.darkened(0.11), edge * 1.1)
	var toward_light := Vector2(-radius.x * 0.12, -radius.y * 0.16).rotated(angle * 0.0)
	draw_colored_polygon(_ellipse(center + toward_light, radius * 0.84, angle), color)
	if radius.x > 2.4 and radius.y > 2.4:
		var shine := color.lightened(0.17)
		shine.a = 0.55
		draw_colored_polygon(_ellipse(center + Vector2(-radius.x * 0.26, -radius.y * 0.30), radius * 0.42, angle), shine)

func _segment(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var delta := b - a
	_oval(a.lerp(b, 0.5), Vector2(width, delta.length() * 0.5 + width * 0.6), color, delta.angle() - PI / 2.0)

func _build_frame() -> Dictionary:
	var action: String = pose.get("action", "idle")
	var phase: float = pose.get("phase", 0.0)
	var gait: float = float(pose.get("gait_phase", 0.0)) * TAU
	var moving: bool = pose.get("moving", false)
	# 0 = walking pace .. 1 = full sprint. It ramps up when sprinting starts and back down after
	# shift is released, so the gait, lean and arms all ease in and out instead of switching.
	var run_amount: float = clampf(float(pose.get("run_blend", 0.0)), 0.0, 1.0)
	var run_w: float = smoothstep(0.0, 1.0, run_amount)
	var trend: float = float(pose.get("run_trend", 0.0))
	var run := run_amount > 0.5 and moving
	var work := sin(phase * TAU)
	var impact := smoothstep(0.17, 0.45, phase) * (1.0 - smoothstep(0.53, 0.93, phase))
	var build := BuildMotion.build_cycle(phase) if action == "build" else {"carry": 0.0, "raise": 0.0, "hit": 0.0, "check": 0.0}
	if action == "build": impact = build.hit
	var crouch := 0.0
	if action in ["pickup", "drop", "harvest"]:
		var reach_phase := 1.0 - phase if action == "drop" else phase
		crouch = smoothstep(0.02, 0.36, reach_phase) * (1.0 - smoothstep(0.44, 0.96, reach_phase))
	if action == "getup": crouch = maxf(crouch, 0.8 * sin(phase * PI))  # push up onto the knees, then rise
	var bob := 0.0
	if moving and not pose.get("reduced_motion", false):
		# Running has two flight phases per stride: the body rises mid-flight and drops at footfall.
		bob = lerpf(pow(sin(gait), 2.0) * 1.15, pow(sin(gait - TAU * 0.09), 2.0) * 3.6, run_w)
		bob -= 2.2 * maxf(trend, 0.0) * (1.0 - run_w)  # dip into the first push-off stride
	elif not moving and run_w > 0.0:
		bob = -3.0 * run_w  # sink onto the braking leg
	var fold := 9.0 * run_w + crouch * 12.0
	fold += 3.0 * trend * run_w if moving else 0.0  # lean harder while accelerating, ease back while slowing
	if not moving: fold = -5.0 * run_w  # skid to a stop: lean back against the momentum
	if action in ["stagger", "hit"]: fold = -5.0 * sin(phase * PI)
	if action == "fall": fold = -7.0 * sin(phase * PI)
	if action in ["chop", "mine", "punch", "shove"]: fold += impact * 5.0
	if action == "build": fold += build.hit * 5.0 + build.raise * 1.5 - build.check * 1.5  # lean into each blow
	if action == "shoot": fold -= 4.0 * smoothstep(0.0, 0.08, phase) * (1.0 - smoothstep(0.1, 0.55, phase))
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
	var armed := action in ["aim", "shoot", "reload"]
	var recoil := 7.0 * smoothstep(0.0, 0.08, phase) * (1.0 - smoothstep(0.1, 0.55, phase)) if action == "shoot" else 0.0
	var stock := head + _joint(0, 3 - recoil, -8)
	var muzzle := stock + _joint(0, 56, 0)
	var pump := 0.0
	if action == "reload":
		# Muzzle drops while the forend pumps and shells go in at the loading port.
		muzzle = stock + _joint(0, 50, -16)
		pump = absf(sin(phase * TAU))
	elif action == "shoot":
		# Recoil kicks the muzzle up and the gun back into the shoulder, then the forend is worked.
		muzzle = stock + _joint(0, 56, 0) + Vector2(0, -9.0 * smoothstep(0.0, 0.08, phase) * (1.0 - smoothstep(0.1, 0.55, phase)))
		pump = smoothstep(0.55, 0.75, phase) * (1.0 - smoothstep(0.8, 1.0, phase))
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
			hand = stock.lerp(muzzle, 0.31 if side > 0 else 0.64 - 0.17 * pump)
			if action == "reload" and side > 0: hand = stock.lerp(muzzle, 0.42) + Vector2(0, 5.0 + 4.0 * sin(phase * TAU * 2.0))
			elbow = shoulder.lerp(hand, 0.45) + _joint(side * 2, -1, -7)
		elif action in ["hit", "stagger", "fall"]:
			# Flinch: both arms fling outward and up as the body recoils.
			var flare := sin(phase * PI)
			hand = shoulder + _joint(side * (5.0 + 8.0 * flare), 1.0 - 4.0 * flare, -8.0 + 13.0 * flare)
			elbow = shoulder.lerp(hand, 0.5) + _joint(side * 2.5, 0, -4)
		elif action in ["punch", "shove", "melee", "ready", "combat_idle"] or pose.get("ready", false):
			var extension := impact if side > 0 or action == "shove" else 0.0
			hand = chest + _joint(side * 5, 9 + extension * 23, 1 - extension * 3)
			elbow = shoulder.lerp(hand, 0.50) + _joint(side * 3, 0, -8)
		elif action in ["chop", "mine", "build", "saw", "eat", "harvest"]:
			hand = _work_hand(side, action, chest, work, impact)
			elbow = shoulder.lerp(hand, 0.45) + _joint(side * 4, -2, -7)
		elif run_amount > 0.001 and action in ["walk", "run", "idle"]:
			# Running arms: opposite to the legs (the arm swings forward as the other leg drives
			# forward), elbows bent near 90 degrees, hands travelling from hip to chest.
			var opposite := fposmod(gait / TAU + (0.5 if -side > 0 else 0.0), 1.0)
			var swing := cos(TAU * opposite)
			var upper := 0.95 * swing
			var forearm := upper + 1.55 + 0.35 * swing
			var run_elbow := shoulder + _joint(side * 2.6, sin(upper) * 9.5, -cos(upper) * 9.5)
			var run_hand := run_elbow + _joint(side * -1.2, sin(forearm) * 9.0, -cos(forearm) * 9.0)
			if not moving:
				# Braking: arms spread out and down for balance.
				run_elbow = shoulder + _joint(side * 7.0, 2.0, -7.5)
				run_hand = shoulder + _joint(side * 11.5, 5.0, -4.5)
			elbow = elbow.lerp(run_elbow, run_w)
			hand = hand.lerp(run_hand, run_w)
		arms[side] = PackedVector2Array([shoulder, elbow, hand])
	var tilt := 0.0
	var origin := Vector2.ZERO
	# 0 standing .. 1 lying, for the fall, the time on the ground and the climb back up.
	var lying := 0.0
	if action in ["down", "rest"]: lying = 1.0
	elif action == "fall": lying = smoothstep(0.0, 1.0, phase)
	elif action == "getup": lying = 1.0 - smoothstep(0.1, 0.85, phase)
	var lie_scale := 1.0
	var left_leg := leg_joints(-1, hip, gait, moving, run_amount, 23.0 + bob - crouch * 5.0)
	var right_leg := leg_joints(1, hip, gait, moving, run_amount, 23.0 + bob - crouch * 5.0)
	if lying > 0.001:
		var style: String = "rest" if action == "rest" else str(pose.get("fall_style", "back"))
		var data: Dictionary = LYING_STYLES.get(style, LYING_STYLES.back)
		var lie_side: float = float(pose.get("fall_side", 1))
		var rest_rot: int = int(pose.get("rest_rot", -1)) if action == "rest" else -1
		if rest_rot == 1: lie_side = 1.0
		elif rest_rot == 3: lie_side = -1.0
		# Arms are thrown out past their final spot while falling and brace against the ground getting up.
		var flail := sin(clampf(phase, 0.0, 1.0) * PI) if action in ["fall", "getup"] else 0.0
		for arm_side in [-1, 1]:
			var index: int = 0 if arm_side < 0 else 1
			var joints: PackedVector2Array = arms[arm_side]
			var target_hand: Vector2 = joints[0] + (data.hands[index] as Vector2) * (1.0 + 0.3 * flail)
			if action == "getup": target_hand += Vector2(0.0, 10.0 * flail)
			var target_elbow: Vector2 = joints[0].lerp(target_hand, 0.5) + Vector2(arm_side * 2.5, 2.5)
			joints[1] = joints[1].lerp(target_elbow, lying)
			joints[2] = joints[2].lerp(target_hand, lying)
			arms[arm_side] = joints
		for leg_side in [-1, 1]:
			var index: int = 0 if leg_side < 0 else 1
			var leg: PackedVector2Array = left_leg if leg_side < 0 else right_leg
			leg[1] = leg[1].lerp(leg[0] + (data.knees[index] as Vector2), lying)
			leg[2] = leg[2].lerp(leg[0] + (data.feet[index] as Vector2), lying)
			if leg_side < 0: left_leg = leg
			else: right_leg = leg
		head += (data.head as Vector2) * lying
		chest += (data.chest as Vector2) * lying
		tilt = lie_side * lying * (PI / 2.0 + float(data.twist))
		origin = Vector2(-30.0 * lie_side, 1.0) * lying
		if rest_rot == 0 or rest_rot == 2:
			# A bed running up and down the screen: lie along it, head up or head down, foreshortened.
			tilt = 0.0 if rest_rot == 0 else PI
			origin = Vector2(0.0, 24.0 if rest_rot == 0 else -24.0) * lying
			lie_scale = lerpf(1.0, 0.74, lying)
	elif action in ["stagger", "hit"]:
		tilt = sin(phase * PI) * (0.38 if action == "stagger" else 0.26) * signf(forward.x + 0.01)
	return {
		"hip": hip, "chest": chest, "head": head, "cargo": cargo_center, "stock": stock, "muzzle": muzzle,
		"left_arm": arms[-1], "right_arm": arms[1],
		"left_leg": left_leg, "right_leg": right_leg, "lie_scale": lie_scale,
		"origin": origin, "tilt": tilt, "item": item, "quantity": quantity, "carrying": carrying,
		"armed": armed, "impact": impact, "show_cargo": show_cargo, "build_raise": build.raise, "build_carry": build.carry, "build_check": build.check, "pump": pump, "slung": bool(pose.get("slung", false)) and not armed,
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
	# What is actually worn: a missing shirt or trousers shows pale underclothes, missing boots show
	# bare feet, a missing vest leaves the shirt showing, and a missing hat shows the hair.
	var outfit: Dictionary = pose.get("outfit", {})
	pants_color = PANTS
	boot_color = BOOT
	hat_item = "<legacy>"
	if not outfit.is_empty():
		shirt = Outfits.color(str(outfit.get("shirt", "")))
		vest = Outfits.color(str(outfit.get("vest", "")), shirt)
		pants_color = Outfits.color(str(outfit.get("pants", "")))
		boot_color = Outfits.color(str(outfit.get("boots", "")), skin.darkened(0.08))
		hat_item = str(outfit.get("hat", ""))
	var near_side := -1 if across.y < 0 else 1
	var arms: Dictionary = {-1: frame.left_arm, 1: frame.right_arm}
	var legs: Dictionary = {-1: frame.left_leg, 1: frame.right_leg}
	draw_set_transform(frame.origin, frame.tilt, Vector2(1.0, float(frame.get("lie_scale", 1.0))))

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
		if frame.armed: _draw_rifle(frame.stock, frame.muzzle, frame.pump)
	if frame.slung and front >= -0.08: _draw_slung(frame.chest, frame.hip, front)
	_draw_coat(frame.chest, frame.hip, width, vest, shirt)
	if frame.slung and front < -0.08: _draw_slung(frame.chest, frame.hip, front)
	_draw_head(frame.head, skin)
	if not object_behind:
		if frame.show_cargo: _draw_cargo(frame.item, frame.quantity, frame.cargo)
		if frame.armed: _draw_rifle(frame.stock, frame.muzzle, frame.pump)
	elif frame.armed and action == "reload":
		# Seen from behind the tilted gun would vanish behind the body, so it is drawn over it.
		_draw_rifle(frame.stock, frame.muzzle, frame.pump)
	if action == "build" and float(frame.build_carry) > 0.03:
		# The board being carried to its place, held at both ends.
		var held: Vector2 = arms[1][2] - arms[-1][2]
		var along: Vector2 = held.normalized() if held.length() > 0.5 else Vector2.RIGHT
		Props.plank(self, arms[-1][2] - along * 5.0, arms[1][2] + along * 6.0, 2.6, Color("c6a16b"))
	if action in ["chop", "mine", "build", "saw"] and not pose.get("machine_work", false) and not (action == "build" and float(frame.build_carry) > 0.5):
		_draw_tool(action, arms[1][2], frame.impact, float(frame.build_raise))
	if far_arm_in_front:
		_draw_arm(arms[-near_side], shirt, skin)
	if not both_arms_behind:
		_draw_arm(arms[near_side], shirt, skin)
	draw_set_transform(Vector2.ZERO)

## Leg chain for one side. `run` is a 0-1 blend (a bool still works): 0 is the walking
## cycle, 1 the running cycle, and when not moving a non-zero value is the braking stance.
func leg_joints(side: int, hip: Vector2, gait: float, moving: bool, run: Variant = 0.0, hip_height: float = 23.0) -> PackedVector2Array:
	var amount: float = clampf(float(run), 0.0, 1.0)
	var walk := _walk_leg(side, hip, gait, moving)
	if amount <= 0.001: return walk
	var fast := _run_leg(side, hip, hip_height, gait, moving)
	var weight: float = smoothstep(0.0, 1.0, amount)
	return PackedVector2Array([walk[0].lerp(fast[0], weight), walk[1].lerp(fast[1], weight), walk[2].lerp(fast[2], weight)])

func _walk_leg(side: int, hip: Vector2, gait: float, moving: bool) -> PackedVector2Array:
	var cycle := fposmod(gait / TAU + (0.5 if side > 0 else 0.0), 1.0)
	var direction: Vector2 = pose.get("move_direction", forward)
	var stance := 0.57
	var cycle_distance := Director.CELL * Director.WALK_CYCLE_METERS
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
			lift = pow(sin(swing * PI), 1.35) * 5.3
	var travel := Vector2(direction.x, direction.y * 0.49)
	var foot := _joint(side * 5.4, 1.5, 3.0 + lift) + travel * stride
	var top := hip + _joint(side * 5.3, 0, 0)
	var knee := top.lerp(foot, 0.54) + travel * (lift * 0.35 + 2.5)
	return PackedVector2Array([top, knee, foot])

## Running cycle, solved as a two-bone leg so the knee always bends forwards: a short stance
## with the foot landing under the hip, a high heel recovery behind the body, then the knee
## drives forward again. Both feet leave the ground for part of each stride.
func _run_leg(side: int, hip: Vector2, hip_height: float, gait: float, moving: bool) -> PackedVector2Array:
	const THIGH := 13.5
	var foot_reach: float
	var foot_lift: float
	if moving:
		var cycle := fposmod(gait / TAU + (0.5 if side > 0 else 0.0), 1.0)
		var stance := 0.36
		# Stance reach is exactly the ground covered, so planted feet do not slide.
		var reach := Director.CELL * Director.RUN_CYCLE_METERS * stance * 0.5
		if cycle < stance:
			foot_reach = lerpf(reach, -reach, cycle / stance)
			foot_lift = 0.0
		else:
			var swing := (cycle - stance) / (1.0 - stance)
			foot_reach = lerpf(-reach, reach * 1.1, smoothstep(0.0, 1.0, swing))
			foot_lift = 17.0 * pow(sin(PI * pow(swing, 0.75)), 1.2)
	else:
		# Braking stance: one foot planted well ahead, the other trailing.
		var lead := -1 if fposmod(gait / TAU, 1.0) < 0.5 else 1
		foot_reach = 9.0 if side == lead else -3.0
		foot_lift = 0.0
	var span := Vector2(foot_reach, 3.0 + foot_lift - hip_height)
	var length := span.length()
	var limit := THIGH * 2.0 - 0.2
	if length > limit:
		span *= limit / length
		length = limit
	var bend := sqrt(maxf(0.0, THIGH * THIGH - length * length * 0.25))
	var knee_offset := span * 0.5 + Vector2(-span.y, span.x) / maxf(length, 0.001) * bend
	var top := hip + _joint(side * 5.3, 0, 0)
	var knee := _joint(side * 5.3, knee_offset.x, hip_height + knee_offset.y)
	var foot := _joint(side * 5.4, 1.5 + span.x, hip_height + span.y)
	return PackedVector2Array([top, knee, foot])

func _draw_leg(side: int, points: PackedVector2Array) -> void:
	var top := points[0]
	var knee := points[1]
	var foot := points[2]
	var tone := pants_color.darkened(0.13) if across.y * side < -0.02 else pants_color
	_segment(top, knee, 4.9, tone)
	_segment(knee, foot, 3.8, tone.lightened(0.08))
	# Knee patch and a turned-up cuff above the boot.
	_oval(knee, Vector2(3.0, 2.4), tone.darkened(0.12), 0.0, 0.0)
	var shin := (foot - knee).normalized()
	_oval(foot - shin * 3.6, Vector2(4.1, 1.5), tone.lightened(0.2), shin.angle() + PI / 2.0, 0.5)
	# Boot: shaded upper, darker sole, and a lace highlight.
	var shoe := foot + _joint(0, 1.5, 0)
	var rx := 3.8 + absf(forward.x) * 1.9
	_oval(shoe + Vector2(0, 1.4), Vector2(rx + 0.4, 2.0), boot_color.darkened(0.45), forward.x * 0.14, 0.0)
	_oval(shoe, Vector2(rx, 2.9), boot_color, forward.x * 0.14)
	draw_line(shoe + Vector2(-rx * 0.4, -1.4), shoe + Vector2(rx * 0.3, -1.6), boot_color.lightened(0.35), 0.6, true)

func _draw_arm(joints: PackedVector2Array, color: Color, skin: Color) -> void:
	_segment(joints[0], joints[1], 4.25, color)
	_segment(joints[1], joints[2], 3.6, color.lightened(0.06))
	# Shoulder seam, elbow fold and a lighter cuff at the wrist.
	_oval(joints[0], Vector2(3.4, 3.0), color.darkened(0.06), 0.0, 0.0)
	var fore := (joints[2] - joints[1]).normalized()
	draw_line(joints[1] + fore.orthogonal() * 2.8, joints[1] - fore.orthogonal() * 2.8, color.darkened(0.2), 0.6, true)
	_oval(joints[2] - fore * 2.7, Vector2(3.5, 1.5), color.lightened(0.24), fore.angle() + PI / 2.0, 0.5)
	# Hand with a thumb.
	_oval(joints[2], Vector2(3.0, 3.4), skin)
	_oval(joints[2] + fore.orthogonal() * 2.3 + fore * 0.4, Vector2(1.1, 1.9), skin.darkened(0.04), fore.angle(), 0.5)

func _draw_coat(chest: Vector2, hip: Vector2, width: float, vest: Color, shirt: Color) -> void:
	var center := chest.lerp(hip, 0.5)
	var body := PackedVector2Array([
		chest + Vector2(-width * 0.55, -4), chest + Vector2(width * 0.55, -4),
		chest + Vector2(width * 0.87, 0), center + Vector2(width * 0.82, 0),
		hip + Vector2(width * 0.66, 0), hip + Vector2(width * 0.35, 3),
		hip + Vector2(-width * 0.48, 3), hip + Vector2(-width * 0.70, 0),
		center + Vector2(-width * 0.83, 0), chest + Vector2(-width * 0.87, 0),
	])
	_shape(body.duplicate(), vest.darkened(0.1), 1.7)
	# Light from the upper left: a lighter inner panel, a soft shoulder highlight and hem shadow.
	var middle := Vector2.ZERO
	for point in body: middle += point
	middle /= float(body.size())
	var inner := PackedVector2Array()
	for point in body: inner.append(middle + (point - middle) * 0.86 + Vector2(-0.8, -1.2))
	draw_colored_polygon(inner, vest)
	draw_line(chest + Vector2(-width * 0.5, -3.2), chest + Vector2(width * 0.5, -3.2), vest.lightened(0.22), 1.1, true)
	draw_line(hip + Vector2(-width * 0.62, 2.4), hip + Vector2(width * 0.32, 2.7), vest.darkened(0.3), 1.0, true)
	var seam_top := chest + Vector2(forward.x * width * 0.58, -1)
	var seam_low := hip + Vector2(forward.x * width * 0.47, 0)
	if forward.y >= -0.08:
		# Collar opening with the shirt showing, then the front edge and buttons.
		var collar := chest + Vector2(forward.x * 1.5, -3.0)
		draw_colored_polygon(PackedVector2Array([collar + Vector2(-3.6, -1.2), collar + Vector2(3.6, -1.2), collar + Vector2(0, 5.4)]), shirt.lightened(0.1))
		draw_polyline(PackedVector2Array([collar + Vector2(-3.6, -1.2), collar + Vector2(0, 5.4), collar + Vector2(3.6, -1.2)]), INK, 0.7, true)
		draw_line(seam_top, seam_low, vest.darkened(0.32), 1.0, true)
		for side in [-1, 1]:
			var lapel_width := maxf(0.15, absf(forward.y)) * width * 0.58
			_shape(PackedVector2Array([seam_top, seam_top + Vector2(side * lapel_width, -3),
				seam_top + Vector2(side * minf(lapel_width * 0.47, 2.2), 6)]),
				vest.lightened(0.17), 0.8)
		for t in [0.44, 0.65, 0.84]:
			draw_circle(seam_top.lerp(seam_low, t) + Vector2(-2.6 * maxf(0.2, forward.y), 0), 0.85, INK.lightened(0.1), true, -1, true)
	else:
		draw_line(chest + Vector2(forward.x * -3, 2), hip + Vector2(forward.x * -3, -1), vest.darkened(0.24), 1.0, true)
		draw_line(chest + Vector2(-width * 0.55, 3), chest + Vector2(width * 0.55, 3), vest.lightened(0.13), 1.0, true)

func _draw_head(head: Vector2, skin: Color) -> void:
	var hair: Color = HAIRS[posmod(actor_id * 7 + 3, HAIRS.size())]
	var iris: Color = EYES[posmod(actor_id * 5 + 1, EYES.size())]
	# Neck, then the back of the hair behind the head.
	_oval(head + Vector2(0, 8.8), Vector2(3.3, 2.8), skin.darkened(0.1), 0.0, 0.0)
	_oval(head + Vector2(-forward.x * 1.8, -3.0), Vector2(8.6, 7.6), hair)
	var show_face := smoothstep(-0.62, -0.04, forward.y)
	if show_face > 0.01:
		var face := head + Vector2(forward.x * (3.6 + 3.2 * (1.0 - show_face)), 0.2)
		var w := lerpf(1.1, 7.0, show_face)
		var outline := PackedVector2Array([
			face + Vector2(-w * 0.93, -6.4), face + Vector2(w * 0.93, -6.4),
			face + Vector2(w, -1), face + Vector2(w * 0.74, 3.8),
			face + Vector2(w * 0.28, 7.7), face + Vector2(-w * 0.4, 7.5),
			face + Vector2(-w * 0.88, 3.8)])
		_shape(outline.duplicate(), skin.darkened(0.07), 0.8)
		var inner := PackedVector2Array()
		for point in outline: inner.append(face + (point - face) * 0.86 + Vector2(-0.5, -0.7))
		draw_colored_polygon(inner, skin)
		if absf(forward.x) > 0.49 and show_face > 0.65:
			var edge := face + Vector2(signf(forward.x) * w * 0.77, 0)
			_shape(PackedVector2Array([edge + Vector2(0, -2), edge + Vector2(signf(forward.x) * 2.2, 1), edge + Vector2(0, 2.4)]), skin, 0.7)
		for side in [-1, 1]:
			var visibility := smoothstep(-0.12, 0.36, forward.y + side * forward.x * 0.44)
			if visibility < 0.04 or show_face < 0.42: continue
			var eye := face + Vector2(side * 3.0 * maxf(0.3, forward.y) + forward.x * 0.9, -0.6)
			# Ear, cheek blush, eye (white, iris, pupil, glint) and brow.
			if show_face > 0.6: _oval(face + Vector2(side * (w + 0.4), 1.6), Vector2(1.2, 1.9), skin.darkened(0.06), 0.0, 0.5)
			var blush := Color("e39a8a")
			blush.a = 0.32 * visibility
			draw_colored_polygon(_ellipse(eye + Vector2(side * 0.3, 3.0), Vector2(1.9, 1.2), 0.0, 10), blush)
			_oval(eye, Vector2(1.9 * visibility, 1.35), Color("fbf3dc"), 0, 0.5)
			var look := Vector2(forward.x * 0.35, 0)
			draw_colored_polygon(_ellipse(eye + look, Vector2(0.95 * visibility, 1.05), 0.0, 10), iris)
			draw_colored_polygon(_ellipse(eye + look, Vector2(0.45 * visibility, 0.55), 0.0, 8), INK)
			draw_circle(eye + look + Vector2(-0.3, -0.35), 0.28, Color("ffffff"))
			draw_line(eye + Vector2(-2.1 * visibility, -2.0), eye + Vector2(2.1 * visibility, -2.2 - side * 0.15), hair.darkened(0.25), 0.9, true)
		if show_face > 0.65:
			# Nose shadow and a small, slightly upturned mouth.
			draw_line(face + Vector2(forward.x * 1.2, 0.8), face + Vector2(forward.x * 1.2 + 0.4, 3.2), skin.darkened(0.22), 0.8, true)
			var mouth := face + Vector2(forward.x * 1.8, 5.2)
			draw_arc(mouth + Vector2(0, -0.8), 1.9 - absf(forward.x) * 0.6, 0.35, PI - 0.35, 8, INK, 0.9, true)
		# Fringe: a few swept locks across the forehead.
		var fringe := face + Vector2(0, -6.3)
		for lock in range(4):
			var u := float(lock) / 3.0 - 0.5
			var base := fringe + Vector2(u * w * 1.7, 0)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-2.6, -2.8), base + Vector2(2.4, -3.0), base + Vector2(1.4 + u * 1.6, 2.6 - absf(u) * 0.8), base + Vector2(-1.6, 1.6)]), hair.lightened(0.05 * float(lock % 2)))
	var hatless: bool = (hat_item == "") if hat_item != "<legacy>" else (not is_player and posmod(actor_id, 4) == 1)
	if hatless:
		# Windswept top hair: layered tufts over the crown.
		var top := head + Vector2(-forward.x * 1.3, -6.6)
		_shape(PackedVector2Array([top + Vector2(-8, 3), top + Vector2(-7, -3), top + Vector2(-3, -6), top + Vector2(3, -5.4), top + Vector2(8.6, -1.6),
			top + Vector2(7, 3.4), top + Vector2(1, 1.4), top + Vector2(-4, 3.6)]), hair, 0.8)
		for tuft in range(3):
			var o := top + Vector2(-4.0 + tuft * 4.0, -4.6 + float(tuft % 2) * 0.8)
			draw_line(o, o + Vector2(1.6, 3.4), hair.lightened(0.18), 0.8, true)
		return
	var hat: Color = Outfits.color(hat_item, Color("bf9558")) if hat_item != "<legacy>" else (Color("d3a35a") if is_player else Color("bf9558"))
	var brim := head + Vector2(forward.x * 0.8, -6.9)
	_oval(brim, Vector2(12.8, 3.8), hat, -forward.x * 0.09, 1.2)
	var crown := brim + Vector2(-forward.x * 1.35, -3.8)
	_shape(PackedVector2Array([crown + Vector2(-5.9, -1.5), crown + Vector2(5.8, -1.5),
		crown + Vector2(6.2, 3.1), crown + Vector2(2.7, 4.4),
		crown + Vector2(-3.1, 4.2), crown + Vector2(-6.2, 2.8)]), hat.darkened(0.19), 0.8)
	_oval(crown + Vector2(0, -1.6), Vector2(5.8, 1.9), hat.lightened(0.14), 0, 0.7)
	# Hat band.
	draw_line(crown + Vector2(-6.0, 2.4), crown + Vector2(6.0, 2.4), hat.darkened(0.45), 1.8, true)

func _work_hand(side: int, action: String, chest: Vector2, wave: float, impact: float) -> Vector2:
	match action:
		"build":
			var b := BuildMotion.build_cycle(float(pose.get("phase", 0.0)))
			# Working height by the part being built: floor boards low, walls at the chest, roof overhead.
			var base: float = {"floor": -9.0, "roof": 13.0}.get(pose.get("build_kind", ""), 3.0)
			if side > 0:
				var height: float = base + 13.0 * b.raise - 5.0 * b.hit
				var reach: float = 8.0 + 9.0 * b.hit
				height = lerpf(height, base - 1.0, b.carry)
				reach = lerpf(reach, 17.0, b.carry)
				height = lerpf(height, -7.0, b.check)
				reach = lerpf(reach, 5.0, b.check)
				return chest + _joint(4, reach, height)
			var steady: float = base - 2.0 - 1.6 * b.hit
			steady = lerpf(steady, base - 1.0, b.carry)
			steady = lerpf(steady, -8.0, b.check)
			return chest + _joint(-4, lerpf(lerpf(12.5, 5.0, b.check), 6.0, b.carry), steady)
		"chop", "mine":
			return chest + _joint(side * 3, 5 + impact * 16, (12.0 if side > 0 else 5.0) - impact * 23)
		"saw":
			return chest + _joint(side * 6, 10.0 + wave * 5, -8)
		"eat":
			return chest + _joint(side * (4 if side > 0 else 8), 7, 1 + wave * 3 if side > 0 else -13)
		_:
			return chest + _joint(side * 6, 11, -15)

func _draw_tool(action: String, hand: Vector2, impact: float, raise: float = 0.0) -> void:
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
	if action == "build":
		# Hammer: resting forward and down, cocked up and back for the wind-up, swung out on the blow.
		var resting := hand + _joint(0, 8, -9)
		var cocked := hand + _joint(0, -3, 15)
		var struck := hand + _joint(0, 13, -5)
		tip = resting.lerp(cocked, raise).lerp(struck, impact)
	var axis := hand.direction_to(tip)
	if axis.is_zero_approx(): axis = Vector2.UP
	var side := axis.orthogonal()
	_segment(hand, tip, 1.65, Color("966740"))
	draw_line(hand.lerp(tip, 0.20) - side * 0.45, tip - side * 0.45, Color("c09460"), 0.55, true)
	if action == "mine":
		# Pickaxe: a long double-pointed head across the top of the haft.
		for sign in [-1.0, 1.0]:
			Props.polygon(self, PackedVector2Array([tip - axis * 1.2 + side * sign * 1.0, tip + side * sign * 6.4 - axis * 3.0, tip + side * sign * 7.2 - axis * 1.6, tip + axis * 1.2 + side * sign * 1.0]), Color("9aa3a0"))
		draw_line(tip - side * 1.5, tip + side * 1.5, Color("5a625f"), 1.4, true)
	elif action == "chop":
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

## Pump-action shotgun: walnut stock, blued barrel with a magazine tube beneath it,
## a sliding forend and a muzzle flash while the shot is leaving the barrel.
func _draw_rifle(stock: Vector2, muzzle: Vector2, pump: float = 0.0) -> void:
	var axis := (muzzle - stock).normalized()
	var normal := axis.orthogonal()
	var length := stock.distance_to(muzzle)
	var grip := stock.lerp(muzzle, 0.40)
	var receiver := stock.lerp(muzzle, 0.34)
	# Stock with a drop at the comb and a brass butt plate.
	_shape(PackedVector2Array([
		stock - normal * 2.6, receiver - normal * 1.4,
		receiver + normal * 1.9, stock + axis * 4 + normal * 3.8,
		stock + normal * 3.4,
	]), Color("8a5a30"), 1.1)
	draw_line(stock - normal * 2.8, stock + normal * 3.6, Color("c79a52"), 1.2, true)
	draw_line(stock + axis * 3 - normal * 1.4, receiver - axis * 2 - normal * 0.6, Color("b17c46"), 0.5, true)
	# Receiver, barrel and the shorter magazine tube beneath.
	_shape(PackedVector2Array([receiver - normal * 1.5, receiver + axis * 5 - normal * 1.5, receiver + axis * 5 + normal * 2.2, receiver + normal * 2.2]), Color("4f5558"), 1.0)
	_shape(PackedVector2Array([receiver + axis * 5 - normal * 0.9, muzzle - normal * 0.9, muzzle + normal * 0.9, receiver + axis * 5 + normal * 0.9]), Color("5f666a"), 0.95)
	draw_line(receiver + axis * 5 - normal * 0.4, muzzle - normal * 0.4, Color("a6adaa"), 0.5, true)
	var tube_end := stock.lerp(muzzle, 0.84)
	draw_line(receiver + axis * 6 + normal * 2.0, tube_end + normal * 2.0, INK, 2.0, true)
	draw_line(receiver + axis * 6 + normal * 2.0, tube_end + normal * 2.0, Color("737a7c"), 1.0, true)
	# Forend slides back along the tube when pumped.
	var fore_start := stock.lerp(muzzle, 0.52 - 0.14 * pump)
	var fore_end := stock.lerp(muzzle, 0.74 - 0.14 * pump)
	_shape(PackedVector2Array([fore_start + normal * 1.0, fore_end + normal * 1.0, fore_end + normal * 3.5, fore_start + normal * 3.5]), Color("9a6a3a"), 0.95)
	for groove in range(3):
		var g := fore_start.lerp(fore_end, 0.25 + groove * 0.25)
		draw_line(g + normal * 1.2, g + normal * 3.3, Color("5f3f23"), 0.5, true)
	# Trigger guard and loading port.
	draw_arc(grip + normal * 3.0, 2.0, 0.0, PI, 8, INK, 0.8, true)
	draw_line(receiver + axis * 2 + normal * 2.4, receiver + axis * 3.5 + normal * 3.6, Color("c9c0a0"), 0.6, true)
	Props.nail(self, receiver + axis * 3, 0.6)
	draw_line(muzzle - axis * 1.6 - normal, muzzle - axis * 1.6 - normal * 2.2, INK, 0.9, true)
	if pose.get("action", "") == "shoot" and float(pose.get("phase", 1.0)) < 0.2:
		# Blast: a hot core, an orange cone and drifting smoke.
		var burst := 1.0 - float(pose.get("phase", 0.0)) / 0.2
		var cone := PackedVector2Array([muzzle, muzzle + axis * (10 + 8 * burst) + normal * (5 + 3 * burst), muzzle + axis * (19 + 12 * burst), muzzle + axis * (10 + 8 * burst) - normal * (5 + 3 * burst)])
		draw_colored_polygon(cone, Color(1.0, 0.62, 0.18, 0.85 * burst))
		draw_colored_polygon(PackedVector2Array([muzzle, muzzle + axis * (6 + 5 * burst) + normal * 2.4, muzzle + axis * (12 + 7 * burst), muzzle + axis * (6 + 5 * burst) - normal * 2.4]), Color(1.0, 0.92, 0.55, burst))
		for puff in range(3):
			var drift := muzzle + axis * (12.0 + puff * 7.0) + Vector2(0, -3.0 - puff * 3.0)
			draw_circle(drift, 2.2 + puff * 1.6, Color(0.82, 0.82, 0.78, 0.28 * burst))

## Stowed shotgun: a big gun slung over the character's right shoulder, barrel up past the shoulder
## and stock down by the opposite hip. Its on-screen length and thickness are fixed, so it looks the
## same size whichever way the character faces; only the anchor and draw order follow the facing.
const SLUNG_LENGTH := 80.0
const SLUNG_GIRTH := 1.45
func _draw_slung(chest: Vector2, hip: Vector2, front: float) -> void:
	var shoulder := chest + _joint(9.0, -2.0, 7.0)             # the character's right shoulder, slightly behind
	var top := shoulder + Vector2(0.0, -22.0)                    # barrel clears the shoulder
	var hip_side := hip + _joint(-8.0, -3.0, -2.0)
	var axis := (top - hip_side).normalized()
	if axis.length() < 0.5: axis = Vector2.UP
	var bottom := top - axis * SLUNG_LENGTH
	var normal := axis.orthogonal()
	var shade: float = 0.0 if front < -0.08 else 0.12          # a little darker when it hangs behind the body
	var wood := Color("8a5a30").darkened(shade)
	var metal := Color("5f666a").darkened(shade)
	# Stock: wide at the butt, narrowing to the receiver.
	var receiver := bottom.lerp(top, 0.36)
	_shape(PackedVector2Array([bottom - normal * 5.51, receiver - normal * 2.90, receiver + normal * 3.77, bottom + normal * 6.67]), wood, 1.1)
	draw_line(bottom - normal * 5.65, bottom + normal * 6.82, Color("c79a52").darkened(shade), 1.6, true)
	# Receiver, long barrel and magazine tube, with the pump forend on the tube.
	_shape(PackedVector2Array([receiver - normal * 3.19, receiver.lerp(top, 0.14) - normal * 3.19, receiver.lerp(top, 0.14) + normal * 3.77, receiver + normal * 3.77]), Color("4f5558").darkened(shade), 1.0)
	draw_line(receiver.lerp(top, 0.1), top, metal, 4.8, true)
	draw_line(receiver.lerp(top, 0.1), top, Color("aab1ae").darkened(shade), 1.4, true)
	var tube_end := bottom.lerp(top, 0.84)
	draw_line(receiver.lerp(top, 0.12) + normal * 4.35, tube_end + normal * 4.35, metal.darkened(0.15), 3.2, true)
	_shape(PackedVector2Array([bottom.lerp(top, 0.52) + normal * 2.17, bottom.lerp(top, 0.74) + normal * 2.17, bottom.lerp(top, 0.74) + normal * 7.25, bottom.lerp(top, 0.52) + normal * 7.25]), Color("9a6a3a").darkened(shade), 1.0)
	# Sling strap from the muzzle end over the shoulder and across the chest.
	draw_line(bottom.lerp(top, 0.34), chest + Vector2(-3.0, 4.0), Color("5b4330"), 1.2, true)
	draw_line(top.lerp(bottom, 0.12), chest + Vector2(5.0, -1.0), Color("5b4330"), 1.2, true)

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
