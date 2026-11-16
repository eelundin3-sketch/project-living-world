extends RefCounted
## Original ink-outlined frontier figures, drawn from simulation snapshots only.
const INK := Color("29251d")
const SHIRTS := [Color("c6c09a"), Color("9a9b77"), Color("b69568"), Color("8c968a"), Color("b6a887")]

static func oval(canvas: Node2D, center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle: float = TAU * index / 20.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	canvas.draw_colored_polygon(points, color)
	points.append(points[0])
	canvas.draw_polyline(points, INK, 0.9, true)

static func limb(canvas: Node2D, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	canvas.draw_line(a, b, INK, width + 1.8, true)
	canvas.draw_line(a, b, color, width, true)

static func paint(canvas: Node2D, point: Vector2, id: int, tick: int, npc: Dictionary, player: bool, cargo: bool, pose: Dictionary = {}) -> void:
	var action: String = pose.get("action", "idle")
	if action == "down":
		canvas.draw_set_transform(point, PI / 2.0)
		limb(canvas, Vector2(0, -5), Vector2(0, -33), Color("8c8064"), 14)
		oval(canvas, Vector2(0, -38), Vector2(6, 7), Color("caa575"))
		limb(canvas, Vector2(-4, -5), Vector2(-5, 5), Color("81734e"), 5)
		limb(canvas, Vector2(4, -5), Vector2(5, 5), Color("81734e"), 5)
		canvas.draw_set_transform(Vector2.ZERO)
		return
	var phase: float = pose.get("phase", 0.0)
	var gait: float = pose.get("gait_phase", 0.0)
	var moving: bool = pose.get("moving", false)
	var gait_wave: float = gait * TAU
	var facing: float = pose.get("facing", 1.0)
	var heading: float = pose.get("heading", 0.0 if facing > 0 else PI)
	var side_view: float = absf(cos(heading))
	var body_width: float = lerpf(1.18, 0.82, side_view)
	var face_offset: float = side_view * 2.0
	var looking_back: bool = sin(heading) < -0.35
	var bob: float = -absf(sin(gait_wave * 2.0)) * (3.2 if action=="run" else 1.8) if moving and not pose.get("reduced_motion", false) else 0.0
	var bend: float = sin(phase * PI) * 8.0 if action in ["pickup", "drop", "harvest"] else 0.0
	var work: float = sin(phase * TAU)
	var lean: float = -0.08 if action=="run" else (work * 0.09 if action in ["chop", "saw", "build"] else 0.0)
	if action == "hit": lean = -0.20
	elif action == "melee": lean = 0.20 * sin(phase * PI)
	var shirt: Color = Color("778a85") if player else SHIRTS[id % SHIRTS.size()]
	var skin: Color = [Color("e2ca9b"), Color("caa575"), Color("ac835e")][id % 3]
	var trousers := Color("81734e")
	var torso_sway: float = sin(gait_wave) * 1.5 if moving else (sin(float(tick) * 0.06 + id) * 0.35)
	canvas.draw_set_transform(point + Vector2(torso_sway, bob), 0.0, Vector2(facing * body_width, 1.32))
	for side in [-1, 1]:
		var leg_phase: float = gait_wave + (PI if side == 1 else 0.0)
		var leg_swing: float = sin(leg_phase) * (6.5 if action=="run" else 5.0) if moving else 0.0
		var foot_lift: float = maxf(0.0, cos(leg_phase)) * (4.0 if action=="run" else 2.5) if moving else 0.0
		var hip := Vector2(side * 4, -19)
		var knee := Vector2(side * 4 + leg_swing * 0.47, -10 - foot_lift * 0.45 - absf(leg_swing) * 0.12)
		var foot := Vector2(side * 5 + leg_swing, -1 - foot_lift)
		limb(canvas, hip, knee, trousers, 5.4)
		limb(canvas, knee, foot, trousers.darkened(0.12), 4.5)
		limb(canvas, foot + Vector2(0, -3), foot, Color("493b2b"), 4.7)
		var boot := PackedVector2Array([foot + Vector2(-2, -1), foot + Vector2(4, -2), foot + Vector2(7, 0), foot + Vector2(5, 2), foot + Vector2(-2, 2)])
		canvas.draw_colored_polygon(boot, Color("59442c"))
		boot.append(boot[0]); canvas.draw_polyline(boot, INK, 0.8, true)
	canvas.draw_set_transform(point + Vector2(0, bob + bend - 5), lean, Vector2(facing * body_width, 1.32))
	var coat := PackedVector2Array([Vector2(-6, -29), Vector2(6, -29), Vector2(8, -23), Vector2(6, -11), Vector2(-6, -11), Vector2(-8, -23)])
	canvas.draw_colored_polygon(coat, shirt)
	coat.append(coat[0])
	canvas.draw_polyline(coat, INK, 1.1, true)
	canvas.draw_line(Vector2(-5, -23), Vector2(-4, -14), shirt.lightened(0.22), 1.5)
	canvas.draw_line(Vector2(-5, -11), Vector2(5, -11), Color("51432e"), 2)
	canvas.draw_line(Vector2(1, -26), Vector2(1, -13), shirt.darkened(0.25), 1)
	canvas.draw_polyline(PackedVector2Array([Vector2(-5, -28), Vector2(-2, -24), Vector2(0, -27), Vector2(3, -24), Vector2(5, -28)]), INK, 1.2, true)
	canvas.draw_rect(Rect2(-2, -12, 4, 2), Color("c6aa65"))
	for y in [-23, -18]:
		canvas.draw_circle(Vector2(2, y), 0.8, INK)
	var arm_swing: float = sin(gait_wave + PI) * (6.0 if action=="run" else 4.0) if moving and not cargo else 0.0
	var left_hand := Vector2(-9, -18 if cargo else -13 + arm_swing)
	var right_hand := Vector2(9, -18 if cargo else -13 - arm_swing)
	if action in ["aim", "shoot"]:
		var recoil: float = 3.0 if action == "shoot" else 0.0
		left_hand = Vector2(5 - recoil, -26)
		right_hand = Vector2(13 - recoil, -28)
		limb(canvas, Vector2(1 - recoil, -25), Vector2(30 - recoil, -30), Color("8b663f"), 3)
		canvas.draw_line(Vector2(16 - recoil, -30), Vector2(34 - recoil, -32), INK, 2)
	elif action == "melee":
		var swing: float = sin(phase * PI)
		right_hand = Vector2(13 + swing * 7, -25 - swing * 8)
		limb(canvas, right_hand, right_hand + Vector2(10, -11 + swing * 15), Color("b4b4a6"), 3)
	elif action == "chop":
		# Hold/aim, lift, strike, then recoil: the impact occurs halfway through each cycle.
		var swing: float = smoothstep(0.28, 0.5, phase) - smoothstep(0.64, 1.0, phase)
		left_hand = Vector2(4, -35 + swing * 18)
		right_hand = Vector2(10, -41 + swing * 22)
		var head := Vector2(14 - swing * 17, -57 + swing * 33)
		limb(canvas, right_hand + Vector2(-3, 8), head, Color("977146"), 3)
		var blade := PackedVector2Array([head + Vector2(-4, -3), head + Vector2(9, -7), head + Vector2(11, 3), head + Vector2(-3, 3)])
		canvas.draw_colored_polygon(blade, Color("aaa99b"))
		blade.append(blade[0])
		canvas.draw_polyline(blade, INK, 1.5, true)
		if phase >= 0.5 and phase < 0.72:
			var scatter: float = (phase - 0.5) * 60
			for chip in range(3):
				var q := Vector2(-3 + (chip - 1) * scatter, -24 - scatter * 0.4 + chip * 2)
				canvas.draw_line(q, q + Vector2(3, -2), Color("d8b87a"), 2, true)
	elif action == "saw":
		left_hand = Vector2(-8 + work * 5, -22)
		right_hand = Vector2(10 + work * 5, -23)
		if pose.get("machine_work",false):
			left_hand = Vector2(-7+work*2,-34)
			right_hand = Vector2(8+work*2,-32)
		else:
			var saw := Rect2(Vector2(-17 + work * 5, -26), Vector2(37, 6))
			canvas.draw_rect(saw, Color("b2b2a3"))
			canvas.draw_rect(saw, INK, false, 1)
			for tooth in range(9):
				canvas.draw_line(saw.position + Vector2(tooth * 4, 6), saw.position + Vector2(tooth * 4 + 2, 9), INK, 1)
	elif action == "build":
		right_hand = Vector2(12, -27 - work * 9)
		limb(canvas, right_hand, right_hand + Vector2(2, -12), Color("9b7946"), 2)
		canvas.draw_rect(Rect2(right_hand + Vector2(-4, -15), Vector2(13, 5)), INK)
	elif action == "eat":
		right_hand = Vector2(5, -25 - (work + 1) * 3)
		oval(canvas, right_hand, Vector2(3, 2), Color("b89456"))
	elif action in ["pickup", "drop", "harvest"]:
		left_hand = Vector2(-8, -8)
		right_hand = Vector2(8, -8)
	for side in [-1, 1]:
		var shoulder := Vector2(side * 6.5, -26)
		var hand: Vector2 = left_hand if side == -1 else right_hand
		var elbow := shoulder.lerp(hand, 0.53) + Vector2(side * 2.4, 1.5)
		limb(canvas, shoulder, elbow, shirt, 4.8)
		limb(canvas, elbow, hand, shirt.lightened(0.08), 3.8)
		canvas.draw_line(hand + Vector2(-2, -2), hand + Vector2(2, -2), shirt.darkened(0.35), 1)
	oval(canvas, left_hand, Vector2(2.6, 3), skin)
	oval(canvas, right_hand, Vector2(2.6, 3), skin)
	var face := PackedVector2Array([Vector2(-5.5, -39), Vector2(5.5, -39), Vector2(5, -32), Vector2(3, -28), Vector2(-2, -28), Vector2(-5, -32)])
	canvas.draw_colored_polygon(face, Color("63432d") if pose.get("machine_work",false) or looking_back else skin)
	face.append(face[0])
	canvas.draw_polyline(face, INK, 1.0, true)
	canvas.draw_line(Vector2(-4, -35), Vector2(-3, -30), Color("564735"), 2)
	if not looking_back or action == "chop":
		var eyes: Array = [1.5] if side_view > 0.8 else [-2.5, 2.5]
		for eye_x in eyes:
			canvas.draw_circle(Vector2(eye_x + face_offset, -34), 1.2, Color("eee8c9"))
			canvas.draw_circle(Vector2(eye_x + face_offset + 0.3, -34), 0.5, Color("354c40"))
		canvas.draw_line(Vector2(face_offset, -33), Vector2(face_offset + 1, -31), skin.darkened(0.25), 1)
		canvas.draw_line(Vector2(face_offset - 2, -29), Vector2(face_offset + 2, -29), INK, 1)
	if id % 3 == 0 and not pose.get("machine_work",false):
		canvas.draw_arc(Vector2(0, -31), 4.5, 0.1, 2.8, 10, Color("5b4933"), 2)
	# Visible hair beneath the brim, distinct from skin and clothing.
	canvas.draw_arc(Vector2(0, -36), 5.5, 3.2, 6.2, 12, Color("4a3528"), 2.5)
	var hat := Color("b7985c") if not player else Color("b58e48")
	if player or id % 4 != 1:
		oval(canvas, Vector2(0, -39), Vector2(11.5, 3.7), hat)
		var crown := PackedVector2Array([Vector2(-6, -40), Vector2(-5, -47), Vector2(5, -47), Vector2(7, -40)])
		canvas.draw_colored_polygon(crown, hat)
		crown.append(crown[0])
		canvas.draw_polyline(crown, INK, 1.0, true)
		canvas.draw_line(Vector2(-5, -41), Vector2(6, -41), Color("62492d"), 2)
		oval(canvas, Vector2(0, -47), Vector2(5, 1.7), hat.lightened(0.12))
	else:
		var hair := PackedVector2Array([Vector2(-6,-34), Vector2(-7,-41), Vector2(-3,-44), Vector2(0,-42), Vector2(4,-44), Vector2(7,-40), Vector2(5,-34), Vector2(3,-39), Vector2(-2,-38), Vector2(-4,-40)])
		canvas.draw_colored_polygon(hair, Color("63432d"))
		if id % 3 == 1:
			limb(canvas, Vector2(-5,-36), Vector2(-7,-23), Color("63432d"), 3)
	if npc.get("occupation", "") == "Builder":
		canvas.draw_rect(Rect2(-4, -22, 8, 11), Color("746042"))
	if npc.get("occupation", "") == "Guard":
		limb(canvas, Vector2(11, -4), Vector2(12, -35), Color("967b4d"), 2)
	var item: String = pose.get("cargo_item", "log" if cargo else "")
	var quantity: int = pose.get("cargo_quantity", 1 if cargo else 0)
	if action == "drop" and quantity == 0:
		item = pose.get("last_item", "")
		quantity = pose.get("last_quantity", 0)
	if action == "pickup" and quantity == 0:
		item = pose.get("expected_item", "")
		quantity = pose.get("expected_quantity", 0)
	if quantity > 0:
		var lift: float = -18.0
		if action == "pickup": lift = lerpf(-3, -18, phase)
		elif action == "drop": lift = lerpf(-18, -3, phase)
		canvas.draw_set_transform(point + Vector2(0, bob - 5), 0, Vector2(facing * body_width, 1.32))
		match item:
			"log":
				for index in range(mini(3, ceili(quantity / 2.0))):
					var y: float = lift - index * 5
					limb(canvas, Vector2(-13, y), Vector2(13, y - 2), Color("997347"), 5)
					oval(canvas, Vector2(13, y - 2), Vector2(3, 2.5), Color("d0af73"))
			"plank":
				for index in range(mini(3, quantity)):
					var rect := Rect2(-15, lift - index * 4, 30, 4)
					canvas.draw_rect(rect, Color("c4a26a"))
					canvas.draw_rect(rect, INK, false, 1)
			"bandage":
				canvas.draw_rect(Rect2(-8,lift-7,16,10),Color("e3dfca"))
				canvas.draw_rect(Rect2(-8,lift-7,16,10),INK,false,1)
				canvas.draw_line(Vector2(-2,lift-7),Vector2(-2,lift+3),Color("a8aa92"),2)
			"antiseptic":
				canvas.draw_rect(Rect2(-5,lift-12,10,16),Color("728b76"))
				canvas.draw_rect(Rect2(-4,lift-15,8,4),Color("c3ba95"))
			"food":
				oval(canvas, Vector2(0, lift - 3), Vector2(9, 8), Color("c1b080"))
				canvas.draw_line(Vector2(-5, lift - 10), Vector2(5, lift - 10), INK, 2)
	if action == "rest":
		canvas.draw_string(ThemeDB.fallback_font, Vector2(12, -42 - sin(phase * TAU) * 3), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("efe3bc"))
	canvas.draw_set_transform(Vector2.ZERO)
