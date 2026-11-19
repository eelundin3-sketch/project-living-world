extends RefCounted
## Plans the roads between the towns the way people would wear them in: each leaves its town from
## the end of the main street facing where it goes, bends around rocks, buildings and fields, keeps
## out of the thick of the woods, and follows a road that is already there for as long as that is
## the easier way, so the later roads fork off the first at natural junctions. A signpost stands
## at every fork.
##
## Runs once when the world is made (TownLayout.generate); the result is ordinary road segments in
## world.roads, so everything that reads roads works unchanged. Deterministic: the search is
## Godot's AStarGrid2D over a coarse grid built only from the state.
const World = preload("res://sim/world/world_db.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const STEP := 2                 # one planning cell is STEP x STEP world cells
const TREE_COST := 0.35         # extra cost per tree in a planning cell (woods are slow going)
const TREE_COST_MAX := 1.6
const NEAR_SOLID := [1.4, 0.6]  # extra cost one and two planning cells from anything solid
const ROAD_COST := 0.6          # walking an existing road is much easier than breaking new ground
const GROUND_COST := 1.8        # gentle rises and soft ground: makes roads meander, not run ruler-straight
const GROUND_SCALE := 10        # planning cells between the ground's highs and lows
const SHARE_ANGLE := 90.0       # roads leaving a town within this many degrees of each other share a way out
const LINKS := [[1, 2], [1, 3], [2, 3]]   # the trunk first (Alder Hollow-Reedbank), then the forks

static func _coarse(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / STEP), floori(p.y / STEP))

static func _fine(c: Vector2i) -> Vector2:
	return Vector2(c) * STEP + Vector2(0.5, 0.5) * (STEP - 1)

## Plans every link road, appending "link" segments; returns the junctions ([x, y] in cells).
static func plan(sim: RefCounted, segments: Array, layout: Dictionary) -> Array:
	var s: Dictionary = sim.state
	var b: Array = s.world.get("bounds", [0, 0, World.WIDTH, World.HEIGHT])
	var region := Rect2i(floori(float(b[0]) / STEP), floori(float(b[1]) / STEP), ceili(float(b[2] - b[0]) / STEP), ceili(float(b[3] - b[1]) / STEP))
	var grid := AStarGrid2D.new()
	grid.region = region
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.jumping_enabled = false
	grid.update()
	var solid := _solid_cells(s, region)
	var weight: Dictionary = {}
	for tree in World.of_kind(s, "tree"):
		var c := _coarse(Vector2(tree.cell[0], tree.cell[1]))
		weight[c] = minf(float(weight.get(c, 0.0)) + TREE_COST, TREE_COST_MAX)
	for c in solid:
		for ring in range(NEAR_SOLID.size()):
			var r: int = ring + 1
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dy)) != r: continue
					var n: Vector2i = c + Vector2i(dx, dy)
					if not solid.has(n): weight[n] = float(weight.get(n, 0.0)) + float(NEAR_SOLID[ring])
	var seed_value: int = int(s.get("seed", 0))
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var c := Vector2i(x, y)
			weight[c] = float(weight.get(c, 0.0)) + GROUND_COST * _ground(c, seed_value)
	for c in solid:
		if region.has_point(c): grid.set_point_solid(c, true)
	for c in weight:
		if region.has_point(c) and not solid.has(c): grid.set_point_weight_scale(c, 1.0 + float(weight[c]))
	var on_road: Dictionary = {}
	var on_link: Dictionary = {}
	for segment in segments:
		if segment.kind == "main": _mark(grid, on_road, solid, segment.points)
	var junctions: Array = []
	for pair in LINKS:
		var a: String = str(pair[0])
		var z: String = str(pair[1])
		if not layout.has(a) or not layout.has(z): continue
		var from := _exit(layout, a, z, solid)
		var to := _exit(layout, z, a, solid)
		var path: Array[Vector2i] = grid.get_id_path(_coarse(from), _coarse(to))
		if path.size() < 2: continue
		for run in _new_ground(path, on_road):
			var points: Array = []
			for index in range(int(run.start), int(run.end) + 1):
				points.append(_fine(path[index]))
			if int(run.start) == 0: points[0] = from
			if int(run.end) == path.size() - 1: points[points.size() - 1] = to
			# Where the new stretch leaves (or joins) a road between towns, that is a fork.
			for end_index in [int(run.start), int(run.end)]:
				var p: Vector2 = points[0] if end_index == int(run.start) else points[points.size() - 1]
				if on_link.has(path[end_index]) and not _near_any(junctions, p): junctions.append([roundi(p.x), roundi(p.y)])
			var smooth := _chaikin(_simplify(points, 1.1), 3)
			var line: Array = []
			for p in smooth: line.append([snappedf(p.x, 0.1), snappedf(p.y, 0.1)])
			segments.append({"id": segments.size() + 1, "kind": "link", "town": int(pair[0]), "radius": 17.0 if pair == [1, 2] else 16.0, "reach": 4.0, "points": line})
			_mark(grid, on_road, solid, line)
			_mark(grid, on_link, solid, line)
	return junctions

## Cells nothing can be built through: rocks and other blocked cells, walls, fixtures, every
## building's footprint (with a cell to spare) and the fields.
static func _solid_cells(s: Dictionary, region: Rect2i) -> Dictionary:
	var solid: Dictionary = {}
	for table in [s.world.blocked, s.world.get("building_walls", {}), s.world.get("fixture_cells", {})]:
		for key in table:
			var comma: int = String(key).find(",")
			solid[_coarse(Vector2(int(String(key).substr(0, comma)), int(String(key).substr(comma + 1))))] = true
	var rects: Array = []
	for entity in World.buildings(s):
		var r: Rect2i = World.building_rect(entity)
		rects.append(r.grow(1))
	for plot in s.get("crops", {}).values():
		rects.append(Rect2i(plot.rect[0], plot.rect[1], plot.rect[2], plot.rect[3]).grow(1))
	for r in rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				solid[_coarse(Vector2(x, y))] = true
	return solid

## Smooth, seeded ground cost in 0..1 (value noise): the lie of the land the roads follow.
static func _ground(c: Vector2i, seed_value: int) -> float:
	var g := Vector2(c) / float(GROUND_SCALE)
	var base := Vector2i(floori(g.x), floori(g.y))
	var f: Vector2 = g - Vector2(base)
	f = f * f * (Vector2(3, 3) - 2.0 * f)
	var a := _hash(base, seed_value)
	var b := _hash(base + Vector2i(1, 0), seed_value)
	var c2 := _hash(base + Vector2i(0, 1), seed_value)
	var d := _hash(base + Vector2i(1, 1), seed_value)
	return lerpf(lerpf(a, b, f.x), lerpf(c2, d, f.x), f.y)

static func _hash(c: Vector2i, seed_value: int) -> float:
	var h: int = (c.x * 374761393 + c.y * 668265263 + seed_value * 2246822519) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 10007) / 10006.0

## Where a road to `other` leaves this town: the end of the main street facing it, moved on past
## anything solid there (Dustvale's iron rock sits at the east end of its street). Roads to towns
## in much the same direction share the same way out, so they run together and fork further on.
static func _exit(layout: Dictionary, here: String, there: String, solid: Dictionary) -> Vector2:
	var town: Dictionary = layout[here]
	var y: float = float(town.street_y)
	var west := Vector2(float(town.extent[0]), y)
	var east := Vector2(float(town.extent[1]), y)
	var centre := Vector2(float(town.centre[0]), float(town.centre[1]))
	var target := Vector2(float(layout[there].centre[0]), float(layout[there].centre[1]))
	var heading: Vector2 = (target - centre).normalized()
	var together := Vector2.ZERO
	for key in layout:
		if key == here: continue
		var way: Vector2 = (Vector2(float(layout[key].centre[0]), float(layout[key].centre[1])) - centre).normalized()
		if rad_to_deg(absf(heading.angle_to(way))) < SHARE_ANGLE: together += way
	target = centre + together.normalized() * 100.0
	var point: Vector2 = east if east.distance_to(target) < west.distance_to(target) else west
	var outward := Vector2(1, 0) if point == east else Vector2(-1, 0)
	for step in range(16):
		if not solid.has(_coarse(point)): return point
		point += outward * STEP
	return point

## The stretches of a planned path that are not on a road yet, each with the road cell before and
## after it, so every new stretch joins the network: [{start, end}] indexes into the path.
static func _new_ground(path: Array[Vector2i], on_road: Dictionary) -> Array:
	var runs: Array = []
	var last: int = path.size() - 1
	var index := 0
	while index <= last:
		if on_road.has(path[index]):
			index += 1
			continue
		var first_off: int = index
		while index <= last and not on_road.has(path[index]): index += 1
		var start: int = maxi(0, first_off - 1)
		var finish: int = mini(last, index)
		if finish - start >= 2: runs.append({"start": start, "end": finish})
	return runs

## Records a laid road: cheap to walk along from now on.
static func _mark(grid: AStarGrid2D, on_road: Dictionary, solid: Dictionary, points: Array) -> void:
	for i in range(points.size() - 1):
		var a := Vector2(float(points[i][0]), float(points[i][1])) if points[i] is Array else Vector2(points[i])
		var b := Vector2(float(points[i + 1][0]), float(points[i + 1][1])) if points[i + 1] is Array else Vector2(points[i + 1])
		var steps: int = maxi(1, ceili(a.distance_to(b)))
		for k in range(steps + 1):
			var c := _coarse(a.lerp(b, float(k) / float(steps)))
			if solid.has(c) or not grid.region.has_point(c): continue
			on_road[c] = true
			grid.set_point_weight_scale(c, ROAD_COST)

static func _near_any(points: Array, p: Vector2) -> bool:
	for q in points:
		if Vector2(q[0], q[1]).distance_to(p) < 24.0: return true
	return false

## Drops points that add nothing to the shape (Ramer-Douglas-Peucker), keeping both ends.
static func _simplify(points: Array, tolerance: float) -> Array:
	if points.size() < 3: return points
	var worst: float = 0.0
	var at: int = 0
	for i in range(1, points.size() - 1):
		var d: float = Geometry2D.get_closest_point_to_segment(points[i], points[0], points[points.size() - 1]).distance_to(points[i])
		if d > worst:
			worst = d
			at = i
	if worst <= tolerance: return [points[0], points[points.size() - 1]]
	var left := _simplify(points.slice(0, at + 1), tolerance)
	var right := _simplify(points.slice(at), tolerance)
	return left.slice(0, left.size() - 1) + right

## Rounds the corners (Chaikin), keeping both ends where they are.
static func _chaikin(points: Array, rounds: int) -> Array:
	var result: Array = points
	for r in range(rounds):
		if result.size() < 3: return result
		var next: Array = [result[0]]
		for i in range(result.size() - 1):
			var a: Vector2 = result[i]
			var b: Vector2 = result[i + 1]
			next.append(a.lerp(b, 0.25))
			next.append(a.lerp(b, 0.75))
		next.append(result[result.size() - 1])
		result = next
	return result

## A signpost beside each fork, naming the way to each town. Not solid: it stands at the verge.
static func place_signposts(sim: RefCounted, junctions: Array) -> void:
	var s: Dictionary = sim.state
	for junction in junctions:
		var spot: Array = []
		for offset in [[5, 0], [-5, 0], [0, 5], [0, -5], [6, 3], [-6, -3]]:
			var cell: Array = [int(junction[0]) + offset[0], int(junction[1]) + offset[1]]
			if World.walkable(s, cell): spot = cell; break
		if spot.is_empty(): continue
		var ways: Array = []
		var towns: Array = s.settlements.keys()
		towns.sort()
		for key in towns:
			var town: Dictionary = s.settlements[key]
			var store: Array = s.entities[str(town.warehouse)].cell
			ways.append("%s to the %s" % [town.name, _compass(Vector2(store[0] - spot[0], store[1] - spot[1]))])
		var id: int = World.add_entity(sim, "signpost", "Signpost", spot, 0)
		s.entities[str(id)].directions = ", ".join(ways)
		Inventory.create(s, id, 0)

static func _compass(v: Vector2) -> String:
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return names[posmod(roundi(v.angle() / (PI / 4.0)), 8)]
