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
		for x in range(36, 216, 2):
			var bend := sin(float(x) * 0.27) * 5.2 + sin(float(x) * 0.61) * 2.6
			route.append(Vector2(x * CELL, ROAD_Y + bend))
		_track(route, 17.0)
	for town in state.get("settlements", {}).values():
		var store: Dictionary = state.entities[str(town.warehouse)]
		var square := Vector2(store.cell[0], 49) * CELL
		for offset in [Vector2(-26, 0), Vector2(21, -9), Vector2(5, 18)]:
			_stamp(square + offset, 39.0)
	for entity in state.entities.values():
		if entity.has("footprint"):
			var door := Vector2(entity.cell[0], entity.cell[1]) * CELL
			if door.y <= ROAD_Y:
				_track(PackedVector2Array([door, Vector2(door.x, ROAD_Y)]), 14.0)
			else:
				var edge := float(World.building_rect(entity).end.x + 1) * CELL
				_track(PackedVector2Array([
					door, door + Vector2(0, 32), Vector2(edge - 14, door.y + 34),
					Vector2(edge, door.y + 18), Vector2(edge, ROAD_Y),
				]), 13.0)
		elif entity.kind == "market_stall":
			var counter := Vector2(entity.cell[0], entity.cell[1] + 1) * CELL
			_track(PackedVector2Array([Vector2(counter.x, ROAD_Y), counter]), 11)
			_stamp(counter, 20)
		elif entity.kind == "farm":
			var entrance := Vector2(entity.cell[0] * CELL, entity.cell[1] * CELL - 37.0)
			_track(PackedVector2Array([
				Vector2(entrance.x - 24, ROAD_Y),
				Vector2(entrance.x - 8, (entrance.y + ROAD_Y) * 0.5), entrance,
			]), 9.0)
	return ImageTexture.create_from_image(mask)

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
