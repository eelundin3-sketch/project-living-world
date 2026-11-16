extends RefCounted
## Furniture drawn in a low oblique view, with material detail sized to the prop.
const Props = preload("res://view/world/prop_art.gd")
const INK := Color("3b2a1d")

static func slab(c: Node2D, r: Rect2, color: Color, depth: float = 5.0) -> void:
	var front := Rect2(Vector2(r.position.x, r.end.y), Vector2(r.size.x, depth))
	c.draw_rect(front, color.darkened(0.34))
	c.draw_rect(front, INK, false, 0.8)
	c.draw_rect(r, color)
	c.draw_rect(r, INK, false, 1.0)
	c.draw_line(r.position + Vector2(1, 1), Vector2(r.end.x - 1, r.position.y + 1), color.lightened(0.20), 0.75, true)

static func timber(c: Node2D, r: Rect2, color: Color, depth: float = 4.0) -> void:
	slab(c, r, color, depth)
	if r.size.x > 9 and r.size.y > 4:
		Props.grain(c, r.grow(-1), color.darkened(0.18))

static func bed(c: Node2D, p: Vector2, color: Color) -> void:
	c.draw_rect(Rect2(p + Vector2(3, 7), Vector2(65, 32)), Color(0, 0, 0, 0.23))
	timber(c, Rect2(p, Vector2(64, 33)), Color("795332"))
	for leg in [Vector2(3, 30), Vector2(59, 30)]:
		timber(c, Rect2(p + leg, Vector2(4, 5)), Color("725034"), 1.5)
	slab(c, Rect2(p + Vector2(5, 4), Vector2(54, 24)), Color("d8cfb2"), 2.0)
	slab(c, Rect2(p + Vector2(19, 4), Vector2(40, 25)), color, 1.7)
	for y in [8, 16, 24]:
		c.draw_polyline(PackedVector2Array([p + Vector2(21, y), p + Vector2(33, y + 1),
			p + Vector2(44, y + 0.4), p + Vector2(57, y + 1)]), color.darkened(0.21), 0.62, true)
	c.draw_line(p + Vector2(22, 5), p + Vector2(22, 28), color.lightened(0.32), 1.1, true)
	c.draw_line(p + Vector2(56, 5), p + Vector2(56, 28), color.darkened(0.22), 0.75, true)
	Props.ellipse(c, p + Vector2(12, 16), Vector2(6.5, 8.8), Color("eee1c2"), -0.14, Color("a89b7f"))
	Props.ellipse(c, p + Vector2(11.6, 15.5), Vector2(4.2, 7.1), Color("e3d7b9"), -0.14, Color("d1c3a3"), 0.55)
	timber(c, Rect2(p - Vector2(2, 3), Vector2(6, 35)), Color("946239"))
	for corner in [Vector2(0, -2), Vector2(0, 30), Vector2(61, 1), Vector2(61, 31)]:
		Props.nail(c, p + corner, 0.7)

static func table(c: Node2D, p: Vector2) -> void:
	for offset in [Vector2(3, 4), Vector2(44, 4), Vector2(3, 30), Vector2(44, 30)]:
		timber(c, Rect2(p + offset, Vector2(4, 8)), Color("67452e"), 1.0)
	timber(c, Rect2(p, Vector2(50, 32)), Color("a77a4a"), 4.0)
	for y in [8, 16, 24]:
		c.draw_line(p + Vector2(1, y), p + Vector2(49, y), Color("704c31"), 0.65)
		Props.grain(c, Rect2(p + Vector2(2, y - 7), Vector2(46, 7)), Color("92603c"))
	for x in [3, 47]:
		for y in [3, 28]: Props.nail(c, p + Vector2(x, y), 0.68)
	Props.ellipse(c, p + Vector2(15, 17), Vector2(7.3, 5.9), Color("d6c4a1"), 0.0, Color("73634d"))
	Props.ellipse(c, p + Vector2(15, 17), Vector2(4.8, 3.8), Color("ac9373"), 0.0, Color("ad9d84"), 0.55)
	Props.ellipse(c, p + Vector2(35, 14), Vector2(2.6, 2.0), Color("d4a676"))
	slab(c, Rect2(p + Vector2(30, 13), Vector2(6, 6)), Color("c4a17c"), 1.0)
	Props.ellipse(c, p + Vector2(33, 13), Vector2(3, 2), Color("795843"), 0.0, Color("e5c396"), 0.55)

static func shelf(c: Node2D, p: Vector2, width: float = 58) -> void:
	timber(c, Rect2(p, Vector2(width, 31)), Color("785134"), 4.0)
	c.draw_rect(Rect2(p + Vector2(3, 3), Vector2(width - 6, 25)), Color("543929"))
	for row in range(2):
		for col in range(int((width - 5) / 13)):
			var q := p + Vector2(7 + col * 13, 11 + row * 14)
			match (col + row * 2) % 3:
				0:
					timber(c, Rect2(q - Vector2(1, 6), Vector2(9, 7)), Color("aa8555"), 1)
					c.draw_line(q - Vector2(0, 5), q + Vector2(7, 0), Color("d2ad71"), 0.8, true)
				1:
					Props.ellipse(c, q + Vector2(3, -3), Vector2(3.5, 4.5), Color("9a886a"))
					Props.ellipse(c, q + Vector2(3, -6), Vector2(2.4, 1.2), Color("b9a07d"))
				2:
					c.draw_rect(Rect2(q + Vector2(0, -6), Vector2(8, 7)), Color("838b6e"))
					c.draw_line(q + Vector2(1, -5), q + Vector2(7, -5), Color("b2b397"), 0.7, true)
		timber(c, Rect2(p + Vector2(1, 12 + row * 14), Vector2(width - 2, 3)), Color("b08351"), 1.6)
	for x in [2.0, width - 2.5]:
		for y in [3, 15, 29]: Props.nail(c, p + Vector2(x, y), 0.65)

static func stove(c: Node2D, p: Vector2) -> void:
	slab(c, Rect2(p, Vector2(27, 30)), Color("5e6058"))
	slab(c, Rect2(p + Vector2(4, 12), Vector2(19, 14)), Color("3f433f"), 1.3)
	for side in [7, 20]: Props.nail(c, p + Vector2(side, 16))
	c.draw_line(p + Vector2(10, 20), p + Vector2(18, 20), Color("a28b66"), 1.6, true)
	c.draw_circle(p + Vector2(11, 7), 5.4, Color("373a36"), true, -1, true)
	c.draw_arc(p + Vector2(11, 7), 3.7, 0, TAU, 24, Color("787971"), 0.6, true)
	c.draw_line(p + Vector2(21, 0), p + Vector2(21, -20), Color("3c3d36"), 7, true)
	c.draw_line(p + Vector2(19.5, 0), p + Vector2(19.5, -20), Color("787b6c"), 1.2, true)
	Props.ellipse(c, p + Vector2(21, -20), Vector2(3.8, 1.8), Color("292d2a"), 0.0, Color("77766c"))

static func workbench(c: Node2D, p: Vector2, phase: float = 0.0, logs: int = 0) -> void:
	var metal := Color("596461")
	c.draw_rect(Rect2(p + Vector2(1, 16), Vector2(97, 26)), Color(0, 0, 0, 0.20))
	for x in [7, 84]:
		timber(c, Rect2(p + Vector2(x, 23), Vector2(7, 14)), Color("795436"), 3)
	timber(c, Rect2(p + Vector2(8, 33), Vector2(78, 3)), Color("997046"), 2)
	timber(c, Rect2(p, Vector2(96, 29)), Color("9c7049"), 4.5)
	for y in [4.0, 23.0]:
		slab(c, Rect2(p + Vector2(4, y), Vector2(88, 3.3)), Color("68736e"), 1.2)
		for x in [8.0, 29.0, 70.0, 87.0]:
			Props.nail(c, p + Vector2(x, y + 1.7), 0.7)
	for x in [13.0, 28.0, 43.0, 74.0, 88.0]:
		slab(c, Rect2(p + Vector2(x, 8), Vector2(2.4, 15)), Color("a4aba0"), 0.8)
	slab(c, Rect2(p + Vector2(9, 27), Vector2(20, 11)), metal.darkened(0.19), 1.6)
	for fin in range(4):
		var x := 11.5 + fin * 3.2
		c.draw_line(p + Vector2(x, 29), p + Vector2(x, 35), metal.lightened(0.28), 0.85, true)
	var drive := p + Vector2(27, 34)
	var arbor := p + Vector2(58, 31)
	c.draw_line(drive + Vector2(0, -4), arbor + Vector2(0, -5), Color("352e2a"), 2.8, true)
	c.draw_line(drive + Vector2(0, 4), arbor + Vector2(0, 5), Color("433a30"), 2.8, true)
	for pulley in [drive, arbor]:
		Props.ellipse(c, pulley, Vector2(5.7, 5.1), metal)
		for spoke in range(3):
			c.draw_line(pulley, pulley + Vector2.from_angle(phase + spoke * TAU / 3.0) * 4, Color("b8bdab"), 0.72, true)
		Props.nail(c, pulley, 1.1)

	slab(c, Rect2(p + Vector2(43, 10), Vector2(30, 11)), metal.darkened(0.28), 1.1)
	if logs > 0:
		var feed := sin(phase * 0.35) * 4.0
		Props.log_piece(c, p + Vector2(6 + feed, 15), p + Vector2(55 + feed, 15), 5.0)
	var center := p + Vector2(58, 12)
	var teeth := PackedVector2Array()
	for index in range(64):
		var angle := phase + index * TAU / 64.0
		var radius := 12.4 if index % 4 in [0, 1] else 10.8
		teeth.append(center + Vector2(cos(angle), sin(angle) * 0.66) * radius)
	Props.polygon(c, teeth, Color("b6bfb6"), Color("394441"), 0.66)
	Props.ellipse(c, center, Vector2(7.6, 4.9), Color("9ea99f"), 0.0, Color("6e7b73"), 0.55)
	Props.ellipse(c, center, Vector2(2.8, 1.9), Color("68756d"))
	Props.nail(c, center, 1.0)
	var guard := PackedVector2Array()
	for i in range(13):
		var angle := PI + i * PI / 12.0
		guard.append(center + Vector2(cos(angle) * 14, sin(angle) * 9.5) + Vector2(0, -0.5))
	c.draw_polyline(guard, Color("4a534e"), 3.1, true)
	c.draw_polyline(guard, Color("8b998e"), 1.45, true)
	Props.nail(c, center + Vector2(14, -0.3), 0.9)
