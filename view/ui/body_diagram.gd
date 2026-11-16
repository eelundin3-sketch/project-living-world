extends Control
## The health window's figure: the player's own character, in the clothes they are wearing,
## standing front-on, with the wounds drawn over it. Hover a part to find it, click to select,
## right-click for treatment. Zones are measured from the character's real joints.
const Character = preload("res://view/actors/drawn_character.gd")
const Health = preload("res://sim/player/body_health.gd")

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
	figure.set_pose({"position": feet, "heading": PI / 2.0, "action": "idle", "moving": false, "outfit": outfit, "phase": 0.0})
	var frame: Dictionary = figure.frame
	if frame.is_empty(): return
	zones.clear()
	var head: Vector2 = frame.head
	var chest: Vector2 = frame.chest
	var hip: Vector2 = frame.hip
	zones["head"] = _box(head + Vector2(-9, -12), head + Vector2(9, 11), 0.0)
	zones["neck"] = _box(head + Vector2(-3.5, 10), head + Vector2(3.5, 16), 0.0)
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

func _box(a: Vector2, b: Vector2, pad: float) -> Rect2:
	var low := Vector2(minf(a.x, b.x) - pad, minf(a.y, b.y) - pad)
	var high := Vector2(maxf(a.x, b.x) + pad, maxf(a.y, b.y) + pad)
	return Rect2(low, high - low)

func _draw() -> void:
	# The floor under the figure; the character and the overlay are child nodes drawn above this.
	draw_rect(Rect2(Vector2.ZERO, size), Color("141719"))
	draw_circle(Vector2(size.x * 0.5, size.y - 10.0), 1.0, Color(0, 0, 0, 0))
	draw_set_transform(Vector2(size.x * 0.5, size.y - 8.0), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, size.x * 0.32, Color(0.0, 0.0, 0.0, 0.35))
	draw_set_transform(Vector2.ZERO)
	if figure != null and not zones.is_empty():
		var wanted: Dictionary = outfit
		if figure.pose.get("outfit", {}) != wanted: _layout()
	if overlay != null: overlay.queue_redraw()

func draw_overlay(canvas: Control) -> void:
	for part in zones:
		var rect: Rect2 = zones[part]
		var state: Dictionary = parts.get(part, {})
		var damage: int = int(state.get("damage", 0))
		if damage > 0:
			var tint := Color("c0392e")
			tint.a = clampf(0.18 + float(damage) / 160.0, 0.2, 0.55)
			canvas.draw_rect(rect, tint)
		var bandage: String = state.get("bandage", "none")
		if bandage != "none":
			var cloth := Color("ddd8c6") if bandage == "clean" else Color("bd9c73")
			for stripe in range(3):
				var y: float = rect.position.y + rect.size.y * (0.25 + 0.25 * stripe)
				canvas.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y + 3.0), cloth, 3.0)
		elif state.get("bleeding", false):
			canvas.draw_circle(rect.get_center(), 4.0, Color("ec3b33"))
			canvas.draw_circle(rect.get_center() + Vector2(0, 7), 2.2, Color("ec3b33"))
		if part == selected:
			canvas.draw_rect(rect, Color("e6cf8e"), false, 2.0)
		elif part == hovered:
			canvas.draw_rect(rect, Color(1, 1, 1, 0.5), false, 1.2)

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
