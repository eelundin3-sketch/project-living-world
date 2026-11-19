extends RefCounted
## Turning a south-facing building template to face any side. A door faces 0 north, 1 east, 2 south
## or 3 west (the same numbering as furniture `rot`). Templates are written with the door on the
## south wall; a building facing `side` is the template turned clockwise `turns(side)` quarter turns
## about its door cell.

## Clockwise quarter turns from the south-facing template to a door that faces `side`.
static func turns(side: int) -> int:
	return posmod(side - 2, 4)

## A vector relative to the door, turned.
static func vec(v: Vector2i, quarter_turns: int) -> Vector2i:
	var result := v
	for index in range(posmod(quarter_turns, 4)): result = Vector2i(-result.y, result.x)
	return result

## A cell given relative to the door in the south-facing template, as a world cell.
static func cell(relative: Vector2i, door: Array, side: int) -> Array:
	var turned := vec(relative, turns(side))
	return [int(door[0]) + turned.x, int(door[1]) + turned.y]

## A rectangle [x, y, w, h] given relative to the door cell (south-facing), as a world rectangle.
static func rect(relative: Array, door: Array, side: int) -> Array:
	var a := cell(Vector2i(int(relative[0]), int(relative[1])), door, side)
	var b := cell(Vector2i(int(relative[0]) + int(relative[2]) - 1, int(relative[1]) + int(relative[3]) - 1), door, side)
	var low := Vector2i(mini(a[0], b[0]), mini(a[1], b[1]))
	var high := Vector2i(maxi(a[0], b[0]), maxi(a[1], b[1]))
	return [low.x, low.y, high.x - low.x + 1, high.y - low.y + 1]

## The unit vector pointing out through a door that faces `side`.
static func outward(side: int) -> Vector2i:
	return [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][posmod(side, 4)]
