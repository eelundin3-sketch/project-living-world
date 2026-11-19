extends RefCounted
## The ground's woodland mask, in GDScript. It mirrors `view/world/landscape.gdshader`, so the
## simulation can plant trees exactly where the ground is drawn as dark green forest floor.
## Keep the two in step: same constants, same order of operations.

## Town centres (cells) that clear the ground around each settlement.
static func town_centres(s: Dictionary) -> Dictionary:
	var centres := {1: Vector2(64, 47), 2: Vector2(180, 47), 3: Vector2(122, 128)}
	for key in s.get("settlements", {}):
		var store: Array = s.entities[str(s.settlements[key].warehouse)].cell
		var id: int = int(key)
		if id == 3: centres[3] = Vector2(store[0], store[1])
		elif id in [1, 2]: centres[id] = Vector2(store[0], store[1] + 1)
	return centres

static func _hash(p: Vector2) -> float:
	var q := Vector3(fposmod(p.x * 0.1031, 1.0), fposmod(p.y * 0.1031, 1.0), fposmod(p.x * 0.1031, 1.0))
	var d: float = q.dot(Vector3(q.y, q.z, q.x) + Vector3(33.33, 33.33, 33.33))
	q += Vector3(d, d, d)
	return fposmod((q.x + q.y) * q.z, 1.0)

static func _field(p: Vector2) -> float:
	var cell := Vector2(floorf(p.x), floorf(p.y))
	var f := p - cell
	var blend := f * f * (Vector2(3, 3) - 2.0 * f)
	return lerpf(lerpf(_hash(cell), _hash(cell + Vector2(1, 0)), blend.x),
		lerpf(_hash(cell + Vector2(0, 1)), _hash(cell + Vector2(1, 1)), blend.x), blend.y)

## 0 (open ground) .. 1 (deep woodland) at a cell, as the landscape shader draws it.
static func woodland(land: Vector2, seed_value: int, centres: Dictionary) -> float:
	var p := land + Vector2(seed_value * 0.013, seed_value * 0.017)
	var warp := Vector2(_field(p * 0.023), _field(p * 0.027 + Vector2(34, 34))) * 15.0
	var warped := p + warp
	var masses: float = _field(warped * 0.037) * 0.69 + _field(warped * 0.105) * 0.31
	var hollow: float = ((land - centres[1]) / Vector2(35.0, 27.0)).length()
	var reedbank: float = ((land - centres[2]) / Vector2(34.0, 26.0)).length()
	var village: float = 1.0 - smoothstep(0.52, 1.21, minf(hollow, reedbank))
	var dust: float = 1.0 - smoothstep(0.55, 1.35, ((land - centres[3]) / Vector2(50.0, 40.0)).length())
	var upland: float = 1.0 - smoothstep(0.35, 1.4, ((land - Vector2(89.0, 0.0)) / Vector2(48.0, 24.0)).length())
	var broken_edge: float = (_field(warped * 0.32) - 0.5) * 0.077
	return smoothstep(0.43, 0.545, masses + 0.045 + broken_edge - village * 0.37 - upland * 0.22 - dust * 0.62)
