extends RefCounted
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Work = preload("res://sim/production/recipe_system.gd")
const Society = preload("res://sim/factions/society.gd")

static func initialize(s: Dictionary) -> void:
	s.conflicts = []
	for caravan in s.caravans.values():
		caravan.health = 100
		caravan.last_conflict = 0

static func resolve(sim: RefCounted, event: Dictionary) -> void:
	var s: Dictionary = sim.state
	var actor_id: int = int(event.payload.get("actor", 0))
	var key := str(actor_id)
	var actor: Dictionary = s.caravans.get(key, s.residents.get(key, {}))
	if actor.is_empty() or actor.get("last_conflict", 0) >= event.id:
		return
	if event.payload.get("fidelity", actor.fidelity) != actor.fidelity:
		return
	actor.last_conflict = event.id
	var threat: int = clampi(int(event.payload.get("threat", 30)), 0, 100)
	var guards: int = s.routes["1"].guards
	var roll: int = sim.random_int("conflict:%d" % event.id, 0, 99)
	var loss: int = 0
	if roll < maxi(0, threat - guards * 15):
		var inventory: Dictionary = s.inventories[key].items.duplicate()
		for item in inventory:
			var quantity: int = mini(2, inventory[item])
			if Inventory.consume(s, actor_id, item, quantity):
				loss += quantity
		actor.health = maxi(1, actor.get("health", 100) - 10)
	var result := {"id": event.id, "actor": actor_id, "tick": s.tick, "loss": loss, "fidelity": actor.fidelity}
	s.conflicts.append(result)
	if s.conflicts.size() > 64:
		s.conflicts.pop_front()
	sim.record("Road incident: %d goods lost; %d guards reduced the danger" % [loss, guards])
	if s.residents.has(key):
		Society.remember(s, actor_id, "danger", s.player, "I encountered danger on the road.")

static func update(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	if s.tick % 100 != 0:
		return
	var route: Dictionary = s.routes["1"]
	var guards: int = 0
	for npc in s.residents.values():
		if npc.health <= 0 or s.tick < int(npc.get("impact_until", 0)) or s.get("local_combat", {}).get("fighters", {}).has(str(npc.id)): continue
		if npc.occupation == "Guard":
			if npc.goal.is_empty() and npc.hunger < 60 and npc.fatigue < 75:
				guards += 1
				npc.status = "Patrolling Moss Road"
				Work.work_at(s, npc, s.settlements[str(npc.settlement)].warehouse)
	if route.risk >= 30 and guards < 2:
		for npc in s.residents.values():
			if npc.occupation == "Gatherer" and npc.get("migration", {}).is_empty() and npc.job == 0 and npc.goal.is_empty():
				npc.occupation = "Guard"
				guards += 1
				Society.remember(s, npc.id, "duty", s.player, "The council assigned me to protect the road.")
				if guards >= 2:
					break
	route.guards = guards
