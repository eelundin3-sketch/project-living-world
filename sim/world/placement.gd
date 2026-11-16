extends RefCounted
## Furniture placement with four orientations and wall-aware auto arrangement.
## Orientation `rot` is the direction an object faces: 0 up, 1 right, 2 down, 3 left.
## For a bed it is the side the head (pillow) is on.
# World and navigation are loaded lazily: world_db.gd (through fixtures.gd) depends on this file.
static func _world() -> GDScript:
	return load("res://sim/world/world_db.gd")

static func _nav() -> GDScript:
	return load("res://sim/movement/navigation.gd")

const UP := 0
const RIGHT := 1
const DOWN := 2
const LEFT := 3
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## Footprint in cells when the object faces left or right (the long axis runs along x).
const BASE_SIZE: Dictionary = {"bed": Vector2i(3, 2), "table": Vector2i(3, 2), "shelf": Vector2i(3, 2), "chest": Vector2i(2, 1), "chair": Vector2i(1, 1), "lamp": Vector2i(1, 1), "stove": Vector2i(1, 1), "desk": Vector2i(3, 2)}
## Objects that read best with their back or head against a wall, and how much each side matters.
const WALL_WEIGHTS: Dictionary = {"bed": {"head": 12, "long": 3, "foot": 1}, "shelf": {"head": 10, "long": 1, "foot": 1}, "chest": {"head": 6, "long": 2, "foot": 1}, "stove": {"head": 8, "long": 1, "foot": 1}, "table": {"head": 0, "long": 0, "foot": 0}, "chair": {"head": 0, "long": 0, "foot": 0}, "lamp": {"head": 4, "long": 1, "foot": 0}}

static func size_for(kind: String, rot: int) -> Vector2i:
	var base: Vector2i = BASE_SIZE.get(kind, Vector2i(1, 1))
	return base if rot % 2 == 1 else Vector2i(base.y, base.x)

## Cells covered by `kind` with its origin (top-left) at `cell`.
static func rect_for(kind: String, cell: Array, rot: int) -> Array:
	var size := size_for(kind, rot)
	return [cell[0], cell[1], size.x, size.y]

static func is_wall(s: Dictionary, building: Dictionary, x: int, y: int) -> bool:
	var cell: Array = [x, y]
	if s.world.get("building_walls", {}).has(_world().cell_key(cell)) and cell != building.get("door", building.cell): return true
	return not _world().building_contains(building, cell)

## The doorway and a short approach inside it must stay clear.
static func door_clearance(building: Dictionary, x: int, y: int) -> bool:
	var door: Array = building.get("door", building.cell)
	return absi(x - door[0]) <= 1 and y >= door[1] - 3

static func can_place(s: Dictionary, building: Dictionary, kind: String, rect: Array, ignore: Dictionary = {}) -> bool:
	for y in range(rect[1], rect[1] + rect[3]):
		for x in range(rect[0], rect[0] + rect[2]):
			if is_wall(s, building, x, y) or door_clearance(building, x, y): return false
			var key: String = _world().cell_key([x, y])
			var owner: int = int(s.world.get("fixture_cells", {}).get(key, 0))
			if owner != 0 and not ignore.has(key): return false
			if s.world.get("building_walls", {}).has(key): return false
	return true

## How many sides of the footprint touch a wall, weighted by which side it is.
static func wall_score(s: Dictionary, building: Dictionary, kind: String, rect: Array, rot: int) -> int:
	var weights: Dictionary = WALL_WEIGHTS.get(kind, {"head": 0, "long": 0, "foot": 0})
	var score := 0
	for side in range(4):
		var direction := DIRS[side]
		var touching := 0
		var length := 0
		var cells: Array = []
		if side == 0: for x in range(rect[0], rect[0] + rect[2]): cells.append([x, rect[1]])
		elif side == 2: for x in range(rect[0], rect[0] + rect[2]): cells.append([x, rect[1] + rect[3] - 1])
		elif side == 3: for y in range(rect[1], rect[1] + rect[3]): cells.append([rect[0], y])
		else: for y in range(rect[1], rect[1] + rect[3]): cells.append([rect[0] + rect[2] - 1, y])
		for cell in cells:
			length += 1
			if is_wall(s, building, cell[0] + direction.x, cell[1] + direction.y): touching += 1
		if length == 0 or touching == 0: continue
		var fraction: float = float(touching) / float(length)
		var weight: int = weights.head if side == rot else (weights.foot if side == (rot + 2) % 4 else weights.long)
		score += roundi(weight * fraction)
	return score

## Best legal (origin, orientation) for a new object, preferring wall contact for walls-loving kinds.
## Deterministic: ties break toward `prefer` (a nearby cell) then lowest y, x, rot.
static func best_placement(s: Dictionary, building: Dictionary, kind: String, prefer: Array = []) -> Dictionary:
	var fp: Rect2i = _world().building_rect(building)
	var best: Dictionary = {}
	var best_score := -1000000
	for rot in range(4):
		var size := size_for(kind, rot)
		for y in range(fp.position.y + 1, fp.end.y - size.y):
			for x in range(fp.position.x + 1, fp.end.x - size.x):
				var rect: Array = [x, y, size.x, size.y]
				if not can_place(s, building, kind, rect): continue
				var score := wall_score(s, building, kind, rect, rot) * 100
				if not prefer.is_empty(): score -= absi(x - prefer[0]) + absi(y - prefer[1])
				if score > best_score:
					best_score = score
					best = {"rect": rect, "rot": rot, "score": score}
	return best

static func occupy(s: Dictionary, rect: Array, owner: int) -> void:
	for y in range(rect[1], rect[1] + rect[3]):
		for x in range(rect[0], rect[0] + rect[2]):
			s.world.fixture_cells[_world().cell_key([x, y])] = owner

static func vacate(s: Dictionary, rect: Array) -> void:
	for y in range(rect[1], rect[1] + rect[3]):
		for x in range(rect[0], rect[0] + rect[2]):
			s.world.fixture_cells.erase(_world().cell_key([x, y]))

static func cells_of(rect: Array) -> Dictionary:
	var result: Dictionary = {}
	for y in range(rect[1], rect[1] + rect[3]):
		for x in range(rect[0], rect[0] + rect[2]):
			result[_world().cell_key([x, y])] = true
	return result

## Rotate a placed object a quarter turn clockwise about its centre. If the turned footprint
## does not fit, try the other turns; returns the new rot, or -1 when it cannot turn at all.
static func rotate_item(s: Dictionary, building: Dictionary, index: int, steps: int = 1) -> int:
	var items: Array = building.get("furniture", [])
	if index < 0 or index >= items.size(): return -1
	var item: Dictionary = items[index]
	var current: int = int(item.get("rot", LEFT if item.kind == "bed" else DOWN))
	var old_rect: Array = item.rect
	var own := cells_of(old_rect)
	var centre := Vector2(old_rect[0] + old_rect[2] / 2.0, old_rect[1] + old_rect[3] / 2.0)
	for turn in range(1, 5):
		var candidate_rot: int = (current + steps * turn) % 4
		var size := size_for(item.kind, candidate_rot)
		var origin := Vector2i(roundi(centre.x - size.x / 2.0), roundi(centre.y - size.y / 2.0))
		for nudge in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var rect: Array = [origin.x + nudge.x, origin.y + nudge.y, size.x, size.y]
			if can_place(s, building, item.kind, rect, own):
				vacate(s, old_rect)
				occupy(s, rect, building.id)
				item.rect = rect
				item.rot = candidate_rot
				s.world.nav_revision += 1
				return candidate_rot
	return -1

## Moves a bed (or other object) to its best wall-hugging spot, keeping its identity in the list.
static func rearrange(s: Dictionary, building: Dictionary, index: int) -> bool:
	var items: Array = building.get("furniture", [])
	if index < 0 or index >= items.size(): return false
	var item: Dictionary = items[index]
	var old_rect: Array = item.rect
	vacate(s, old_rect)
	var found := best_placement(s, building, item.kind, [old_rect[0], old_rect[1]])
	if found.is_empty():
		occupy(s, old_rect, building.id)
		return false
	occupy(s, found.rect, building.id)
	item.rect = found.rect
	item.rot = found.rot
	s.world.nav_revision += 1
	return true

## Doorway to every workstation stance must stay walkable after changes.
static func circulation_ok(s: Dictionary, building: Dictionary) -> bool:
	var door: Array = building.get("door", building.cell)
	var inside: Array = [door[0], door[1] - 1]
	for fixture in building.get("fixtures", []):
		if not _nav().request_path(s, inside, fixture.stance).ok: return false
	return true

static func nearest_index(building: Dictionary, cell: Array) -> int:
	var best := -1
	var best_distance := 1 << 30
	var items: Array = building.get("furniture", [])
	for index in range(items.size()):
		var rect: Array = items[index].rect
		var dx: int = maxi(0, maxi(rect[0] - cell[0], cell[0] - (rect[0] + rect[2] - 1)))
		var dy: int = maxi(0, maxi(rect[1] - cell[1], cell[1] - (rect[1] + rect[3] - 1)))
		var distance: int = dx * dx + dy * dy
		if distance < best_distance:
			best_distance = distance
			best = index
	return best

## Adds a new object at an exact origin and orientation, if it fits.
static func place(s: Dictionary, building: Dictionary, kind: String, cell: Array, rot: int) -> bool:
	if not BASE_SIZE.has(kind) or rot < 0 or rot > 3: return false
	var rect: Array = rect_for(kind, cell, rot)
	if not can_place(s, building, kind, rect): return false
	building.furniture.append({"kind": kind, "rect": rect, "rot": rot})
	occupy(s, rect, building.id)
	s.world.nav_revision += 1
	return true
