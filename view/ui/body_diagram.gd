extends Control

signal part_selected(part: String)
signal treatment_requested(part: String)

# Original outline in a 160 × 340 drawing space. Left and right follow the
# character's perspective, as if facing the player.
const OUTLINE: Array[Vector2] = [
	Vector2(80, 9), Vector2(90, 12), Vector2(97, 22), Vector2(98, 35),
	Vector2(102, 37), Vector2(100, 45), Vector2(94, 50), Vector2(90, 60),
	Vector2(94, 66), Vector2(117, 74), Vector2(126, 86), Vector2(128, 111),
	Vector2(126, 133), Vector2(132, 160), Vector2(139, 181), Vector2(147, 191),
	Vector2(149, 201), Vector2(145, 209), Vector2(139, 207), Vector2(133, 198),
	Vector2(130, 187), Vector2(120, 164), Vector2(114, 140), Vector2(111, 116),
	Vector2(105, 147), Vector2(113, 172), Vector2(113, 194), Vector2(108, 223),
	Vector2(103, 248), Vector2(108, 274), Vector2(104, 302), Vector2(103, 318),
	Vector2(110, 328), Vector2(109, 336), Vector2(86, 336), Vector2(85, 328),
	Vector2(87, 316), Vector2(84, 290), Vector2(82, 268), Vector2(84, 245),
	Vector2(80, 205), Vector2(76, 245), Vector2(78, 268), Vector2(76, 290),
	Vector2(73, 316), Vector2(75, 328), Vector2(74, 336), Vector2(51, 336),
	Vector2(50, 328), Vector2(57, 318), Vector2(56, 302), Vector2(52, 274),
	Vector2(57, 248), Vector2(52, 223), Vector2(47, 194), Vector2(47, 172),
	Vector2(55, 147), Vector2(49, 116), Vector2(46, 140), Vector2(40, 164),
	Vector2(30, 187), Vector2(27, 198), Vector2(21, 207), Vector2(15, 209),
	Vector2(11, 201), Vector2(13, 191), Vector2(21, 181), Vector2(28, 160),
	Vector2(34, 133), Vector2(32, 111), Vector2(34, 86), Vector2(43, 74),
	Vector2(66, 66), Vector2(70, 60), Vector2(66, 50), Vector2(60, 45),
	Vector2(58, 37), Vector2(62, 35), Vector2(63, 22), Vector2(70, 12),
]
const ZONES := {
	"head": Rect2(56, 8, 48, 44), "neck": Rect2(65, 52, 30, 16),
	"upper_torso": Rect2(49, 68, 62, 61), "lower_torso": Rect2(47, 129, 66, 35),
	"groin": Rect2(47, 164, 66, 32),
	"right_upper_arm": Rect2(28, 77, 21, 57), "left_upper_arm": Rect2(111, 77, 21, 57),
	"right_forearm": Rect2(19, 134, 28, 49), "left_forearm": Rect2(113, 134, 28, 49),
	"right_hand": Rect2(9, 183, 23, 28), "left_hand": Rect2(128, 183, 23, 28),
	"right_thigh": Rect2(46, 196, 34, 52), "left_thigh": Rect2(80, 196, 34, 52),
	"right_shin": Rect2(49, 248, 31, 70), "left_shin": Rect2(80, 248, 31, 70),
	"right_foot": Rect2(47, 318, 32, 20), "left_foot": Rect2(81, 318, 32, 20),
}

var parts: Dictionary = {}
var selected := "head"
var outline := PackedVector2Array(OUTLINE)
var regions: Dictionary = {}
var wraps: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(148, 310)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for part in ZONES:
		var zone: Rect2 = ZONES[part]
		regions[part] = _clip(zone)
		wraps[part] = []
		for offset in [-4.0, 1.0, 6.0]:
			var y: float = zone.get_center().y + offset
			wraps[part].append(Geometry2D.intersect_polygons(outline, PackedVector2Array([
				Vector2(zone.position.x, y - 3), Vector2(zone.end.x, y + 3),
				Vector2(zone.end.x, y + 8), Vector2(zone.position.x, y + 2),
			])))

func _clip(rect: Rect2) -> Array[PackedVector2Array]:
	return Geometry2D.intersect_polygons(outline, PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y),
	]))

func _scale_factor() -> float:
	return minf(size.x / 160.0, size.y / 346.0)

func _origin(factor: float) -> Vector2:
	return (size - Vector2(160, 346) * factor) * 0.5

func _draw() -> void:
	var factor := _scale_factor()
	draw_set_transform(_origin(factor), 0, Vector2.ONE * factor)
	draw_colored_polygon(outline, Color("17191b"))
	for part in ZONES:
		var state: Dictionary = parts.get(part, {})
		if state.get("damage", 0) > 0 or part == selected:
			var color := Color("592e33") if state.get("damage", 0) > 0 else Color("324348")
			for shape in regions[part]:
				draw_colored_polygon(shape, color)
		var bandage: String = state.get("bandage", "none")
		if bandage != "none":
			var cloth := Color("ddd8c6") if bandage == "clean" else Color("bd9c73")
			for index in range(wraps[part].size()):
				for strip in wraps[part][index]:
					draw_colored_polygon(strip, cloth.darkened(0.14) if index == 1 else cloth)
		elif state.get("bleeding", false):
			var zone: Rect2 = ZONES[part]
			draw_circle(zone.get_center(), 4, Color("ec7773"), true, -1, true)
		if part == selected:
			for shape in regions[part]:
				_draw_edge(shape, Color("d2b97e"), 1.5)
	_draw_edge(outline, Color("d4d7d6"), 1.35)

func _draw_edge(shape: PackedVector2Array, color: Color, width: float) -> void:
	var edge := shape.duplicate()
	edge.append(edge[0])
	draw_polyline(edge, color, width, true)

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed: return
	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]: return
	var factor := _scale_factor()
	if factor <= 0: return
	var point: Vector2 = (event.position - _origin(factor)) / factor
	for part in ZONES:
		for region in regions[part]:
			if not Geometry2D.is_point_in_polygon(point, region): continue
			if event.button_index == MOUSE_BUTTON_RIGHT: treatment_requested.emit(part)
			else: part_selected.emit(part)
			accept_event()
			return
