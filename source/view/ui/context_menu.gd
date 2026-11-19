extends Control
## A pop-up action menu for whatever was clicked: a header with the name, then one row per
## action with a pictogram. Greyed rows say why they are unavailable. Click a row to act; click
## elsewhere, right-click or Escape to dismiss.
signal chosen(target: int, action: String)
const ROW := 30.0
const WIDTH := 236.0
const HEADER := 46.0
var target: int = 0
var title: String = ""
var subtitle: String = ""
var rows: Array = []
var origin: Vector2 = Vector2.ZERO
var hover: int = -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func is_open() -> bool:
	return visible

func open(target_id: int, header: String, detail: String, options: Array, at: Vector2) -> void:
	target = target_id
	title = header
	subtitle = detail
	rows = options
	hover = -1
	var height := HEADER + ROW * rows.size() + 8.0
	origin = Vector2(clampf(at.x + 8.0, 6.0, size.x - WIDTH - 6.0), clampf(at.y + 6.0, 6.0, size.y - height - 6.0))
	visible = true
	queue_redraw()

func close() -> void:
	visible = false
	rows = []

func _rect() -> Rect2:
	return Rect2(origin, Vector2(WIDTH, HEADER + ROW * rows.size() + 8.0))

func _row_at(point: Vector2) -> int:
	var rect := _rect()
	if not rect.has_point(point): return -1
	var index := int((point.y - rect.position.y - HEADER) / ROW)
	return index if index >= 0 and index < rows.size() else -1

func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseMotion:
		var now := _row_at(event.position)
		if now != hover:
			hover = now
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var inside := _rect().has_point(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT and inside:
			var index := _row_at(event.position)
			if index >= 0 and rows[index].enabled:
				var action: String = rows[index].id
				close()
				chosen.emit(target, action)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT or not inside:
			# A click elsewhere dismisses the menu and still reaches the world (to open another).
			close()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if not visible: return
	var font: Font = ThemeDB.fallback_font
	var rect := _rect()
	draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color(0, 0, 0, 0.35))
	draw_rect(rect, Color(0.08, 0.075, 0.055, 0.96))
	draw_rect(rect, Color("a68d5f"), false, 1.5)
	draw_string(font, rect.position + Vector2(12, 20), title, HORIZONTAL_ALIGNMENT_LEFT, WIDTH - 24, 16, Color("f4ecd6"))
	draw_string(font, rect.position + Vector2(12, 37), subtitle, HORIZONTAL_ALIGNMENT_LEFT, WIDTH - 24, 11, Color("a89d84"))
	draw_line(rect.position + Vector2(8, HEADER - 4), rect.position + Vector2(WIDTH - 8, HEADER - 4), Color("5a4a30"), 1.0)
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var cell := Rect2(rect.position + Vector2(4, HEADER + ROW * index), Vector2(WIDTH - 8, ROW - 2))
		var lit: bool = index == hover and row.enabled
		if lit: draw_rect(cell, Color("5b4623"))
		var ink: Color = Color("f4ecd6") if row.enabled else Color("7d745f")
		_icon(row.icon, cell.position + Vector2(17, ROW * 0.5 - 1), ink if not lit else Color("ffe9a8"))
		draw_string(font, cell.position + Vector2(36, 19), row.label, HORIZONTAL_ALIGNMENT_LEFT, WIDTH - 60, 14, ink if not lit else Color("ffe9a8"))
		if not row.enabled and not String(row.reason).is_empty():
			draw_string(font, cell.position + Vector2(WIDTH - 12 - font.get_string_size(row.reason, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, 18), row.reason, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8a7c5c"))

## Small pictograms for the actions, drawn around `c`.
func _icon(kind: String, c: Vector2, ink: Color) -> void:
	draw_circle(c, 10.5, Color(0, 0, 0, 0.35))
	draw_arc(c, 10.5, 0, TAU, 20, ink.darkened(0.3), 1.0)
	match kind:
		"fist":
			draw_rect(Rect2(c + Vector2(-5, -4), Vector2(10, 8)), ink)
			for i in range(4): draw_line(c + Vector2(-3.6 + i * 2.4, -4), c + Vector2(-3.6 + i * 2.4, -6), ink, 1.6)
		"hand":
			draw_circle(c + Vector2(0, 1.5), 4.2, ink)
			for i in range(4): draw_line(c + Vector2(-3.6 + i * 2.4, -1), c + Vector2(-4.2 + i * 2.8, -6), ink, 1.5)
		"talk":
			draw_rect(Rect2(c + Vector2(-6, -5), Vector2(12, 8)), ink)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3, 3), c + Vector2(-5, 7), c + Vector2(1, 3)]), ink)
		"eye":
			draw_arc(c + Vector2(0, 3), 6.5, PI * 1.15, PI * 1.85, 10, ink, 1.6)
			draw_arc(c + Vector2(0, -3), 6.5, PI * 0.15, PI * 0.85, 10, ink, 1.6)
			draw_circle(c, 2.0, ink)
		"axe":
			draw_line(c + Vector2(-5, 6), c + Vector2(4, -5), ink, 1.8)
			draw_colored_polygon(PackedVector2Array([c + Vector2(1, -7), c + Vector2(7, -2), c + Vector2(3, 0)]), ink)
		"pick":
			draw_line(c + Vector2(-5, 6), c + Vector2(4, -4), ink, 1.8)
			draw_arc(c + Vector2(3, -3), 6.0, PI * 1.1, PI * 1.95, 10, ink, 2.0)
		"log":
			draw_rect(Rect2(c + Vector2(-7, -3), Vector2(14, 6)), ink)
			draw_circle(c + Vector2(7, 0), 3.2, ink.lightened(0.2))
		"gun":
			draw_rect(Rect2(c + Vector2(-7, -1), Vector2(14, 3)), ink)
			draw_rect(Rect2(c + Vector2(-8, 0), Vector2(5, 5)), ink)
		"food":
			draw_circle(c + Vector2(-2.5, 1), 4.0, ink)
			draw_circle(c + Vector2(2.5, 1), 4.0, ink)
		"drop":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(5, 1), c + Vector2(3, 5), c + Vector2(-3, 5), c + Vector2(-5, 1)]), ink)
		"bag":
			draw_rect(Rect2(c + Vector2(-5, -3), Vector2(10, 9)), ink, false, 1.6)
			draw_arc(c + Vector2(0, -3), 3.6, PI, TAU, 8, ink, 1.6)
		"heart":
			draw_circle(c + Vector2(-2.6, -2), 3.3, ink)
			draw_circle(c + Vector2(2.6, -2), 3.3, ink)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5.6, -0.5), c + Vector2(5.6, -0.5), c + Vector2(0, 6.5)]), ink)
		"chest":
			draw_rect(Rect2(c + Vector2(-7, -3), Vector2(14, 9)), ink)
			draw_arc(c + Vector2(0, -3), 7.0, PI, TAU, 10, ink, 2.0)
			draw_rect(Rect2(c + Vector2(-1.5, -2), Vector2(3, 4)), Color(0, 0, 0, 0.6))
		"shirt":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -5), c + Vector2(-3, -7), c + Vector2(3, -7), c + Vector2(8, -5), c + Vector2(6, -1), c + Vector2(4, -2), c + Vector2(4, 7), c + Vector2(-4, 7), c + Vector2(-4, -2), c + Vector2(-6, -1)]), ink)
		"sun":
			draw_circle(c, 3.4, ink)
			for i in range(8): draw_line(c + Vector2.from_angle(i * TAU / 8) * 5.0, c + Vector2.from_angle(i * TAU / 8) * 7.5, ink, 1.3)
		_:
			draw_circle(c, 3.0, ink)
