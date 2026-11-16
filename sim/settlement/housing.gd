extends RefCounted
## Houses for households. A town's people live as families or on their own; each household gets
## a house sized for it (one bed per person, 1 to 3) chosen from a catalogue of house types, and
## the houses are scattered irregularly around the square instead of standing in a row, always
## clear of the roads into town, of each other, of fields and of the market.
const World = preload("res://sim/world/world_db.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")

## Size is [width, height] in cells (the door is the middle of the bottom wall). Shapes: "rect",
## "notch_right" / "notch_left" (a corner cut out at the back). `style` picks the timber tint.
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

## The fields a house entity carries (also given to a construction site before it is built).
static func house_fields(entry: Dictionary) -> Dictionary:
	return {"house_type": entry.id, "house_size": entry.size.duplicate(), "layout_shape": entry.shape,
		"house_beds": int(entry.beds), "house_partition": bool(entry.partition), "house_style": entry.style}

## Where nothing may be built: a corridor along every road, the market square and its stalls,
## every building (with a yard around it), fields and gardens, and planned sites.
static func blocked_areas(s: Dictionary) -> Array[Rect2i]:
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
	areas.append_array(World.road_corridors(s))
	return areas

## A spot for a house of `entry` near the town's square: rings outwards with a random angle and
## distance for each try, so towns grow irregularly. Returns the door cell, or [] if none fits.
static func find_plot(sim: RefCounted, settlement: int, entry: Dictionary) -> Array:
	var s: Dictionary = sim.state
	var store: Array = s.entities[str(s.settlements[str(settlement)].warehouse)].cell
	var blocked := blocked_areas(s)
	var w: int = entry.size[0]
	var h: int = entry.size[1]
	for attempt in range(260):
		var radius: float = 16.0 + float(attempt) * 0.16 + float(sim.random_int("plots:%d" % settlement, 0, 9))
		var angle: float = float(sim.random_int("plots:%d" % settlement, 0, 6283)) / 1000.0
		var door: Array = [store[0] + roundi(cos(angle) * radius * 1.25), store[1] + roundi(sin(angle) * radius)]
		var rect := Rect2i(door[0] - w / 2, door[1] - h + 1, w, h)
		var clear := true
		for area in blocked:
			if area.intersects(rect.grow(1)):
				clear = false
				break
		if not clear: continue
		for y in range(rect.position.y - 1, rect.end.y + 3):
			for x in range(rect.position.x - 1, rect.end.x + 1):
				if not World.walkable(s, [x, y]):
					clear = false
					break
			if not clear: break
		if clear: return door
	return []

## Builds a finished house for a household and moves them in. Returns the house id or 0.
static func build_for(sim: RefCounted, household_key: String) -> int:
	var s: Dictionary = sim.state
	var household: Dictionary = s.households[household_key]
	var entry := choose(sim, household.members.size(), int(household.settlement))
	var door := find_plot(sim, int(household.settlement), entry)
	if door.is_empty(): return 0
	var surname: String = String(s.entities[str(household.members[0])].name).split(" ")[-1]
	var label: String = "The %s %s" % [surname, String(entry.name).to_lower()] if household.members.size() > 1 else "%s's %s" % [s.entities[str(household.members[0])].name.split(" ")[0], String(entry.name).to_lower()]
	var id := World.add_entity(sim, "home", label, door, int(household.settlement), house_fields(entry))
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
