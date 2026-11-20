extends RefCounted
## Cover and peeking. Everything solid has a height: *high* (walls, standing trees, big rocks, tall
## furniture such as lockers, shelves, the weapon rack, ovens and forges) stops a shot whoever stands
## behind it; *low* (beds, chests, tables, chairs, counters, piles, small rocks) only shields someone
## crouched right behind it, and shots pass over it otherwise. A *cover cell* is a walkable cell with
## such a blocker in one of its four neighbours (a low one counts only for someone crouching). A *corner* is a cover cell where that blocker ends
## beside it, so one step along the wall you can see past it. Standing still at a cover cell puts
## the player in cover; holding the right mouse button there leans them out to the corner cell:
## their eye and gun origin moves one cell past the corner, and only then are they exposed.
## Sheriffs use the same rules for their hide / peek / fire cycle; a sheriff in cover is crouched.
## The player takes cover only when sneaking (crouched) or in a fight.
const World = preload("res://sim/world/world_db.gd")
const HIGH := 2
const LOW := 1
const HIGH_ITEMS := ["locker", "shelf", "weapon_rack", "oven", "forge", "workshop_storage", "wardrobe"]
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const HOLD_TICKS := 2          # standing still this long counts as taking cover

## True when something solid stands in `cell` (a wall, furniture, a rock or a standing tree).
static func blocker(s: Dictionary, cell: Array) -> bool:
	return height(s, cell) > 0

## How tall what stands in `cell` is: HIGH, LOW or 0.
static func height(s: Dictionary, cell: Array) -> int:
	var key: String = "%d,%d" % [cell[0], cell[1]]
	if s.world.get("building_walls", {}).has(key): return HIGH
	if s.world.get("fixture_cells", {}).has(key) or s.world.blocked.has(key):
		return int(_heights(s).get(key, LOW))
	return HIGH if tree_at(s, cell) else 0

## Heights of furniture, fixtures and rocks by cell, derived from the state (rebuilt when they change).
static var _height_cache: Array = []
static func _heights(s: Dictionary) -> Dictionary:
	var cache: Dictionary = World.DerivedCache.slot(_height_cache, s.world)
	var signature := [s.world.get("fixture_cells", {}).size(), s.world.blocked.size(), int(s.world.get("nav_revision", 0)), World.entity_serial]
	if cache.get("signature") == signature: return cache.heights
	var heights := {}
	for building in World.buildings(s):
		for list_name in ["furniture", "fixtures"]:
			for item in building.get(list_name, []):
				var r: Array = item.rect
				var tall: int = HIGH if str(item.kind) in HIGH_ITEMS else LOW
				for y in range(r[1], r[1] + r[3]):
					for x in range(r[0], r[0] + r[2]): heights["%d,%d" % [x, y]] = tall
	for rock in World.of_kind(s, "ore"):
		if not rock.has("rock_rect"): continue
		var rr: Array = rock.rock_rect
		for y in range(rr[1], rr[1] + rr[3]):
			for x in range(rr[0], rr[0] + rr[2]): heights["%d,%d" % [x, y]] = HIGH   # a great rock to hide behind
	cache.heights = heights
	cache.signature = signature
	return heights

## Does what stands at `cell` stop a shot? High things always; a low thing only when the one it
## shields (at `low_a` or `low_b`'s end of the line, crouched) is right behind it.
static func _stops(s: Dictionary, cell: Array, a: Array, b: Array, low_a: bool, low_b: bool) -> bool:
	var tall: int = height(s, cell)
	if tall == HIGH: return true
	if tall == LOW:
		if low_a and _beside(cell, a): return true
		if low_b and _beside(cell, b): return true
	return false

static func _beside(a: Array, b: Array) -> bool:
	return absi(int(a[0]) - int(b[0])) <= 1 and absi(int(a[1]) - int(b[1])) <= 1

static func tree_at(s: Dictionary, cell: Array) -> bool:
	for id in _trees_by_cell(s).get(Vector2i(int(cell[0]), int(cell[1])), []):
		var entity: Dictionary = s.entities.get(str(id), {})
		if not entity.is_empty() and not entity.get("felled", false) and entity.get("cell", []) == cell: return true
	return false

## Tree ids by cell. Derived from the state and rebuilt only when entities are added or removed
## (trees never walk), so asking "is there a tree here?" no longer scans a whole chunk.
static var _trees_cache: Array = []
static func _trees_by_cell(s: Dictionary) -> Dictionary:
	var cache: Dictionary = World.DerivedCache.slot(_trees_cache, s.entities)
	var signature := [s.entities.size(), World.entity_serial]
	if cache.get("signature") == signature: return cache.trees
	var trees := {}
	for entity in World.of_kind(s, "tree"):
		if not entity.has("cell"): continue
		var at := Vector2i(int(entity.cell[0]), int(entity.cell[1]))
		if not trees.has(at): trees[at] = []
		trees[at].append(int(entity.id))
	cache.trees = trees
	cache.signature = signature
	return trees

## Directions (0 up, 1 right, 2 down, 3 left) in which a neighbouring cell gives cover: anything
## solid for someone crouched, only high things for someone standing.
static func cover_sides(s: Dictionary, cell: Array, crouched: bool = true) -> Array:
	var sides: Array = []
	for index in range(4):
		var tall: int = height(s, [cell[0] + DIRS[index].x, cell[1] + DIRS[index].y])
		if tall == HIGH or (tall == LOW and crouched): sides.append(index)
	return sides

static func is_cover(s: Dictionary, cell: Array, crouched: bool = true) -> bool:
	return World.walkable(s, cell) and not cover_sides(s, cell, crouched).is_empty()

## The open cell one step along the wall where the blocker ends (so you can see past it), on the
## side nearest `toward`; [] when there is no corner that way. `toward` is a direction vector.
static func peek_cell(s: Dictionary, cell: Array, toward: Vector2) -> Array:
	var best: Array = []
	var best_score := 0.05
	for side in cover_sides(s, cell):
		var along: Array = [(side + 1) % 4, (side + 3) % 4]
		for turn in along:
			var step: Vector2i = DIRS[turn]
			var next: Array = [cell[0] + step.x, cell[1] + step.y]
			var wall_next: Array = [next[0] + DIRS[side].x, next[1] + DIRS[side].y]
			if not World.walkable(s, next) or blocker(s, wall_next): continue   # the wall goes on: no corner here
			var score: float = Vector2(step.x, step.y).dot(toward.normalized()) if toward.length() > 0.01 else 0.0
			if score > best_score:
				best_score = score
				best = next
	return best

## The cells of a straight line from `a` to `b` (Bresenham), both ends included.
static func line(a: Array, b: Array) -> Array:
	var cells: Array = []
	var x0: int = int(a[0]); var y0: int = int(a[1]); var x1: int = int(b[0]); var y1: int = int(b[1])
	var dx: int = absi(x1 - x0); var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var error: int = dx + dy
	while true:
		cells.append([x0, y0])
		if x0 == x1 and y0 == y1: break
		var doubled: int = 2 * error
		if doubled >= dy: error += dy; x0 += sx
		if doubled <= dx: error += dx; y0 += sy
	return cells

## True when nothing stops a shot (or a look) between `a` and `b` (the end cells themselves do not
## count). `low_a` / `low_b`: whoever is at that end is crouched, so a low thing right beside them shields them.
static func line_clear(s: Dictionary, a: Array, b: Array, low_a: bool = false, low_b: bool = false) -> bool:
	var cells := line(a, b)
	for index in range(1, cells.size() - 1):
		if _stops(s, cells[index], a, b, low_a, low_b): return false
	return true

## The first cell that stops a shot on the way from `a` towards `b`, or [] if the way is clear.
static func first_block(s: Dictionary, a: Array, b: Array, low_b: bool = false) -> Array:
	var cells := line(a, b)
	for index in range(1, cells.size()):
		if _stops(s, cells[index], a, b, false, low_b): return cells[index]
	return []

## Is the player low (crouched, or knocked down)?
static func player_low(s: Dictionary) -> bool:
	return bool(s.get("player_control", {}).get("crouching", false)) or Brawl_down(s)

## In a fight: a gunfight in town, the shotgun readied, or a brawl.
static func player_in_combat(s: Dictionary) -> bool:
	if not s.get("law", {}).get("alert", {}).is_empty(): return true
	if bool(s.get("shotgun", {}).get("equipped", false)): return true
	for npc in s.get("residents", {}).values():
		if int(npc.get("brawl", {}).get("target", 0)) == int(s.get("player", -1)): return true
	return false

## The player's cover state, updated every tick: `cover` while standing still at a cover cell,
## `peek` ({from, to}) while the right button is held and a corner exists towards the mouse.
static func update(s: Dictionary) -> void:
	if not s.has("player_control") or not s.has("player"): return
	var pc: Dictionary = s.player_control
	var cell: Array = s.entities[str(s.player)].cell
	var still: bool = s.tick >= int(pc.get("next_move", 0)) + HOLD_TICKS and s.get("player_path", []).is_empty()
	# Cover is taken only when sneaking or in a fight; standing, only something high covers you.
	var crouched: bool = bool(pc.get("crouching", false))
	var covered: bool = still and (crouched or player_in_combat(s)) and is_cover(s, cell, crouched) and not Brawl_down(s)
	if covered:
		if not pc.has("cover") or pc.cover.cell != cell or bool(pc.cover.get("low", false)) != crouched:
			pc.cover = {"cell": cell.duplicate(), "sides": cover_sides(s, cell, crouched), "low": crouched}
	elif pc.has("cover"):
		pc.erase("cover")
	if covered and bool(pc.get("peek_hold", false)):
		var toward := Vector2(float(pc.get("peek_toward", [0, 0])[0]), float(pc.get("peek_toward", [0, 0])[1]))
		var corner: Array = peek_cell(s, cell, toward)
		if not corner.is_empty():
			pc.peek = {"from": cell.duplicate(), "to": corner}
		elif pc.has("peek"):
			pc.erase("peek")
	elif pc.has("peek"):
		pc.erase("peek")

static func Brawl_down(s: Dictionary) -> bool:
	return load("res://sim/combat/brawl.gd").player_down(s)

## Where the player's eyes and gun are: the corner cell while peeking, else their own cell.
static func eye_cell(s: Dictionary) -> Array:
	var pc: Dictionary = s.get("player_control", {})
	if pc.has("peek"): return pc.peek.to
	return s.entities[str(s.player)].cell

## True when a shooter at `from` could hit the player: not in cover, or leaning out.
static func player_exposed(s: Dictionary) -> bool:
	var pc: Dictionary = s.get("player_control", {})
	return not pc.has("cover") or pc.has("peek")
