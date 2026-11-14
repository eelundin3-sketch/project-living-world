extends RefCounted
const World = preload("res://sim/world/world_db.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Work = preload("res://sim/production/recipe_system.gd")

static func initialize(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	s.building_defs = JSON.parse_string(FileAccess.get_file_as_string("res://content/buildings/core.json")).buildings
	s.settlements = {"1": {"id": 1, "name": "Alder Hollow", "warehouse": s.warehouse, "home": s.home,
		"housing": 8, "population": s.residents.size(), "policy": "Balanced", "demand": {}, "fidelity": "detailed", "faction": 1}}
	s.construction = {}
	s.completed_buildings = 0

static func suitable(s: Dictionary, cell: Array, kind: String = "home") -> bool:
	var rect := World.footprint(cell, kind).grow(1)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not World.walkable(s, [x, y]):
				return false
	for entity in s.entities.values():
		if not entity.has("cell") or entity.kind in ["resident", "player", "caravan"]:
			continue
		if entity.has("footprint") and rect.intersects(World.building_rect(entity)):
			return false
		if entity.kind == "construction" and rect.intersects(World.footprint(entity.cell, "home")):
			return false
		if rect.has_point(Vector2i(entity.cell[0], entity.cell[1])):
			return false
	return true

static func plan(sim: RefCounted, settlement_id: int, definition: String) -> int:
	var s: Dictionary = sim.state
	if not s.building_defs.has(definition):
		return 0
	var town: Dictionary = s.settlements[str(settlement_id)]
	var home: Array = s.entities[str(town.home)].cell
	var location: Array = []
	for radius in range(9, 45, 3):
		for direction in [[1, 0], [0, 1], [-1, 0], [0, -1], [1, 1], [-1, -1]]:
			var cell: Array = [home[0] + direction[0] * radius, home[1] + direction[1] * radius]
			if suitable(s, cell, s.building_defs[definition].kind):
				location = cell
				break
		if not location.is_empty():
			break
	if location.is_empty():
		sim.record(town.name + ": no buildable construction site")
		return 0
	var def: Dictionary = s.building_defs[definition]
	var id := World.add_entity(sim, "construction", "Planned " + def.kind, location, settlement_id)
	Inventory.create(s, id, def.planks)
	s.construction[str(id)] = {"id": id, "settlement": settlement_id, "definition": definition,
		"cost": def.planks, "work_ticks": def.work_ticks, "progress": 0, "worker": 0, "status": "Waiting for planks", "done": false}
	sim.record(town.name + " plans a " + def.kind + "; needs %d planks" % def.planks)
	return id

static func update(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	if s.tick % 600 == 0:
		for town in s.settlements.values():
			town.population = 0
			for npc in s.residents.values():
				if npc.settlement == town.id:
					town.population += 1
			town.demand = {"housing": maxi(0, town.population - town.housing), "food": maxi(0, 100 - Inventory.amount(s, town.warehouse, "food"))}
			var active: bool = false
			for site in s.construction.values():
				if site.settlement == town.id and not site.done:
					active = true
			if town.demand.housing > 0 and not active:
				plan(sim, town.id, "core:building/home")
	if s.tick % 2 != 0:
		return
	for site in s.construction.values():
		if site.done:
			continue
		if not s.residents.has(str(site.worker)):
			site.worker = 0
			for npc in s.residents.values():
				if npc.settlement == site.settlement and npc.occupation == "Gatherer" and npc.get("migration", {}).is_empty() and npc.job == 0:
					npc.occupation = "Builder"
					site.worker = npc.id
					break
		if site.worker == 0:
			site.status = "Waiting for available builder"
			continue
		var npc: Dictionary = s.residents[str(site.worker)]
		if not npc.goal.is_empty() or npc.hunger >= 60 or npc.fatigue >= 75:
			site.status = "Builder attending to needs"
			continue
		var store: int = s.settlements[str(site.settlement)].warehouse
		var delivered: int = Inventory.amount(s, site.id, "plank")
		var carried: int = Inventory.amount(s, npc.id, "plank")
		if delivered < site.cost:
			if carried == 0:
				if Work.work_at(s, npc, store):
					var quantity: int = mini(site.cost - delivered, mini(10, Inventory.amount(s, store, "plank")))
					if quantity > 0:
						Inventory.transfer(s, store, npc.id, "plank", quantity)
					else:
						site.status = "Waiting for planks from sawmill"
			else:
				npc.status = "Hauling planks to construction"
				if Work.work_at(s, npc, site.id):
					Inventory.transfer(s, npc.id, site.id, "plank", carried)
			continue
		if not Work.work_at(s, npc, site.id):
			continue
		site.status = "Building"
		npc.status = "Building a home"
		site.progress += 2
		if site.progress >= site.work_ticks:
			if not Inventory.consume(s, site.id, "plank", site.cost):
				site.status = "Missing construction materials"
				continue
			var def: Dictionary = s.building_defs[site.definition]
			site.done = true
			site.status = "Completed"
			s.entities[str(site.id)].kind = def.kind
			s.entities[str(site.id)].name = "New " + def.kind
			World.install_building(s, site.id)
			s.settlements[str(site.settlement)].housing += int(def.get("housing", 0))
			if def.has("capacity"):
				s.inventories[str(site.id)].capacity = def.capacity
			npc.occupation = "Gatherer"
			s.completed_buildings += 1
			sim.record("Finished %s using %d planks and worker time" % [def.kind, site.cost])
