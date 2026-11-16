extends Node2D
const MapArt = preload("res://view/world/frontier_map_art.gd")
const Planner = preload("res://sim/settlement/planner.gd")
const World = preload("res://sim/world/world_db.gd")
const FixtureArt = preload("res://view/world/fixture_art.gd")
const Fixtures = preload("res://view/world/fixture_director.gd")
const Director = preload("res://view/actors/animation_director.gd")
const DrawnCharacter = preload("res://view/actors/drawn_character.gd")
const RoadSurface = preload("res://view/world/road_surface.gd")
const LANDSCAPE = preload("res://view/world/landscape.gdshader")
const CELL: float = 24.0
var simulation: RefCounted
var selected_id: int = 0
var visible_entities: int = 0
var loaded_chunks: int = 0
var font: Font = ThemeDB.fallback_font
var motion := Director.new()
var fixture_motion := Fixtures.new()
var background: Node2D
var landscape: ColorRect
var landscape_region := Rect2()
var landscape_seed: int = -1
var roads := RoadSurface.new()
var road_buildings: int = -1
var refresh_age: float = 0.0
var last_camera: Vector2 = Vector2.INF
var last_zoom: Vector2 = Vector2.ZERO
var daylight: CanvasModulate
var building_rects: Array[Rect2i] = []
var atmosphere_time: float = 0.0
var character_models: Dictionary = {}
var depth_objects: Dictionary = {}

class Background extends Node2D:
	var projector: Node2D
	func _draw() -> void:
		projector.draw_static(self)

class DepthObject extends Node2D:
	var projector: Node2D
	var object_kind: String = ""
	var entity_id: int = 0
	var fixture_index: int = 0
	var furniture_data: Dictionary = {}
	var construction_tile: Dictionary = {}
	var wall_neighbours: Dictionary = {}
	func _draw() -> void:
		if projector.simulation == null: return
		var s: Dictionary = projector.simulation.state
		if object_kind == "wall":
			MapArt.cutaway_wall(self, wall_neighbours)
		elif object_kind == "construction_tile":
			MapArt.build_piece(self, construction_tile.kind, construction_tile.progress, construction_tile.cell)
		elif object_kind == "tree":
			var entity: Dictionary = s.entities.get(str(entity_id), {})
			if not entity.is_empty():
				MapArt.tree(self, Vector2.ZERO, s.inventories[str(entity_id)].items.get("log", 0), entity_id, projector.motion.tree_pose(entity_id, position))
		elif object_kind == "fixture":
			var entity: Dictionary = s.entities.get(str(entity_id), {})
			if not entity.is_empty() and s.inventories.has(str(entity_id)):
				draw_set_transform(-position)
				FixtureArt.paint(self, entity, s.inventories[str(entity_id)].items, float(projector.fixture_motion.phases.get(str(entity_id), 0)), projector.fixture_motion.running.get(str(entity_id), false), fixture_index)
				draw_set_transform(Vector2.ZERO)
		elif object_kind == "furniture":
			draw_set_transform(-position)
			MapArt.draw_furnishing(self, furniture_data)
			draw_set_transform(Vector2.ZERO)
		elif object_kind == "rock": MapArt.rock(self, Vector2.ZERO)
		elif object_kind == "caravan": MapArt.cart(self, Vector2.ZERO)
		elif object_kind == "stash":
			var stock: Dictionary = s.inventories.get(str(entity_id), {}).get("items", {})
			var offset: int = 0
			for item in stock:
				FixtureArt.item(self, Vector2(offset, 0), item)
				offset += 12

func _ready() -> void:
	y_sort_enabled = true
	landscape = ColorRect.new()
	landscape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	landscape.z_index = -2
	var material := ShaderMaterial.new()
	material.shader = LANDSCAPE
	landscape.material = material
	add_child(landscape)
	daylight = CanvasModulate.new()
	add_child(daylight)
	background = Background.new()
	background.projector = self
	background.z_index = -1
	add_child(background)

func animate(delta: float, paused: bool, speed: int) -> void:
	if simulation == null:
		return
	_sync_landscape()
	motion.update(simulation.state, delta, paused, speed)
	_sync_characters(0.0 if paused else minf(delta, 0.1) * speed)
	if not paused: atmosphere_time += minf(delta, 0.1) * speed
	fixture_motion.update(simulation.state,delta,paused,speed)
	_sync_depth_objects()
	# Lighting follows the authoritative 24-hour clock and freezes on pause.
	var sun: float = sin((float(simulation.state.tick % 14400) / 14400.0 - 0.25) * TAU)
	var light: float = smoothstep(-0.35, 0.25, sun)
	var weather: Dictionary = simulation.state.get("weather", {})
	var overcast: float = _weather_amount(weather, "rain") * 0.17 + _weather_amount(weather, "snow") * 0.10 + _weather_amount(weather, "fog") * 0.13
	daylight.color = Color("8797b0").lerp(Color("fff1d5"), light).darkened(overcast)
	refresh_age += delta
	var camera := get_viewport().get_camera_2d()
	if camera != null and (camera.position != last_camera or camera.zoom != last_zoom or refresh_age > 0.25):
		background.queue_redraw()
		last_camera = camera.position
		last_zoom = camera.zoom
		refresh_age = 0
	queue_redraw()

func _sync_landscape() -> void:
	var state: Dictionary = simulation.state
	var limits: Array = state.world.get("bounds", [0, 0, 128, 96])
	var region := Rect2(
		Vector2(limits[0], limits[1]) * CELL,
		Vector2(limits[2] - limits[0], limits[3] - limits[1]) * CELL)
	var seed_value: int = int(state.seed) % 9973
	var completed: int = state.get("completed_buildings", 0)
	if landscape_region == region and landscape_seed == seed_value and road_buildings == completed: return
	road_buildings = completed
	landscape_region = region
	landscape_seed = seed_value
	landscape.position = region.position
	landscape.size = region.size
	landscape.material.set_shader_parameter("world_origin", region.position)
	landscape.material.set_shader_parameter("terrain_seed", float(seed_value))
	landscape.material.set_shader_parameter("road_mask", roads.bake(state, region))

func snap_visuals() -> void:
	road_buildings = -1
	motion.reset()
	fixture_motion.reset()
	if simulation != null:
		_sync_landscape()
		motion.update(simulation.state, 0, true, 1)
		_sync_characters()
		fixture_motion.update(simulation.state,0,true,1)
		_sync_depth_objects()
	if background != null:
		background.queue_redraw()
	queue_redraw()

func _sync_characters(delta: float = -1.0) -> void:
	if simulation == null: return
	var bounds := view_bounds().grow(120)
	var keep: Dictionary = {}
	for key in motion.actors:
		var pose: Dictionary = motion.actors[key]
		if not bounds.has_point(pose.position): continue
		var entity: Dictionary = simulation.state.entities.get(key, {})
		if entity.is_empty(): continue
		keep[key] = true
		if not character_models.has(key):
			var character := DrawnCharacter.new()
			add_child(character)
			character.setup(entity.id, entity.kind == "player", entity.kind == "raider")
			character_models[key] = character
		character_models[key].set_pose(pose, delta)
	for key in character_models.keys():
		if not keep.has(key):
			character_models[key].queue_free()
			character_models.erase(key)

func _depth_node(key: String, kind: String, pos: Vector2, entity_id: int = 0) -> void:
	if not depth_objects.has(key):
		var item := DepthObject.new()
		item.projector = self
		item.object_kind = kind
		item.entity_id = entity_id
		add_child(item)
		depth_objects[key] = item
	var item: DepthObject = depth_objects[key]
	item.position = pos
	if kind != "wall": item.queue_redraw()

func _sync_depth_objects() -> void:
	if simulation == null: return
	var s: Dictionary = simulation.state
	var bounds := view_bounds().grow(130)
	var keep: Dictionary = {}
	var occupied_rooms: Array[Rect2i] = []
	for building in s.entities.values():
		if building.has("footprint"): occupied_rooms.append(World.building_rect(building))
	for cell_key in s.world.get("building_walls", {}):
		var xy: PackedStringArray = cell_key.split(",")
		var x: int = int(xy[0])
		var y: int = int(xy[1])
		var p := Vector2(x * CELL, y * CELL + CELL / 2)
		if not bounds.has_point(p): continue
		var key: String = "wall:" + cell_key
		keep[key] = true
		_depth_node(key, "wall", p)
		var owner: int = s.world.building_walls[cell_key]
		var neighbours := {
			"north": s.world.building_walls.get("%d,%d" % [x, y - 1], 0) == owner,
			"south": s.world.building_walls.get("%d,%d" % [x, y + 1], 0) == owner,
			"west": s.world.building_walls.get("%d,%d" % [x - 1, y], 0) == owner,
			"east": s.world.building_walls.get("%d,%d" % [x + 1, y], 0) == owner,
			"northwest": s.world.building_walls.get("%d,%d" % [x - 1, y - 1], 0) == owner,
			"northeast": s.world.building_walls.get("%d,%d" % [x + 1, y - 1], 0) == owner,
			"southwest": s.world.building_walls.get("%d,%d" % [x - 1, y + 1], 0) == owner,
			"southeast": s.world.building_walls.get("%d,%d" % [x + 1, y + 1], 0) == owner,
		}
		var wall: DepthObject = depth_objects[key]
		if wall.wall_neighbours != neighbours:
			wall.wall_neighbours = neighbours
			wall.queue_redraw()
	for site in s.get("construction", {}).values():
		if site.done or site.get("build_phase", "") != "build": continue
		var piece := Planner.current_tile(site)
		if piece.is_empty() or piece.progress <= 0.0: continue
		var p := Vector2(piece.cell[0], piece.cell[1]) * CELL + Vector2(0, CELL / 2)
		if not bounds.has_point(p): continue
		var key := "construction_tile:%d" % site.id
		keep[key] = true
		_depth_node(key, "construction_tile", p, site.id)
		depth_objects[key].construction_tile = piece
	for cell_key in s.world.blocked:
		var xy: PackedStringArray = cell_key.split(",")
		var p := Vector2(int(xy[0]), int(xy[1])) * CELL
		if not bounds.has_point(p): continue
		var key: String = "rock:" + cell_key
		keep[key] = true
		_depth_node(key, "rock", p)
	for entity in s.entities.values():
		if entity.get("kind", "") == "tree":
			var p := Vector2(entity.cell[0], entity.cell[1]) * CELL
			if not bounds.has_point(p): continue
			var inside: bool = false
			for room in occupied_rooms:
				if room.has_point(Vector2i(entity.cell[0], entity.cell[1])): inside = true; break
			if inside: continue
			var key := "tree:%d" % entity.id
			keep[key] = true
			_depth_node(key, "tree", p, entity.id)
		elif entity.get("kind", "") in ["stash", "caravan"] and entity.has("cell"):
			var p := Vector2(entity.cell[0], entity.cell[1]) * CELL
			if not bounds.has_point(p): continue
			var key := "%s:%d" % [entity.kind, entity.id]
			keep[key] = true
			_depth_node(key, entity.kind, p, entity.id)
		elif not entity.get("fixtures", []).is_empty() and s.inventories.has(str(entity.id)):
			for index in range(entity.fixtures.size()):
				var rect: Array = entity.fixtures[index].rect
				var p := Vector2(rect[0] + rect[2] / 2.0, rect[1] + rect[3]) * CELL - Vector2(0, 12)
				if not bounds.has_point(p): continue
				var key := "fixture:%d" % entity.id if index == 0 else "fixture:%d:%d" % [entity.id, index]
				keep[key] = true
				_depth_node(key, "fixture", p, entity.id)
				depth_objects[key].fixture_index = index
		if entity.has("footprint"):
			var items := MapArt.furnishings(entity)
			for index in range(items.size()):
				var entry: Dictionary = items[index]
				var p: Vector2 = entry.point + Vector2(0, entry.bottom)
				if not bounds.has_point(p): continue
				var key := "furniture:%d:%d" % [entity.id, index]
				keep[key] = true
				_depth_node(key, "furniture", p, entity.id)
				depth_objects[key].furniture_data = entry
	for key in depth_objects.keys():
		if not keep.has(key):
			depth_objects[key].queue_free()
			depth_objects.erase(key)

func view_bounds() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	var center: Vector2 = camera.global_position if camera else Vector2(64, 46) * CELL
	var half := get_viewport_rect().size / (camera.zoom if camera else Vector2.ONE) / 2 + Vector2(60, 60)
	return Rect2(center - half, half * 2)


func draw_static(canvas: Node2D) -> void:
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
	for settlement in s.get("settlements", {}).values():
		var store: Dictionary = s.entities[str(settlement.warehouse)]
		MapArt.square(canvas, Vector2(store.cell[0], 49) * CELL)
	var garden_exclusions: Array = []
	for building in s.entities.values():
		if building.has("footprint"):
			var r := World.building_rect(building)
			garden_exclusions.append(Rect2(Vector2(r.position)*CELL,Vector2(r.size)*CELL))
	MapArt.vegetation(canvas, bounds, garden_exclusions, atmosphere_time, motion.wind_strength, roads.coverage)
	var weather: Dictionary = s.get("weather", {})
	var snow: float = float(weather.get("snow", 0)) / 100.0
	if snow > 0.0:
		canvas.draw_rect(bounds, Color(0.83, 0.89, 0.88, snow * 0.56))
	for entity in s.entities.values():
		if not entity.has("cell") or entity.kind in ["resident", "player", "raider", "tree", "caravan", "stash"]:
			continue
		var point := Vector2(entity.cell[0], entity.cell[1]) * CELL
		if bounds.grow(200).has_point(point):
			_draw_entity(s, entity, point, canvas)

func _draw() -> void:
	if simulation == null:
		return
	if motion.previous_tick < 0:
		motion.update(simulation.state, 0, true, 1)
		fixture_motion.update(simulation.state,0,true,1)
	var s: Dictionary = simulation.state
	var bounds := view_bounds().grow(90)
	building_rects.clear()
	for building in s.entities.values():
		if building.has("footprint"):
			building_rects.append(World.building_rect(building))
	var visible: Array = []
	for entity in s.entities.values():
		if not entity.has("cell") or entity.kind not in ["resident", "player", "raider"]:
			continue
		var point := Vector2(entity.cell[0], entity.cell[1]) * CELL
		if motion.actors.has(str(entity.id)):
			point = motion.actors[str(entity.id)].position
		if bounds.has_point(point):
			visible.append({"entity": entity, "point": point})
	visible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.point.y < b.point.y or (a.point.y == b.point.y and a.entity.id < b.entity.id))
	visible_entities = visible.size()
	for entry in visible:
		_draw_entity(s, entry.entity, entry.point)
	fixture_motion.draw_transfers(self)
	_draw_combat(s)
	_draw_weather(s, bounds)

func _draw_combat(s: Dictionary) -> void:
	var combat: Dictionary = s.get("local_combat", {})
	for shot in combat.get("projectiles", []):
		var cell: Array = shot.cells[shot.index]
		var p := Vector2(cell[0], cell[1]) * CELL + Vector2(0, -34)
		draw_line(p - Vector2(7, 0), p + Vector2(5, 0), Color("ffe6a2"), 3)
	for effect in combat.get("effects", []):
		var age: int = s.tick - effect.tick
		var p := Vector2(effect.cell[0], effect.cell[1]) * CELL + Vector2(0, -34)
		var color := Color("ffc968") if effect.kind == "muzzle" else Color("ef8b6c")
		color.a = clampf(1.0 - float(age) / 12.0, 0, 1)
		for i in range(4):
			var direction := Vector2.from_angle(float(i) * TAU / 4.0 + 0.3)
			draw_line(p + direction * 4, p + direction * (8 + age), color, 2)

func _weather_amount(weather: Dictionary, kind: String) -> float:
	if weather.is_empty(): return 0.0
	var blend: float = clampf(float(simulation.state.tick - int(weather.get("since", 0))) / 300.0, 0.0, 1.0)
	return (1.0 - blend if weather.get("previous", "clear") == kind else 0.0) + (blend if weather.get("kind", "clear") == kind else 0.0)

func _draw_weather(s: Dictionary, bounds: Rect2) -> void:
	var weather: Dictionary = s.get("weather", {})
	var fog: float = _weather_amount(weather, "fog")
	if fog > 0.0: draw_rect(bounds, Color(0.72, 0.75, 0.72, fog * 0.16))
	var rain: float = _weather_amount(weather, "rain")
	var snow: float = _weather_amount(weather, "snow")
	if rain + snow <= 0.01: return
	var count: int = 120
	for index in range(count):
		var x: float = fposmod(index * 97.0 + atmosphere_time * (24.0 + weather.get("wind", 25) * 0.3), bounds.size.x)
		var y: float = fposmod(index * 157.0 + atmosphere_time * (210.0 if rain > snow else 35.0), bounds.size.y)
		var p: Vector2 = bounds.position + Vector2(x, y)
		if rain > snow:
			draw_line(p, p + Vector2(-4, 13), Color(0.72, 0.81, 0.86, rain * 0.48), 1.0)
		else:
			draw_circle(p, 1.8, Color(0.94, 0.96, 0.94, snow * 0.75))

func _draw_entity(s: Dictionary, entity: Dictionary, p: Vector2, canvas: Node2D = null) -> void:
	if canvas == null: canvas = self
	var selected: bool = entity.id == selected_id
	if selected:
		var marker := Rect2(p + Vector2(-14, -14), Vector2(28, 28))
		var mark_color := Color("f4d889")
		for corner in [Vector2(marker.position.x, marker.position.y), Vector2(marker.end.x, marker.position.y), Vector2(marker.position.x, marker.end.y), marker.end]:
			var sx: float = 7 if corner.x == marker.position.x else -7
			var sy: float = 7 if corner.y == marker.position.y else -7
			canvas.draw_line(corner, corner + Vector2(sx, 0), mark_color, 2)
			canvas.draw_line(corner, corner + Vector2(0, sy), mark_color, 2)
	match entity.kind:
		"tree":
			if not tree_inside_building(entity.cell):
				MapArt.tree(canvas, p, s.inventories[str(entity.id)].items.get("log", 0), entity.id, motion.tree_pose(entity.id, p))
		"resident", "raider":
			var npc: Dictionary = s.residents.get(str(entity.id), {})
			var cargo: bool = not s.inventories[str(entity.id)].items.is_empty()
			var fighter: Dictionary = s.get("local_combat", {}).get("fighters", {}).get(str(entity.id), {})
			if not fighter.is_empty():
				canvas.draw_rect(Rect2(p + Vector2(-15, -87), Vector2(30, 4)), Color("382b25"))
				canvas.draw_rect(Rect2(p + Vector2(-15, -87), Vector2(30.0 * fighter.health / 100.0, 4)), Color("b5cd85") if fighter.side == "defender" else Color("df8a6d"))
			if npc.get("hunger", 0) >= 60:
				canvas.draw_string(font, p + Vector2(-3, -83), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffce75"))
			if selected and npc.has("path"):
				var previous := p
				for cell in npc.path:
					var next := Vector2(cell[0], cell[1]) * CELL
					canvas.draw_line(previous, next, Color(0.9, 0.8, 0.5, 0.55), 2)
					previous = next
		"player":
			canvas.draw_string(font, p + Vector2(-13, -83), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fff2ce"))
		"farm":
			MapArt.farm(canvas, p, s.inventories[str(entity.id)].items.get("food", 0))
		"warehouse", "home", "sawmill", "market":
			var footprint := World.building_rect(entity)
			var rect := Rect2(Vector2(footprint.position) * CELL - Vector2.ONE * CELL / 2, Vector2(footprint.size) * CELL)
			MapArt.frontage(canvas, entity, rect)
			MapArt.building(canvas, entity)
			if selected:
				canvas.draw_string(font, Vector2(rect.get_center().x - 25, rect.position.y - 10), entity.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f7e3ac"))
		"construction":
			var site: Dictionary = s.construction.get(str(entity.id), {})
			var definition: Dictionary = s.building_defs.get(site.get("definition", ""), {"kind": "home"})
			var footprint := World.plot_rect(entity, definition.get("kind", "home"))
			var rect := Rect2(Vector2(footprint.position) * CELL - Vector2.ONE * CELL / 2, Vector2(footprint.size) * CELL)
			MapArt.construction(canvas, entity, site, rect)
		"caravan": MapArt.cart(canvas, p)
		"stash":
			var items: Dictionary = s.inventories[str(entity.id)].items
			var offset: int=0
			for item in items:
				FixtureArt.item(canvas,p+Vector2(offset,0),item)
				offset+=12

func pick(world_position: Vector2) -> int:
	var best: int = 0
	var distance: float = 34.0
	for entity in simulation.state.entities.values():
		if not entity.has("cell"):
			continue
		var p := Vector2(entity.cell[0], entity.cell[1]) * CELL
		var candidate := (p - Vector2(0, 30) if entity.kind in ["resident", "player"] else p).distance_to(world_position)
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

func tree_inside_building(cell: Array) -> bool:
	for rect in building_rects:
		if rect.has_point(Vector2i(cell[0], cell[1])):
			return true
	return false
