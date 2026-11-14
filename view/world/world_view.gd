extends Node2D
const CharacterArt = preload("res://view/actors/frontier_character.gd")
const MapArt = preload("res://view/world/frontier_map_art.gd")
const World = preload("res://sim/world/world_db.gd")
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
	draw_rect(Rect2(world_bounds[0] * CELL, world_bounds[1] * CELL, (world_bounds[2] - world_bounds[0]) * CELL, (world_bounds[3] - world_bounds[1]) * CELL), Color("77794d"))
	for y in range(top, bottom):
		for x in range(left, right):
			MapArt.ground(self, x, y)
	if s.has("routes"):
		draw_line(Vector2(46, 48) * CELL, Vector2(202, 48) * CELL, Color("a68b60"), 38, true)
	for entity in s.entities.values():
		if entity.has("footprint"):
			var door := Vector2(entity.cell[0], entity.cell[1]) * CELL
			if entity.cell[1] <= 48:
				draw_line(door, Vector2(door.x, 48 * CELL), Color("ad9163"), 26, true)
			else:
				var edge: float = (World.building_rect(entity).end.x + 1) * CELL
				var points := PackedVector2Array([door, door + Vector2(0, 36), Vector2(edge, door.y + 36), Vector2(edge, 48 * CELL)])
				draw_polyline(points, Color("ad9163"), 26, true)
	for key in s.world.blocked:
		var parts: PackedStringArray = key.split(",")
		var point := Vector2(int(parts[0]), int(parts[1])) * CELL
		if bounds.has_point(point):
			MapArt.rock(self, point)
	visible_entities = 0
	# Static places first, residents and player above them.
	for actors in [false, true]:
		for entity in s.entities.values():
			if not entity.has("cell"):
				continue
			if (entity.kind in ["resident", "player"]) != actors:
				continue
			var p := Vector2(entity.cell[0], entity.cell[1]) * CELL
			if not bounds.grow(200).has_point(p):
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
			if World.inside_building(s, entity.cell) == 0:
				MapArt.tree(self, p, s.inventories[str(entity.id)].items.get("log", 0), entity.id)
		"resident":
			var npc: Dictionary = s.residents[str(entity.id)]
			var cargo: bool = not s.inventories[str(entity.id)].items.is_empty()
			CharacterArt.paint(self, p, entity.id, s.tick, npc, false, cargo)
			if npc.hunger >= 60:
				draw_string(font, p + Vector2(-3, -51), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffce75"))
			if selected:
				var previous := p
				for cell in npc.path:
					var next := Vector2(cell[0], cell[1]) * CELL
					draw_line(previous, next, Color(0.9, 0.8, 0.5, 0.55), 2)
					previous = next
		"player":
			CharacterArt.paint(self, p, entity.id, s.tick, {"path": s.get("player_path", [])}, true, false)
			draw_string(font, p + Vector2(-13, -51), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fff2ce"))
		"farm":
			MapArt.farm(self, p, s.inventories[str(entity.id)].items.get("food", 0))
		"warehouse", "home", "sawmill", "market":
			var footprint := World.building_rect(entity)
			var rect := Rect2(Vector2(footprint.position) * CELL - Vector2.ONE * CELL / 2, Vector2(footprint.size) * CELL)
			MapArt.building(self, entity, rect, s.inventories.get(str(entity.id), {}).get("items", {}))
			draw_string(font, Vector2(rect.get_center().x - 25, rect.position.y - 23), entity.kind.capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f7e3ac"))
		"construction":
			var footprint := World.footprint(entity.cell, "home")
			var rect := Rect2(Vector2(footprint.position) * CELL - Vector2.ONE * CELL / 2, Vector2(footprint.size) * CELL)
			draw_rect(rect, Color("9b8055"))
			draw_rect(rect, Color("d9be7f"), false, 3)
			for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
				MapArt.box(self, Rect2(corner - Vector2(3, 20), Vector2(6, 25)), Color("75502f"))
			MapArt.crate(self, p - Vector2(25, 20))
		"caravan": MapArt.cart(self, p)
		"stash": MapArt.crate(self, p)

func pick(world_position: Vector2) -> int:
	var best: int = 0
	var distance: float = 27.0
	for entity in simulation.state.entities.values():
		if not entity.has("cell"):
			continue
		var p := Vector2(entity.cell[0], entity.cell[1]) * CELL
		var candidate := (p - Vector2(0, 20) if entity.kind in ["resident", "player"] else p).distance_to(world_position)
		if candidate < distance:
			distance = candidate
			best = entity.id
	if best == 0:
		for entity in simulation.state.entities.values():
			if entity.has("footprint"):
				var rect := World.building_rect(entity)
				if Rect2(Vector2(rect.position) * CELL - Vector2.ONE * CELL / 2, Vector2(rect.size) * CELL).has_point(world_position):
					return entity.id
	return best
