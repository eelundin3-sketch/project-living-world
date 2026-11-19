extends Control
## The health window's figure: the player's own character, in the clothes they are wearing,
## standing front-on, with the wounds drawn over it. Hover a part to find it, click to select,
## right-click for treatment. Zones are measured from the character's real joints.
const Character = preload("res://view/actors/drawn_character.gd")
const Health = preload("res://sim/combat/body_health.gd")

signal part_selected(part: String)
signal treatment_requested(part: String)

class Overlay extends Control:
	var owner_diagram: Control
	func _draw() -> void:
		owner_diagram.draw_overlay(self)

var parts: Dictionary = {}
var selected := "head"
var outfit: Dictionary = {}
var player_id: int = 0
var figure: Node2D
var overlay: Overlay
var zones: Dictionary = {}     # part -> Rect2 in the control's own pixels
var hovered := ""
## Draw no floor panel of its own (when placed on a card that already has a background).
var transparent := false
## Minimal marking: a small dot on every injured part instead of tinted patches.
var minimal := false
## The figure acts out a treatment while one is running: part, kind and progress 0..1.
var treat_part := ""
var treat_kind := ""
var treat_phase := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(190, 340)
	mouse_filter = Control.MOUSE_FILTER_STOP
	figure = Character.new()
	figure.setup(player_id, true, false)
	add_child(figure)
	overlay = Overlay.new()
	overlay.owner_diagram = self
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	resized.connect(_layout)
	_layout()

## Places and scales the figure to fill the control, then measures a zone for every body part.
func _layout() -> void:
	if figure == null: return
	var factor: float = minf(size.x / 46.0, size.y / 84.0)
	var feet := Vector2(size.x * 0.5, size.y - 12.0)
	figure.setup(player_id, true, false)
	figure.scale = Vector2.ONE * factor
	figure.set_pose(_figure_pose(feet))
	var frame: Dictionary = figure.frame
	if frame.is_empty(): return
	zones.clear()
	var head: Vector2 = frame.head
	var chest: Vector2 = frame.chest
	var hip: Vector2 = frame.hip
	zones["head"] = _box(head + Vector2(-9, -12), head + Vector2(9, 11), 0.0)
	zones["neck"] = _box(head + Vector2(-3.5, 7.8), head + Vector2(3.5, 10.4), 0.0)
	zones["upper_torso"] = _box(chest + Vector2(-10, -6), hip.lerp(chest, 0.45) + Vector2(10, 0), 0.0)
	zones["lower_torso"] = _box(hip.lerp(chest, 0.45) + Vector2(-9, 0), hip + Vector2(9, -3), 0.0)
	zones["groin"] = _box(hip + Vector2(-8, -3), hip + Vector2(8, 8), 0.0)
	# The figure's "left" limbs (side -1) stand on the viewer's left, which the health list calls "right".
	for entry in [["right", frame.left_arm, frame.left_leg], ["left", frame.right_arm, frame.right_leg]]:
		var arm: PackedVector2Array = entry[1]
		var leg: PackedVector2Array = entry[2]
		zones[entry[0] + "_upper_arm"] = _box(arm[0], arm[1], 2.2)
		zones[entry[0] + "_forearm"] = _box(arm[1], arm[2] - (arm[2] - arm[1]).normalized() * 3.0, 2.0)
		zones[entry[0] + "_hand"] = _box(arm[2] + Vector2(-5, -4), arm[2] + Vector2(5, 5), 0.0)
		zones[entry[0] + "_thigh"] = _box(leg[0], leg[1], 2.6)
		zones[entry[0] + "_shin"] = _box(leg[1], leg[2] + Vector2(0, -4), 2.2)
		zones[entry[0] + "_foot"] = _box(leg[2] + Vector2(-6, -4), leg[2] + Vector2(6, 3), 0.0)
	for part in zones.keys():
		var local: Rect2 = zones[part]
		zones[part] = Rect2(feet + local.position * factor, local.size * factor)
	queue_redraw()

func _figure_pose(feet: Vector2) -> Dictionary:
	if treat_part.is_empty():
		return {"position": feet, "heading": PI / 2.0, "action": "idle", "moving": false, "outfit": outfit, "phase": 0.0}
	return {"position": feet, "heading": PI / 2.0, "action": "treat", "moving": false, "outfit": outfit, "phase": treat_phase, "treat_part": treat_part, "treat_kind": treat_kind}

## Shows (or ends) the self-treatment on the figure. Zones keep their standing layout.
func set_treatment(part: String, kind: String, phase: float) -> void:
	if part == treat_part and kind == treat_kind and is_equal_approx(phase, treat_phase): return
	treat_part = part
	treat_kind = kind
	treat_phase = phase
	if figure == null or zones.is_empty(): return
	figure.set_pose(_figure_pose(Vector2(size.x * 0.5, size.y - 12.0)))
	if overlay != null: overlay.queue_redraw()

func _box(a: Vector2, b: Vector2, pad: float) -> Rect2:
	var low := Vector2(minf(a.x, b.x) - pad, minf(a.y, b.y) - pad)
	var high := Vector2(maxf(a.x, b.x) + pad, maxf(a.y, b.y) + pad)
	return Rect2(low, high - low)

func _draw() -> void:
	# The floor under the figure; the character and the overlay are child nodes drawn above this.
	if not transparent: draw_rect(Rect2(Vector2.ZERO, size), Color("141719"))
	draw_circle(Vector2(size.x * 0.5, size.y - 10.0), 1.0, Color(0, 0, 0, 0))
	draw_set_transform(Vector2(size.x * 0.5, size.y - 8.0), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, size.x * 0.32, Color(0.0, 0.0, 0.0, 0.35))
	draw_set_transform(Vector2.ZERO)
	if figure != null and not zones.is_empty():
		var wanted: Dictionary = outfit
		if figure.pose.get("outfit", {}) != wanted: _layout()
	if overlay != null: overlay.queue_redraw()

func draw_overlay(canvas: Control) -> void:
	if minimal:
		_draw_dots(canvas)
		return
	var treating := not treat_part.is_empty()
	for part in zones:
		var rect: Rect2 = zones[part]
		var state: Dictionary = parts.get(part, {})
		var damage: int = int(state.get("damage", 0))
		# While a treatment plays the figure moves, so only the part being treated stays marked.
		if treating and part != treat_part: continue
		if damage > 0 and not treating:
			var kind: String = str(state.get("wound", "none"))
			var tint: Color = Color("a07ad8") if kind == "bruise" else (Color("e8a54b") if kind == "sprain" else Color("e8574f"))
			tint.a = clampf(0.16 + float(damage) / 220.0, 0.18, 0.45)
			var patch: Rect2 = rect.grow_individual(-rect.size.x * 0.14, -rect.size.y * 0.14, -rect.size.x * 0.14, -rect.size.y * 0.14)
			if part == "head": patch = Rect2(rect.position + rect.size * Vector2(0.2, 0.42), rect.size * Vector2(0.6, 0.46))
			_blob(canvas, patch, tint)
			_blob(canvas, patch.grow(-patch.size.x * 0.25), Color(tint, tint.a * 0.9))
		var bandage: String = state.get("bandage", "none")
		if bandage != "none" and not treating:
			var cloth := Color("ece6d6") if bandage == "clean" else Color("c9a77c")
			var stripes: int = 3 if rect.size.y > 24 else 2
			for stripe in range(stripes):
				var y: float = rect.position.y + rect.size.y * (0.22 + 0.56 * float(stripe) / maxf(1.0, float(stripes - 1)))
				canvas.draw_line(Vector2(rect.position.x + 1, y), Vector2(rect.end.x - 1, y + 2.0), Color(0, 0, 0, 0.35), 4.6, true)
				canvas.draw_line(Vector2(rect.position.x + 1, y - 0.6), Vector2(rect.end.x - 1, y + 1.4), cloth, 3.4, true)
		elif state.get("bleeding", false) and not treating:
			var c := rect.get_center()
			var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 260.0)
			canvas.draw_circle(c, 7.0 + 3.0 * pulse, Color(0.91, 0.34, 0.31, 0.18))
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(4, 1), c + Vector2(2.8, 4.5), c + Vector2(0, 5.6), c + Vector2(-2.8, 4.5), c + Vector2(-4, 1)]), Color("e8574f"))
		if part == selected and not treating:
			_outline(canvas, rect, Color("56c2a6"), 2.0)
		elif part == hovered and not treating:
			_outline(canvas, rect, Color(1, 1, 1, 0.45), 1.2)

## One small dot per injured part: red bleeding, purple bruise, amber sprain or infection, white
## ring when bandaged. The selected part has a ring; the hovered part is named beside it.
func _draw_dots(canvas: Control) -> void:
	var font: Font = ThemeDB.fallback_font
	var treating := not treat_part.is_empty()
	for part in zones:
		var state: Dictionary = parts.get(part, {})
		var damage: int = int(state.get("damage", 0))
		var bandage: String = state.get("bandage", "none")
		var injured: bool = damage > 0 or int(state.get("infection", 0)) > 0 or bandage != "none"
		var at: Vector2 = (zones[part] as Rect2).get_center()
		if part == "head": at += Vector2(0, 2)
		if injured and not (treating and part != treat_part):
			var tone := Color("e8574f") if state.get("bleeding", false) else (Color("a58ae0") if state.get("wound", "") == "bruise" else (Color("e8a54b") if state.get("wound", "") in ["sprain"] or int(state.get("infection", 0)) > 0 else Color("e8574f")))
			if bandage == "clean": tone = Color("74d08f")
			elif bandage == "dirty": tone = Color("e8a54b")
			var radius: float = 4.0 + clampf(float(damage) / 40.0, 0.0, 3.0)
			canvas.draw_circle(at, radius + 3.0, Color(tone, 0.18))
			canvas.draw_circle(at, radius, tone)
			if bandage != "none": canvas.draw_arc(at, radius + 2.5, 0.0, TAU, 20, Color("ece6d6"), 1.4, true)
		if part == selected and not treating and injured:
			canvas.draw_arc(at, 12.0, 0.0, TAU, 28, Color("56c2a6"), 2.0, true)
		if part == hovered and not treating:
			var label: String = part.replace("_", " ").capitalize()
			var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0
			var box := Rect2(at + Vector2(14, -11), Vector2(width, 22))
			if box.end.x > size.x: box.position.x = at.x - 14.0 - width
			canvas.draw_rect(box, Color(0.06, 0.08, 0.09, 0.95))
			canvas.draw_rect(box, Color("2a3a40"), false, 1.0)
			canvas.draw_string(font, box.position + Vector2(7, 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e9eef1"))

## A soft rounded patch filling a zone.
func _blob(canvas: Control, rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	var c := rect.get_center()
	var r := rect.size * 0.5
	for i in range(20):
		var a := float(i) / 20.0 * TAU
		points.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	canvas.draw_colored_polygon(points, color)

func _outline(canvas: Control, rect: Rect2, color: Color, width: float) -> void:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(int(ceil(width)))
	style.set_corner_radius_all(int(minf(rect.size.x, rect.size.y) * 0.45))
	style.anti_aliasing = true
	canvas.draw_style_box(style, rect.grow(2.0))

func _part_at(point: Vector2) -> String:
	# Smaller zones win where they overlap (a hand over a forearm, a foot over a shin).
	var best := ""
	var best_area := INF
	for part in zones:
		var rect: Rect2 = zones[part]
		if rect.has_point(point) and rect.get_area() < best_area:
			best = part
			best_area = rect.get_area()
	return best

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var now := _part_at(event.position)
		if now != hovered:
			hovered = now
			if overlay != null: overlay.queue_redraw()
		return
	if not event is InputEventMouseButton or not event.pressed: return
	if event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]: return
	var part := _part_at(event.position)
	if part.is_empty(): return
	if event.button_index == MOUSE_BUTTON_RIGHT: treatment_requested.emit(part)
	else: part_selected.emit(part)
	accept_event()
