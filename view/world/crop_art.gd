extends RefCounted
## Rye fields and household gardens. Everything is a continuous function of the
## crop's growth permille `t`, so plants lengthen, thicken and change colour
## smoothly rather than switching between sprites.
const Crops = preload("res://sim/farming/crops.gd")
const INK := Color("3b2a1d")
const SOIL := Color("6e4f33")
const SOIL_DARK := Color("4a3422")
const SOIL_LIGHT := Color("8a6843")
const LEAF_YOUNG := Color("7fb04a")
const LEAF_GREEN := Color("5e9a3a")
const STALK_GREEN := Color("8fae48")
const STALK_GOLD := Color("d9b24f")
const EAR_GREEN := Color("a2b955")
const EAR_GOLD := Color("e6bf5a")
const EAR_RIPE := Color("f0cc66")

static func rand01(a: int, b: int) -> float:
	return fposmod(sin(float(a) * 127.1 + float(b) * 311.7 + 17.0) * 43758.5453, 1.0)

## Green until the crop passes 55%, then a steady turn toward golden rye.
static func ripeness(t: float) -> float:
	return clampf((t - 0.5) / 0.5, 0.0, 1.0)

static func plant_height(t: float) -> float:
	return 3.0 + 29.0 * pow(smoothstep(0.0, 0.8, t), 0.85)

static func field(c: Node2D, area: Rect2, plot: Dictionary, wind: float = 0.0) -> void:
	var t: float = Crops.permille(plot) / 1000.0
	var fallow: bool = plot.get("state", "growing") == "fallow"
	var garden: bool = plot.kind == "garden"
	# Tilled bed: base soil, then alternating ridge and furrow bands with a lit top edge.
	c.draw_rect(area.grow(2), SOIL_DARK)
	c.draw_rect(area, SOIL)
	var spacing: float = 11.0 if garden else 15.0
	var rows: int = maxi(2, int(area.size.y / spacing))
	var pitch: float = area.size.y / float(rows)
	for row in range(rows):
		var y: float = area.position.y + pitch * (row + 0.5)
		c.draw_line(Vector2(area.position.x + 2, y + pitch * 0.32), Vector2(area.end.x - 2, y + pitch * 0.32), SOIL_DARK, 2.2)
		c.draw_line(Vector2(area.position.x + 2, y - pitch * 0.18), Vector2(area.end.x - 2, y - pitch * 0.18), SOIL_LIGHT, 1.2)
	# Plants are drawn back row first so nearer rows overlap farther ones.
	if not fallow:
		var step: float = 10.0 if not garden else 8.0
		var columns: int = maxi(2, int((area.size.x - 8.0) / step))
		for row in range(rows):
			var y: float = area.position.y + pitch * (row + 0.5) + pitch * 0.28
			for column in range(columns):
				var x: float = area.position.x + 5.0 + step * (column + 0.5) + (rand01(column, row) - 0.5) * 2.2
				plant(c, Vector2(x, y), t, column * 31 + row * 7 + int(plot.id) * 101, wind)
	_edging(c, area, plot, garden)
	if t >= 1.0 and not fallow:
		# Ready to harvest: a pale sheen runs across the heads and a tied sheaf marks the field.
		for index in range(7):
			var sx: float = area.position.x + area.size.x * (0.12 + rand01(index, 5) * 0.76)
			var sy: float = area.position.y + area.size.y * (0.1 + rand01(index, 9) * 0.8)
			c.draw_circle(Vector2(sx, sy - 22), 1.5, Color(1, 0.96, 0.7, 0.55))
		_sheaf(c, Vector2(area.end.x - 10, area.end.y + 4))

static func plant(c: Node2D, base: Vector2, t: float, seed_value: int, wind: float) -> void:
	var h: float = plant_height(t) * (0.9 + rand01(seed_value, 1) * 0.2)
	var ripe: float = ripeness(t)
	var leaf: Color = LEAF_YOUNG.lerp(LEAF_GREEN, clampf(t * 2.0, 0, 1)).lerp(STALK_GOLD.darkened(0.12), ripe * 0.8)
	var stalk: Color = STALK_GREEN.lerp(STALK_GOLD, ripe)
	c.draw_circle(base + Vector2(0, 1), 2.0 + 2.5 * t, Color(0, 0, 0, 0.16))
	if t < 0.04:
		# Freshly sown: seed dots in the furrow and the first pale shoots.
		for i in range(3):
			c.draw_circle(base + Vector2(-2 + i * 2.2, -0.5 + rand01(seed_value, i)), 0.8, Color("c8b078"))
		c.draw_line(base, base + Vector2(0, -2.5), LEAF_YOUNG, 1.0)
		return
	var blades: int = 2 + int(minf(t, 0.7) * 5.0)
	var spread: float = lerpf(0.35, 0.8, minf(t * 2.0, 1.0))
	var sway: float = sin(wind * 1.6 + base.x * 0.08) * 1.8 * clampf(h / 30.0, 0, 1)
	for blade in range(blades):
		var u: float = (float(blade) / float(maxi(1, blades - 1))) - 0.5
		var length: float = h * (0.7 + rand01(seed_value, blade + 3) * 0.3)
		var lean: float = u * spread * length + sway
		var mid: Vector2 = base + Vector2(lean * 0.45, -length * 0.55)
		var tip: Vector2 = base + Vector2(lean + u * 2.0, -length)
		var width: float = lerpf(0.9, 1.5, t)
		c.draw_polyline(PackedVector2Array([base, mid, tip]), leaf if t < 0.45 or blade % 2 == 0 else stalk, width, true)
	# From intermediate growth on, the tallest stalks carry the slender, bearded rye ear.
	if t >= 0.42:
		var ears: int = 3 + int(minf(t, 1.0) * 2.0)
		var growth: float = clampf((t - 0.42) / 0.58, 0.0, 1.0)
		var ear_color: Color = EAR_GREEN.lerp(EAR_RIPE if t >= 1.0 else EAR_GOLD, ripe)
		for ear in range(ears):
			var u: float = (float(ear) / float(maxi(1, ears - 1))) - 0.5
			var stem_top: Vector2 = base + Vector2(u * spread * h * 0.9 + sway, -h * (0.93 + rand01(seed_value, ear + 9) * 0.07))
			var droop: float = smoothstep(0.88, 1.0, t) * (0.7 + rand01(seed_value, ear) * 0.35)
			var direction: Vector2 = Vector2(sin(droop) * (1.0 if u >= 0 else -1.0), -cos(droop)).normalized()
			var ear_length: float = 3.0 + 8.0 * growth
			var ear_tip: Vector2 = stem_top + direction * ear_length
			c.draw_line(stem_top, ear_tip, ear_color.darkened(0.18), 3.6 + growth * 1.2, true)
			c.draw_line(stem_top, ear_tip, ear_color, 2.4 + growth * 1.0, true)
			# Kernels and long awns give the head its recognisable bristled outline.
			for k in range(int(2 + growth * 4)):
				var along: Vector2 = stem_top.lerp(ear_tip, float(k + 1) / (3.0 + growth * 4.0))
				c.draw_line(along, along + direction * 2.5 + Vector2(1.2, 0), ear_color.lightened(0.25), 0.6, true)
				c.draw_line(along, along + direction * 2.5 + Vector2(-1.2, 0), ear_color.darkened(0.1), 0.6, true)

static func _edging(c: Node2D, area: Rect2, plot: Dictionary, garden: bool) -> void:
	var post: Color = Color("a07a49")
	var rail: Color = Color("b8935a")
	var spacing: float = 36.0 if not garden else 30.0
	var gate_x: float = area.position.x + area.size.x * 0.5
	var y: float = area.end.y + 3.0
	# Back and side rails first, then front posts, so the fence sits around the plants.
	c.draw_line(Vector2(area.position.x - 3, area.position.y - 3), Vector2(area.end.x + 3, area.position.y - 3), rail.darkened(0.15), 2.0, true)
	for side_x in [area.position.x - 3.0, area.end.x + 3.0]:
		c.draw_line(Vector2(side_x, area.position.y - 3), Vector2(side_x, y), rail.darkened(0.1), 2.0, true)
	var count: int = int(area.size.x / spacing) + 1
	for index in range(count + 1):
		var x: float = area.position.x - 3.0 + (area.size.x + 6.0) * float(index) / float(count)
		if absf(x - gate_x) < spacing * 0.3: continue
		c.draw_line(Vector2(x, y), Vector2(x, y - 12), INK, 3.2, true)
		c.draw_line(Vector2(x, y), Vector2(x, y - 12), post, 1.8, true)
	if not garden:
		c.draw_line(Vector2(area.position.x - 3, y - 7), Vector2(gate_x - spacing * 0.3, y - 7), rail, 1.6, true)
		c.draw_line(Vector2(gate_x + spacing * 0.3, y - 7), Vector2(area.end.x + 3, y - 7), rail, 1.6, true)
		_scarecrow(c, Vector2(area.position.x + area.size.x * 0.82, area.position.y + area.size.y * 0.55))
	else:
		# Household beds get a low wattle border rather than a full fence.
		for index in range(int(area.size.x / 8.0)):
			var wx: float = area.position.x + 4.0 + index * 8.0
			c.draw_line(Vector2(wx, y - 1), Vector2(wx + 4, y - 4), Color("9a7547"), 1.6, true)
			c.draw_line(Vector2(wx + 4, y - 4), Vector2(wx + 8, y - 1), Color("b08a56"), 1.6, true)

static func _scarecrow(c: Node2D, p: Vector2) -> void:
	c.draw_line(p + Vector2(0, 8), p + Vector2(0, -20), INK, 3.0, true)
	c.draw_line(p + Vector2(-10, -12), p + Vector2(10, -12), INK, 3.0, true)
	c.draw_line(p + Vector2(0, 8), p + Vector2(0, -20), Color("8a6a40"), 1.5, true)
	c.draw_line(p + Vector2(-10, -12), p + Vector2(10, -12), Color("8a6a40"), 1.5, true)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -12), p + Vector2(6, -12), p + Vector2(4, -2), p + Vector2(-4, -2)]), Color("6d6a55"))
	c.draw_circle(p + Vector2(0, -22), 4.3, Color("cdb27c"))
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -24), p + Vector2(6, -24), p + Vector2(0, -33)]), Color("4d3b2b"))

static func _sheaf(c: Node2D, p: Vector2) -> void:
	for stalk in range(7):
		var u: float = float(stalk) / 6.0 - 0.5
		c.draw_line(p, p + Vector2(u * 9.0, -16.0), EAR_RIPE.darkened(0.1), 1.4, true)
		c.draw_line(p + Vector2(u * 9.0, -16.0), p + Vector2(u * 11.0, -20.0), EAR_RIPE, 2.0, true)
	c.draw_line(p + Vector2(-4, -7), p + Vector2(4, -7), Color("6a4b2d"), 2.0, true)
