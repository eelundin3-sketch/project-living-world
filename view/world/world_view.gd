extends Node2D
const MapArt = preload("res://view/world/frontier_map_art.gd")
const CropArt = preload("res://view/world/crop_art.gd")
const MarketArt = preload("res://view/world/market_art.gd")
const Crops = preload("res://sim/farming/crops.gd")
const Planner = preload("res://sim/settlement/planner.gd")
const World = preload("res://sim/world/world_db.gd")
const FixtureArt = preload("res://view/world/fixture_art.gd")
const Fixtures = preload("res://view/world/fixture_director.gd")
const Director = preload("res://view/actors/animation_director.gd")
const DrawnCharacter = preload("res://view/actors/drawn_character.gd")
const RoadSurface = preload("res://view/world/road_surface.gd")
const LANDSCAPE = preload("res://view/world/landscape.gdshader")
const CELL: float = 24.0
## Characters are drawn at half size so they are in proportion to doors, furniture and trees.
const CHAR_SCALE: float = 0.625
## The static background is painted this far beyond the screen so small camera moves need no repaint.
const BACKGROUND_MARGIN: float = 260.0
var simulation: RefCounted
var selected_id: int = 0
var visible_entities: int = 0
var loaded_chunks: int = 0
var font: Font = ThemeDB.fallback_font
var motion := Director.new()
var fixture_motion := Fixtures.new()
var background: Node2D
var shadows: Node2D
var sun_overcast: float = 0.0
var roofs: Array[Rect2] = []
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
var depth_frame: int = 0

class Background extends Node2D:
	var projector: Node2D
	func _draw() -> void:
		projector.draw_static(self)

## Sun shadows for everything that stands up: drawn above the ground and buildings' floors,
## below trees and people.
class ShadowLayer extends Node2D:
	var projector: Node2D
	func _draw() -> void:
		projector.draw_shadows(self)

## Large, slow-changing ground art (the market plaza, one crop plot) is painted once into a
## texture and shown as a sprite. Thousands of small shapes cost real time to submit every
## frame even when cached, so the picture is only re-rendered when the thing it shows changes.
class Painter extends Node2D:
	var decor: Node2D
	func _draw() -> void:
		decor.projector.draw_decor(self, decor)

class Decor extends Node2D:
	const SUPERSAMPLE := 2.0
	var projector: Node2D
	var kind: String = ""
	var key: int = 0
	var area: Rect2 = Rect2()
	var viewport: SubViewport
	var painter: Painter
	var sprite: Sprite2D

	func _ready() -> void:
		viewport = SubViewport.new()
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(viewport)
		painter = Painter.new()
		painter.decor = self
		painter.scale = Vector2.ONE * SUPERSAMPLE
		viewport.add_child(painter)
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.scale = Vector2.ONE / SUPERSAMPLE
		sprite.texture = viewport.get_texture()
		add_child(sprite)
		_apply()

	func set_area(value: Rect2) -> void:
		area = value
		if viewport != null: _apply()

	func _apply() -> void:
		viewport.size = Vector2i(maxi(8, ceili(area.size.x * SUPERSAMPLE)), maxi(8, ceili(area.size.y * SUPERSAMPLE)))
		painter.position = -area.position * SUPERSAMPLE
		sprite.position = area.position
		repaint()

	func repaint() -> void:
		painter.queue_redraw()
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

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
			MapArt.draw_furnishing(self, furniture_data, -position)
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
	shadows = ShadowLayer.new()
	shadows.projector = self
	shadows.z_index = -1
	add_child(shadows)

func animate(delta: float, paused: bool, speed: int) -> void:
	if simulation == null:
		return
	_sync_landscape()
	_sync_decor(delta)
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
	sun_overcast = overcast
	shadows.queue_redraw()
	refresh_age += delta
	var camera := get_viewport().get_camera_2d()
	if camera != null and (camera.position.distance_to(last_camera) > BACKGROUND_MARGIN * 0.4 or camera.zoom != last_zoom or refresh_age > 1.0):
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
	decor_signatures.clear()
	decor_clock = 99.0
	if simulation != null: _sync_decor(1.0)
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
			character.scale = Vector2.ONE * CHAR_SCALE
			add_child(character)
			character.setup(entity.id, entity.kind == "player", entity.kind == "raider")
			character_models[key] = character
		character_models[key].z_index = 2 if pose.get("action", "") == "rest" and int(pose.get("rest_rot", -1)) >= 0 else 0  # sleepers lie on top of the bed
		character_models[key].set_pose(pose, delta)
	for key in character_models.keys():
		if not keep.has(key):
			character_models[key].queue_free()
			character_models.erase(key)

func _depth_node(key: String, kind: String, pos: Vector2, entity_id: int = 0) -> void:
	var fresh: bool = not depth_objects.has(key)
	if fresh:
		var item := DepthObject.new()
		item.projector = self
		item.object_kind = kind
		item.entity_id = entity_id
		add_child(item)
		depth_objects[key] = item
	var item: DepthObject = depth_objects[key]
	item.position = pos
	# Redraw only what can have changed: new nodes, animated things, or a slow refresh for
	# the rest. Walls, rocks and furniture repaint when their data changes (see callers).
	if fresh:
		item.queue_redraw()
		return
	match kind:
		"wall", "rock", "furniture": pass
		"tree":
			# Trees sway slowly, so a third of them per frame is invisible; stumps and falling trees animate every frame.
			var logs: int = simulation.state.inventories.get(str(entity_id), {}).get("items", {}).get("log", 0)
			var felled: bool = simulation.state.entities.get(str(entity_id), {}).get("felled", false)
			if logs == 0 or felled or (depth_frame + entity_id) % 3 == 0: item.queue_redraw()
		"fixture":
			if fixture_motion.running.get(str(entity_id), false) or (depth_frame + entity_id) % 4 == 0: item.queue_redraw()
		_: item.queue_redraw()

func _sync_depth_objects() -> void:
	if simulation == null: return
	depth_frame += 1
	if is_far():
		# Map view: nothing is individually depth-sorted, so drop the nodes until zoomed back in.
		for key in depth_objects.keys():
			depth_objects[key].queue_free()
			depth_objects.erase(key)
		return
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
	var big_rocks: Array = []
	for entity in s.entities.values():
		if entity.has("rock_rect"): big_rocks.append(entity.rock_rect)
	for cell_key in s.world.blocked:
		var xy: PackedStringArray = cell_key.split(",")
		var p := Vector2(int(xy[0]), int(xy[1])) * CELL
		if not bounds.has_point(p): continue
		var under_big_rock := false
		for rr in big_rocks:
			if int(xy[0]) >= rr[0] and int(xy[0]) < rr[0] + rr[2] and int(xy[1]) >= rr[1] and int(xy[1]) < rr[1] + rr[3]: under_big_rock = true
		if under_big_rock: continue  # drawn once as the large boulder
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
				if depth_objects[key].furniture_data != entry:
					depth_objects[key].furniture_data = entry
					depth_objects[key].queue_redraw()
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
	var half := get_viewport_rect().size / (camera.zoom if camera else Vector2.ONE) / 2.0 + Vector2(BACKGROUND_MARGIN, BACKGROUND_MARGIN)
	var bounds := Rect2(center - half, half * 2)
	var world_bounds: Array = s.world.get("bounds", [0, 0, 128, 96])
	var left: int = maxi(world_bounds[0], floori(bounds.position.x / CELL))
	var top: int = maxi(world_bounds[1], floori(bounds.position.y / CELL))
	var right: int = mini(world_bounds[2], ceili(bounds.end.x / CELL))
	var bottom: int = mini(world_bounds[3], ceili(bounds.end.y / CELL))
	loaded_chunks = (right / 64 - left / 64 + 1) * (bottom / 64 - top / 64 + 1)
	for settlement in s.get("settlements", {}).values():
		var store: Dictionary = s.entities[str(settlement.warehouse)]
		MapArt.square(canvas, Vector2(store.cell[0], store.cell[1] + 3) * CELL)
	var garden_exclusions: Array = []
	for settlement in s.get("settlements", {}).values():
		var square_store: Dictionary = s.entities[str(settlement.warehouse)]
		garden_exclusions.append(Rect2(Vector2(square_store.cell[0], square_store.cell[1] + 7) * CELL + Vector2(-300, -78), Vector2(600, 270)))
	for building in s.entities.values():
		if building.has("footprint"):
			var r := World.building_rect(building)
			garden_exclusions.append(Rect2(Vector2(r.position)*CELL,Vector2(r.size)*CELL))
	for plot in s.get("crops", {}).values():
		garden_exclusions.append(plot_area(plot).grow(10))
	if is_far():
		# Map view: canopies as dots instead of thousands of grass tufts and tree nodes.
		for tree in s.entities.values():
			if tree.get("kind", "") == "tree" and bounds.has_point(Vector2(tree.cell[0], tree.cell[1]) * CELL) and s.inventories[str(tree.id)].items.get("log", 0) > 0:
				canvas.draw_circle(Vector2(tree.cell[0], tree.cell[1]) * CELL + Vector2(0, -14), 12.0, Color("14452f"))
	else:
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
	_draw_shotgun(s)
	_draw_brawl(s)
	_draw_travel_goal(s)
	_draw_map_labels(s)
	_draw_weather(s, bounds)

## Blood left on the ground by fights (pools and flung drops that darken as they dry), a short
## spray at the moment a blow lands, and the "z z" over someone who is out cold.
func _draw_brawl(s: Dictionary) -> void:
	var brawl: Dictionary = s.get("brawl", {})
	if brawl.is_empty(): return
	for decal in brawl.blood:
		var age: float = float(s.tick - int(decal.tick))
		var dried: float = clampf(age / 9000.0, 0.0, 1.0)
		var fade: float = 1.0 - clampf((age - 18000.0) / 18000.0, 0.0, 1.0) * 0.7
		var color := Color("a3160f").lerp(Color("46100c"), dried)
		color.a = 0.82 * fade
		var base := Vector2(decal.cell[0], decal.cell[1]) * CELL + Vector2(0, 5)
		var seed_value: int = int(decal.seed)
		var direction := Vector2(decal.dir[0], decal.dir[1]).normalized() if (decal.dir[0] != 0 or decal.dir[1] != 0) else Vector2.RIGHT
		for blob in range(2 + int(decal.size) * 2):
			var centre := base + Vector2((CropArt.rand01(seed_value, blob) - 0.5) * 12.0, (CropArt.rand01(blob, seed_value) - 0.5) * 5.0) + direction * 3.0 * blob * 0.5
			var rx: float = 2.2 + CropArt.rand01(seed_value + 3, blob) * 3.2 * (0.7 + 0.4 * float(decal.size))
			var points := PackedVector2Array()
			for step in range(10):
				var angle: float = TAU * float(step) / 10.0
				var wobble: float = 0.8 + 0.4 * CropArt.rand01(seed_value + step, blob)
				points.append(centre + Vector2(cos(angle) * rx * wobble, sin(angle) * rx * 0.55 * wobble))
			draw_colored_polygon(points, color)
		for drop in range(3 + int(decal.size)):
			var distance: float = 7.0 + CropArt.rand01(seed_value + 9, drop) * 12.0
			var sideways: float = (CropArt.rand01(drop, seed_value + 5) - 0.5) * 8.0
			draw_circle(base + direction * distance + direction.orthogonal() * sideways * 0.5, 0.9 + CropArt.rand01(drop, seed_value) * 1.1, color)
	for fight_event in brawl.events:
		if fight_event.kind != "punch_hit": continue
		var age: float = clampf(float(s.tick - int(fight_event.tick)) / 8.0, 0.0, 1.0)
		if age >= 1.0: continue
		var at := Vector2(fight_event.cell[0], fight_event.cell[1]) * CELL + Vector2(0, -18)
		var push := Vector2(fight_event.dir[0], fight_event.dir[1]).normalized() if (fight_event.dir[0] != 0 or fight_event.dir[1] != 0) else Vector2.RIGHT
		for fleck in range(5):
			var angle: float = push.angle() + (CropArt.rand01(int(fight_event.tick), fleck) - 0.5) * 1.6
			draw_circle(at + Vector2.from_angle(angle) * (4.0 + 12.0 * age) + Vector2(0, 8.0 * age * age), 1.5 * (1.0 - age * 0.5), Color(0.6, 0.08, 0.07, 1.0 - age))
	for entity in s.entities.values():
		var npc: Dictionary = s.get("residents", {}).get(str(entity.id), {})
		if npc.is_empty(): continue
		var knock: Dictionary = npc.get("knock", {})
		if not knock.is_empty() and knock.kind == "ko" and s.tick >= int(knock.start) + 6 and s.tick < int(knock.down_until):
			var head := Vector2(entity.cell[0], entity.cell[1]) * CELL + Vector2(float(knock.get("side", 1)) * 22.0, -20.0 + sin(float(s.tick) * 0.15) * 2.0)
			draw_string(font, head, "z z", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.95, 0.8, 0.85))

## A pulsing ring on the square the player is walking to after a double right-click.
func _draw_travel_goal(s: Dictionary) -> void:
	var path: Array = s.get("player_path", [])
	var goal: Array = s.get("player_travel_goal", [])
	if path.is_empty() or goal.size() != 2: return
	var at := Vector2(goal[0], goal[1]) * CELL + Vector2(0, 6)
	var pulse: float = 0.5 + 0.5 * sin(atime_for_marker() * 6.0)
	draw_arc(at, 9.0 + 3.0 * pulse, 0.0, TAU, 24, Color(1.0, 0.86, 0.4, 0.9), 2.0, true)
	draw_circle(at, 2.2, Color(1.0, 0.86, 0.4, 0.9))

func atime_for_marker() -> float:
	return atmosphere_time

## On the map view: settlement names and a marker on the player, sized for the screen not the world.
func _draw_map_labels(s: Dictionary) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null or camera.zoom.x >= 0.6: return
	var inverse: float = 1.0 / camera.zoom.x
	for town in s.get("settlements", {}).values():
		var store: Array = s.entities[str(town.warehouse)].cell
		var at := Vector2(store[0], store[1] - 16) * CELL
		var size: Vector2 = font.get_string_size(town.name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * inverse))
		draw_rect(Rect2(at + Vector2(-size.x / 2.0 - 8 * inverse, -size.y), size + Vector2(16 * inverse, 6 * inverse)), Color(0.07, 0.06, 0.04, 0.6))
		draw_string(font, at + Vector2(-size.x / 2.0, -4 * inverse), town.name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * inverse), Color("f7e3ac"))
	var player: Dictionary = s.entities.get(str(s.get("player", 0)), {})
	if not player.is_empty():
		var position: Vector2 = motion.actors.get(str(player.id), {}).get("position", Vector2(player.cell[0], player.cell[1]) * CELL)
		draw_circle(position, 9.0 * inverse, Color(0.07, 0.06, 0.04, 0.75))
		draw_circle(position, 6.5 * inverse, Color("ffd45a"))
		draw_string(font, position + Vector2(12 * inverse, 5 * inverse), "You", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * inverse), Color("fff2ce"))

func _draw_combat(s: Dictionary) -> void:
	var combat: Dictionary = s.get("local_combat", {})
	for shot in combat.get("projectiles", []):
		var cell: Array = shot.cells[shot.index]
		var p := Vector2(cell[0], cell[1]) * CELL + Vector2(0, -21)
		draw_line(p - Vector2(5, 0), p + Vector2(3, 0), Color("ffe6a2"), 2)
	for effect in combat.get("effects", []):
		var age: int = s.tick - effect.tick
		var p := Vector2(effect.cell[0], effect.cell[1]) * CELL + Vector2(0, -21)
		var color := Color("ffc968") if effect.kind == "muzzle" else Color("ef8b6c")
		color.a = clampf(1.0 - float(age) / 12.0, 0, 1)
		for i in range(4):
			var direction := Vector2.from_angle(float(i) * TAU / 4.0 + 0.3)
			draw_line(p + direction * 4, p + direction * (8 + age), color, 2)

## Shotgun pellets in flight and the effect each surface produces when struck.
func _draw_shotgun(s: Dictionary) -> void:
	var gun: Dictionary = s.get("shotgun", {})
	if gun.is_empty(): return
	for pellet in gun.pellets:
		var p := Vector2(pellet.x, pellet.y) * CELL + Vector2(0, -20)
		var d := Vector2(pellet.dx, pellet.dy)
		draw_line(p - d * 10.0, p, Color(1.0, 0.92, 0.6, 0.9), 1.4)
	for effect in gun.effects:
		if effect.kind == "blast": continue
		var age: float = clampf(float(s.tick - effect.tick) / 14.0, 0.0, 1.0)
		var base := Vector2(effect.cell[0], effect.cell[1]) * CELL + Vector2(0, -11)
		var dir := Vector2(effect.dir[0], effect.dir[1]) / 1000.0
		var seed_value: int = int(effect.tick) * 7 + int(effect.cell[0]) * 31 + int(effect.cell[1])
		match effect.kind:
			"blood":  # a few small dark-red flecks thrown forward, kept deliberately small and non-graphic
				for i in range(6):
					var angle: float = dir.angle() + (CropArt.rand01(seed_value, i) - 0.5) * 1.5
					var pos: Vector2 = base + Vector2.from_angle(angle) * (5.0 + 16.0 * age * (0.5 + CropArt.rand01(i, seed_value))) + Vector2(0, 26.0 * age * age)
					draw_circle(pos, 1.7 * (1.0 - age * 0.5), Color(0.62, 0.1, 0.09, 1.0 - age))
			"ground":  # dust puff and flung grit
				draw_circle(base + Vector2(0, 8), 5.0 + 10.0 * age, Color(0.72, 0.6, 0.42, 0.45 * (1.0 - age)))
				draw_circle(base + Vector2(-5, 4), 3.0 + 7.0 * age, Color(0.66, 0.55, 0.4, 0.35 * (1.0 - age)))
				for i in range(5):
					var pos: Vector2 = base + Vector2(0, 8) + Vector2((CropArt.rand01(seed_value, i) - 0.5) * 30.0 * age, -14.0 * age * (1.0 - age) * 2.0 * CropArt.rand01(i, 3))
					draw_rect(Rect2(pos, Vector2(1.6, 1.6)), Color(0.5, 0.4, 0.28, 1.0 - age))
			"wall":  # pale plaster-and-timber chips with a dust puff
				draw_circle(base, 4.0 + 8.0 * age, Color(0.82, 0.78, 0.68, 0.4 * (1.0 - age)))
				for i in range(7):
					var angle: float = (-dir).angle() + (CropArt.rand01(seed_value, i) - 0.5) * 2.2
					var pos: Vector2 = base + Vector2.from_angle(angle) * (4.0 + 15.0 * age) + Vector2(0, 18.0 * age * age)
					draw_rect(Rect2(pos, Vector2(2.2, 1.6)), Color(0.86, 0.78, 0.6, 1.0 - age))
			"wood":  # long light splinters
				for i in range(6):
					var angle: float = (-dir).angle() + (CropArt.rand01(seed_value, i) - 0.5) * 2.0
					var a: Vector2 = base + Vector2.from_angle(angle) * (3.0 + 13.0 * age)
					draw_line(a, a + Vector2.from_angle(angle + 0.4) * 4.5, Color(0.8, 0.64, 0.4, 1.0 - age), 1.3)
			"bark":  # brown flecks, torn leaves and a pale scar on the trunk
				draw_circle(base, 2.5, Color(0.9, 0.82, 0.62, 0.8 * (1.0 - age)))
				for i in range(7):
					var angle: float = (-dir).angle() + (CropArt.rand01(seed_value, i) - 0.5) * 2.4
					var pos: Vector2 = base + Vector2.from_angle(angle) * (3.0 + 14.0 * age) + Vector2(0, 16.0 * age * age)
					draw_rect(Rect2(pos, Vector2(2, 2)), Color(0.4, 0.27, 0.15, 1.0 - age) if i % 3 else Color(0.35, 0.55, 0.25, 1.0 - age))
			"spark":
				for i in range(6):
					var angle: float = (-dir).angle() + (CropArt.rand01(seed_value, i) - 0.5) * 2.6
					var a: Vector2 = base + Vector2.from_angle(angle) * (2.0 + 12.0 * age)
					draw_line(a, a + Vector2.from_angle(angle) * 3.5, Color(1.0, 0.9, 0.5, 1.0 - age), 1.2)

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
		var marker := Rect2(p + Vector2(-11, -11), Vector2(22, 22))
		var mark_color := Color("f4d889")
		for corner in [Vector2(marker.position.x, marker.position.y), Vector2(marker.end.x, marker.position.y), Vector2(marker.position.x, marker.end.y), marker.end]:
			var sx: float = 5 if corner.x == marker.position.x else -5
			var sy: float = 5 if corner.y == marker.position.y else -5
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
				canvas.draw_rect(Rect2(p + Vector2(-10, -56), Vector2(20, 3)), Color("382b25"))
				canvas.draw_rect(Rect2(p + Vector2(-10, -56), Vector2(20.0 * fighter.health / 100.0, 3)), Color("b5cd85") if fighter.side == "defender" else Color("df8a6d"))
			if not npc.get("brawl", {}).is_empty():
				canvas.draw_string(font, p + Vector2(-7, -56), "!!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e0443a"))
				for bolt in [-1, 1]:
					canvas.draw_line(p + Vector2(bolt * 9, -56), p + Vector2(bolt * 13, -61), Color("e0443a"), 1.5)
			if npc.get("hunger", 0) >= 60:
				canvas.draw_string(font, p + Vector2(-2, -52), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffce75"))
			_name_tag(canvas, p, entity.name, Color("f2ead2") if entity.kind == "resident" else Color("e79b86"))
			if selected and npc.has("path"):
				var previous := p
				for cell in npc.path:
					var next := Vector2(cell[0], cell[1]) * CELL
					canvas.draw_line(previous, next, Color(0.9, 0.8, 0.5, 0.55), 2)
					previous = next
		"player":
			canvas.draw_string(font, p + Vector2(-9, -52), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("fff2ce"))
			_name_tag(canvas, p, entity.name, Color("ffe9a8"))
		"farm":
			if Crops.plot_for_farm(s, entity.id).is_empty(): MapArt.farm(canvas, p, s.inventories[str(entity.id)].items.get("food", 0))
		"warehouse", "home", "sawmill", "bakery", "forge", "office", "market":
			var footprint := World.building_rect(entity)
			var rect := Rect2(Vector2(footprint.position) * CELL - Vector2.ONE * CELL / 2, Vector2(footprint.size) * CELL)
			# Floors and frontage are painted once into a cached texture (see _sync_decor).
			if selected:
				canvas.draw_string(font, Vector2(rect.get_center().x - 25, rect.position.y - 10), entity.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f7e3ac"))
		"construction":
			var site: Dictionary = s.construction.get(str(entity.id), {})
			var definition: Dictionary = s.building_defs.get(site.get("definition", ""), {"kind": "home"})
			var footprint := World.plot_rect(entity, definition.get("kind", "home"))
			var rect := Rect2(Vector2(footprint.position) * CELL - Vector2.ONE * CELL / 2, Vector2(footprint.size) * CELL)
			MapArt.construction(canvas, entity, site, rect)
		"caravan": MapArt.cart(canvas, p)
		"ore":
			if entity.get("big", false):
				var rr: Array = entity.rock_rect
				MapArt.big_rock(canvas, Rect2(Vector2(rr[0], rr[1]) * CELL - Vector2(12, 12), Vector2(rr[2], rr[3]) * CELL), int(s.inventories[str(entity.id)].items.get("ore", 0)), int(entity.id))
				return
			MapArt.rock(canvas, p)
			for glint in [Vector2(-6, -9), Vector2(5, -14), Vector2(0, -5)]:
				canvas.draw_circle(p + glint, 1.7, Color("d09a52"))
				canvas.draw_circle(p + glint, 0.8, Color("f2d9a0"))
		"stash":
			var items: Dictionary = s.inventories[str(entity.id)].items
			var offset: int=0
			for item in items:
				FixtureArt.item(canvas,p+Vector2(offset,0),item)
				offset+=12

static func plot_area(plot: Dictionary) -> Rect2:
	return Rect2(Vector2(plot.rect[0], plot.rect[1]) * CELL - Vector2(12, 12), Vector2(plot.rect[2], plot.rect[3]) * CELL)

func draw_decor(node: Node2D, decor: Decor) -> void:
	var s: Dictionary = simulation.state
	if decor.kind == "plot":
		var plot: Dictionary = s.get("crops", {}).get(str(decor.key), {})
		if not plot.is_empty(): CropArt.field(node, plot_area(plot), plot, 0.0)
	elif decor.kind == "building":
		var entity: Dictionary = s.entities.get(str(decor.key), {})
		if entity.is_empty() or not entity.has("footprint"): return
		var footprint := World.building_rect(entity)
		var rect := Rect2(Vector2(footprint.position) * CELL - Vector2.ONE * CELL / 2, Vector2(footprint.size) * CELL)
		MapArt.frontage(node, entity, rect)
		MapArt.building(node, entity)
	elif decor.kind == "plaza":
		var settlement: Dictionary = s.get("settlements", {}).get(str(decor.key), {})
		if settlement.is_empty(): return
		var store: Dictionary = s.entities[str(settlement.warehouse)]
		var stalls: Array = []
		for stall_id in settlement.get("stalls", []):
			if s.entities.has(str(stall_id)): stalls.append(s.entities[str(stall_id)])
		MarketArt.plaza(node, Vector2(store.cell[0], store.cell[1] + 7) * CELL, stalls)

## Below this zoom the view is a map: per-object nodes are dropped and trees are simple canopies.
const FAR_ZOOM: float = 0.35

## The sun's shadow for a point one pixel tall, in screen pixels, and how dark shadows are.
## Morning sun in the east throws long shadows to the left; they shorten and swing north (up the
## screen) towards noon, then lengthen to the right through the afternoon and fade at dusk.
func sun_shadow(tick: int) -> Dictionary:
	var day: float = float(tick % 14400) / 14400.0
	var elevation: float = sin((day - 0.25) * TAU)          # matches the daylight colour cycle
	var arc: float = clampf((day - 0.25) / 0.5, 0.0, 1.0)   # 06:00 east .. 18:00 west
	var direction := Vector2(-cos(arc * PI), -0.42 * sin(arc * PI))
	var angle: float = asin(clampf(elevation, 0.0, 1.0)) * 1.05
	var length: float = clampf(cos(angle) / maxf(0.05, sin(angle)), 0.35, 3.4)
	var strength: float = 0.30 * smoothstep(0.0, 0.16, elevation) * clampf(1.0 - sun_overcast * 3.2, 0.15, 1.0)
	return {"vector": Vector2(direction.x, direction.y * 0.55) * length, "strength": strength}

## A soft ellipse laid along the shadow direction.
func _shadow_blob(canvas: Node2D, center: Vector2, along: Vector2, length: float, width: float, color: Color) -> void:
	var axis: Vector2 = along.normalized() if along.length() > 0.001 else Vector2.RIGHT
	var normal := axis.orthogonal()
	var points := PackedVector2Array()
	for i in range(18):
		var a := float(i) / 18.0 * TAU
		points.append(center + axis * cos(a) * length + normal * sin(a) * width)
	_shadow_polygon(canvas, points, color)

## Fills a shadow shape, cutting away any part that lies on a building's floor.
func _shadow_polygon(canvas: Node2D, points: PackedVector2Array, color: Color) -> void:
	var pieces: Array = [points]
	var extent := Rect2(points[0], Vector2.ZERO)
	for point in points: extent = extent.expand(point)
	for roof in roofs:
		if not roof.intersects(extent): continue
		var cut := PackedVector2Array([roof.position, Vector2(roof.end.x, roof.position.y), roof.end, Vector2(roof.position.x, roof.end.y)])
		var remaining: Array = []
		for piece in pieces:
			for part in Geometry2D.clip_polygons(piece, cut): remaining.append(part)
		pieces = remaining
	for piece in pieces:
		# Holes come back wound the other way round; skip them.
		if (piece as PackedVector2Array).size() >= 3 and (pieces.size() == 1 or Geometry2D.is_polygon_clockwise(piece) == Geometry2D.is_polygon_clockwise(points)):
			canvas.draw_colored_polygon(piece, color)

func draw_shadows(canvas: Node2D) -> void:
	if simulation == null or is_far(): return
	var s: Dictionary = simulation.state
	var sun := sun_shadow(int(s.tick))
	var strength: float = sun.strength
	if strength < 0.01: return
	var cast: Vector2 = sun.vector
	var tone := Color(0.08, 0.10, 0.14, strength)
	var soft := Color(0.08, 0.10, 0.14, strength * 0.55)
	var bounds := view_bounds().grow(220)
	# Interiors are under a roof: no sunlight, so no sun shadows fall on building floors.
	roofs.clear()
	for entity in s.entities.values():
		if entity.has("footprint"):
			var fp := World.building_rect(entity)
			var area := Rect2(Vector2(fp.position) * CELL - Vector2.ONE * CELL / 2, Vector2(fp.size) * CELL)
			if bounds.intersects(area): roofs.append(area)
	for entity in s.entities.values():
		if not entity.has("cell"): continue
		var p := Vector2(entity.cell[0], entity.cell[1]) * CELL
		match entity.get("kind", ""):
			"tree":
				if not bounds.has_point(p): continue
				var logs: int = int(s.inventories.get(str(entity.id), {}).get("items", {}).get("log", 0))
				if logs <= 0 or entity.get("felled", false):
					continue
				var dead: bool = entity.get("dead", false)
				# Trunk, then the crown's shadow thrown out along the sun line.
				var foot := p + Vector2(0, -2)
				_shadow_polygon(canvas, PackedVector2Array([foot + cast.orthogonal().normalized() * 3.0, foot - cast.orthogonal().normalized() * 3.0, foot + cast * 46.0 - cast.orthogonal().normalized() * 1.6, foot + cast * 46.0 + cast.orthogonal().normalized() * 1.6]), tone)
				var crown := foot + cast * 64.0
				var spread: float = 15.0 if dead else 27.0
				_shadow_blob(canvas, crown, cast, spread + 7.0 * cast.length(), spread * 0.82, tone)
				_shadow_blob(canvas, crown + cast * 6.0, cast, (spread + 7.0 * cast.length()) * 0.7, spread * 0.6, soft)
			"ore":
				if entity.has("rock_rect"):
					var r: Array = entity.rock_rect
					_building_shadow(canvas, Rect2(Vector2(r[0], r[1]) * CELL - Vector2(12, 12), Vector2(r[2], r[3]) * CELL), 34.0, cast, tone, bounds)
			"caravan":
				if bounds.has_point(p): _shadow_blob(canvas, p + cast * 14.0, cast, 20.0 + 9.0 * cast.length(), 12.0, tone)
		if entity.has("footprint"):
			var fp := World.building_rect(entity)
			_building_shadow(canvas, Rect2(Vector2(fp.position) * CELL - Vector2.ONE * CELL / 2, Vector2(fp.size) * CELL), 46.0, cast, tone, bounds)
	# People: a body-long shadow from the feet, plus a small dark contact patch.
	for key in motion.actors:
		var pose: Dictionary = motion.actors[key]
		var feet: Vector2 = pose.position
		if not bounds.has_point(feet): continue
		var action: String = pose.get("action", "idle")
		var tall: float = 42.0 * (0.45 if action in ["down", "rest"] else (0.7 if action in ["fall", "getup"] else 1.0 - 0.3 * clampf(float(pose.get("sneak", 0.0)), 0.0, 1.0)))
		_shadow_blob(canvas, feet + Vector2(0, 1), Vector2.RIGHT, 7.5, 3.0, Color(0.05, 0.06, 0.08, 0.16 + strength * 0.4))
		_shadow_blob(canvas, feet + cast * tall * 0.5, cast, maxf(5.0, tall * cast.length() * 0.5 + 3.0), 5.5, tone)

## A wall-high block's shadow: the footprint swept along the sun line, minus the footprint itself.
func _building_shadow(canvas: Node2D, rect: Rect2, height: float, cast: Vector2, tone: Color, bounds: Rect2) -> void:
	if not bounds.intersects(rect.grow(height * 3.5)): return
	var offset := cast * height
	var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var swept := PackedVector2Array()
	for corner in corners:
		swept.append(corner)
		swept.append(corner + offset)
	var hull := Geometry2D.convex_hull(swept)
	for piece in Geometry2D.clip_polygons(hull, corners):
		if piece.size() >= 3: _shadow_polygon(canvas, piece, tone)

func is_far() -> bool:
	var camera := get_viewport().get_camera_2d()
	return camera != null and camera.zoom.x < FAR_ZOOM

var decor_nodes: Dictionary = {}
var decor_signatures: Dictionary = {}
var decor_clock: float = 99.0

## Creates, refreshes and removes the cached ground layers; checked twice a second.
func _sync_decor(delta: float) -> void:
	decor_clock += delta
	if decor_clock < 0.5: return
	decor_clock = 0.0
	var s: Dictionary = simulation.state
	var wanted: Dictionary = {}
	for settlement in s.get("settlements", {}).values():
		var square: Array = s.entities[str(settlement.warehouse)].cell
		wanted["plaza:%d" % settlement.id] = ["plaza", int(settlement.id), str(settlement.get("stalls", [])), Rect2(Vector2(square[0], square[1] + 7) * CELL + Vector2(-520, -110), Vector2(1040, 330))]
	for entity in s.entities.values():
		if entity.has("footprint") and entity.kind in ["warehouse", "home", "sawmill", "bakery", "forge", "office", "market"]:
			var fp := World.building_rect(entity)
			var rect := Rect2(Vector2(fp.position) * CELL - Vector2.ONE * CELL / 2, Vector2(fp.size) * CELL)
			wanted["building:%d" % entity.id] = ["building", int(entity.id), "%s:%s:%s" % [entity.kind, str(entity.footprint), str(entity.get("door", []))], rect.grow(48)]
	for plot in s.get("crops", {}).values():
		# One redraw per 1% of growth keeps the crop visibly changing without per-frame cost.
		var field_area: Rect2 = plot_area(plot)
		wanted["plot:%d" % plot.id] = ["plot", int(plot.id), "%d:%s:%s" % [Crops.permille(plot) / 10, plot.state, str(plot.rect)], Rect2(field_area.position - Vector2(16, 48), field_area.size + Vector2(32, 64))]
	for key in wanted:
		var entry: Array = wanted[key]
		if not decor_nodes.has(key):
			var node := Decor.new()
			node.projector = self
			node.kind = entry[0]
			node.key = entry[1]
			node.area = entry[3]
			node.z_index = -1
			add_child(node)
			move_child(node, background.get_index())
			decor_nodes[key] = node
		if decor_signatures.get(key, "") != entry[2]:
			decor_signatures[key] = entry[2]
			decor_nodes[key].set_area(entry[3])
	for key in decor_nodes.keys():
		if not wanted.has(key):
			decor_nodes[key].queue_free()
			decor_nodes.erase(key)
			decor_signatures.erase(key)


## Name plate centred underneath a character; it follows the actor's drawn position.
func _name_tag(canvas: Node2D, p: Vector2, label: String, color: Color) -> void:
	var size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	var origin: Vector2 = p + Vector2(-size.x / 2.0, 14)
	canvas.draw_rect(Rect2(origin + Vector2(-2, -9), size + Vector2(4, 3)), Color(0.07, 0.06, 0.04, 0.55))
	canvas.draw_string(font, origin + Vector2(0.5, 0.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, 0.8))
	canvas.draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)

func pick(world_position: Vector2) -> int:
	var best: int = 0
	var distance: float = 26.0
	for entity in simulation.state.entities.values():
		if not entity.has("cell"):
			continue
		var p := Vector2(entity.cell[0], entity.cell[1]) * CELL
		var candidate := (p - Vector2(0, 19) if entity.kind in ["resident", "player", "raider"] else p).distance_to(world_position) - float(entity.get("pick_radius", 0.0))
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
