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
	canvas.draw_polyline(points, INK, 1.4, true)

static func limb(canvas: Node2D, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	canvas.draw_line(a, b, INK, width + 2.6, true)
	canvas.draw_line(a, b, color, width, true)

static func paint(canvas: Node2D, point: Vector2, id: int, tick: int, npc: Dictionary, player: bool, cargo: bool) -> void:
	var moving: bool = not npc.get("path", []).is_empty() or npc.get("status", "").begins_with("Walking")
	var stride: float = sin(float(tick) * 0.85 + id) * 3.0 if moving else 0.0
	var shirt: Color = Color("778a85") if player else SHIRTS[id % SHIRTS.size()]
	var skin: Color = [Color("dbc297"), Color("b89269"), Color("976e4c")][id % 3]
	var trousers := Color("81734e")
	canvas.draw_set_transform(point)
	oval(canvas, Vector2(0, 2), Vector2(11, 3.5), Color(0.08, 0.07, 0.04, 0.3))
	limb(canvas, Vector2(-4, -12), Vector2(-5 - stride * 0.4, -2 + stride * 0.3), trousers, 5)
	limb(canvas, Vector2(4, -12), Vector2(5 + stride * 0.4, -2 - stride * 0.3), trousers, 5)
	oval(canvas, Vector2(-5 - stride * 0.4, -1 + stride * 0.3), Vector2(4.5, 2.5), Color("514832"))
	oval(canvas, Vector2(5 + stride * 0.4, -1 - stride * 0.3), Vector2(4.5, 2.5), Color("514832"))
	oval(canvas, Vector2(0, -20), Vector2(7.5, 11), shirt)
	canvas.draw_line(Vector2(-5, -11), Vector2(5, -11), Color("51432e"), 2)
	canvas.draw_line(Vector2(1, -26), Vector2(1, -13), shirt.darkened(0.25), 1)
	for y in [-23, -18]:
		canvas.draw_circle(Vector2(2, y), 0.8, INK)
	var hand_y: float = -18 if cargo else -13
	limb(canvas, Vector2(-7, -25), Vector2(-9, hand_y + stride), shirt, 4)
	limb(canvas, Vector2(7, -25), Vector2(9, hand_y - stride), shirt, 4)
	oval(canvas, Vector2(-9, hand_y + stride), Vector2(2.6, 3), skin)
	oval(canvas, Vector2(9, hand_y - stride), Vector2(2.6, 3), skin)
	oval(canvas, Vector2(0, -33), Vector2(5.8, 7.2), skin)
	canvas.draw_line(Vector2(-4, -35), Vector2(-3, -30), Color("564735"), 2)
	canvas.draw_circle(Vector2(2.5, -33), 1.0, INK)
	canvas.draw_line(Vector2(1, -28), Vector2(4, -29), INK, 1)
	if id % 3 == 0:
		canvas.draw_arc(Vector2(0, -31), 4.5, 0.1, 2.8, 10, Color("5b4933"), 2)
	var hat := Color("ad9257") if not player else Color("927947")
	oval(canvas, Vector2(0, -38), Vector2(11, 3.3), hat)
	oval(canvas, Vector2(0, -42), Vector2(6.5, 4.4), hat)
	canvas.draw_arc(Vector2(0, -42), 6, 0.15, 3, 12, Color("59472f"), 2.2)
	if npc.get("occupation", "") == "Builder":
		canvas.draw_rect(Rect2(-4, -22, 8, 11), Color("746042"))
	if npc.get("occupation", "") == "Guard":
		limb(canvas, Vector2(11, -4), Vector2(12, -35), Color("967b4d"), 2)
	if cargo:
		limb(canvas, Vector2(-10, -17), Vector2(10, -19), Color("997347"), 6)
		oval(canvas, Vector2(10, -19), Vector2(3, 3), Color("c2a16c"))
	canvas.draw_set_transform(Vector2.ZERO)
