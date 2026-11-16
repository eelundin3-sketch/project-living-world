extends SceneTree
## Renders the six rye growth stages side by side: docs/screenshots/rye-growth.png
const CropArt = preload("res://view/world/crop_art.gd")
const Crops = preload("res://sim/farming/crops.gd")
class Sheet extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 460), Color("a8905f"))
		var names: Array = ["1 Planting", "2 Early growth", "3 Intermediate", "4 Maturation", "5 Fully grown", "6 Harvest-ready"]
		var growth: Array = [600, 9000, 21000, 33500, 41500, 43200]
		for index in range(6):
			var column: int = index % 3
			var row: int = index / 3
			var plot := {"id": index + 1, "kind": "field", "state": "growing", "grown": growth[index], "rect": [0, 0, 7, 3]}
			var area := Rect2(Vector2(36 + column * 410, 70 + row * 210), Vector2(336, 112))
			CropArt.field(self, area, plot, 1.0)
			draw_string(ThemeDB.fallback_font, area.position + Vector2(0, -32), names[index] + "  (%d%%)" % (Crops.permille(plot) / 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("2a1d12"))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 460)
	root.add_child(Sheet.new())
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/rye-growth.png")
	quit()
