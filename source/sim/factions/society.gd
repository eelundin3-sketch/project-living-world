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

## What people remember, how strongly (+/- opinion of the subject) and for how many days (0 = for
## good). Kinds not listed keep the older behaviour: their trust change is permanent.
const MEMORY_KINDS := {
	"robbed": [-25, 21], "shot_at": [-35, 21], "assaulted": [-20, 14], "killed_kin": [-60, 0],
	"saw_crime": [-10, 14], "saw_murder": [-30, 21], "threatened": [-15, 14], "insulted": [-8, 3],
	"helped": [10, 7], "saved_life": [40, 28], "paid_well": [3, 3], "delivered_goods": [5, 7], "gift": [8, 7],
	"pleasant": [4, 5], "bribed": [10, 14]}
const DAY := 14400

## Records that `npc_id` remembers `kind` about `subject`. Listed kinds fade over their days; a
## repeat of the same kind about the same subject strengthens the old memory (up to twice the
## base) instead of crowding out other memories. At most 16 memories: the faintest goes first.
static func remember(s: Dictionary, npc_id: int, kind: String, subject: int, text: String, trust_delta: int = 0, scale: int = 100) -> void:
	if not s.residents.has(str(npc_id)) or not s.entities.has(str(subject)):
		return
	var npc: Dictionary = s.residents[str(npc_id)]
	var relation: Dictionary = npc.relations.get(str(subject), {"trust": 0, "last_tick": s.tick})
	relation.last_tick = s.tick
	if MEMORY_KINDS.has(kind):
		var base: int = int(MEMORY_KINDS[kind][0]) * scale / 100
		var merged := false
		for memory in npc.memories:
			if memory.kind == kind and int(memory.subject) == subject:
				var cap: int = absi(base) * 2
				memory.weight = clampi(current_weight(s, memory) + base, -cap, cap)
				memory.tick = s.tick
				memory.text = text
				merged = true
				break
		if not merged: npc.memories.append({"tick": s.tick, "kind": kind, "subject": subject, "text": text, "weight": base})
	else:
		npc.memories.append({"tick": s.tick, "kind": kind, "subject": subject, "text": text})
		relation.trust = clampi(relation.trust + trust_delta, -100, 100)
	while npc.memories.size() > 16:
		var faintest := 0
		for index in range(npc.memories.size()):
			if absi(current_weight(s, npc.memories[index])) < absi(current_weight(s, npc.memories[faintest])): faintest = index
		npc.memories.remove_at(faintest)
	npc.relations[str(subject)] = relation
	if npc.relations.size() > 32:
		var oldest: String = npc.relations.keys()[0]
		for key in npc.relations:
			if npc.relations[key].last_tick < npc.relations[oldest].last_tick:
				oldest = key
		npc.relations.erase(oldest)

## A memory's strength now: its weight, fading in a straight line to nothing over its kind's days.
static func current_weight(s: Dictionary, memory: Dictionary) -> int:
	if not memory.has("weight"): return 0
	var days: int = int(MEMORY_KINDS.get(str(memory.kind), [0, 0])[1])
	if days <= 0: return int(memory.weight)
	var age: int = int(s.tick) - int(memory.tick)
	var span: int = days * DAY
	if age >= span: return 0
	return int(memory.weight) * (span - age) / span

## How `npc_id` feels about `subject`, -100..100: lasting trust plus every live memory.
static func opinion(s: Dictionary, npc_id: int, subject: int) -> int:
	var npc: Dictionary = s.get("residents", {}).get(str(npc_id), {})
	if npc.is_empty(): return 0
	var total: int = int(npc.get("relations", {}).get(str(subject), {}).get("trust", 0))
	for memory in npc.get("memories", []):
		if int(memory.subject) == subject: total += current_weight(s, memory)
	return clampi(total, -100, 100)

## The victim remembers `kind` in full, their household at half strength (in full for a killing:
## it is their kin who was killed), and everyone who saw it
## remembers `witness_kind` (when given).
static func witnessed(s: Dictionary, victim: int, kind: String, subject: int, text: String, witnesses: Array = [], witness_kind: String = "") -> void:
	if s.get("residents", {}).has(str(victim)):
		remember(s, victim, kind, subject, text)
		var household: String = str(s.residents[str(victim)].get("household", ""))
		if not household.is_empty() and s.get("households", {}).has(household):
			for member in s.households[household].members:
				if int(member) != victim: remember(s, int(member), kind, subject, text, 0, 100 if kind == "killed_kin" else 50)
	if not witness_kind.is_empty():
		for id in witnesses:
			if int(id) != victim: remember(s, int(id), witness_kind, subject, text)

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
	load("res://sim/world/chronicle.gd").record(s, "migration", int(npc.settlement), npc_id, 0, s.entities[str(npc_id)].cell, {"to": destination})
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
