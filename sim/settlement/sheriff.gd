extends RefCounted
## Sheriff's offices, their weapon racks and the sheriff's patrol rounds.
const World = preload("res://sim/world/world_db.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const OFFICE_CELLS: Dictionary = {1: [29, 42], 2: [325, 42], 3: [116, 246]}
const RACK_SHOTGUNS := 2
const RACK_SHELLS := 30

## One office per settlement; its rack is the office inventory (shotguns and shells).
static func install(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	if not s.has("settlements"): return
	for town in s.settlements.values():
		if town.has("office") or not OFFICE_CELLS.has(town.id): continue
		var id := World.add_entity(sim, "office", "%s sheriff's office" % town.name, OFFICE_CELLS[town.id], town.id)
		Inventory.create(s, id, 200)
		Inventory.produce(s, id, "shotgun", RACK_SHOTGUNS)
		Inventory.produce(s, id, "shell", RACK_SHELLS)
		town.office = id

## Every sheriff wears the badge and goes by "Sheriff <surname>", so the law is easy to spot.
static func dress(s: Dictionary) -> void:
	var Outfits = load("res://sim/entities/outfits.gd")
	var keys: Array = s.get("residents", {}).keys()
	keys.sort()
	for key in keys:
		var npc: Dictionary = s.residents[key]
		if npc.occupation != "Sheriff" or npc.health <= 0: continue
		var entity: Dictionary = s.entities[str(npc.id)]
		if not String(entity.name).begins_with("Sheriff "):
			var parts: PackedStringArray = String(entity.name).split(" ")
			entity.name = "Sheriff " + parts[parts.size() - 1]
			load("res://sim/entities/names.gd").used(s)[entity.name] = true   # so reloads see the same pool
		if not npc.get("sheriff_dressed", false):
			Outfits.dress(s, npc.id, Outfits.SHERIFF)
			npc.sheriff_dressed = true

static func patrol_points(s: Dictionary, npc: Dictionary) -> Array:
	var town: Dictionary = s.settlements[str(npc.settlement)]
	var store: Array = s.entities[str(town.warehouse)].cell
	var points: Array = [[store[0], store[1] + 4], [store[0] - 14, store[1] + 4], [store[0] + 14, store[1] + 4], [store[0], store[1] + 10]]
	if town.has("office") and s.entities.has(str(town.office)): points.push_front(s.entities[str(town.office)].cell.duplicate())
	return points

## Gives an idle sheriff the next patrol leg. Returns true when a goal was set.
static func next_patrol(s: Dictionary, npc: Dictionary) -> bool:
	var points: Array = patrol_points(s, npc)
	var index: int = (int(npc.get("patrol_index", -1)) + 1) % points.size()
	for attempt in range(points.size()):
		var route := Nav.request_path(s, s.entities[str(npc.id)].cell, points[index])
		if route.ok:
			npc.path = route.path
			npc.nav_revision = s.world.nav_revision
			npc.goal = "patrol"
			npc.patrol_index = index
			npc.status = "Patrolling the square"
			return true
		index = (index + 1) % points.size()
	npc.retry_at = s.tick + 100
	return false

## Sheriffs answer threats first, so they take the ranged defender slot.
static func defender_order(s: Dictionary) -> Array:
	var sheriffs: Array = []
	var others: Array = []
	for npc in s.residents.values():
		(sheriffs if npc.occupation == "Sheriff" else others).append(npc)
	return sheriffs + others
