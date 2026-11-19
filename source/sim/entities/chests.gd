extends RefCounted
## Chests: each chest piece of furniture is backed by a real entity with an inventory, so what
## is inside can be seen, taken, and counted in the conservation checks.
const World = preload("res://sim/world/world_db.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Outfits = preload("res://sim/entities/outfits.gd")

static func ensure_all(sim: RefCounted) -> void:
	var buildings: Array = []
	var unlinked := false
	for entity in sim.state.entities.values():
		if not entity.has("furniture"): continue
		buildings.append(entity)
		for item in entity.furniture:
			if item.kind == "chest" and not item.has("chest_id"): unlinked = true
	if not unlinked: return
	# A layout upgrade rebuilds a building's furniture and drops the links to its chests. Those
	# chests (and what is in them) still exist: hand them back to the new chest pieces, in id
	# order, instead of making new ones, so loading the same save twice changes nothing.
	var linked: Dictionary = {}
	for building in buildings:
		for item in building.furniture:
			if item.has("chest_id"): linked[int(item.chest_id)] = true
	var spare: Dictionary = {}
	for entity in sim.state.entities.values():
		if entity.kind == "chest" and entity.has("building") and not linked.has(int(entity.id)):
			if not spare.has(int(entity.building)): spare[int(entity.building)] = []
			spare[int(entity.building)].append(int(entity.id))
	for list in spare.values(): list.sort()
	for building in buildings: ensure(sim, building, spare.get(int(building.id), []))

static func ensure(sim: RefCounted, building: Dictionary, spare: Array = []) -> void:
	var s: Dictionary = sim.state
	var index := 0
	for item in building.get("furniture", []):
		index += 1
		if item.kind != "chest" or item.has("chest_id"): continue
		var rect: Array = item.rect
		if not spare.is_empty():
			var kept: Dictionary = s.entities[str(spare.pop_front())]
			World.move_record(s, kept, [rect[0], rect[1]])
			kept.rock_rect = rect.duplicate()
			item.chest_id = int(kept.id)
			continue
		var id: int = World.add_entity(sim, "chest", "Chest", [rect[0], rect[1]], int(building.get("settlement", 0)))
		var chest: Dictionary = s.entities[str(id)]
		chest.rock_rect = rect.duplicate()   # reach is measured from the whole chest, not one cell
		chest.pick_radius = 14.0
		chest.building = building.id
		item.chest_id = id
		Inventory.create(s, id, 40)
		for stored in contents(building, index):
			Inventory.produce(s, id, stored[0], stored[1])

## A few ordinary things, varying by building and by chest.
static func contents(building: Dictionary, index: int) -> Array:
	var seed_value: int = int(building.id) * 7 + index * 3
	match building.get("kind", ""):
		"home":
			var list: Array = [["food", 1 + seed_value % 3], [Outfits.key("shirt", seed_value % 4), 1]]
			if seed_value % 2 == 0: list.append(["bandage", 1])
			if seed_value % 3 == 0: list.append([Outfits.key("hat", seed_value % 3), 1])
			if seed_value % 4 == 1: list.append([Outfits.key("boots", seed_value % 2), 1])
			return list
		"office": return [["shell", 6], ["bandage", 2], [Outfits.key("vest", 2), 1]]
		"bakery": return [["rye", 4], [Outfits.key("hat", 0), 1]]
		"sawmill": return [["plank", 3], [Outfits.key("pants", 2), 1]]
		"forge": return [["tool", 1], ["ore", 2], [Outfits.key("boots", 1), 1]]
	return [["food", 1]]
