extends RefCounted
## A feathered mask for sand and gravel in the terrain material. No collision.
const World = preload("res://sim/world/world_db.gd")
const CELL := 24.0
const SAMPLE := 4.0
const ROAD_Y := 48.0 * CELL

var mask: Image
var region: Rect2

func bake(state: Dictionary, extent: Rect2) -> ImageTexture:
	region = extent
	var resolution := Vector2i(extent.size / SAMPLE)
	mask = Image.create_empty(resolution.x, resolution.y, false, Image.FORMAT_L8)
	if state.has("routes"):
		var route := PackedVector2Array()
		var east: int = 216
		if state.get("settlements", {}).has("2"): east = int(state.entities[str(state.settlements["2"].warehouse)].cell[0]) + 36
		for x in range(36, east, 2):
			var bend := sin(float(x) * 0.27) * 5.2 + sin(float(x) * 0.61) * 2.6
			route.append(Vector2(x * CELL, ROAD_Y + bend))
		_track(route, 17.0)
	if state.get("settlements", {}).has("3"):
		# The south road from Alder Hollow's square down to Dustvale, and Dustvale's own street.
		var south := PackedVector2Array()
		var from_cell := Vector2(70, 50)
		var dust_store: Array = state.entities[str(state.settlements["3"].warehouse)].cell
		var to_cell := Vector2(dust_store[0], dust_store[1] - 2)
		for step in range(0, 121):
			var t := float(step) / 120.0
			var along := from_cell.lerp(to_cell, t)
			south.append(Vector2(along.x + sin(t * 9.0) * 3.2 + sin(t * 23.0) * 1.2, along.y) * CELL)
		_track(south, 16.0)
		var store3: Array = state.entities[str(state.settlements["3"].warehouse)].cell
		var street := PackedVector2Array()
		for x in range(store3[0] - 42, store3[0] + 36, 2):
			street.append(Vector2(x * CELL, (store3[1] + 2) * CELL + sin(float(x) * 0.31) * 6.0))
		_track(street, 16.0)
	for town in state.get("settlements", {}).values():
		var store: Dictionary = state.entities[str(town.warehouse)]
		var square := Vector2(store.cell[0], store.cell[1] + 3) * CELL
		for offset in [Vector2(-26, 0), Vector2(21, -9), Vector2(5, 18)]:
			_stamp(square + offset, 39.0)
	for entity in state.entities.values():
		if entity.has("footprint"):
			var door := Vector2(entity.cell[0], entity.cell[1]) * CELL
			var road_y := _road_y(state, entity)
			if door.y <= road_y:
				_track(PackedVector2Array([door, Vector2(door.x, road_y)]), 14.0)
			else:
				var edge := float(World.building_rect(entity).end.x + 1) * CELL
				_track(PackedVector2Array([
					door, door + Vector2(0, 32), Vector2(edge - 14, door.y + 34),
					Vector2(edge, door.y + 18), Vector2(edge, road_y),
				]), 13.0)
		elif entity.kind == "market_stall":
			var counter := Vector2(entity.cell[0], entity.cell[1] + 1) * CELL
			_track(PackedVector2Array([Vector2(counter.x, _road_y(state, entity)), counter]), 11)
			_stamp(counter, 20)
		elif entity.kind == "farm":
			var entrance := Vector2(entity.cell[0] * CELL, entity.cell[1] * CELL - 37.0)
			var farm_road := _road_y(state, entity)
			_track(PackedVector2Array([
				Vector2(entrance.x - 24, farm_road),
				Vector2(entrance.x - 8, (entrance.y + farm_road) * 0.5), entrance,
			]), 9.0)
	return ImageTexture.create_from_image(mask)

## Each settlement's main street runs two cells below its storehouse (the old fixed 48 for the first two).
func _road_y(state: Dictionary, entity: Dictionary) -> float:
	var town: Dictionary = state.get("settlements", {}).get(str(entity.get("settlement", 0)), {})
	if town.is_empty(): return ROAD_Y
	return float(state.entities[str(town.warehouse)].cell[1] + 2) * CELL

func coverage(point: Vector2) -> float:
	if mask == null or not region.has_point(point): return 0.0
	var pixel := Vector2i((point - region.position) / SAMPLE)
	return mask.get_pixelv(pixel).r

func _track(points: PackedVector2Array, radius: float) -> void:
	var distance := 0.0
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var steps := maxi(1, ceili(length / (SAMPLE * 1.5)))
		for step in range(steps + 1):
			var weight := float(step) / float(steps)
			var width := radius * (1.0 + 0.09 * sin((distance + weight * length) * 0.065 + a.x * 0.004))
			_stamp(a.lerp(b, weight), width)
		distance += length

func _stamp(point: Vector2, radius: float) -> void:
	var center := (point - region.position) / SAMPLE
	var reach := radius / SAMPLE + 2.0
	var lo := Vector2i((center - Vector2.ONE * reach).floor()).max(Vector2i.ZERO)
	var hi := Vector2i((center + Vector2.ONE * reach).ceil()).min(mask.get_size() - Vector2i.ONE)
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var m := Vector2(x + 0.5, y + 0.5).distance_to(center) * SAMPLE
			var amount := 1.0 - smoothstep(radius * 0.44, radius + 5.0, m)
			if amount > mask.get_pixel(x, y).r:
				mask.set_pixel(x, y, Color(amount, amount, amount))
