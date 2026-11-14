extends Node2D
const CELL: float = 24.0
var simulation: RefCounted
var selected_id: int = 0
var visible_entities: int = 0
var loaded_chunks: int = 0
var font: Font = ThemeDB.fallback_font

func _draw() -> void:
	if simulation == null:
		return
	var s: Dictionary = simulation.state
	var camera := get_viewport().get_camera_2d()
	var center: Vector2 = camera.global_position if camera else Vector2(64, 46) * CELL
	var half := get_viewport_rect().size / (camera.zoom if camera else Vector2.ONE) / 2.0 + Vector2(60, 60)
	var bounds := Rect2(center - half, half * 2)
	var world_bounds: Array = s.world.get("bounds", [0, 0, 128, 96])
	var left: int = maxi(world_bounds[0], floori(bounds.position.x / CELL))
	var top: int = maxi(world_bounds[1], floori(bounds.position.y / CELL))
	var right: int = mini(world_bounds[2], ceili(bounds.end.x / CELL))
	var bottom: int = mini(world_bounds[3], ceili(bounds.end.y / CELL))
	loaded_chunks = (right / 64 - left / 64 + 1) * (bottom / 64 - top / 64 + 1)
	draw_rect(Rect2(world_bounds[0] * CELL, world_bounds[1] * CELL, (world_bounds[2] - world_bounds[0]) * CELL, (world_bounds[3] - world_bounds[1]) * CELL), Color("293f35"))
	if s.has("routes"):
		draw_line(Vector2(64, 46) * CELL, Vector2(180, 46) * CELL, Color("675e49"), 22)
	for y in range(top, bottom):
		for x in range(left, right):
			var color := Color("30483a") if (x * 13 + y * 7) % 5 == 0 else Color("2c4236")
			draw_rect(Rect2(x * CELL, y * CELL, CELL - 1, CELL - 1), color)
	# Footpaths are decoration, not a second authoritative map.
	draw_line(Vector2(55, 46) * CELL, Vector2(78, 46) * CELL, Color("756c50"), 30)
	draw_line(Vector2(64, 40) * CELL, Vector2(64, 54) * CELL, Color("756c50"), 30)
	for key in s.world.blocked:
		var parts: PackedStringArray = key.split(",")
		var point := Vector2(int(parts[0]), int(parts[1])) * CELL
		if bounds.has_point(point):
			draw_circle(point, 10, Color("87918a"))
	visible_entities = 0
	# Static places first, residents and player above them.
	for actors in [false, true]:
		for entity in s.entities.values():
			if not entity.has("cell"):
				continue
			if (entity.kind in ["resident", "player"]) != actors:
				continue
			var p := Vector2(entity.cell[0], entity.cell[1]) * CELL
			if not bounds.grow(50).has_point(p):
				continue
			visible_entities += 1
			_draw_entity(s, entity, p)
	var player: Dictionary = s.entities[str(s.player)]
	var player_point := Vector2(player.cell[0], player.cell[1]) * CELL
	if bounds.has_point(player_point):
		_draw_entity(s, player, player_point)

func _draw_entity(s: Dictionary, entity: Dictionary, p: Vector2) -> void:
	var selected: bool = entity.id == selected_id
	if selected:
		draw_arc(p, 22, 0, TAU, 32, Color("f4d889"), 2.5)
	match entity.kind:
		"tree":
			var logs: int = s.inventories[str(entity.id)].items.get("log", 0)
			draw_rect(Rect2(p - Vector2(3, 0), Vector2(6, 14)), Color("8a6a44"))
			if logs > 0:
				draw_circle(p - Vector2(0, 5), 13, Color("192e28"))
				draw_circle(p - Vector2(3, 8), 10, Color("4e7651"))
		"resident":
			var npc: Dictionary = s.residents[str(entity.id)]
			draw_circle(p + Vector2(2, 5), 8, Color(0, 0, 0, 0.25))
			draw_circle(p, 7, Color("d59d61") if npc.job != 0 else Color("8fa9ba"))
			draw_circle(p - Vector2(0, 6), 4, Color("e9c39c"))
			if npc.hunger >= 60:
				draw_string(font, p + Vector2(-3, -14), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffce75"))
			if selected:
				var previous := p
				for cell in npc.path:
					var next := Vector2(cell[0], cell[1]) * CELL
					draw_line(previous, next, Color(0.9, 0.8, 0.5, 0.55), 2)
					previous = next
		"player":
			draw_circle(p, 10, Color("e9e4ce"))
			draw_circle(p, 6, Color("386e83"))
			draw_string(font, p + Vector2(-13, -18), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fff2ce"))
		"farm":
			for row in range(4):
				draw_line(p + Vector2(-21, row * 9 - 16), p + Vector2(21, row * 9 - 16), Color("a2a45c"), 5)
		"warehouse", "home", "sawmill", "construction", "market":
			var colors: Dictionary = {"warehouse": Color("bc945f"), "home": Color("a98772"), "sawmill": Color("a5b4aa"), "construction": Color("d8c576"), "market": Color("7a9daa")}
			draw_rect(Rect2(p - Vector2(19, 15), Vector2(38, 32)), colors[entity.kind])
			var roof := PackedVector2Array([p + Vector2(-23, -14), p + Vector2(0, -29), p + Vector2(23, -14)])
			draw_colored_polygon(roof, Color("654b43"))
			draw_rect(Rect2(p + Vector2(-4, 3), Vector2(8, 14)), Color("3d392f"))
			draw_string(font, p + Vector2(-30, 33), entity.kind.capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ece0bf"))
		"caravan":
			draw_rect(Rect2(p - Vector2(12, 7), Vector2(24, 14)), Color("e8c582"))
			draw_circle(p + Vector2(-7, 8), 4, Color("242d29"))
			draw_circle(p + Vector2(7, 8), 4, Color("242d29"))
		"stash":
			draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color("d8c576"))

func pick(world_position: Vector2) -> int:
	var best: int = 0
	var distance: float = 27.0
	for entity in simulation.state.entities.values():
		if not entity.has("cell"):
			continue
		var p := Vector2(entity.cell[0], entity.cell[1]) * CELL
		var candidate := p.distance_to(world_position)
		if candidate < distance:
			distance = candidate
			best = entity.id
	return best
