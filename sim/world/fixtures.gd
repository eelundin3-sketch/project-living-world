extends RefCounted
const Placement = preload("res://sim/world/placement.gd")
## Real fixture footprints and their clear approaches. Workshop stations share
## the building inventory, so the storage rack cannot duplicate machine stock.

static func install(s: Dictionary, building: Dictionary) -> void:
	if not s.world.has("fixture_cells"): s.world.fixture_cells = {}
	for key in s.world.fixture_cells.keys():
		if s.world.fixture_cells[key] == building.id: s.world.fixture_cells.erase(key)
	building.fixtures = []
	building.furniture = []
	var x: int = building.cell[0]
	var y: int = building.cell[1]
	var footprint: Array = building.get("footprint", [])
	var expanded: bool = not footprint.is_empty() and building.get("building_scale", 1) >= 2
	match building.kind:
		"market_stall":
			building.fixtures.append(_fixture("stall", [x-1, y, 4, 1], [x, y+1]))
		"construction":
			var offset := 7 if building.get("building_scale", 1) >= 2 else 5
			var stance_y := y - (5 if offset == 7 else 2)
			building.fixtures.append(_fixture("stockpile", [x-1, y-offset, 4, 2], [x+1, stance_y]))
		"sawmill", "bakery", "forge", "office", "warehouse", "market":
			var is_saw: bool = building.kind in ["sawmill", "bakery", "forge"]
			var rack_x: int = x+1 if expanded else x-1
			var rack_y: int = int(footprint[1]) + 2 if expanded else y-5
			var stance: Array = [rack_x+1, rack_y+2] if expanded else [x+1, y-2]
			building.fixtures.append(_fixture({"sawmill": "saw", "bakery": "oven", "forge": "forge", "office": "weapon_rack"}.get(building.kind, "stockpile"), [rack_x, rack_y, 4, 2], stance))
			if is_saw and expanded:
				var storage_y: int = int(footprint[1]) + 6
				building.fixtures.append(_fixture("workshop_storage", [rack_x+1, storage_y, 4, 2], [rack_x+2, storage_y+2]))
	if expanded:
		var left: int = footprint[0]
		var top: int = footprint[1]
		var right: int = left + footprint[2]
		match building.kind:
			"home":
				building.furniture = [
					{"kind": "table", "rect": [left+1, top+2, 3, 2], "rot": 2},
					{"kind": "chair", "rect": [left+1, top+4, 1, 1], "rot": 0},
					{"kind": "lamp", "rect": [left+1, top+1, 1, 1], "rot": 2},
					{"kind": "chest", "rect": [right-3, top+4, 2, 1], "rot": 2},
					{"kind": "lamp", "rect": [right-2, y-5, 1, 1], "rot": 2},
				]
			"warehouse", "market":
				building.furniture = [
					{"kind": "shelf", "rect": [left+1, top+1, 3, 2]},
					{"kind": "shelf", "rect": [left+1, top+4, 3, 2]},
				]
			"office":
				building.furniture = [
					{"kind": "table", "rect": [left+1, top+5, 3, 2]},
					{"kind": "chair", "rect": [left+1, top+7, 1, 1]},
					{"kind": "lamp", "rect": [left+1, top+1, 1, 1]},
					{"kind": "chest", "rect": [right-4, top+2, 2, 1]},
				]
			"sawmill", "bakery", "forge":
				building.furniture = [
					{"kind": "shelf", "rect": [left+1, top+1, 3, 2]},
					{"kind": "chest", "rect": [left+1, top+4, 2, 1]},
				]
	for item in building.fixtures: _occupy(s, item.rect, building.id)
	for item in building.furniture: _occupy(s, item.rect, building.id)
	if expanded and building.kind == "home":
		# Beds go in last so they can pick the best wall-hugging spot, head against the wall.
		var beds: int = clampi(_bed_count(s, building), 1, 6)
		for index in range(beds):
			var found: Dictionary = Placement.best_placement(s, building, "bed", [int(footprint[0]) + int(footprint[2]) - 4, y - 3])
			if found.is_empty(): break
			building.furniture.append({"kind": "bed", "rect": found.rect, "rot": found.rot})
			_occupy(s, found.rect, building.id)
	for actor in s.entities.values():
		if actor.kind not in ["resident", "player", "caravan", "raider"]: continue
		var key := "%d,%d" % [actor.cell[0], actor.cell[1]]
		if s.world.fixture_cells.get(key, 0) == building.id:
			actor.cell = interaction_cell(s, building.id).duplicate()

static func _bed_count(s: Dictionary, building: Dictionary) -> int:
	# Settlements do not exist yet when the first lodge is built, so identify lodges by name.
	return 6 if "lodge" in String(building.get("name", "")).to_lower() else 3

static func _fixture(kind: String, rect: Array, stance: Array) -> Dictionary:
	return {"kind": kind, "rect": rect, "stance": stance}

static func _occupy(s: Dictionary, rect: Array, owner: int) -> void:
	for y in range(rect[1], rect[1]+rect[3]):
		for x in range(rect[0], rect[0]+rect[2]):
			s.world.fixture_cells["%d,%d" % [x, y]] = owner

static func interaction_cell(s: Dictionary, id: int, index: int = 0) -> Array:
	var entity: Dictionary = s.entities[str(id)]
	var fixtures: Array = entity.get("fixtures", [])
	return fixtures[index].stance if index < fixtures.size() else entity.cell

static func stock_station(s: Dictionary, id: int) -> int:
	var fixtures: Array = s.entities[str(id)].get("fixtures", [])
	return 1 if fixtures.size() > 1 and fixtures[1].kind == "workshop_storage" else 0

static func upgrade(s: Dictionary) -> void:
	if not s.has("world") or s.world.get("fixture_version", 0) >= 2: return
	s.world.fixture_cells = {}
	for entity in s.entities.values():
		if entity.kind == "construction" and not entity.get("fixtures", []).is_empty():
			for item in entity.fixtures: _occupy(s, item.rect, entity.id)
		elif entity.has("footprint") or entity.kind in ["construction", "market_stall"]:
			install(s, entity)
	s.world.fixture_version = 2
	s.world.nav_revision += 1
	s.player_path = []
