extends Control
## A screen-space reticle follows the mouse while the button is held.
var active: bool = false
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	if not active: return
	var p: Vector2 = get_local_mouse_position()
	var ink := Color("25291f")
	var light := Color("f6e9bd")
	draw_arc(p, 10, 0, TAU, 28, ink, 3.0, true)
	draw_arc(p, 10, 0, TAU, 28, light, 1.5, true)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(p + direction * 5, p + direction * 15, ink, 4.0, true)
		draw_line(p + direction * 5, p + direction * 15, light, 1.5, true)
