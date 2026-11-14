extends Camera2D
## Presentation-only zoom. The application chooses follow or observer movement.
const MIN_ZOOM: float = 0.4
const MAX_ZOOM: float = 2.5
const ZOOM_FACTOR: float = 1.15

func adjust_zoom(factor: float) -> void:
	zoom = Vector2.ONE * clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			adjust_zoom(ZOOM_FACTOR)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			adjust_zoom(1.0 / ZOOM_FACTOR)
