extends Camera2D
## Presentation-only zoom. The application chooses follow or observer movement.
const MIN_ZOOM: float = 0.06
const MAX_ZOOM: float = 5.0
const ZOOM_FACTOR: float = 1.15

func adjust_zoom(factor: float) -> void:
	zoom = Vector2.ONE * clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		adjust_zoom(event.factor)
