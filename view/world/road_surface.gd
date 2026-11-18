extends RefCounted
## A feathered mask for sand and gravel in the terrain material. No collision.
const World = preload("res://sim/world/world_db.gd")
const TownLayout = preload("res://sim/world/town_layout.gd")
const CELL := 24.0
const SAMPLE := 4.0
const ROAD_Y := 48.0 * CELL

var mask: Image
var region: Rect2

func bake(state: Dictionary, extent: Rect2) -> ImageTexture:
	region = extent
	var resolution := Vector2i(extent.size / SAMPLE)
	mask = Image.create_empty(resolution.x, resolution.y, false, Image.FORMAT_L8)
	# Every road is a polyline in the simulation (town_layout.gd): the streets, the lanes and the links.
	for segment in TownLayout.segments(state):
		var line := PackedVector2Array()
		for point in segment.points: line.append(Vector2(float(point[0]), float(point[1])) * CELL)
		_track(line, float(segment.radius))
	for town in state.get("settlements", {}).values():
		var store: Dictionary = state.entities[str(town.warehouse)]
		var square := Vector2(store.cell[0], store.cell[1] + 3) * CELL
		for offset in [Vector2(-26, 0), Vector2(21, -9), Vector2(5, 18)]:
			_stamp(square + offset, 39.0)
	for entity in state.entities.values():
		if entity.has("footprint"):
			# A path from the door, straight out the way it faces, then to the nearest road.
			var door := Vector2(entity.cell[0], entity.cell[1]) * CELL
			var facing := Vector2(TownLayout.facing_vector(int(entity.get("door_side", 2))))
			var near: Dictionary = TownLayout.nearest_road_point(state, Vector2(entity.cell[0], entity.cell[1]) + facing * 2.0)
			if not near.is_empty():
				var target: Vector2 = near.point * CELL
				var out: Vector2 = door + facing * 1.5 * CELL
				_track(PackedVector2Array([door, out, target]) if out.distance_to(target) > 6.0 else PackedVector2Array([door, target]), 13.0)
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
