extends RefCounted
const Crops = preload("res://sim/farming/crops.gd")
const World = preload("res://sim/world/world_db.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Residents = preload("res://sim/entities/residents.gd")
const Recipes = preload("res://sim/production/recipe_system.gd")
const Market = preload("res://sim/economy/market.gd")
const Dustvale = preload("res://sim/settlement/dustvale.gd")
const Traders = preload("res://sim/economy/traders.gd")

static func initialize(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	s.world.bounds = [-96, -84, 486, 336]   # a much larger region: towns are a journey apart
	var store := World.add_entity(sim, "warehouse", "Reedbank exchange", [364, 46], 2)
	Inventory.create(s, store, 3000)
	Inventory.produce(s, store, "food", 400)
	Inventory.produce(s, store, "log", 30)
	var home := World.add_entity(sim, "home", "Reedbank lodge", [346, 40], 2)
	var farm := World.add_entity(sim, "farm", "Reedbank fields", [383, 60], 2)
	Inventory.create(s, farm, 1500)
	Inventory.produce(s, farm, "food", 700)
	Crops.add_plot(s, "field", [377, 57, 12, 6], 2, farm, 0, 30000)
	# Iron outcrops east of Reedbank give its miners and blacksmith a reason to exist.
	for ore_cell in [[420, 54], [423, 57], [418, 59]]:
		var ore := World.add_entity(sim, "ore", "Iron outcrop", ore_cell, 2)
		Inventory.create(s, ore, 80)
		Inventory.produce(s, ore, "ore", 40)
	s.settlements["2"] = {"id": 2, "name": "Reedbank", "warehouse": store, "home": home, "housing": 12,
		"population": 5, "policy": "Food exports", "demand": {}, "fidelity": "coarse", "faction": 2}
	Residents.spawn(sim, 5, 2, [362, 48])
	World.populate_forest(sim, 2, 140, [364, 46])
	World.populate_dense_groves(sim, 2, 60, [364, 46])
	Recipes.add_workshop(sim, 2, [381, 45], store)
	Recipes.add_workshop(sim, 2, [397, 45], store, "bakery")
	Recipes.add_workshop(sim, 2, [413, 45], store, "forge")
	Market.add_market(s, 2)
	Dustvale.install(sim)
	s.routes = {"1": {"id": 1, "from": 1, "to": 2, "blocked": false, "risk": 0, "guards": 0, "travel_ticks": 1500}}
	# The roads to Dustvale (planned in road_planner.gd) are routes too, so a closure or danger can
	# apply to any of them.
	if s.settlements.has("3"):
		s.routes["2"] = {"id": 2, "from": 1, "to": 3, "blocked": false, "risk": 0, "guards": 0, "travel_ticks": 1700}
		s.routes["3"] = {"id": 3, "from": 2, "to": 3, "blocked": false, "risk": 0, "guards": 0, "travel_ticks": 1900}
	# Trade between the towns is carried by a villager who takes up trading when prices make it
	# worth the walk (see traders.gd); there is no abstract cart.
	s.caravans = {}

static func dispatch(sim: RefCounted, caravan: Dictionary) -> bool:
	var s: Dictionary = sim.state
	if s.residents.has(str(caravan.id)): return Traders.decide(sim, caravan)
	var route: Dictionary = s.routes[str(caravan.route)]
	if s.has("treaty") and not s.treaty.open_trade:
		caravan.status = "Trade suspended by treaty"
		return false
	if caravan.in_transit or route.blocked:
		caravan.status = "Route blocked" if route.blocked else "Travelling"
		return false
	if route.risk > 60 + route.guards * 10:
		caravan.status = "Avoiding dangerous road"
		return false
	var origin: int = caravan.town
	var destination: int = 2 if origin == 1 else 1
	var source: int = s.settlements[str(origin)].warehouse
	var target: int = s.settlements[str(destination)].warehouse
	var best: String = ""
	var margin: int = 0
	for item in ["log", "food", "plank"]:
		var buy_price := Market.quote(s, origin, item, true)
		var sale_price := Market.quote(s, destination, item, false)
		if sale_price - buy_price > margin and Inventory.amount(s, source, item) >= 20 and Inventory.available(s, target) >= 20:
			margin = sale_price - buy_price
			best = item
	if best.is_empty():
		caravan.status = "No profitable cargo"
		return false
	var quantity: int = mini(20, Inventory.available(s, caravan.id))
	if quantity <= 0:
		caravan.status = "Unsold cargo fills wagon"
		return false
	var purchased := Market.transact(s, source, caravan.id, best, quantity, Market.quote(s, origin, best, true), origin)
	if not purchased.ok:
		caravan.status = purchased.error_code
		return false
	caravan.origin = origin
	caravan.destination = destination
	caravan.item = best
	caravan.quantity = quantity
	caravan.in_transit = true
	caravan.depart_tick = s.tick
	caravan.arrival_tick = s.tick + route.travel_ticks
	caravan.event_id = sim.schedule("caravan_arrival", caravan.arrival_tick, {"id": caravan.id})
	if s.has("conflicts") and route.risk > 0:
		sim.schedule("encounter", s.tick + route.travel_ticks / 2, {"actor": caravan.id, "threat": route.risk, "fidelity": caravan.fidelity})
	caravan.status = "Carrying %d %s to %s" % [quantity, best, s.settlements[str(destination)].name]
	sim.record(caravan.status)
	return true

static func arrive(sim: RefCounted, event: Dictionary) -> void:
	var s: Dictionary = sim.state
	var key := str(event.payload.get("id", 0))
	if not s.caravans.has(key):
		return
	var caravan: Dictionary = s.caravans[key]
	if not caravan.in_transit or caravan.event_id != event.id:
		return
	if s.routes[str(caravan.route)].blocked:
		caravan.arrival_tick = s.tick + 100
		caravan.event_id = sim.schedule("caravan_arrival", caravan.arrival_tick, {"id": caravan.id})
		caravan.status = "Waiting safely for route to reopen"
		return
	if s.residents.has(key):
		Traders.arrive(sim, caravan)
		return
	caravan.in_transit = false
	caravan.town = caravan.destination
	caravan.event_id = 0
	var town: Dictionary = s.settlements[str(caravan.town)]
	s.entities[key].cell = s.entities[str(town.warehouse)].cell.duplicate()
	s.entities[key].settlement = caravan.town
	_sell_cargo(sim, caravan)

static func _sell_cargo(sim: RefCounted, caravan: Dictionary) -> void:
	var s: Dictionary = sim.state
	var town: Dictionary = s.settlements[str(caravan.town)]
	for item in s.inventories[str(caravan.id)].items.keys():
		var quantity: int = Inventory.amount(s, caravan.id, item)
		var price := Market.quote(s, caravan.town, item, false)
		var sold := Market.transact(s, caravan.id, town.warehouse, item, quantity, price, caravan.town)
		if sold.ok:
			caravan.deliveries += 1
			caravan.status = "Sold %d %s in %s" % [quantity, item, town.name]
			sim.record(caravan.status)
		else:
			caravan.status = "Holding cargo: " + sold.error_code

static func update(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	Traders.update(sim)
	for caravan in s.caravans.values():
		if s.residents.has(str(caravan.id)): continue   # a walking trader (traders.gd)
		if caravan.in_transit:
			# Position is presentation of the single coarse travel commitment.
			var start: Array = s.entities[str(s.settlements[str(caravan.origin)].warehouse)].cell
			var finish: Array = s.entities[str(s.settlements[str(caravan.destination)].warehouse)].cell
			var elapsed: int = s.tick - caravan.depart_tick
			var duration: int = maxi(1, caravan.arrival_tick - caravan.depart_tick)
			s.entities[str(caravan.id)].cell = [start[0] + (finish[0] - start[0]) * mini(elapsed, duration) / duration, start[1]]
		elif s.tick % 300 == 0:
			_sell_cargo(sim, caravan)
			dispatch(sim, caravan)

## The route record between two towns (either way round); older saves only have route 1.
static func route_between(s: Dictionary, a: int, b: int) -> int:
	for route in s.get("routes", {}).values():
		if (int(route.from) == a and int(route.to) == b) or (int(route.from) == b and int(route.to) == a): return int(route.id)
	return 1
