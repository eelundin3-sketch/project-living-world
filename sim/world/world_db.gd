extends RefCounted
const Fixtures = preload("res://sim/world/fixtures.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const CHUNK_SIDE: int = 64
const WIDTH: int = 128
const HEIGHT: int = 96
const METERS_PER_CELL: float = 1.0

const VILLAGE_HOME_PLOTS := [Vector2i(-18, 17), Vector2i(0, 19), Vector2i(0, 35)]

static func reserved_home_plots(center: Array) -> Array[Rect2i]:
	var plots: Array[Rect2i] = []
	for offset in VILLAGE_HOME_PLOTS:
		plots.append(footprint([center[0] + offset.x, center[1] + offset.y], "home").grow(1))
	return plots

static func in_reserved_plot(plots: Array[Rect2i], cell: Array) -> bool:
	var point := Vector2i(cell[0], cell[1])
	for plot in plots:
		if plot.has_point(point): return true
	return false

static func cell_key(cell: Array) -> String:
	return "%d,%d" % [cell[0], cell[1]]

static func chunk_coord(x: int, y: int) -> Vector2i:
	return Vector2i(floori(float(x) / CHUNK_SIDE), floori(float(y) / CHUNK_SIDE))

static func walkable(state: Dictionary, cell: Array) -> bool:
	var bounds: Array = state.world.get("bounds", [0, 0, WIDTH, HEIGHT])
	return cell[0] >= bounds[0] and cell[1] >= bounds[1] and cell[0] < bounds[2] and cell[1] < bounds[3] and not state.world.blocked.has(cell_key(cell)) and not state.world.get("building_walls", {}).has(cell_key(cell)) and not state.world.get("fixture_cells", {}).has(cell_key(cell))

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
	if kind in ["home", "warehouse", "sawmill", "market", "construction"]:
		sim.state.entities[str(id)].building_scale = 2
	if kind == "home": sim.state.entities[str(id)].layout_shape = "stepped_joined"
	var coord := chunk_coord(cell[0], cell[1])
	var key := "%d,%d" % [coord.x, coord.y]
	if not sim.state.world.chunks.has(key):
		sim.state.world.chunks[key] = {"seed": sim.state.seed, "version": 1, "entities": [], "mutations": {}}
	sim.state.world.chunks[key].entities.append(id)
	if kind in ["home", "warehouse", "sawmill", "market"]:
		install_building(sim.state, id)
	elif kind in ["construction", "market_stall"]:
		Fixtures.install(sim.state, sim.state.entities[str(id)])
		sim.state.world.nav_revision += 1
	return id

static func seed_world(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	s.world = {"blocked": {}, "chunks": {}, "nav_revision": 0, "building_walls": {}, "architecture_version": 3, "house_layout_version": 2, "building_scale_version": 2, "fixture_version": 2, "fixture_cells": {}, "meters_per_cell": METERS_PER_CELL}
	s.inventories = {}
	s.accounting = {"initial": {}, "created": {}, "consumed": {}}
	s.player = add_entity(sim, "player", "Traveller", [62, 49])
	Inventory.create(s, s.player, 40, {"food": 4})
	s.warehouse = add_entity(sim, "warehouse", "Alder Hollow storehouse", [64, 46], 1)
	Inventory.create(s, s.warehouse, 3000, {"food": 160})
	s.home = add_entity(sim, "home", "Common lodge", [46, 42], 1)
	s.farm = add_entity(sim, "farm", "Communal vegetable beds", [81, 57], 1)
	Inventory.create(s, s.farm, 1000, {"food": 300})
	populate_forest(sim, 1, 280, [64, 46], false)
	populate_dense_groves(sim, 1, 100, [64, 46], false)
	s.world.forest_version = 3
	var plots := reserved_home_plots([64, 46])
	for index in range(60):
		var cell: Array = [sim.random_int("rocks", 15, 110), sim.random_int("rocks", 10, 85)]
		if (abs(cell[0] - 64) > 28 or abs(cell[1] - 46) > 25) and not in_reserved_plot(plots, cell):
			apply_mutation(s, cell, true)
	s.accounting.initial = Inventory.totals(s)

static func ensure_chunk(state: Dictionary, coord: Vector2i) -> Dictionary:
	var key := "%d,%d" % [coord.x, coord.y]
	if not state.world.chunks.has(key):
		var seed_value: int = (str(state.seed) + ":" + key).sha256_text().substr(0, 8).hex_to_int()
		state.world.chunks[key] = {"seed": seed_value, "version": 1, "entities": [], "mutations": {}, "biome": "meadow" if seed_value % 3 == 0 else "woodland"}
	return state.world.chunks[key]

static func footprint(cell: Array, kind: String, scale_version: int = 2) -> Rect2i:
	var width: int = 17 if kind in ["home", "warehouse"] else 15
	var height: int = 14 if kind == "home" else (15 if kind == "warehouse" else 13)
	if scale_version < 2:
		width = 11 if kind == "home" else 13
		height = 9 if kind == "home" else (10 if kind == "warehouse" else 8)
	return Rect2i(cell[0] - width / 2, cell[1] - height + 1, width, height)

static func plot_rect(entity: Dictionary, kind: String) -> Rect2i:
	return footprint(entity.cell, kind, entity.get("building_scale", 1))

static func house_notch(rect: Rect2i) -> Vector2i:
	return rect.position + (Vector2i(10, 3) if rect.size.x >= 17 else Vector2i(7, 2))

static func partition_cells(rect: Rect2i) -> Array:
	var cells: Array = []
	var large := rect.size.x >= 15
	var partition_x: int = rect.position.x + (rect.size.x / 2 - 2 if large else 4)
	var passage_start: int = rect.end.y - (6 if large else 4)
	var passage_width := 3 if large else 2
	for y in range(rect.position.y + 1, rect.end.y - 1):
		if y < passage_start or y >= passage_start + passage_width:
			cells.append([partition_x, y])
	return cells

# The same footprint drives floors, collision and construction; legacy sites retain
# their original rectangular layout until completed.
static func building_contains(entity: Dictionary, cell: Array, kind: String = "") -> bool:
	var actual_kind: String = kind if not kind.is_empty() else entity.kind
	var rect := plot_rect(entity, actual_kind)
	var notch := house_notch(rect)
	if not rect.has_point(Vector2i(cell[0], cell[1])): return false
	return not (actual_kind == "home" and entity.get("layout_shape", "") in ["stepped", "stepped_joined"] and cell[0] >= notch.x and cell[1] < notch.y)

static func exterior_wall(entity: Dictionary, cell: Array, kind: String) -> bool:
	if not building_contains(entity, cell, kind): return false
	if kind == "home" and entity.get("layout_shape", "") == "stepped_joined":
		var corner := house_notch(plot_rect(entity, kind)) + Vector2i.LEFT
		if Vector2i(cell[0], cell[1]) == corner: return true
	for offset in [[0, -1], [0, 1], [-1, 0], [1, 0]]:
		if not building_contains(entity, [cell[0] + offset[0], cell[1] + offset[1]], kind): return true
	return false

static func construction_stages(entity: Dictionary, kind: String) -> Array[Dictionary]:
	var rect := plot_rect(entity, kind)
	var floor_tiles: Array = []
	var roof_tiles: Array = []
	var wall_tiles: Array = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell: Array = [x, y]
			if not building_contains(entity, cell, kind): continue
			if exterior_wall(entity, cell, kind):
				if cell != entity.cell: wall_tiles.append(cell)
			else:
				floor_tiles.append(cell)
				roof_tiles.append(cell.duplicate())
	wall_tiles.append_array(partition_cells(rect))
	var walls := {"id": "walls", "label": "Building walls", "tiles": wall_tiles}
	var floor_stage := {"id": "floor", "label": "Laying floor", "tiles": floor_tiles}
	var door := {"id": "door", "label": "Fitting doorway", "tiles": [entity.cell.duplicate()]}
	var roof := {"id": "roof", "label": "Installing roof tiles", "tiles": roof_tiles}
	if entity.get("walls_first", false):
		return [walls, floor_stage, door, roof]
	return [floor_stage, walls, door, roof]

static func add_constructed_wall(s: Dictionary, id: int, cell: Array) -> void:
	if not walkable(s, cell): return
	s.world.building_walls[cell_key(cell)] = id
	s.world.nav_revision += 1

static func building_rect(entity: Dictionary) -> Rect2i:
	var data: Array = entity.get("footprint", [])
	return Rect2i(data[0], data[1], data[2], data[3]) if data.size() == 4 else plot_rect(entity, entity.kind)

static func inside_building(s: Dictionary, cell: Array) -> int:
	for entity in s.entities.values():
		if entity.has("footprint") and building_contains(entity, cell):
			return entity.id
	return 0

static func install_building(s: Dictionary, id: int) -> void:
	var entity: Dictionary = s.entities[str(id)]
	var rect := plot_rect(entity, entity.kind)
	entity.footprint = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	entity.door = entity.cell.duplicate()
	if not s.world.has("building_walls"):
		s.world.building_walls = {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if exterior_wall(entity, [x, y], entity.kind):
				if [x, y] != entity.door:
					s.world.building_walls[cell_key([x, y])] = id
	entity.interior_walls = partition_cells(rect)
	for cell in entity.interior_walls:
		s.world.building_walls[cell_key(cell)] = id
	Fixtures.install(s, entity)
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
	if not s.has("world"):
		return
	s.world.meters_per_cell = METERS_PER_CELL
	if s.world.has("building_walls"):
		return
	s.world.building_walls = {}
	s.world.fixture_cells = {}
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
				var rect := plot_rect(entity, entity.kind).grow(1)
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

static func populate_forest(sim: RefCounted, town: int, desired: int, center: Array, account_growth: bool = true) -> void:
	var s: Dictionary = sim.state
	var occupied: Dictionary = {}
	var count: int = 0
	var plots := reserved_home_plots(center)
	for entity in s.entities.values():
		if entity.get("kind", "") == "tree":
			occupied[cell_key(entity.cell)] = true
			if entity.settlement == town:
				count += 1
	for attempt in range(15000):
		if count >= desired:
			break
		var cell: Array = [center[0] + sim.random_int("forest:%d" % town, -39, 39), center[1] + sim.random_int("forest:%d" % town, -33, 33)]
		if not walkable(s, cell) or in_reserved_plot(plots, cell) or inside_building(s, cell) != 0:
			continue
		# Keep the village expansion plots and road clear while filling surrounding woods.
		if absi(cell[0] - center[0]) < 27 and cell[1] > center[1] - 18 and cell[1] < center[1] + 25:
			continue
		if absi(cell[1] - 48) < 3:
			continue
		var close: bool = false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if occupied.has(cell_key([cell[0] + dx, cell[1] + dy])):
					close = true
		if close:
			continue
		var id := add_entity(sim, "tree", "Alder %03d" % (count + 1) if town == 1 else "Reedbank willow %03d" % (count + 1), cell, town)
		Inventory.create(s, id, 80, {} if account_growth else {"log": 60})
		if account_growth:
			Inventory.produce(s, id, "log", 60)
		occupied[cell_key(cell)] = true
		count += 1

static func populate_dense_groves(sim: RefCounted, town: int, desired: int, center: Array, account_growth: bool = true) -> void:
	var s: Dictionary = sim.state
	var occupied: Dictionary = {}
	var protected_plots := reserved_home_plots(center)
	for entity in s.entities.values():
		if entity.has("cell"): occupied[cell_key(entity.cell)] = true
		if entity.has("footprint"): protected_plots.append(building_rect(entity).grow(1))
		elif entity.get("kind", "") == "construction":
			var site: Dictionary = s.get("construction", {}).get(str(entity.id), {})
			var def: Dictionary = s.get("building_defs", {}).get(site.get("definition", ""), {})
			protected_plots.append(plot_rect(entity, def.get("kind", "home")).grow(1))
	# Small stands create dense canopy beside larger clearings, away from streets
	# and expansion plots. Trees remain real, harvestable inventory owners.
	var centers: Array = [[-34, -25], [34, -25], [-34, 29], [34, 29]]
	var added: int = 0
	for attempt in range(6000):
		if added >= desired: break
		var grove: Array = centers[attempt % centers.size()]
		var cell: Array = [center[0] + grove[0] + sim.random_int("grove:%d" % town, -7, 7), center[1] + grove[1] + sim.random_int("grove:%d" % town, -7, 7)]
		var key := cell_key(cell)
		if occupied.has(key) or not walkable(s, cell): continue
		var protected: bool = false
		for plot in protected_plots:
			if plot.has_point(Vector2i(cell[0], cell[1])): protected = true; break
		if protected: continue
		if absi(cell[0] - center[0]) < 27 and cell[1] > center[1] - 18 and cell[1] < center[1] + 25: continue
		if absi(cell[1] - 48) < 3: continue
		var id := add_entity(sim, "tree", "Woodland tree", cell, town)
		Inventory.create(s, id, 80, {} if account_growth else {"log": 60})
		if account_growth: Inventory.produce(s, id, "log", 60)
		occupied[key] = true
		added += 1

static func upgrade_forests(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	if not s.has("world") or s.world.get("forest_version", 0) >= 3:
		return
	if s.world.get("forest_version", 0) < 2:
		populate_forest(sim, 1, 280, [64, 46])
		if s.get("settlements", {}).has("2"): populate_forest(sim, 2, 140, [180, 46])
	populate_dense_groves(sim, 1, 100, [64, 46])
	if s.get("settlements", {}).has("2"): populate_dense_groves(sim, 2, 60, [180, 46])
	s.world.forest_version = 3

static func upgrade_architecture(s: Dictionary) -> void:
	if not s.has("world") or s.world.get("architecture_version", 0) >= 3:
		return
	# Reflow legacy villages once. IDs, inventory owners and work records survive.
	var slots: Dictionary = {}
	var buildings: Array = []
	for entity in s.entities.values():
		if entity.kind not in ["home", "warehouse", "sawmill", "market", "construction"]: continue
		var town: Dictionary = s.get("settlements", {}).get(str(entity.settlement), {})
		var store_id: int = town.get("warehouse", s.get("warehouse", 0))
		if not s.entities.has(str(store_id)): continue
		var store: Array = s.entities[str(store_id)].cell
		var cell: Array = entity.cell.duplicate()
		if entity.kind == "sawmill": cell = [store[0]+17, store[1]-4]
		elif entity.kind in ["home", "construction"]:
			if entity.id == town.get("home", s.get("home", 0)):
				cell = [store[0]-15,store[1]-4]
			else:
				var slot: int = slots.get(str(entity.settlement),0)
				var offsets: Array = [[-15,12],[0,22],[17,22],[-15,25]]
				var offset: Array = offsets[slot%4]
				cell = [store[0]+offset[0],store[1]+offset[1]+(slot/4)*15]
				slots[str(entity.settlement)] = slot+1
		move_record(s,entity,cell)
		if entity.kind != "construction": buildings.append(entity.id)
	s.world.building_walls = {}
	s.world.fixture_cells = {}
	for id in buildings: install_building(s,id)
	s.player_path = []
	s.world.architecture_version = 3

static func upgrade_house_layouts(s: Dictionary) -> void:
	if not s.has("world") or s.world.get("house_layout_version", 0) >= 2: return
	# In-progress sites keep their original recorded stages and finish unchanged.
	for entity in s.entities.values():
		if entity.get("kind", "") != "home": continue
		for key in s.world.building_walls.keys():
			if s.world.building_walls[key] == entity.id: s.world.building_walls.erase(key)
		entity.layout_shape = "stepped_joined"
		install_building(s, entity.id)
	s.world.house_layout_version = 2
	s.player_path = []

static func upgrade_building_scale(s: Dictionary) -> void:
	if not s.has("world") or s.world.get("building_scale_version", 0) >= 2: return
	var reserved: Dictionary = {}
	for entity in s.entities.values():
		if entity.has("footprint"):
			reserved[entity.id] = building_rect(entity)
		elif entity.kind == "construction":
			var site: Dictionary = s.get("construction", {}).get(str(entity.id), {})
			var definition: Dictionary = s.get("building_defs", {}).get(site.get("definition", ""), {})
			reserved[entity.id] = plot_rect(entity, definition.get("kind", "home"))
	# Grow completed buildings in place, or shift their doorway a few metres
	# east or west. Crowded plots and ongoing construction retain their layout.
	for entity in s.entities.values():
		if not entity.has("footprint") or entity.get("building_scale", 1) >= 2: continue
		for dx in [0, -3, 3, -6, 6]:
			var entrance: Array = [entity.cell[0] + dx, entity.cell[1]]
			var expanded := footprint(entrance, entity.kind)
			if not _fits_expansion(s, expanded, reserved, entity.id): continue
			for key in s.world.building_walls.keys():
				if s.world.building_walls[key] == entity.id: s.world.building_walls.erase(key)
			move_record(s, entity, entrance)
			entity.building_scale = 2
			reserved[entity.id] = expanded
			install_building(s, entity.id)
			break
	s.world.building_scale_version = 2
	s.player_path = []

static func _fits_expansion(s: Dictionary, rect: Rect2i, reserved: Dictionary, id: int) -> bool:
	var limits: Array = s.world.get("bounds", [0, 0, WIDTH, HEIGHT])
	var extent := Rect2i(limits[0], limits[1], limits[2] - limits[0], limits[3] - limits[1])
	if not extent.encloses(rect): return false
	for other in reserved:
		if other != id and rect.grow(1).intersects(reserved[other]): return false
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if s.world.blocked.has(cell_key([x, y])): return false
	return true
