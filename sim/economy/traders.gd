extends RefCounted
## Traders: villagers who walk the roads between the markets, buying where a good is cheap and
## selling where it is dear. Trading is a profession only while it pays: a town wants a trader
## when some good's price differs enough between two markets; a trader who finds nothing worth
## the walk heads home and, after a while, goes back to ordinary work.
##
## A trader's trip reuses the caravan record (`s.caravans[id]`) so road danger, custody of the
## cargo and scheduled arrival all work as before; the carrier is now the trader himself, walking
## the actual road one cell at a time.
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Market = preload("res://sim/economy/market.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const Pace = preload("res://sim/movement/pace.gd")
const World = preload("res://sim/world/world_db.gd")
const GOODS: Array[String] = ["log", "food", "plank"]
const LOAD := 20
const MIN_MARGIN := 2          # coins per unit that make the walk worth it
const STAKE := 400             # money the town lends a new trader to buy his first load
const TICKS_PER_CELL := 3      # a loaded walk
const IDLE_CHECKS_TO_QUIT := 3
const CHECK_EVERY := 300

## The most profitable load from `from_town` to any other town: {item, to, margin} or {}.
static func best_deal(s: Dictionary, from_town: int) -> Dictionary:
	if not s.has("markets") or not s.settlements.has(str(from_town)): return {}
	var best: Dictionary = {}
	var source: int = s.settlements[str(from_town)].warehouse
	for key in s.settlements:
		var to: int = int(key)
		if to == from_town: continue
		var target: int = s.settlements[key].warehouse
		for item in GOODS:
			var margin: int = Market.quote(s, to, item, false) - Market.quote(s, from_town, item, true)
			if margin >= MIN_MARGIN and margin > int(best.get("margin", 0)) and Inventory.amount(s, source, item) >= LOAD and Inventory.available(s, target) >= LOAD:
				best = {"item": item, "to": to, "margin": margin}
	return best

## A town wants a trader while any market it trades with offers a profit in either direction.
## Only the crossroads town (Alder Hollow, which the roads to both other towns start from) keeps one.
static func wanted(s: Dictionary, settlement: int) -> int:
	if settlement != 1 or not s.has("markets"): return 0
	for key in s.settlements:
		if not best_deal(s, int(key)).is_empty(): return 1
	return 0

## Gives every resident who has taken up trading a trip record, a stake and a pack.
static func ensure(s: Dictionary) -> void:
	if not s.has("routes"): return
	if not s.has("caravans"): s.caravans = {}
	var keys: Array = s.residents.keys()
	keys.sort()
	for key in keys:
		var npc: Dictionary = s.residents[key]
		if npc.occupation != "Trader" or s.caravans.has(key): continue
		var home: int = int(npc.settlement)
		s.caravans[key] = {"id": npc.id, "town": home, "home": home, "origin": home, "destination": home, "route": 1,
			"status": "Looking for profitable cargo", "depart_tick": 0, "arrival_tick": 0, "event_id": 0,
			"item": "", "quantity": 0, "in_transit": false, "deliveries": 0, "fidelity": npc.get("fidelity", "detailed"),
			"health": 100, "last_conflict": 0, "idle": 0, "stake": 0, "path": []}
		s.inventories[key].capacity = maxi(int(s.inventories[key].capacity), LOAD + 10)
		var treasury := str(s.settlements[str(home)].warehouse)
		var lent: int = mini(STAKE, int(s.accounts.get(treasury, 0)))
		if lent > 0 and s.accounts.has(key):
			s.accounts[treasury] -= lent
			s.accounts[key] += lent
			s.caravans[key].stake = lent
		var Outfits = load("res://sim/entities/outfits.gd")
		var outfit: Dictionary = Outfits.worn(s, npc.id).duplicate()
		if str(outfit.get("pack", "")).is_empty():
			outfit.pack = Outfits.key("pack", 0)
			Outfits.dress(s, npc.id, outfit)
		npc.status = "Taking up trading on the roads"

## True while a trader is out on the road or waiting at a foreign market (ordinary life pauses).
static func away(s: Dictionary, npc: Dictionary) -> bool:
	var trip: Dictionary = s.get("caravans", {}).get(str(npc.id), {})
	return not trip.is_empty() and (trip.in_transit or int(trip.town) != int(trip.home))

## How far along its path a travelling trader is now (older saves have no schedule: a cell every
## TICKS_PER_CELL).
static func path_index(s: Dictionary, trip: Dictionary) -> int:
	var elapsed: int = s.tick - int(trip.depart_tick)
	var eta: Array = trip.get("eta", [])
	if eta.size() != trip.path.size(): return mini(elapsed / TICKS_PER_CELL, trip.path.size() - 1)
	return clampi(eta.bsearch(elapsed, false) - 1, 0, trip.path.size() - 1)

## Starts a walk from the trader's current town to `to`, carrying `item` (or nothing).
static func _set_out(sim: RefCounted, trip: Dictionary, to: int, item: String, quantity: int) -> bool:
	var s: Dictionary = sim.state
	var from: Array = s.entities[str(s.settlements[str(trip.town)].warehouse)].cell
	var goal: Array = s.entities[str(s.settlements[str(to)].warehouse)].cell
	var start: Array = [from[0], from[1] + 2]
	var finish: Array = [goal[0], goal[1] + 2]
	var route := Nav.request_travel_path(s, start, finish)   # along the roads
	if not route.ok: return false
	trip.path = [start] + route.path
	# When the trader reaches each cell: a little quicker on the roads (pace.gd).
	trip.eta = Pace.schedule(s, trip.path, TICKS_PER_CELL)
	trip.route = load("res://sim/economy/regional_trade.gd").route_between(s, int(trip.town), to)   # (loaded here: regional_trade preloads this file)
	trip.origin = trip.town
	trip.destination = to
	trip.item = item
	trip.quantity = quantity
	trip.in_transit = true
	trip.idle = 0
	trip.depart_tick = s.tick
	trip.arrival_tick = s.tick + int(trip.eta[trip.eta.size() - 1]) + TICKS_PER_CELL
	trip.fidelity = s.residents[str(trip.id)].get("fidelity", trip.fidelity)
	trip.event_id = sim.schedule("caravan_arrival", trip.arrival_tick, {"id": trip.id})
	var route_record: Dictionary = s.get("routes", {}).get(str(trip.route), {})
	if s.has("conflicts") and int(route_record.get("risk", 0)) > 0:
		sim.schedule("encounter", s.tick + (trip.arrival_tick - s.tick) / 2, {"actor": trip.id, "threat": route_record.risk, "fidelity": trip.fidelity})
	var npc: Dictionary = s.residents[str(trip.id)]
	npc.goal = ""
	npc.path = []
	trip.status = ("Carrying %d %s to %s" % [quantity, item, s.settlements[str(to)].name]) if quantity > 0 else ("Walking to %s to buy" % s.settlements[str(to)].name if to != int(trip.home) else "Walking home")
	npc.status = trip.status
	sim.record("%s: %s" % [s.entities[str(trip.id)].name, trip.status])
	return true

## One trader's decision at a market: buy and go, go where the bargains are, or give up.
static func decide(sim: RefCounted, trip: Dictionary) -> bool:
	var s: Dictionary = sim.state
	if s.has("treaty") and not s.treaty.open_trade:
		trip.status = "Trade suspended by treaty"
		return false
	var route_record: Dictionary = s.get("routes", {}).get(str(trip.route), {})
	if route_record.get("blocked", false):
		trip.status = "Route blocked"
		return false
	if int(route_record.get("risk", 0)) > 60 + int(route_record.get("guards", 0)) * 10:
		trip.status = "Avoiding dangerous road"
		return false
	var here: int = int(trip.town)
	var deal := best_deal(s, here)
	if not deal.is_empty():
		var quantity: int = mini(LOAD, Inventory.available(s, trip.id))
		var price: int = Market.quote(s, here, deal.item, true)
		quantity = mini(quantity, int(s.accounts.get(str(trip.id), 0)) / maxi(1, price))
		if quantity > 0:
			var bought := Market.transact(s, s.settlements[str(here)].warehouse, trip.id, deal.item, quantity, price, here)
			if bought.ok: return _set_out(sim, trip, int(deal.to), deal.item, quantity)
	# Nothing to carry from here: walk to wherever there is something worth buying.
	for key in s.settlements:
		if int(key) != here and not best_deal(s, int(key)).is_empty():
			return _set_out(sim, trip, int(key), "", 0)
	if here != int(trip.home): return _set_out(sim, trip, int(trip.home), "", 0)
	trip.idle = int(trip.idle) + 1
	trip.status = "No prices worth the walk"
	return false

## Pays back the stake and goes back to ordinary work.
static func retire(sim: RefCounted, trip: Dictionary) -> void:
	var s: Dictionary = sim.state
	var key := str(trip.id)
	var npc: Dictionary = s.residents.get(key, {})
	var treasury := str(s.settlements[str(trip.home)].warehouse)
	var repaid: int = mini(int(trip.get("stake", 0)), int(s.accounts.get(key, 0)))
	if repaid > 0:
		s.accounts[key] -= repaid
		s.accounts[treasury] += repaid
	if not npc.is_empty():
		npc.occupation = "Gatherer"
		npc.status = "Gave up trading: no prices worth the walk"
		sim.record("%s gives up trading and looks for other work." % s.entities[key].name)
	s.caravans.erase(key)

## Called every tick: walk the road, and at a market every few minutes decide what to do.
static func update(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	if not s.has("caravans"): return
	ensure(s)
	var keys: Array = s.caravans.keys()
	keys.sort()
	for key in keys:
		var trip: Dictionary = s.caravans[key]
		var npc: Dictionary = s.residents.get(key, {})
		if npc.is_empty():
			continue   # an older save's abstract caravan: regional_trade.gd still runs it
		if npc.occupation != "Trader" and not trip.in_transit:
			retire(sim, trip)
			continue
		if trip.in_transit:
			var step: int = path_index(s, trip)
			if step >= 0 and not trip.path.is_empty(): s.entities[key].cell = trip.path[step].duplicate()
			continue
		if (s.tick + int(trip.id)) % CHECK_EVERY != 0: continue
		_sell_here(sim, trip)
		decide(sim, trip)
		if int(trip.idle) >= IDLE_CHECKS_TO_QUIT and int(trip.town) == int(trip.home): retire(sim, trip)

## Sells whatever the trader carries to the market he is standing in.
static func _sell_here(sim: RefCounted, trip: Dictionary) -> void:
	var s: Dictionary = sim.state
	var town: Dictionary = s.settlements[str(trip.town)]
	for item in s.inventories[str(trip.id)].items.keys():
		if not GOODS.has(item): continue
		var quantity: int = Inventory.amount(s, trip.id, item)
		if quantity <= 0: continue
		var sold := Market.transact(s, trip.id, town.warehouse, item, quantity, Market.quote(s, int(trip.town), item, false), int(trip.town))
		if sold.ok:
			trip.deliveries = int(trip.deliveries) + 1
			trip.status = "Sold %d %s in %s" % [quantity, item, town.name]
			sim.record("%s: %s" % [s.entities[str(trip.id)].name, trip.status])

## On arrival: stand at the market, sell the load, and wait for the next decision.
static func arrive(sim: RefCounted, trip: Dictionary) -> void:
	var s: Dictionary = sim.state
	var key := str(trip.id)
	trip.in_transit = false
	trip.town = trip.destination
	trip.event_id = 0
	trip.path = []
	var store: Array = s.entities[str(s.settlements[str(trip.town)].warehouse)].cell
	s.entities[key].cell = [store[0], store[1] + 2]
	_sell_here(sim, trip)
	if s.residents.has(key): s.residents[key].status = trip.status
