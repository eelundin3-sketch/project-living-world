extends Control
## The inventory as a small desktop-style window: a title bar with the three window buttons
## (close, minimise, and a green one that snaps it back to its home spot at the left), dragged
## around by its title bar. Inside is only the item grid and the clothing squares.
const InventoryGrid = preload("res://view/ui/inventory_grid.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")

signal close_requested
signal minimize_requested

const BAR := 32.0
const PAD := 14.0
const RADIUS := 12
const BG := Color(0.105, 0.14, 0.13, 0.97)
const BAR_COLOR := Color("141b19")
const EDGE := Color("4a3c27")

var simulation: RefCounted:
	set(value):
		simulation = value
		if grid != null: grid.simulation = value
var grid: Control
var dragging := false
var drag_offset := Vector2.ZERO
var hover_button := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	grid = InventoryGrid.new()
	grid.simulation = simulation
	grid.position = Vector2(PAD, BAR + PAD)
	add_child(grid)
	size = grid.custom_minimum_size + Vector2(PAD * 2.0, BAR + PAD * 2.0)
	custom_minimum_size = size

## The window's resting place: the left side of the screen, vertically centred.
func home_position() -> Vector2:
	var view := get_viewport_rect().size
	return Vector2(78.0, maxf(12.0, (view.y - size.y) * 0.5 - 20.0))   # right of the need indicators

func refresh(s: Dictionary) -> void:
	grid.simulation = simulation
	grid.refresh(s)
	grid.queue_redraw()
	queue_redraw()

func _button_center(index: int) -> Vector2:
	return Vector2(20.0 + index * 20.0, BAR * 0.5)

func _button_at(point: Vector2) -> String:
	for index in range(3):
		if point.distance_to(_button_center(index)) <= 8.0: return ["close", "minimize", "home"][index]
	return ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var button := _button_at(event.position)
			if button == "close": close_requested.emit()
			elif button == "minimize": minimize_requested.emit()
			elif button == "home": position = home_position()
			elif event.position.y <= BAR:
				dragging = true
				drag_offset = event.position
			accept_event()
		else:
			dragging = false
	elif event is InputEventMouseMotion:
		if dragging:
			# Keep at least the title bar on screen, like a desktop window.
			var view := get_viewport_rect().size
			var wanted: Vector2 = get_global_mouse_position() - drag_offset
			position = Vector2(clampf(wanted.x, -size.x + 80.0, view.x - 80.0), clampf(wanted.y, 0.0, view.y - BAR))
			accept_event()
		var over := _button_at(event.position)
		if over != hover_button:
			hover_button = over
			queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and not hover_button.is_empty():
		hover_button = ""
		queue_redraw()

func _draw() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = BG
	frame.set_corner_radius_all(RADIUS)
	frame.border_color = EDGE
	frame.set_border_width_all(1)
	frame.shadow_color = Color(0, 0, 0, 0.45)
	frame.shadow_size = 18
	frame.shadow_offset = Vector2(0, 6)
	frame.anti_aliasing = true
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	var bar := StyleBoxFlat.new()
	bar.bg_color = BAR_COLOR
	bar.corner_radius_top_left = RADIUS
	bar.corner_radius_top_right = RADIUS
	bar.anti_aliasing = true
	draw_style_box(bar, Rect2(Vector2(1, 1), Vector2(size.x - 2, BAR)))
	draw_line(Vector2(1, BAR + 1), Vector2(size.x - 1, BAR + 1), EDGE, 1.0)
	var colors := [Color("ff5f57"), Color("febc2e"), Color("28c840")]
	var glyphs := ["×", "–", "+"]
	var font: Font = ThemeDB.fallback_font
	for index in range(3):
		var c := _button_center(index)
		draw_circle(c, 6.2, colors[index])
		draw_arc(c, 6.2, 0.0, TAU, 20, colors[index].darkened(0.25), 0.8, true)
		if not hover_button.is_empty():
			draw_string(font, c + Vector2(-3.4, 4.0), glyphs[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.6))
	draw_string(font, Vector2(0, BAR * 0.5 + 5.0), "Inventory", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color("d8ccb0"))
	if simulation != null and simulation.state.has("inventories"):
		var s: Dictionary = simulation.state
		var inv: Dictionary = s.inventories[str(s.player)]
		var load_text := "%d / %d" % [Inventory.used(inv), inv.capacity]
		draw_string(font, Vector2(size.x - 14.0 - font.get_string_size(load_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, BAR * 0.5 + 4.0), load_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8f8670"))
