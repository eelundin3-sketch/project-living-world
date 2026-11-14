extends RefCounted
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const CHUNK_SIDE: int = 64
const WIDTH: int = 128
const HEIGHT: int = 96

static func cell_key(cell: Array) -> String:
	return "%d,%d" % [cell[0], cell[1]]

static func chunk_coord(x: int, y: int) -> Vector2i:
	return Vector2i(floori(float(x) / CHUNK_SIDE), floori(float(y) / CHUNK_SIDE))

static func walkable(state: Dictionary, cell: Array) -> bool:
	var bounds: Array = state.world.get("bounds", [0, 0, WIDTH, HEIGHT])
	return cell[0] >= bounds[0] and cell[1] >= bounds[1] and cell[0] < bounds[2] and cell[1] < bounds[3] and not state.world.blocked.has(cell_key(cell)) and not state.world.get("building_walls", {}).has(cell_key(cell))

static func get_cell(state: Dictionary, cell: Array) -> Dictionary:
	return {"cell": cell, "walkable": walkable(state, cell), "chunk": [chunk_coord(cell[0], cell[1]).x, chunk_coord(cell[0], cell[1]).y]}

static func get_chunk(state: Dictionary, coord: Vector2i) -> Dictionary:
	var key := "%d,%d" % [coord.x, coord.y]
	return state.world.chunks.get(key, {"seed": state.seed, "version": 1, "entities": [], "mutations": {}})

static func apply_mutation(state: Dictionary, cell: Array, blocked: bool) -> void:
	if blocked:
		state.world.blocked[cell_key(cell)] = true
	else:
		state.world.blocked.erase(cell_key(cell))
	state.world.nav_revision += 1
	var coord := chunk_coord(cell[0], cell[1])
	var key := "%d,%d" % [coord.x, coord.y]
	if not state.world.chunks.has(key):
		state.world.chunks[key] = {"seed": state.seed, "version": 1, "entities": [], "mutations": {}}
	state.world.chunks[key].mutations[cell_key(cell)] = blocked

static func add_entity(sim: RefCounted, kind: String, name_value: String, cell: Array, settlement: int = 0) -> int:
	var id: int = sim.new_id()
	sim.state.entities[str(id)] = {"id": id, "kind": kind, "name": name_value, "cell": cell.duplicate(), "settlement": settlement}
	var coord := chunk_coord(cell[0], cell[1])
	var key := "%d,%d" % [coord.x, coord.y]
	if not sim.state.world.chunks.has(key):
		sim.state.world.chunks[key] = {"seed": sim.state.seed, "version": 1, "entities": [], "mutations": {}}
	sim.state.world.chunks[key].entities.append(id)
	if kind in ["home", "warehouse", "sawmill", "market"]:
		install_building(sim.state, id)
	return id

static func seed_world(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	s.world = {"blocked": {}, "chunks": {}, "nav_revision": 0, "building_walls": {}}
	s.inventories = {}
	s.accounting = {"initial": {}, "created": {}, "consumed": {}}
	s.player = add_entity(sim, "player", "Traveller", [62, 49])
	Inventory.create(s, s.player, 40, {"food": 4})
	s.warehouse = add_entity(sim, "warehouse", "Alder Hollow storehouse", [64, 46], 1)
	Inventory.create(s, s.warehouse, 3000, {"food": 160})
	s.home = add_entity(sim, "home", "Common lodge", [54, 42], 1)
	s.farm = add_entity(sim, "farm", "Communal vegetable beds", [74, 54], 1)
	Inventory.create(s, s.farm, 1000, {"food": 300})
	for index in range(70):
		var cell: Array = [sim.random_int("map", 35, 90), sim.random_int("map", 20, 70)]
		if abs(cell[0] - 64) < 13 and abs(cell[1] - 46) < 10:
			cell[1] -= 19
		while inside_building(s, cell) != 0:
			cell[1] -= 8
		var id := add_entity(sim, "tree", "Alder %02d" % (index + 1), cell, 1)
		Inventory.create(s, id, 40, {"log": 30})
	for index in range(60):
		var cell: Array = [sim.random_int("rocks", 15, 110), sim.random_int("rocks", 10, 85)]
		if abs(cell[0] - 64) > 28 or abs(cell[1] - 46) > 25:
			apply_mutation(s, cell, true)
	s.accounting.initial = Inventory.totals(s)

static func ensure_chunk(state: Dictionary, coord: Vector2i) -> Dictionary:
	var key := "%d,%d" % [coord.x, coord.y]
	if not state.world.chunks.has(key):
		var seed_value: int = (str(state.seed) + ":" + key).sha256_text().substr(0, 8).hex_to_int()
		state.world.chunks[key] = {"seed": seed_value, "version": 1, "entities": [], "mutations": {}, "biome": "meadow" if seed_value % 3 == 0 else "woodland"}
	return state.world.chunks[key]

static func footprint(cell: Array, kind: String) -> Rect2i:
	var width: int = 7 if kind == "home" else 9
	var height: int = 6 if kind != "warehouse" else 7
	return Rect2i(cell[0] - width / 2, cell[1] - height + 1, width, height)

static func building_rect(entity: Dictionary) -> Rect2i:
	var data: Array = entity.get("footprint", [])
	return Rect2i(data[0], data[1], data[2], data[3]) if data.size() == 4 else footprint(entity.cell, entity.kind)

static func inside_building(s: Dictionary, cell: Array) -> int:
	for entity in s.entities.values():
		if entity.has("footprint") and building_rect(entity).has_point(Vector2i(cell[0], cell[1])):
			return entity.id
	return 0

static func install_building(s: Dictionary, id: int) -> void:
	var entity: Dictionary = s.entities[str(id)]
	var rect := footprint(entity.cell, entity.kind)
	entity.footprint = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	entity.door = entity.cell.duplicate()
	if not s.world.has("building_walls"):
		s.world.building_walls = {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if x in [rect.position.x, rect.end.x - 1] or y in [rect.position.y, rect.end.y - 1]:
				if [x, y] != entity.door:
					s.world.building_walls[cell_key([x, y])] = id
	s.world.nav_revision += 1
	for resource in s.entities.values():
		if resource.get("kind", "") in ["tree", "farm"] and rect.has_point(Vector2i(resource.cell[0], resource.cell[1])):
			for offset in range(1, 200):
				var candidate: Array = [entity.cell[0] + (offset % 15) - 7, entity.cell[1] + 2 + offset / 15]
				var occupied: bool = false
				for other in s.entities.values():
					if other.get("cell", []) == candidate:
						occupied = true
				if walkable(s, candidate) and inside_building(s, candidate) == 0 and not occupied:
					move_record(s, resource, candidate)
					break
	# Completion must never enclose a worker/player in a newly occupied wall cell.
	for actor in s.entities.values():
		if actor.get("kind", "") in ["resident", "player", "caravan"] and not walkable(s, actor.cell):
			actor.cell = entity.door.duplicate()

static func upgrade_layouts(s: Dictionary) -> void:
	if not s.has("world") or s.world.has("building_walls"):
		return
	s.world.building_walls = {}
	for entity in s.entities.values():
		if entity.get("kind", "") in ["home", "warehouse", "sawmill", "market"]:
			# Earlier icons sat too close together for full-sized rooms.
			if s.has("settlements") and s.settlements.has(str(entity.settlement)):
				var store: Array = s.entities[str(s.settlements[str(entity.settlement)].warehouse)].cell
				if entity.kind == "sawmill":
					move_record(s, entity, [store[0] + 12, store[1] - 4])
				elif entity.kind == "home" and entity.id == s.settlements[str(entity.settlement)].home:
					move_record(s, entity, [store[0] - 10, store[1] - 4])
			for attempt in range(100):
				var rect := footprint(entity.cell, entity.kind).grow(1)
				var overlaps: bool = false
				for other in s.entities.values():
					if other.id != entity.id and other.has("footprint") and rect.intersects(building_rect(other)):
						overlaps = true
				if not overlaps:
					break
				move_record(s, entity, [entity.cell[0], entity.cell[1] + 9])
			install_building(s, entity.id)

static func move_record(s: Dictionary, entity: Dictionary, destination: Array) -> void:
	var old := chunk_coord(entity.cell[0], entity.cell[1])
	var new_coord := chunk_coord(destination[0], destination[1])
	if old != new_coord:
		var old_key := "%d,%d" % [old.x, old.y]
		if s.world.chunks.has(old_key):
			s.world.chunks[old_key].entities.erase(entity.id)
		ensure_chunk(s, new_coord).entities.append(entity.id)
	entity.cell = destination.duplicate()
