extends RefCounted
## Market plaza dressing. Reference points (period market squares and the working
## stalls of frontier towns): a paved trading ground, a well or cross at its heart,
## stalls with trade goods stacked on both sides and behind, bunting strung between
## awnings, a notice board and a hitching rail at the edge, and a parked cart.
const Props = preload("res://view/world/prop_art.gd")
const MapArt = preload("res://view/world/frontier_map_art.gd")
const INK := Color("3b2a1d")
const STONE_A := Color("a39a86")
const STONE_B := Color("8f8672")
const STONE_C := Color("b7ad97")

static func h(a: int, b: int) -> float:
	return fposmod(sin(float(a) * 91.7 + float(b) * 57.3 + 3.0) * 24634.6345, 1.0)

## Irregular cobbles inside a rounded rectangle; denser toward the middle so the edge frays into dirt.
static func paving(c: Node2D, area: Rect2) -> void:
	var step := 11.0
	var cols := int(area.size.x / step)
	var rows := int(area.size.y / step)
	for row in range(rows):
		for col in range(cols):
			var p := area.position + Vector2((col + 0.5 + (0.5 if row % 2 else 0.0)) * step, (row + 0.5) * step)
			var nx := (p.x - area.get_center().x) / (area.size.x * 0.5)
			var ny := (p.y - area.get_center().y) / (area.size.y * 0.5)
			var edge := 1.0 - (absf(nx) * 0.7 + absf(ny) * 0.9)
			if edge < h(col, row) * 0.32 or p.x > area.end.x - 3: continue
			var tone: Color = [STONE_A, STONE_B, STONE_C][int(h(row, col) * 3.0) % 3]
			var size := Vector2(4.2 + h(col, row + 5) * 2.0, 3.2 + h(row, col + 7) * 1.4)
			Props.ellipse(c, p + Vector2((h(col, 2) - 0.5) * 2.0, (h(row, 4) - 0.5) * 2.0), size, tone, 0.0, tone.darkened(0.28), 0.5)

static func well(c: Node2D, p: Vector2) -> void:
	Props.ellipse(c, p + Vector2(0, 10), Vector2(24, 9), Color(0, 0, 0, 0.22), 0.0, INK, 0.0)
	for ring in range(2):
		var y := -ring * 7.0
		Props.ellipse(c, p + Vector2(0, 4 + y), Vector2(19, 8), Color("8c8472").lightened(0.06 * ring), 0.0, INK, 0.9)
	Props.ellipse(c, p + Vector2(0, -6), Vector2(14, 5.5), Color("20303a"), 0.0, Color("5f6b6a"), 0.9)
	Props.ellipse(c, p + Vector2(-3, -6.5), Vector2(5, 1.6), Color("46606a"), 0.0, Color("46606a"), 0.0)
	for x in [-16, 16]:
		c.draw_line(p + Vector2(x, 2), p + Vector2(x, -36), INK, 4.0, true)
		c.draw_line(p + Vector2(x, 2), p + Vector2(x, -36), Color("a37a4a"), 2.2, true)
	c.draw_line(p + Vector2(-16, -33), p + Vector2(16, -33), Color("5a3f28"), 3.0, true)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-23, -33), p + Vector2(23, -33), p + Vector2(0, -50)]), Color("7b5a3a"))
	c.draw_polyline(PackedVector2Array([p + Vector2(-23, -33), p + Vector2(0, -50), p + Vector2(23, -33), p + Vector2(-23, -33)]), INK, 1.2, true)
	c.draw_line(p + Vector2(0, -33), p + Vector2(0, -15), Color("c9b98c"), 1.0, true)
	c.draw_rect(Rect2(p + Vector2(-3, -15), Vector2(6, 6)), Color("7a5636"))

static func sack(c: Node2D, p: Vector2, tone: Color = Color("c4b184")) -> void:
	Props.ellipse(c, p + Vector2(0, 2), Vector2(7, 3), Color(0, 0, 0, 0.2), 0.0, INK, 0.0)
	Props.ellipse(c, p + Vector2(0, -3), Vector2(6.5, 8), tone, 0.0, tone.darkened(0.4), 0.8)
	c.draw_line(p + Vector2(-3, -10), p + Vector2(3, -10), tone.darkened(0.45), 1.6, true)
	c.draw_line(p + Vector2(-3, -9), p + Vector2(3, -9), tone.lightened(0.2), 0.9, true)

static func notice_board(c: Node2D, p: Vector2) -> void:
	for x in [-9, 9]: c.draw_line(p + Vector2(x, 4), p + Vector2(x, -26), INK, 3.2, true)
	c.draw_rect(Rect2(p + Vector2(-14, -30), Vector2(28, 20)), Color("84613d"))
	c.draw_rect(Rect2(p + Vector2(-14, -30), Vector2(28, 20)), INK, false, 1.2)
	for i in range(3):
		var paper := Rect2(p + Vector2(-11 + i * 8, -27 + (i % 2) * 4), Vector2(7, 9))
		c.draw_rect(paper, Color("e8dcb8"))
		c.draw_line(paper.position + Vector2(1, 3), paper.position + Vector2(6, 3), Color("7b6b4a"), 0.7)
		c.draw_line(paper.position + Vector2(1, 5.5), paper.position + Vector2(5, 5.5), Color("7b6b4a"), 0.7)

static func hitching_rail(c: Node2D, p: Vector2, length: float = 70.0) -> void:
	for x in [0.0, length]: c.draw_line(p + Vector2(x, 4), p + Vector2(x, -12), INK, 3.4, true)
	c.draw_line(p + Vector2(-2, -9), p + Vector2(length + 2, -9), INK, 3.4, true)
	c.draw_line(p + Vector2(-2, -9), p + Vector2(length + 2, -9), Color("a77d4a"), 1.8, true)

static func bunting(c: Node2D, a: Vector2, b: Vector2, seed_value: int) -> void:
	var colors: Array = [Color("b5543a"), Color("d9b45a"), Color("5f7f9b"), Color("e1d6b8"), Color("6f8f56")]
	var points := PackedVector2Array()
	for i in range(13):
		var t := float(i) / 12.0
		points.append(a.lerp(b, t) + Vector2(0, sin(t * PI) * 9.0))
	c.draw_polyline(points, Color("4a3a2a"), 1.1, true)
	for i in range(1, 12):
		var q := points[i]
		c.draw_colored_polygon(PackedVector2Array([q + Vector2(-3.5, 0), q + Vector2(3.5, 0), q + Vector2(0, 8)]), colors[(i + seed_value) % colors.size()])

## Goods around one stall: barrels and crates at the ends, sacks of grain or stacked timber behind.
static func stall_goods(c: Node2D, stall_px: Vector2, timber: bool, seed_value: int) -> void:
	var base := stall_px + Vector2(0, 20)
	MapArt.barrel(c, base + Vector2(-16, 6))
	if h(seed_value, 1) > 0.35: MapArt.barrel(c, base + Vector2(-30, 12))
	MapArt.crate(c, base + Vector2(112, 8))
	if h(seed_value, 2) > 0.4: MapArt.crate(c, base + Vector2(126, 14))
	if timber:
		for i in range(4):
			Props.plank(c, base + Vector2(130, -6 - i * 3.5), base + Vector2(160, -5 - i * 3.5), 3.0, Color("b68e59") if i % 2 == 0 else Color("c7a16d"))
	else:
		sack(c, base + Vector2(122, -2), Color("c4b184"))
		sack(c, base + Vector2(134, 3), Color("b5a173"))
		sack(c, base + Vector2(128, -12), Color("cdbb8c"))

## Draws the whole plaza for one settlement. `stalls` are the stall entities.
static func plaza(c: Node2D, center: Vector2, stalls: Array) -> void:
	paving(c, Rect2(center + Vector2(-300, -78), Vector2(600, 270)))
	well(c, center + Vector2(0, 52))
	notice_board(c, center + Vector2(-140, 46))
	hitching_rail(c, center + Vector2(95, 120))
	var ordered := stalls.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.cell[0] < b.cell[0])
	for index in range(ordered.size()):
		var stall: Dictionary = ordered[index]
		var px := Vector2(stall.cell[0] - 1, stall.cell[1]) * 24 - Vector2(12, 12)
		stall_goods(c, px, "plank" in stall.get("sale_items", []), stall.id)
	if ordered.size() >= 2:
		var left := Vector2(ordered[0].cell[0] - 1, ordered[0].cell[1]) * 24 - Vector2(12, 12) + Vector2(96, -26)
		var right := Vector2(ordered[ordered.size() - 1].cell[0] - 1, ordered[ordered.size() - 1].cell[1]) * 24 - Vector2(12, 12) + Vector2(0, -26)
		if absf(right.x - left.x) < 460: bunting(c, left, right, ordered[0].id)
	MapArt.cart(c, center + Vector2(-190, 120))
