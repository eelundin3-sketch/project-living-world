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
	return cell[0] >= bounds[0] and cell[1] >= bounds[1] and cell[0] < bounds[2] and cell[1] < bounds[3] and not state.world.blocked.has(cell_key(cell))

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
	return id

static func seed_world(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	s.world = {"blocked": {}, "chunks": {}, "nav_revision": 0}
	s.inventories = {}
	s.accounting = {"initial": {}, "created": {}, "consumed": {}}
	s.player = add_entity(sim, "player", "Traveller", [62, 49])
	Inventory.create(s, s.player, 40, {"food": 4})
	s.warehouse = add_entity(sim, "warehouse", "Alder Hollow storehouse", [64, 46], 1)
	Inventory.create(s, s.warehouse, 3000, {"food": 160})
	s.home = add_entity(sim, "home", "Common lodge", [59, 43], 1)
	s.farm = add_entity(sim, "farm", "Communal vegetable beds", [70, 50], 1)
	Inventory.create(s, s.farm, 1000, {"food": 300})
	for index in range(70):
		var cell: Array = [sim.random_int("map", 35, 90), sim.random_int("map", 20, 70)]
		if abs(cell[0] - 64) < 13 and abs(cell[1] - 46) < 10:
			cell[1] -= 19
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
