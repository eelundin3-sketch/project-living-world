extends RefCounted
const World = preload("res://sim/world/world_db.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Work = preload("res://sim/production/recipe_system.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const Households = preload("res://sim/entities/households.gd")
const Chests = preload("res://sim/entities/chests.gd")
const Brawl = preload("res://sim/combat/brawl.gd")
const Housing = preload("res://sim/settlement/housing.gd")
const WORK_PER_TILE: int = 16

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
		if entity.kind == "construction":
			var site: Dictionary = s.construction.get(str(entity.id), {})
			var definition: Dictionary = s.building_defs.get(site.get("definition", ""), {})
			if rect.intersects(World.plot_rect(entity, definition.get("kind", "home"))): return false
		if rect.has_point(Vector2i(entity.cell[0], entity.cell[1])):
			return false
	return true

static func plan(sim: RefCounted, settlement_id: int, definition: String) -> int:
	var s: Dictionary = sim.state
	if not s.building_defs.has(definition):
		return 0
	var town: Dictionary = s.settlements[str(settlement_id)]
	var location: Array = []
	var house: Dictionary = {}
	var door_side := 2
	if s.building_defs[definition].kind == "home" and s.has("households"):
		# Build for whoever needs it most: the biggest household still in the lodge or overcrowded.
		var people := 2
		var best := -1
		for household in s.households.values():
			if household.settlement != settlement_id: continue
			var squeezed: bool = household.home == town.home or Households.members_of(s, household.home) > Households.capacity(s, household.home)
			if squeezed and household.members.size() > best:
				best = household.members.size()
				people = household.members.size()
		house = Housing.choose(sim, people, settlement_id)
		var site := Housing.find_site(sim, settlement_id, house)
		location = site.get("door", [])
		door_side = int(site.get("side", 2))
		if location.is_empty():
			sim.record(town.name + ": no buildable construction site")
			return 0
	# Street-facing plots preserve the common square and the workshop yard.
	var store_cell: Array = s.entities[str(town.warehouse)].cell
	for offset in ([] if not house.is_empty() else World.VILLAGE_HOME_PLOTS + [Vector2i(18, 19), Vector2i(-18, 34), Vector2i(18, 34)]):
		var plot: Array = [store_cell[0] + offset.x, store_cell[1] + offset.y]
		if suitable(s, plot, s.building_defs[definition].kind):
			location = plot
			break
	if location.is_empty() and house.is_empty():
		# Find the nearest usable courtyard before sending a builder far out
		# along one of the original six search rays.
		location = _infill_plot(s, store_cell, s.building_defs[definition].kind)
	if location.is_empty():
		sim.record(town.name + ": no buildable construction site")
		return 0
	var def: Dictionary = s.building_defs[definition]
	var id := World.add_entity(sim, "construction", "Planned " + (String(house.name).to_lower() if not house.is_empty() else def.kind), location, settlement_id, Housing.placed_fields(house, location, door_side) if not house.is_empty() else {})
	Inventory.create(s, id, def.planks)
	s.entities[str(id)].walls_first = true
	if def.kind == "home" and house.is_empty(): s.entities[str(id)].layout_shape = "stepped_joined"
	var stages := World.construction_stages(s.entities[str(id)], def.kind)
	var total_units: int = 0
	var built_tiles: Dictionary = {}
	for stage in stages:
		total_units += stage.tiles.size()
		built_tiles[stage.id] = []
		s.construction[str(id)] = {"id": id, "settlement": settlement_id, "definition": definition,
		"cost": def.planks, "work_ticks": total_units * WORK_PER_TILE, "progress": 0, "total_units": total_units,
		"stages": stages, "stage_index": 0, "stage_progress": 0, "tile_work": 0,
		"built_tiles": built_tiles, "worker": 0, "status": "Waiting for planks", "done": false}
	sim.record(town.name + " marks a %s plot; needs %d planks for a staged build" % [def.kind, def.planks])
	return id

static func _infill_plot(s: Dictionary, center: Array, kind: String) -> Array:
	for radius in range(12, 55):
		for offset in range(-radius, radius + 1):
			for direction in [Vector2i(offset, radius), Vector2i(radius, offset), Vector2i(-radius, offset), Vector2i(offset, -radius)]:
				var cell: Array = [center[0] + direction.x, center[1] + direction.y]
				var rect := World.footprint(cell, kind).grow(1)
				if rect.intersects(Rect2i(35, 47, 181, 3)): continue
				if suitable(s, cell, kind): return cell
	return []

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
		if not site.has("stages"):
			var planned_entity: Dictionary = s.entities[str(site.id)]
			var building_kind: String = s.building_defs[site.definition].kind
			site.stages = World.construction_stages(planned_entity, building_kind)
			site.stage_index = 0
			site.stage_progress = 0
			site.tile_work = 0
			site.built_tiles = {}
			site.total_units = 0
			for stage in site.stages:
				site.total_units += stage.tiles.size()
				site.built_tiles[stage.id] = []
			site.work_ticks = site.total_units * WORK_PER_TILE
		if not s.residents.has(str(site.worker)) or s.residents[str(site.worker)].health <= 0:
			site.worker = 0
			site.build_phase = "fetch"
			site.tile_work = 0
			# Builders come from whoever has no fixed workshop: idle gatherers first, then woodsmen.
			for wanted in ["Builder", "Gatherer", "Woodsman"]:
				for npc in s.residents.values():
					if site.worker == 0 and npc.settlement == site.settlement and npc.occupation == wanted and npc.get("migration", {}).is_empty() and npc.job == 0 and npc.health > 0:
						npc.prior_trade = "Gatherer" if wanted == "Builder" else wanted
						npc.occupation = "Builder"
						site.worker = npc.id
				if site.worker != 0: break
		if site.worker == 0:
			site.status = "Waiting for available builder"
			continue
		var npc: Dictionary = s.residents[str(site.worker)]
		if npc.health <= 0 or s.get("local_combat", {}).get("fighters", {}).has(str(npc.id)): continue
		if not npc.goal.is_empty() or npc.hunger >= 60 or npc.fatigue >= 75 or Brawl.busy(s, npc):
			site.status = "Builder attending to needs"
			continue
		if npc.get("work_pause_until", 0) > s.tick:
			continue
		var store: int = s.settlements[str(site.settlement)].warehouse
		# Include already-used material in the received total, or consuming each
		# placed tile would make the site mistakenly request its full cost again.
		var delivered: int = Inventory.amount(s, site.id, "plank") + int(site.get("planks_spent", 0))
		var carried: int = Inventory.amount(s, npc.id, "plank")
		var phase: String = site.get("build_phase", "fetch")
		if delivered + (carried if phase != "fetch" else 0) < site.cost:
			if carried == 0:
				if Work.work_at(s, npc, store):
					var quantity: int = mini(site.cost - delivered, mini(10, Inventory.amount(s, store, "plank")))
					if quantity > 0:
						Inventory.transfer(s, store, npc.id, "plank", quantity)
						npc.work_pause_until = s.tick + 6
						npc.status = "Picking up planks"
					else:
						site.status = "Waiting for planks from sawmill"
			else:
				npc.status = "Hauling planks to construction"
				if Work.work_at(s, npc, site.id):
					Inventory.transfer(s, npc.id, site.id, "plank", carried)
					npc.work_pause_until = s.tick + 6
					npc.status = "Putting down planks"
			continue
		if phase == "return":
			if not Work.work_at(s, npc, site.id):
				npc.status = "Returning to construction supplies"
				continue
			if carried > 0:
				var returned := Inventory.transfer(s, npc.id, site.id, "plank", carried)
				if not returned.ok:
					site.status = "Waiting for space in the supply pile"
					continue
				npc.status = "Putting down planks"
				npc.work_pause_until = s.tick + 6
			site.build_phase = "fetch"
			continue
		var stage_index: int = site.stage_index
		if stage_index >= site.stages.size():
			_finish(sim, site, npc)
			continue
		var stage: Dictionary = site.stages[stage_index]
		var tile_index: int = site.stage_progress
		if tile_index >= stage.tiles.size():
			site.stage_index += 1
			site.stage_progress = 0
			continue
		var next_tile: Array = stage.tiles[tile_index]
		if site.get("build_worker", npc.id) != npc.id:
			phase = "fetch"
			site.build_phase = phase
			site.tile_work = 0
		site.build_worker = npc.id
		if phase == "fetch":
			if not Work.work_at(s, npc, site.id):
				npc.status = "Returning to construction supplies"
				continue
			if carried == 0:
				var pickup := Inventory.transfer(s, site.id, npc.id, "plank", 1)
				if not pickup.ok:
					site.status = "Waiting for construction material"
					continue
			site.build_phase = "travel"
			npc.work_pause_until = s.tick + 6
			npc.status = "Picking up planks"
			continue
		if phase == "travel":
			if carried == 0:
				site.build_phase = "fetch"
				continue
			if not _work_at_tile(s, npc, site, next_tile):
				npc.status = "Carrying planks to build site"
				continue
			site.build_phase = "build"
			npc.work_pause_until = s.tick + 4
			npc.status = "Putting down planks at work"
			continue
		if phase != "build":
			site.build_phase = "fetch"
			continue
		if not _work_at_tile(s, npc, site, next_tile):
			site.build_phase = "travel"
			continue
		if stage.id == "walls" and _actor_occupies(s, next_tile):
			site.status = "Waiting for the wall space to clear"
			continue
		site.status = "%s · tile %d/%d" % [stage.label, tile_index + 1, stage.tiles.size()]
		npc.status = "Building: " + stage.label.to_lower()
		site.tile_work += 2
		if site.tile_work < WORK_PER_TILE:
			continue
		var completed_units: int = site.progress + 1
		var spend_target: int = site.cost if completed_units >= site.total_units else int(floor(float(site.cost * completed_units) / site.total_units))
		var spend_now: int = spend_target - int(site.get("planks_spent", 0))
		if spend_now > 0 and not Inventory.consume(s, npc.id, "plank", spend_now):
			site.status = "Missing staged planks"
			continue
		site.planks_spent = spend_target
		site.built_tiles[stage.id].append(next_tile.duplicate())
		if stage.id == "walls": World.add_constructed_wall(s, site.id, next_tile)
		if stage.id == "door": s.entities[str(site.id)].door_built = true
		site.progress = completed_units
		site.stage_progress += 1
		site.tile_work = 0
		site.build_phase = "return"
		npc.status = "Returning to construction supplies"
		if site.stage_progress >= stage.tiles.size():
			site.stage_index += 1
			site.stage_progress = 0


static func current_tile(site: Dictionary) -> Dictionary:
	var stages: Array = site.get("stages", [])
	var stage_index: int = site.get("stage_index", 0)
	if stage_index >= stages.size(): return {}
	var stage: Dictionary = stages[stage_index]
	var tile_index: int = site.get("stage_progress", 0)
	if tile_index >= stage.tiles.size(): return {}
	return {"cell": stage.tiles[tile_index], "kind": stage.id,
		"progress": clampf(float(site.get("tile_work", 0)) / WORK_PER_TILE, 0.0, 1.0)}

static func _work_at_tile(s: Dictionary, npc: Dictionary, site: Dictionary, tile: Array) -> bool:
	var actor: Dictionary = s.entities[str(npc.id)]
	var current: Array = actor.cell
	if absi(current[0] - tile[0]) + absi(current[1] - tile[1]) == 1:
		site.work_stance = current.duplicate()
		return true
	if site.get("tile_path_target", []) != tile or site.get("tile_path_revision", -1) != s.world.nav_revision or site.get("tile_path_from", []) != current:
		var best: Array = []
		var found: bool = false
		for offset in [[0, -1], [-1, 0], [1, 0], [0, 1]]:
			var stance: Array = [tile[0] + offset[0], tile[1] + offset[1]]
			if not World.walkable(s, stance): continue
			var route := Nav.request_path(s, current, stance)
			if route.ok and (not found or route.path.size() < best.size()):
				best = route.path
				found = true
				site.work_stance = stance
		if not found:
			site.status = "Waiting for a reachable position beside the build tile"
			return false
		site.tile_path = best
		site.tile_path_target = tile.duplicate()
		site.tile_path_revision = s.world.nav_revision
	if not site.get("tile_path", []).is_empty():
		actor.cell = site.tile_path.pop_front()
	site.tile_path_from = actor.cell.duplicate()
	return false

static func _actor_occupies(s: Dictionary, cell: Array) -> bool:
	for entity in s.entities.values():
		if entity.get("kind", "") in ["resident", "player", "caravan"] and entity.get("cell", []) == cell:
			return true
	return false

static func _finish(sim: RefCounted, site: Dictionary, npc: Dictionary) -> void:
	var s: Dictionary = sim.state
	if site.done: return
	var def: Dictionary = s.building_defs[site.definition]
	var entity: Dictionary = s.entities[str(site.id)]
	site.done = true
	site.status = "Completed"
	entity.kind = def.kind
	entity.name = "New " + (String(Housing.type_by_id(str(entity.house_type)).get("name", def.kind)).to_lower() if entity.has("house_type") else def.kind)
	World.install_building(s, site.id)
	s.settlements[str(site.settlement)].housing += int(entity.get("house_beds", def.get("housing", 0)))
	if def.has("capacity"): s.inventories[str(site.id)].capacity = def.capacity
	npc.occupation = npc.get("prior_trade", "Gatherer")
	s.completed_buildings += 1
	if def.kind == "home" and s.has("households"):
		Households.on_home_built(sim, site.id)
		Chests.ensure(sim, entity)
	sim.record("Finished %s one tile at a time; used %d planks" % [def.kind, site.cost])
