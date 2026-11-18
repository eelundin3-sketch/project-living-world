extends RefCounted
## Cover and peeking. A *cover cell* is a walkable cell with a blocker (wall, furniture, rock or a
## standing tree) in one of its four neighbours. A *corner* is a cover cell where that blocker ends
## beside it, so one step along the wall you can see past it. Standing still at a cover cell puts
## the player in cover; holding the right mouse button there leans them out to the corner cell:
## their eye and gun origin moves one cell past the corner, and only then are they exposed.
## Sheriffs use the same rules for their hide / peek / fire cycle.
const World = preload("res://sim/world/world_db.gd")
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const HOLD_TICKS := 2          # standing still this long counts as taking cover

## True when something solid stands in `cell` (a wall, furniture, a rock or a standing tree).
static func blocker(s: Dictionary, cell: Array) -> bool:
	var key := World.cell_key(cell)
	if s.world.get("building_walls", {}).has(key) or s.world.get("fixture_cells", {}).has(key) or s.world.blocked.has(key): return true
	return tree_at(s, cell)

static func tree_at(s: Dictionary, cell: Array) -> bool:
	var coord := World.chunk_coord(int(cell[0]), int(cell[1]))
	var chunk: Dictionary = s.world.chunks.get("%d,%d" % [coord.x, coord.y], {})
	for id in chunk.get("entities", []):
		var entity: Dictionary = s.entities.get(str(id), {})
		if entity.get("kind", "") == "tree" and not entity.get("felled", false) and entity.get("cell", []) == cell: return true
	return false

## Directions (0 up, 1 right, 2 down, 3 left) in which a neighbouring cell blocks.
static func cover_sides(s: Dictionary, cell: Array) -> Array:
	var sides: Array = []
	for index in range(4):
		if blocker(s, [cell[0] + DIRS[index].x, cell[1] + DIRS[index].y]): sides.append(index)
	return sides

static func is_cover(s: Dictionary, cell: Array) -> bool:
	return World.walkable(s, cell) and not cover_sides(s, cell).is_empty()

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

## True when nothing solid stands between `a` and `b` (the end cells themselves do not count).
static func line_clear(s: Dictionary, a: Array, b: Array) -> bool:
	var cells := line(a, b)
	for index in range(1, cells.size() - 1):
		if blocker(s, cells[index]): return false
	return true

## The first solid cell on the way from `a` towards `b`, or [] if the way is clear.
static func first_block(s: Dictionary, a: Array, b: Array) -> Array:
	var cells := line(a, b)
	for index in range(1, cells.size()):
		if blocker(s, cells[index]): return cells[index]
	return []

## The player's cover state, updated every tick: `cover` while standing still at a cover cell,
## `peek` ({from, to}) while the right button is held and a corner exists towards the mouse.
static func update(s: Dictionary) -> void:
	if not s.has("player_control") or not s.has("player"): return
	var pc: Dictionary = s.player_control
	var cell: Array = s.entities[str(s.player)].cell
	var still: bool = s.tick >= int(pc.get("next_move", 0)) + HOLD_TICKS and s.get("player_path", []).is_empty()
	var covered: bool = still and is_cover(s, cell) and not Brawl_down(s)
	if covered:
		if not pc.has("cover") or pc.cover.cell != cell: pc.cover = {"cell": cell.duplicate(), "sides": cover_sides(s, cell)}
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
	return load("res://sim/player/brawl.gd").player_down(s)

## Where the player's eyes and gun are: the corner cell while peeking, else their own cell.
static func eye_cell(s: Dictionary) -> Array:
	var pc: Dictionary = s.get("player_control", {})
	if pc.has("peek"): return pc.peek.to
	return s.entities[str(s.player)].cell

## True when a shooter at `from` could hit the player: not in cover, or leaning out.
static func player_exposed(s: Dictionary) -> bool:
	var pc: Dictionary = s.get("player_control", {})
	return not pc.has("cover") or pc.has("peek")
