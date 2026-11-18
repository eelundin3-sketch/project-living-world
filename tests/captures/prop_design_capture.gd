extends SceneTree
## Close-up graphic inspection using exactly the same draw calls as gameplay.
const Props = preload("res://view/world/prop_art.gd")
const Fixtures = preload("res://view/world/fixture_art.gd")
const Furniture = preload("res://view/world/interior_art.gd")
const MapArt = preload("res://view/world/frontier_map_art.gd")

class Display extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("b19a77"))
		var scale_value := Vector2.ONE * 4.4
		draw_set_transform(Vector2(195, 112), 0, scale_value)
		Props.log_piece(self, Vector2(-25, 0), Vector2(25, 0), 7)
		draw_set_transform(Vector2(480, 115), 0, scale_value)
		for i in range(3):
			Props.plank(self, Vector2(-27 + i * 3, -i * 4), Vector2(22 + i * 3, -i * 4), 4)
		draw_set_transform(Vector2(824, 115), 0, scale_value)
		Fixtures.item(self, Vector2(-15, 0), "food")
		Fixtures.item(self, Vector2(7, 0), "bandage")
		Fixtures.item(self, Vector2(27, 0), "antiseptic")
		draw_set_transform(Vector2(1109, 116), 0, scale_value)
		MapArt.chest(self, Vector2.ZERO)
		draw_set_transform(Vector2(70, 325), 0, scale_value)
		Furniture.workbench(self, Vector2.ZERO, 0.32, 3)
		draw_set_transform(Vector2(626, 341), 0, scale_value)
		Furniture.bed(self, Vector2.ZERO, Color("9fa7a5"))
		draw_set_transform(Vector2(1100, 450), 0, scale_value)
		MapArt.chair(self, Vector2(-21, 0))
		MapArt.lamp(self, Vector2(9, 0))
		draw_set_transform(Vector2.ZERO)
		_caption("LOG · BARK AND END GRAIN", Vector2(83, 193))
		_caption("SAWN PLANKS", Vector2(416, 193))
		_caption("FOOD AND MEDICAL SUPPLIES", Vector2(732, 193))
		_caption("IRON-BOUND CHEST", Vector2(1024, 193))
		_caption("SAWMILL · FEED ROLLERS, GUARD AND BELT DRIVE", Vector2(76, 548))
		_caption("TIMBER BED AND QUILT", Vector2(626, 548))
		_caption("CHAIR AND LAMP", Vector2(1005, 548))

	func _caption(label: String, point: Vector2) -> void:
		draw_string(ThemeDB.fallback_font, point, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("4c3b2a"))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.add_child(Display.new())
	await process_frame
	await RenderingServer.frame_post_draw
	quit(root.get_texture().get_image().save_png("res://docs/screenshots/prop-detail.png"))
