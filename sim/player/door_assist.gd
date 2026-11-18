extends RefCounted
## Helps the player into buildings without taking over. A doorway is one cell wide, so walking up
## to one along the wall is fiddly. After the *second* time the player bumps a building wall near
## its door, while pushing towards the door, the next few steps slide them along the wall to the
## doorway and through it. It never starts on a single bump, never when moving away, when five or
## more cells from a door, while sneaking, fighting or inside, and it ends once they are in or let go.
## Speed is unchanged (one cell per step); nothing teleports. Off with `player_control.door_assist = false`.
const World = preload("res://sim/world/world_db.gd")
const Orient = preload("res://sim/world/orient.gd")
const NEAR := 4.5
const BUMP_WINDOW := 40
const ASSIST_TICKS := 30

## The nearest doorway within NEAR cells of `cell`: {"door", "approach", "building"} or {}.
static func nearest_door(s: Dictionary, cell: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := NEAR
	for entity in s.entities.values():
		if not entity.has("footprint") or not entity.has("door"): continue
		var door: Array = entity.door
		var distance: float = Vector2(door[0] - cell[0], door[1] - cell[1]).length()
		if distance > best_distance: continue
		var out := Orient.outward(int(entity.get("door_side", 2)))
		best_distance = distance
		best = {"door": door, "approach": [door[0] + out.x, door[1] + out.y], "building": int(entity.id)}
	return best

## Returns the direction to actually step in (the player's own, unless assist changes it).
static func adjust(s: Dictionary, cell: Array, direction: Array) -> Array:
	var pc: Dictionary = s.get("player_control", {})
	if not bool(pc.get("door_assist", true)) or pc.is_empty(): return direction
	if bool(pc.get("crouching", false)) or not pc.get("unarmed", {}).is_empty() or s.get("shotgun", {}).get("equipped", false) and bool(pc.get("aiming", false)): return direction
	var inside: int = World.inside_building(s, cell)
	var door: Dictionary = nearest_door(s, cell)
	if door.is_empty() or inside != 0:
		pc.erase("bump")
		pc.erase("assist")
		return direction
	var to_door := Vector2(door.door[0] - cell[0], door.door[1] - cell[1])
	var heading := Vector2(direction[0], direction[1])
	if heading.length() < 0.1 or to_door.length() < 0.1 or heading.normalized().dot(to_door.normalized()) <= 0.3:
		return direction   # moving away from the door, or along a path that has nothing to do with it
	var next: Array = [cell[0] + direction[0], cell[1] + direction[1]]
	var wall: bool = not World.walkable(s, next) and s.world.get("building_walls", {}).has(World.cell_key(next))
	var assist: Dictionary = pc.get("assist", {})
	if wall:
		var bump: Dictionary = pc.get("bump", {})
		var count: int = 1
		if not bump.is_empty() and int(bump.door[0]) == int(door.door[0]) and int(bump.door[1]) == int(door.door[1]) and s.tick - int(bump.tick) <= BUMP_WINDOW: count = int(bump.count) + 1
		pc.bump = {"door": door.door.duplicate(), "count": count, "tick": s.tick}
		if count >= 2:
			assist = {"until": s.tick + ASSIST_TICKS, "door": door.door.duplicate()}
			pc.assist = assist
	if assist.is_empty() or s.tick > int(assist.until): return direction
	# Slide one cell along the wall towards the doorway (or step through it from the cell outside).
	var goal: Array = door.approach if cell != door.approach else door.door
	var best: Array = direction
	var best_distance: float = Vector2(goal[0] - cell[0], goal[1] - cell[1]).length()
	var improved := false
	for step in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		var candidate: Array = [cell[0] + step[0], cell[1] + step[1]]
		if not World.walkable(s, candidate): continue
		var d: float = Vector2(goal[0] - candidate[0], goal[1] - candidate[1]).length()
		if d < best_distance - 0.01:
			best_distance = d
			best = step
			improved = true
	if improved: pc.assist.until = s.tick + ASSIST_TICKS   # keeps going while they keep pushing
	return best
