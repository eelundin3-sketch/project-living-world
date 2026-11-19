extends RefCounted
## Houses for households. A town's people live as families or on their own; each household gets
## a house sized for it (one bed per person, 1 to 3) chosen from a catalogue of house types, and
## the houses are scattered irregularly around the square instead of standing in a row, always
## clear of the roads into town, of each other, of fields and of the market.
const World = preload("res://sim/world/world_db.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Orient = preload("res://sim/world/orient.gd")
const TownLayout = preload("res://sim/world/town_layout.gd")

## Size is [width, height] in cells (the door is the middle of the bottom wall unless the type says
## where). Shapes: "rect", "notch_right" / "notch_left" (a corner cut out at the back), or "rects": a
## union of `rects` [x, y, w, h] written south-facing with the origin at the top left, and the `door`
## cell [x, y] on the bottom edge. Every house is turned at placement so its door faces the road.
## `style` picks the timber tint.
const TYPES: Array[Dictionary] = [
	{"id": "shack", "name": "Plank shack", "size": [8, 7], "shape": "rect", "beds": 1, "partition": false, "style": "weathered"},
	{"id": "cabin", "name": "Log cabin", "size": [9, 8], "shape": "rect", "beds": 1, "partition": false, "style": "log"},
	{"id": "lean_to", "name": "Lean-to cottage", "size": [10, 8], "shape": "notch_left", "beds": 1, "partition": false, "style": "pine"},
	{"id": "hut", "name": "Adobe hut", "size": [9, 9], "shape": "rect", "beds": 1, "partition": false, "style": "adobe"},
	{"id": "cottage", "name": "Cottage", "size": [11, 9], "shape": "rect", "beds": 2, "partition": false, "style": "whitewash"},
	{"id": "saltbox", "name": "Saltbox house", "size": [12, 10], "shape": "notch_right", "beds": 2, "partition": false, "style": "redwood"},
	{"id": "clapboard", "name": "Clapboard house", "size": [12, 11], "shape": "rect", "beds": 2, "partition": false, "style": "grey"},
	{"id": "stone_cottage", "name": "Stone cottage", "size": [13, 10], "shape": "notch_left", "beds": 2, "partition": false, "style": "stone"},
	{"id": "farmhouse", "name": "Farmhouse", "size": [15, 12], "shape": "rect", "beds": 3, "partition": true, "style": "pine"},
	{"id": "family_house", "name": "Family house", "size": [16, 13], "shape": "notch_right", "beds": 3, "partition": true, "style": "log"},
	{"id": "homestead", "name": "Homestead", "size": [17, 13], "shape": "notch_left", "beds": 3, "partition": true, "style": "redwood"},
	{"id": "two_room", "name": "Two-room house", "size": [16, 12], "shape": "rect", "beds": 3, "partition": true, "style": "whitewash"},
	{"id": "dogtrot", "name": "Dogtrot house", "size": [17, 12], "shape": "rect", "beds": 3, "partition": true, "style": "weathered"},
	# Shapes made of several blocks.
	{"id": "offset_cabin", "name": "Offset cabin", "size": [10, 10], "shape": "rects", "rects": [[0, 0, 7, 5], [3, 5, 7, 5]], "door": [6, 9], "beds": 1, "partition": false, "style": "log"},
	{"id": "porch_shack", "name": "L-shaped shack", "size": [9, 8], "shape": "rects", "rects": [[0, 0, 5, 8], [5, 3, 4, 5]], "door": [7, 7], "beds": 1, "partition": false, "style": "weathered"},
	{"id": "wing_house", "name": "Wing house", "size": [13, 11], "shape": "rects", "rects": [[0, 0, 13, 6], [0, 6, 5, 5]], "door": [2, 10], "beds": 2, "partition": false, "style": "grey"},
	{"id": "longhouse", "name": "Longhouse", "size": [16, 7], "shape": "rect", "beds": 2, "partition": false, "style": "pine"},
	{"id": "court_cottage", "name": "Courtyard cottage", "size": [14, 9], "shape": "rects", "rects": [[0, 0, 5, 9], [9, 0, 5, 9], [5, 0, 4, 3]], "door": [2, 8], "beds": 2, "partition": false, "style": "adobe"},
	{"id": "t_house", "name": "T-shaped house", "size": [17, 12], "shape": "rects", "rects": [[0, 0, 17, 5], [5, 5, 7, 7]], "door": [8, 11], "beds": 3, "partition": false, "style": "redwood"},
	{"id": "u_house", "name": "Courtyard house", "size": [17, 11], "shape": "rects", "rects": [[0, 0, 5, 11], [12, 0, 5, 11], [5, 0, 7, 4]], "door": [2, 10], "beds": 3, "partition": false, "style": "whitewash"},
	{"id": "cross_house", "name": "Cross-gabled house", "size": [15, 12], "shape": "rects", "rects": [[4, 0, 7, 12], [0, 4, 15, 4]], "door": [7, 11], "beds": 3, "partition": false, "style": "stone"},
]
## Dry country builds in earth and stone.
const DESERT_STYLES: Array[String] = ["adobe", "stone", "adobe", "weathered"]

static func type_by_id(id: String) -> Dictionary:
	for entry in TYPES:
		if entry.id == id: return entry
	return {}

## A house for `people` (beds = people, 1..3). Most singles can only afford a one-room place; a
## few better-off ones take a two-bed house, and a well-off couple builds for a growing family.
static func choose(sim: RefCounted, people: int, settlement: int) -> Dictionary:
	var beds: int = clampi(people, 1, 3)
	var luck: int = sim.random_int("houses", 0, 99)
	if beds == 1 and luck < 22: beds = 2
	elif beds == 2 and luck < 30: beds = 3
	var options: Array = TYPES.filter(func(entry: Dictionary) -> bool: return int(entry.beds) == beds)
	var picked: Dictionary = options[sim.random_int("houses", 0, options.size() - 1)].duplicate()
	if settlement == 3: picked.style = DESERT_STYLES[sim.random_int("houses", 0, DESERT_STYLES.size() - 1)]
	return picked

## The south-facing template of a house type: its blocks (local rects), its door and any inside wall.
static func template(entry: Dictionary) -> Dictionary:
	var w: int = entry.size[0]
	var h: int = entry.size[1]
	var rects: Array = []
	var shape: String = entry.shape
	if shape == "rects":
		rects = entry.rects.duplicate(true)
	elif shape == "notch_right" or shape == "notch_left":
		var cut := World.shape_notch(Rect2i(0, 0, w, h), shape)
		if shape == "notch_right": rects = [[0, 0, cut.x, h], [cut.x, cut.y, w - cut.x, h - cut.y]]
		else: rects = [[0, cut.y, cut.x, h - cut.y], [cut.x, 0, w - cut.x, h]]
	else:
		rects = [[0, 0, w, h]]
	var door: Array = entry.get("door", [w / 2, h - 1])
	var walls: Array = World.partition_cells(Rect2i(0, 0, w, h)) if bool(entry.partition) else []
	return {"rects": rects, "door": door, "walls": walls}

## The house turned so its door (at `door_cell`) faces `side`: world blocks, inside walls and bounds.
static func oriented(entry: Dictionary, door_cell: Array, side: int) -> Dictionary:
	var shape := template(entry)
	var door_local := Vector2i(int(shape.door[0]), int(shape.door[1]))
	var rects: Array = []
	for r in shape.rects:
		rects.append(Orient.rect([int(r[0]) - door_local.x, int(r[1]) - door_local.y, int(r[2]), int(r[3])], door_cell, side))
	var walls: Array = []
	for cell in shape.walls: walls.append(Orient.cell(Vector2i(int(cell[0]), int(cell[1])) - door_local, door_cell, side))
	var bounds: Rect2i = World.rects_bounds(rects)
	return {"rects": rects, "walls": walls, "bounds": bounds}

## The fields for a house placed with its door at `door_cell` facing `side` (the house keeps its
## turned blocks, so every part of the game reads the same shape).
static func placed_fields(entry: Dictionary, door_cell: Array, side: int) -> Dictionary:
	var fields := house_fields(entry)
	var placed := oriented(entry, door_cell, side)
	fields.house_rects = placed.rects
	fields.house_walls = placed.walls
	fields.door_side = side
	fields.house_size = [placed.bounds.size.x, placed.bounds.size.y]
	fields.layout_shape = "rects"
	return fields

## The fields a house entity carries (also given to a construction site before it is built).
static func house_fields(entry: Dictionary) -> Dictionary:
	return {"house_type": entry.id, "house_size": entry.size.duplicate(), "layout_shape": entry.shape,
		"house_beds": int(entry.beds), "house_partition": bool(entry.partition), "house_style": entry.style}

## Where nothing may be built: a corridor along every road, the market square and its stalls,
## every building (with a yard around it), fields and gardens, and planned sites.
static func blocked_areas(s: Dictionary, with_roads: bool = true) -> Array[Rect2i]:
	var areas: Array[Rect2i] = []
	for entity in s.entities.values():
		if entity.has("footprint"): areas.append(World.building_rect(entity).grow(4))
		elif entity.get("kind", "") == "construction": areas.append(World.plot_rect(entity, "home").grow(4))
		elif entity.get("kind", "") in ["market_stall", "farm", "ore", "chest"]: areas.append(Rect2i(entity.cell[0] - 4, entity.cell[1] - 3, 9, 7))
		if entity.has("rock_rect"):
			var r: Array = entity.rock_rect
			areas.append(Rect2i(r[0], r[1], r[2], r[3]).grow(3))
	for plot in s.get("crops", {}).values():
		areas.append(Rect2i(plot.rect[0], plot.rect[1], plot.rect[2], plot.rect[3]).grow(3))
	for town in s.get("settlements", {}).values():
		var store: Array = s.entities[str(town.warehouse)].cell
		areas.append(Rect2i(store[0] - 17, store[1] - 6, 35, 26))   # the square, stalls and well
	if with_roads: areas.append_array(World.road_corridors(s))
	return areas

## Whether a house of `entry`, turned so its door at `door` faces `side`, fits there: clear of
## buildings, fields, the roads, rocks and water, with a yard in front of the door.
static func fits(s: Dictionary, entry: Dictionary, door: Array, side: int, blocked: Array, roads: Dictionary) -> bool:
	var placed := oriented(entry, door, side)
	for r in placed.rects:
		var rect := Rect2i(r[0], r[1], r[2], r[3]).grow(1)
		for area in blocked:
			if area.intersects(rect): return false
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if roads.has("%d,%d" % [x, y]) or not World.walkable(s, [x, y]): return false
	var out := Orient.outward(side)
	for step in range(1, 4):
		var yard: Array = [door[0] + out.x * step, door[1] + out.y * step]
		if not World.walkable(s, yard): return false
		for area in blocked:
			if area.has_point(Vector2i(yard[0], yard[1])) and step <= 2: return false
	return true

## Where a house of `entry` goes: a lot along one of the town's lanes with its door facing the road,
## picked from the nearer ones with plenty of chance so no street is a tidy row. Falls back to a
## scatter around the square (door facing south) once the lanes are full. Returns {"door", "side"}
## or {} if nothing fits.
static func find_site(sim: RefCounted, settlement: int, entry: Dictionary) -> Dictionary:
	var s: Dictionary = sim.state
	var blocked := blocked_areas(s, false)
	var roads: Dictionary = TownLayout.road_cells(s)
	var candidates: Array = TownLayout.lots(s, settlement)
	for lot in candidates: lot.rank = float(lot.distance) + float(sim.random_int("plots:%d" % settlement, 0, 300)) / 10.0
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rank < b.rank)
	var tried := 0
	for lot in candidates:
		tried += 1
		if tried > 400: break
		if fits(s, entry, lot.door, int(lot.side), blocked, roads): return {"door": lot.door, "side": int(lot.side)}
	var door := _scatter(sim, settlement, entry)
	return {"door": door, "side": 2} if not door.is_empty() else {}

## The old way: a random spot on an ellipse around the square, door facing south.
static func _scatter(sim: RefCounted, settlement: int, entry: Dictionary) -> Array:
	var s: Dictionary = sim.state
	var store: Array = s.entities[str(s.settlements[str(settlement)].warehouse)].cell
	var blocked := blocked_areas(s, false)
	var roads: Dictionary = TownLayout.road_cells(s)
	for attempt in range(260):
		var radius: float = 16.0 + float(attempt) * 0.16 + float(sim.random_int("plots:%d" % settlement, 0, 9))
		var angle: float = float(sim.random_int("plots:%d" % settlement, 0, 6283)) / 1000.0
		var door: Array = [store[0] + roundi(cos(angle) * radius * 1.25), store[1] + roundi(sin(angle) * radius)]
		if fits(s, entry, door, 2, blocked, roads): return door
	return []

## A spot for a house of `entry`: its door cell, or [] (see find_site for the side it faces).
static func find_plot(sim: RefCounted, settlement: int, entry: Dictionary) -> Array:
	return find_site(sim, settlement, entry).get("door", [])

## Builds a finished house for a household and moves them in. Returns the house id or 0.
static func build_for(sim: RefCounted, household_key: String) -> int:
	var s: Dictionary = sim.state
	var household: Dictionary = s.households[household_key]
	var entry := choose(sim, household.members.size(), int(household.settlement))
	var site := find_site(sim, int(household.settlement), entry)
	if site.is_empty(): return 0
	var door: Array = site.door
	var surname: String = String(s.entities[str(household.members[0])].name).split(" ")[-1]
	var label: String = "The %s %s" % [surname, String(entry.name).to_lower()] if household.members.size() > 1 else "%s's %s" % [s.entities[str(household.members[0])].name.split(" ")[0], String(entry.name).to_lower()]
	var id := World.add_entity(sim, "home", label, door, int(household.settlement), placed_fields(entry, door, int(site.side)))
	if not s.inventories.has(str(id)): Inventory.create(s, id, 400)
	household.home = id
	var town: Dictionary = s.settlements[str(household.settlement)]
	town.housing = int(town.get("housing", 0)) + int(entry.beds)
	return id

## At the start of a game each town's people pair off into families or stay single, and every
## household gets its own house. The common lodge stays for newcomers and travellers.
static func settle(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	if not s.has("households") or not s.has("settlements"): return
	var towns: Array = s.settlements.keys()
	towns.sort()
	for town_key in towns:
		var town: Dictionary = s.settlements[town_key]
		var people: Array = []
		for npc in s.residents.values():
			if npc.settlement == town.id: people.append(npc.id)
		people.sort()
		for key in s.households.keys():
			if s.households[key].settlement == town.id: s.households.erase(key)
		var index := 0
		var group := 0
		while index < people.size():
			# Two or three live together as a family about half of the time; the rest live alone.
			var size := 1
			if people.size() - index >= 2 and sim.random_int("families", 0, 99) < 55:
				size = 3 if people.size() - index >= 3 and sim.random_int("families", 0, 99) < 30 else 2
			var members: Array = people.slice(index, index + size)
			var key := "%d:h%d" % [town.id, group]
			s.households[key] = {"settlement": town.id, "members": members, "home": town.home, "children": 0, "formed": 0}
			for id in members: s.residents[str(id)].household = key
			if members.size() >= 2:
				s.residents[str(members[0])].partner = members[1]
				s.residents[str(members[1])].partner = members[0]
			index += size
			group += 1
		var keys: Array = s.households.keys().filter(func(k: String) -> bool: return s.households[k].settlement == town.id)
		keys.sort()
		# Bigger households first: they need the bigger plots.
		keys.sort_custom(func(a: String, b: String) -> bool: return s.households[a].members.size() > s.households[b].members.size() or (s.households[a].members.size() == s.households[b].members.size() and a < b))
		for key in keys: build_for(sim, key)
