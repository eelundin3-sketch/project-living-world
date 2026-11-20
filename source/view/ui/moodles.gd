extends Control
## Circular condition indicators stacked down the top-left edge. An icon pops in
## only while its condition is present; a ring shows severity (1-4) and the colour
## runs from calm amber to alarm red. Hover for the name and a hint.
const Needs = preload("res://sim/entities/needs.gd")
const RADIUS := 19.0
const SPACING := 48.0
const ORIGIN := Vector2(34, 158)
var simulation: RefCounted
var shown: Array[String] = []
var levels: Dictionary = {}
var pop: Dictionary = {}  # id -> 0..1 pop-in animation
var clock: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # never block clicks meant for the world or panels
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(70, 9 * SPACING)
	size = custom_minimum_size
	position = Vector2(8, 150)

func refresh() -> void:
	if simulation == null: return
	levels = Needs.levels(simulation.state)
	var active: Array[String] = []
	for key in Needs.ORDER:
		if levels.get(key, 0) > 0: active.append(key)
	shown = active
	for key in active:
		if not pop.has(key): pop[key] = 0.0
	for key in pop.keys():
		if not active.has(key) and pop[key] <= 0.0: pop.erase(key)
	queue_redraw()

var last_hovered: int = -1
func _process(delta: float) -> void:
	clock += delta
	var changed := false
	for key in pop.keys():
		var target: float = 1.0 if shown.has(key) else 0.0
		var next: float = move_toward(pop[key], target, delta * 5.0)
		if next != pop[key]: changed = true
		pop[key] = next
	var pulsing: bool = false
	for key in shown:
		if int(levels.get(key, 0)) >= 4: pulsing = true
	# Repaint while icons pop in or out, while a severe one pulses, or when the hover (tooltip) moves.
	var hovered: int = _hovered_slot() if not pop.is_empty() else -1
	if hovered != last_hovered: changed = true
	last_hovered = hovered
	if changed or pulsing: queue_redraw()

static func level_color(level: int) -> Color:
	return [Color("d6c48a"), Color("e3b64f"), Color("e08a38"), Color("d4492f"), Color("b8212a")][clampi(level, 0, 4)]

func _slot_position(index: int) -> Vector2:
	return Vector2(ORIGIN.x - position.x, ORIGIN.y - position.y + index * SPACING)

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var slots: Array[String] = []
	for key in Needs.ORDER:
		if pop.has(key): slots.append(key)
	for index in range(slots.size()):
		var key: String = slots[index]
		var level: int = int(levels.get(key, 0))
		var scale_amount: float = ease(clampf(pop[key], 0.0, 1.0), -2.0) * (1.0 + (0.12 * sin(clock * 6.0) if level >= 4 else 0.0))
		var center: Vector2 = _slot_position(index)
		var radius: float = RADIUS * scale_amount
		var tone: Color = level_color(level)
		draw_circle(center + Vector2(1.5, 2.5), radius, Color(0, 0, 0, 0.35))
		draw_circle(center, radius, Color(0.10, 0.09, 0.07, 0.92))
		draw_circle(center, radius - 2.5, tone.darkened(0.55))
		# Severity ring: one quarter per level, filled clockwise from the top.
		draw_arc(center, radius - 0.8, -PI / 2.0, -PI / 2.0 + TAU * float(level) / 4.0, 32, tone, 3.0, true)
		if scale_amount > 0.6:
			_icon(key, center, radius / RADIUS, Color("f6ecd0") if level < 3 else Color("fff3ee"))
	var hovered: int = _hovered_slot()
	if hovered >= 0 and hovered < slots.size():
		var key: String = slots[hovered]
		var text: String = Needs.label(key, int(levels.get(key, 0)))
		var hint: String = Needs.hint(key)
		var width: float = maxf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x) + 16
		var origin: Vector2 = _slot_position(hovered) + Vector2(RADIUS + 8, -17)
		draw_rect(Rect2(origin, Vector2(width, 36)), Color(0.07, 0.06, 0.04, 0.92))
		draw_rect(Rect2(origin, Vector2(width, 36)), Color("87734e"), false, 1.0)
		draw_string(font, origin + Vector2(8, 15), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, level_color(int(levels.get(key, 0))).lightened(0.3))
		draw_string(font, origin + Vector2(8, 29), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("cfc4a6"))

func _hovered_slot() -> int:
	var mouse: Vector2 = get_local_mouse_position()
	for index in range(pop.size()):
		if mouse.distance_to(_slot_position(index)) <= RADIUS + 2.0: return index
	return -1


## Vector pictograms, drawn in a 16 px design space around `c`.
func _icon(key: String, c: Vector2, k: float, ink: Color) -> void:
	match key:
		"hungry":  # apple with leaf
			draw_circle(c + Vector2(-2.6, 1.5) * k, 5.0 * k, ink)
			draw_circle(c + Vector2(2.6, 1.5) * k, 5.0 * k, ink)
			draw_line(c + Vector2(0, -4) * k, c + Vector2(1, -8) * k, ink, 1.6 * k, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(1, -7) * k, c + Vector2(6, -9) * k, c + Vector2(4, -4) * k]), ink)
		"thirsty":  # water drop
			var drop := PackedVector2Array([c + Vector2(0, -9) * k, c + Vector2(6, 1) * k, c + Vector2(4.5, 5.5) * k, c + Vector2(0, 8) * k, c + Vector2(-4.5, 5.5) * k, c + Vector2(-6, 1) * k])
			draw_colored_polygon(drop, ink)
			draw_line(c + Vector2(-2, 2) * k, c + Vector2(-1.5, 5) * k, Color(0.25, 0.4, 0.55), 1.4 * k, true)
		"tired":  # crescent moon + z
			draw_circle(c + Vector2(-1, 0) * k, 7.0 * k, ink)
			draw_circle(c + Vector2(2.6, -1.5) * k, 6.0 * k, Color(0.2, 0.17, 0.12))
			draw_polyline(PackedVector2Array([c + Vector2(3, -8) * k, c + Vector2(8, -8) * k, c + Vector2(3, -3) * k, c + Vector2(8, -3) * k]), ink, 1.4 * k, true)
		"pain":  # jagged burst
			var points := PackedVector2Array()
			for i in range(12):
				var radius: float = (9.0 if i % 2 == 0 else 4.0) * k
				points.append(c + Vector2.from_angle(float(i) * TAU / 12.0 - PI / 2.0) * radius)
			draw_colored_polygon(points, ink)
		"bleeding":  # blood drop with highlight
			var drop := PackedVector2Array([c + Vector2(0, -9) * k, c + Vector2(6, 1) * k, c + Vector2(4.5, 5.5) * k, c + Vector2(0, 8) * k, c + Vector2(-4.5, 5.5) * k, c + Vector2(-6, 1) * k])
			draw_colored_polygon(drop, Color("e2504a"))
			draw_polyline(drop + PackedVector2Array([drop[0]]), ink, 1.3 * k, true)
		"stressed":  # lightning
			draw_colored_polygon(PackedVector2Array([c + Vector2(1.5, -9) * k, c + Vector2(-5, 1) * k, c + Vector2(-0.5, 1) * k, c + Vector2(-2, 9) * k, c + Vector2(5.5, -2) * k, c + Vector2(0.5, -2) * k]), ink)
		"unhappy":  # frowning face
			draw_arc(c, 8.0 * k, 0, TAU, 24, ink, 1.6 * k, true)
			draw_circle(c + Vector2(-3, -2.5) * k, 1.3 * k, ink)
			draw_circle(c + Vector2(3, -2.5) * k, 1.3 * k, ink)
			draw_arc(c + Vector2(0, 6.5) * k, 4.0 * k, PI * 1.15, PI * 1.85, 10, ink, 1.6 * k, true)
		"wet":  # cloud with rain
			draw_circle(c + Vector2(-3, -2) * k, 4.0 * k, ink)
			draw_circle(c + Vector2(2, -3) * k, 4.8 * k, ink)
			draw_circle(c + Vector2(5, -0.5) * k, 3.2 * k, ink)
			for x in [-4, 0, 4]: draw_line(c + Vector2(x, 3) * k, c + Vector2(x - 1.5, 8) * k, ink, 1.4 * k, true)
		"overloaded":  # a heavy sack
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -2) * k, c + Vector2(6, -2) * k, c + Vector2(8, 8) * k, c + Vector2(-8, 8) * k]), ink)
			draw_line(c + Vector2(-3, -2) * k, c + Vector2(-1, -7) * k, ink, 1.6 * k, true)
			draw_line(c + Vector2(3, -2) * k, c + Vector2(1, -7) * k, ink, 1.6 * k, true)
			draw_line(c + Vector2(-2, -7) * k, c + Vector2(2, -7) * k, ink, 1.6 * k, true)
		"cold":  # snowflake
			for i in range(3):
				var direction: Vector2 = Vector2.from_angle(float(i) * PI / 3.0) * 8.5 * k
				draw_line(c - direction, c + direction, ink, 1.6 * k, true)
