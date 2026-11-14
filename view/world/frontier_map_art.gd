extends RefCounted
## Original, deterministic presentation shapes; no gameplay state is stored here.
const INK := Color("30291e")
const Character = preload("res://view/actors/frontier_character.gd")

static func box(c: Node2D, r: Rect2, color: Color, border: float = 2.0) -> void:
	c.draw_rect(r, color)
	c.draw_rect(r, INK, false, border)

static func poly(c: Node2D, points: PackedVector2Array, color: Color) -> void:
	c.draw_colored_polygon(points, color)
	var edge := points.duplicate()
	edge.append(edge[0])
	c.draw_polyline(edge, INK, 2, true)

static func ground(c: Node2D, x: int, y: int) -> void:
	var p := Vector2(x, y) * 24
	var h: int = absi(x * 7919 + y * 104729 + x * y * 17)
	# Continuous ground with irregular flecks, never a visible checkerboard grid.
	if h % 5 == 0:
		c.draw_circle(p + Vector2(h % 19, h % 13), 7 + h % 5, Color("72764a"))
	if h % 3 == 0:
		var q := p + Vector2(h % 17, h % 23)
		c.draw_line(q, q + Vector2(-3, -5), Color("4d5837"), 1, true)
		c.draw_line(q + Vector2(1, 0), q + Vector2(3, -7), Color("4d5837"), 1, true)
	if h % 7 == 0:
		c.draw_line(p + Vector2(8, 10), p + Vector2(11, 11), Color("aa9c68"), 2, true)

static func tree(c: Node2D, p: Vector2, logs: int, id: int) -> void:
	Character.oval(c, p + Vector2(7, 3), Vector2(19, 6), Color(0.15, 0.12, 0.06, 0.22))
	if logs == 0:
		box(c, Rect2(p - Vector2(7, 10), Vector2(14, 12)), Color("83623c"))
		Character.oval(c, p + Vector2(0, -10), Vector2(8, 4), Color("bd9860"))
		return
	poly(c, PackedVector2Array([p + Vector2(-8, 1), p + Vector2(-4, -37), p + Vector2(5, -39), p + Vector2(9, 1)]), Color("83623c"))
	c.draw_line(p + Vector2(0, -29), p + Vector2(3, -2), Color("bd9860"), 2)
	var leaf := Color("6b7541") if id % 2 == 0 else Color("828048")
	for offset in [Vector2(-15, -32), Vector2(15, -34), Vector2(0, -53), Vector2(-5, -39)]:
		Character.oval(c, p + offset, Vector2(19, 17), leaf)
		c.draw_arc(p + offset - Vector2(3, 3), 11, 3.5, 5.2, 9, leaf.lightened(0.2), 2, true)

static func rock(c: Node2D, p: Vector2) -> void:
	poly(c, PackedVector2Array([p + Vector2(-11, 5), p + Vector2(-12, -4), p + Vector2(-5, -12), p + Vector2(7, -9), p + Vector2(12, 1), p + Vector2(7, 7)]), Color("8c896f"))
	c.draw_polyline(PackedVector2Array([p + Vector2(-5, -10), p + Vector2(0, -1), p + Vector2(10, 1)]), Color("b4ad8b"), 2, true)

static func crate(c: Node2D, p: Vector2) -> void:
	box(c, Rect2(p - Vector2(10, 16), Vector2(20, 19)), Color("a87b45"))
	for x in [-5, 1, 6]:
		c.draw_line(p + Vector2(x, -14), p + Vector2(x, 2), Color("72522f"), 1)
	c.draw_line(p + Vector2(-9, -14), p + Vector2(9, 1), Color("dab47a"), 3)

static func barrel(c: Node2D, p: Vector2) -> void:
	Character.oval(c, p - Vector2(0, 9), Vector2(10, 14), Color("956b3d"))
	for y in [-15, -3]:
		c.draw_line(p + Vector2(-9, y), p + Vector2(9, y), Color("514b3b"), 3)
	Character.oval(c, p - Vector2(0, 21), Vector2(9, 4), Color("ba945b"))

static func farm(c: Node2D, p: Vector2, food: int) -> void:
	box(c, Rect2(p - Vector2(58, 36), Vector2(116, 72)), Color("705236"))
	for row in range(4):
		c.draw_line(p + Vector2(-53, row * 17 - 29), p + Vector2(53, row * 17 - 29), Color("3d3021"), 3)
		for column in range(7):
			var q := p + Vector2(column * 15 - 46, row * 17 - 30)
			if food > 0:
				Character.oval(c, q, Vector2(5, 3), Color("9b9a51"))
				c.draw_line(q, q + Vector2(-4, -8), Color("b7b66d"), 2)
				c.draw_line(q, q + Vector2(5, -6), Color("525c32"), 2)
	for dx in [-62, 62]:
		box(c, Rect2(p + Vector2(dx, -38), Vector2(4, 78)), Color("a7844d"), 1)

static func building(c: Node2D, entity: Dictionary, rect: Rect2, stock: Dictionary) -> void:
	c.draw_rect(Rect2(rect.position + Vector2(8, 8), rect.size), Color(0.12, 0.09, 0.05, 0.3))
	box(c, rect, Color("a37c49"), 3)
	for row in range(int(rect.size.y / 12)):
		var y: float = rect.position.y + row * 12
		c.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("715231"), 1.5)
		for column in range(4):
			var x: float = rect.position.x + 14 + column * 48 + (row % 2) * 20
			if x < rect.end.x:
				c.draw_line(Vector2(x, y), Vector2(x, y + 12), Color("715231"), 1)
	var wall := Color("ad8954")
	# Wall thickness corresponds exactly to the blocked perimeter cells.
	box(c, Rect2(rect.position - Vector2(0, 15), Vector2(rect.size.x, 39)), wall)
	for y in range(3):
		c.draw_line(rect.position + Vector2(0, y * 12 - 12), rect.position + Vector2(rect.size.x, y * 12 - 12), Color("6f4f2d"), 2)
	for x in [rect.position.x, rect.end.x - 24]:
		box(c, Rect2(x, rect.position.y + 24, 24, rect.size.y - 24), wall)
		for y in range(int(rect.size.y / 18)):
			c.draw_line(Vector2(x, rect.position.y + y * 18), Vector2(x + 24, rect.position.y + y * 18), Color("715231"), 1)
	var door_x: float = entity.cell[0] * 24.0
	box(c, Rect2(rect.position.x, rect.end.y - 24, door_x - 12 - rect.position.x, 24), wall)
	box(c, Rect2(door_x + 12, rect.end.y - 24, rect.end.x - door_x - 12, 24), wall)
	box(c, Rect2(door_x - 12, rect.end.y - 24, 24, 24), Color("c6a16a"), 1)
	# Open door leaf beside the clear threshold, never painted across the passage.
	box(c, Rect2(door_x + 12, rect.end.y - 27, 6, 29), Color("65482d"), 1)
	for x in [rect.position.x + 5, rect.end.x - 12]:
		box(c, Rect2(x, rect.position.y - 17, 7, 30), Color("65482d"), 1)
	var inside: Vector2 = rect.position + Vector2(37, 46)
	match entity.kind:
		"home":
			for dx in [0, rect.size.x - 95]:
				box(c, Rect2(inside + Vector2(dx, 0), Vector2(24, 43)), Color("695035"))
				box(c, Rect2(inside + Vector2(dx + 2, 12), Vector2(20, 28)), Color("92927b"), 1)
				box(c, Rect2(inside + Vector2(dx + 3, 3), Vector2(18, 9)), Color("d5c6a1"), 1)
			box(c, Rect2(rect.get_center() - Vector2(13, 0), Vector2(26, 20)), Color("825b34"))
			Character.oval(c, rect.get_center() + Vector2(0, 7), Vector2(5, 3), Color("c6b787"))
		"warehouse", "market":
			for index in range(4):
				crate(c, inside + Vector2(index * 32, 12))
			barrel(c, inside + Vector2(0, 53))
			barrel(c, inside + Vector2(27, 53))
			if int(stock.get("log", 0)) > 0:
				for row in range(3):
					Character.limb(c, inside + Vector2(85, 35 + row * 7), inside + Vector2(134, 35 + row * 7), Color("9d7440"), 6)
		"sawmill":
			box(c, Rect2(inside + Vector2(10, 8), Vector2(104, 27)), Color("715033"))
			Character.limb(c, inside + Vector2(2, 16), inside + Vector2(124, 16), Color("bd945b"), 9)
			c.draw_circle(inside + Vector2(65, 14), 12, INK)
			c.draw_circle(inside + Vector2(65, 14), 9, Color("b6b2a0"))
			for index in range(10):
				var angle: float = index * TAU / 10
				c.draw_line(inside + Vector2(65, 14), inside + Vector2(65, 14) + Vector2(cos(angle), sin(angle)) * 13, INK, 1)
			crate(c, inside + Vector2(0, 60))

static func cart(c: Node2D, p: Vector2) -> void:
	for x in [-18, 18]:
		Character.oval(c, p + Vector2(x, 2), Vector2(5, 10), Color("4b3b25"))
	box(c, Rect2(p - Vector2(20, 21), Vector2(40, 25)), Color("a17b45"))
	for x in range(-15, 20, 7):
		c.draw_line(p + Vector2(x, -19), p + Vector2(x, 2), Color("67482b"), 1)
	crate(c, p + Vector2(-8, -11))
	Character.oval(c, p + Vector2(10, -21), Vector2(8, 10), Color("c4b386"))
	for x in [-12, 12]:
		Character.limb(c, p + Vector2(x, 4), p + Vector2(x, 23), Color("876539"), 2)
