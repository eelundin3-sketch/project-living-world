extends RefCounted
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Jobs = preload("res://sim/jobs/job_board.gd")
const Professions = preload("res://sim/settlement/professions.gd")

static func initialize(s: Dictionary) -> void:
	s.factions = {"1": {"id": 1, "name": "Alder Council", "treasury": s.warehouse}, "2": {"id": 2, "name": "Reedbank Compact", "treasury": s.settlements["2"].warehouse}}
	if s.settlements.has("3"): s.factions["3"] = {"id": 3, "name": "Dustvale Compact", "treasury": s.settlements["3"].warehouse}
	s.treaty = {"open_trade": true, "since": s.tick}
	s.households = {}
	for town in s.settlements.values():
		var members: Array = []
		for npc in s.residents.values():
			if npc.settlement == town.id:
				members.append(npc.id)
		for index in range(0, members.size(), 4):
			var key := "%d:%d" % [town.id, index / 4]
			s.households[key] = {"settlement": town.id, "members": members.slice(index, index + 4), "home": town.home}
			for id in s.households[key].members:
				s.residents[str(id)].household = key

static func remember(s: Dictionary, npc_id: int, kind: String, subject: int, text: String, trust_delta: int = 0) -> void:
	if not s.residents.has(str(npc_id)) or not s.entities.has(str(subject)):
		return
	var npc: Dictionary = s.residents[str(npc_id)]
	npc.memories.append({"tick": s.tick, "kind": kind, "subject": subject, "text": text})
	while npc.memories.size() > 16:
		npc.memories.pop_front()
	var relation: Dictionary = npc.relations.get(str(subject), {"trust": 0, "last_tick": s.tick})
	relation.trust = clampi(relation.trust + trust_delta, -100, 100)
	relation.last_tick = s.tick
	npc.relations[str(subject)] = relation
	if npc.relations.size() > 32:
		var oldest: String = npc.relations.keys()[0]
		for key in npc.relations:
			if npc.relations[key].last_tick < npc.relations[oldest].last_tick:
				oldest = key
		npc.relations.erase(oldest)

static func helpful_trade(sim: RefCounted, town_id: int, item: String) -> void:
	for npc in sim.state.residents.values():
		if npc.settlement == town_id:
			remember(sim.state, npc.id, "helpful_trade", sim.state.player, "The traveller delivered " + item + " to our town.", 5)
			break

static func migrate(sim: RefCounted, npc_id: int, destination: int) -> bool:
	var s: Dictionary = sim.state
	if not s.residents.has(str(npc_id)) or not s.settlements.has(str(destination)):
		return false
	var npc: Dictionary = s.residents[str(npc_id)]
	if npc.get("migration", {}).size() > 0 or npc.settlement == destination or npc.occupation in Professions.WORKSHOP_TRADES or npc.occupation in ["Builder", "Sheriff", "Child"]:
		return false
	if npc.job != 0:
		Jobs.release(s, npc.job, "MIGRATING")
	npc.goal = ""
	npc.path = []
	npc.fidelity = "coarse"
	var event_id: int = sim.schedule("migration_arrival", s.tick + 600, {"npc": npc_id, "destination": destination})
	npc.migration = {"event": event_id, "destination": destination}
	npc.status = "Migrating to " + s.settlements[str(destination)].name
	sim.record(s.entities[str(npc_id)].name + " is " + npc.status.to_lower())
	return true

static func arrive(sim: RefCounted, event: Dictionary) -> void:
	var s: Dictionary = sim.state
	var key := str(event.payload.npc)
	if not s.residents.has(key):
		return
	var npc: Dictionary = s.residents[key]
	if npc.get("migration", {}).get("event", 0) != event.id:
		return
	var destination: int = event.payload.destination
	npc.settlement = destination
	npc.fidelity = s.settlements[str(destination)].fidelity
	npc.migration = {}
	s.entities[key].settlement = destination
	s.entities[key].cell = s.entities[str(s.settlements[str(destination)].home)].cell.duplicate()
	for household in s.households.values():
		household.members.erase(npc.id)
	var house_key := "migrant:" + key
	s.households[house_key] = {"settlement": destination, "members": [npc.id], "home": s.settlements[str(destination)].home}
	npc.household = house_key
	remember(s, npc.id, "migration", s.player, "I made a new home in " + s.settlements[str(destination)].name)
	sim.record(s.entities[key].name + " arrived in " + s.settlements[str(destination)].name)

static func update(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	if s.tick % 600 == 0:
		for town in s.settlements.values():
			var policy: String = "Food first" if Inventory.amount(s, town.warehouse, "food") < 60 else ("Build homes" if town.population > town.housing else "Balanced")
			if policy != town.policy:
				town.policy = policy
				sim.record(town.name + " adopts policy: " + policy)
	if s.tick % 14400 == 0:
		for town in s.settlements.values():
			if town.population <= town.housing:
				continue
			for other in s.settlements.values():
				if other.id == town.id or other.population >= other.housing:
					continue
				for npc in s.residents.values():
					if npc.settlement == town.id and migrate(sim, npc.id, other.id):
						break
