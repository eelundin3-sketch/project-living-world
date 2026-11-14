extends RefCounted
## One authoritative resident/inventory survives every fidelity transition.
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const World = preload("res://sim/world/world_db.gd")

static func transition(s: Dictionary, settlement_id: int, fidelity: String) -> bool:
	if fidelity not in ["detailed", "coarse", "aggregate"] or not s.settlements.has(str(settlement_id)):
		return false
	var town: Dictionary = s.settlements[str(settlement_id)]
	if town.fidelity == fidelity:
		return true
	town.fidelity = fidelity
	for npc in s.residents.values():
		if npc.settlement != settlement_id or not npc.get("migration", {}).is_empty():
			continue
		npc.fidelity = fidelity
		if npc.job != 0:
			s.jobs[str(npc.job)].lease_until = maxi(s.jobs[str(npc.job)].lease_until, s.tick + 150)
	return true

static func update(s: Dictionary) -> void:
	if s.tick % 100 != 0:
		return
	var player: Array = s.entities[str(s.player)].cell
	for town in s.settlements.values():
		var cell: Array = s.entities[str(town.warehouse)].cell
		var distance: int = absi(player[0] - cell[0]) + absi(player[1] - cell[1])
		transition(s, town.id, "detailed" if distance < 50 else ("coarse" if distance < 150 else "aggregate"))
	# Chunk generation is demand driven and seed/version based; views can detach freely.
	var chunk := World.chunk_coord(player[0], player[1])
	for y in range(chunk.y - 2, chunk.y + 3):
		for x in range(chunk.x - 2, chunk.x + 3):
			World.ensure_chunk(s, Vector2i(x, y))

static func summarize(s: Dictionary, town_id: int) -> Dictionary:
	var town: Dictionary = s.settlements[str(town_id)]
	var population: int = 0
	var pools: Dictionary = {"log": 0, "food": 0}
	for npc in s.residents.values():
		if npc.settlement == town_id:
			population += 1
	for entity in s.entities.values():
		if entity.get("settlement", 0) != town_id:
			continue
		if entity.kind == "tree":
			pools.log += Inventory.amount(s, entity.id, "log")
		elif entity.kind == "farm":
			pools.food += Inventory.amount(s, entity.id, "food")
	return {"population": population, "stocks": s.inventories[str(town.warehouse)].items.duplicate(),
		"visible_resources": pools if town.fidelity == "detailed" else {"log": 0, "food": 0},
		"hidden_residual": pools if town.fidelity != "detailed" else {"log": 0, "food": 0}}
