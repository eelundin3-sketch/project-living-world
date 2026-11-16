extends RefCounted
## Resource-driven profession demand. A settlement does not receive a fixed roster:
## each trade's demand is derived from what the land around it offers and how many
## people it must feed and protect. Farmers and a sheriff emerge from the food and
## safety terms in the same way a miner emerges from nearby ore.
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const GATHERERS: Array[String] = ["Gatherer", "Woodsman", "Farmer", "Miner"]
const WORKSHOP_TRADES: Array[String] = ["Sawyer", "Baker", "Blacksmith"]
## Which resource entity kinds each gathering profession works.
## When several trades are equally short, the more essential one is filled first.
const PRIORITY: Array[String] = ["Farmer", "Sheriff", "Woodsman", "Sawyer", "Miner", "Baker", "Blacksmith"]
const TARGETS: Dictionary = {"Woodsman": ["tree"], "Farmer": ["farm"], "Miner": ["ore"], "Gatherer": ["tree", "farm", "ore"]}
const DESCRIPTIONS: Dictionary = {
	"Farmer": "Grows and harvests rye for the settlement's food supply.",
	"Woodsman": "Fells trees and hauls logs to the storehouse.",
	"Sawyer": "Plank maker: saws logs into planks at the timber workshop.",
	"Miner": "Digs iron ore from nearby deposits.",
	"Blacksmith": "Forge worker: smelts ore into iron tools.",
	"Baker": "Bakes rye into bread for the provisions stall and storehouse.",
	"Builder": "Raises homes and workshops from planks.",
	"Sheriff": "Keeps the peace, patrols the square and guards the road.",
	"Carpenter": "Craftsman: joinery and furniture for new homes.",
	"Child": "Too young to work; helps in the household garden."}

static func settlement_resources(s: Dictionary, settlement: int) -> Dictionary:
	var town: Dictionary = s.settlements[str(settlement)]
	var center: Array = s.entities[str(town.warehouse)].cell
	var result := {"trees": 0, "ore": 0, "fields": 0, "population": 0, "danger": 0, "workshops": {}}
	for entity in s.entities.values():
		if not entity.has("cell"): continue
		var near: bool = absi(entity.cell[0] - center[0]) <= 62 and absi(entity.cell[1] - center[1]) <= 40
		match entity.kind:
			"tree": result.trees += 1 if near else 0
			"ore": result.ore += 1 if near else 0
			"farm": result.fields += 1 if entity.settlement == settlement else 0
	for npc in s.residents.values():
		if npc.settlement == settlement and npc.health > 0 and npc.occupation != "Child": result.population += 1
	for workshop in s.get("workshops", {}).values():
		if workshop.settlement == settlement: result.workshops[workshop.get("kind", "sawmill")] = true
	result.danger = int(s.get("routes", {}).get("1", {}).get("risk", 0))
	return result

## Desired head-count per profession, derived from resources and needs.
static func demand(s: Dictionary, settlement: int) -> Dictionary:
	var r: Dictionary = settlement_resources(s, settlement)
	var pop: int = r.population
	var want: Dictionary = {}
	if r.fields > 0: want.Farmer = maxi(1, ceili(pop * 0.2))
	# Timber needs two pairs of hands in a small town, because one of them is borrowed whenever a house is built.
	if r.trees >= 20: want.Woodsman = maxi(1, ceili(pop * 0.4))
	if want.get("Woodsman", 0) > 0 and r.workshops.has("sawmill"): want.Sawyer = 1
	# Households bake their own rye; a dedicated baker only pays for itself once there are six or more people.
	if r.fields > 0 and r.workshops.has("bakery") and pop >= 6: want.Baker = 1
	if r.ore >= 1: want.Miner = maxi(1, ceili(pop * 0.15))
	if want.get("Miner", 0) > 0 and r.workshops.has("forge"): want.Blacksmith = 1
	# Safety: a settlement large enough to have something worth stealing, or one beside a dangerous road.
	if pop >= 3 or r.danger > 0: want.Sheriff = 1 + pop / 18
	return want

static func count(s: Dictionary, settlement: int, occupation: String) -> int:
	var total := 0
	for npc in s.residents.values():
		if npc.settlement == settlement and npc.occupation == occupation and npc.health > 0: total += 1
	return total

## Fills unmet demand from residents without a trade. Deterministic: lowest id first,
## and the trade with the largest shortfall ratio is filled first.
static func assign(s: Dictionary, settlement: int) -> void:
	var want: Dictionary = demand(s, settlement)
	var free: Array = []
	for npc in s.residents.values():
		if npc.settlement == settlement and npc.occupation == "Gatherer" and npc.health > 0 and npc.job == 0 and npc.get("migration", {}).is_empty(): free.append(npc.id)
	free.sort()
	while not free.is_empty():
		var best := "~"   # sorts after every real trade
		var ratio := 0.0
		for key in want:
			var trade: String = str(key)
			var have: int = count(s, settlement, trade)
			var shortfall: float = float(want[trade] - have) / float(want[trade])
			if want[trade] > have and (shortfall > ratio or (shortfall == ratio and PRIORITY.find(trade) < PRIORITY.find(best))):
				best = trade
				ratio = shortfall
		if best == "~": break
		s.residents[str(free.pop_front())].occupation = best
	if s.has("settlements"): load("res://sim/settlement/sheriff.gd").dress(s)

static func gathers(npc: Dictionary, target_kind: String) -> bool:
	return TARGETS.get(npc.occupation, []).has(target_kind)
