extends RefCounted
const World = preload("res://sim/world/world_db.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Residents = preload("res://sim/entities/residents.gd")
const Recipes = preload("res://sim/production/recipe_system.gd")
const Market = preload("res://sim/economy/market.gd")

static func initialize(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	s.world.bounds = [-64, -64, 320, 192]
	var store := World.add_entity(sim, "warehouse", "Reedbank exchange", [180, 46], 2)
	Inventory.create(s, store, 3000)
	Inventory.produce(s, store, "food", 400)
	Inventory.produce(s, store, "log", 30)
	var home := World.add_entity(sim, "home", "Reedbank lodge", [162, 40], 2)
	var farm := World.add_entity(sim, "farm", "Reedbank fields", [199, 60], 2)
	Inventory.create(s, farm, 1500)
	Inventory.produce(s, farm, "food", 700)
	s.settlements["2"] = {"id": 2, "name": "Reedbank", "warehouse": store, "home": home, "housing": 12,
		"population": 10, "policy": "Food exports", "demand": {}, "fidelity": "coarse", "faction": 2}
	Residents.spawn(sim, 10, 2, [178, 48])
	World.populate_forest(sim, 2, 140, [180, 46])
	World.populate_dense_groves(sim, 2, 60, [180, 46])
	Recipes.add_workshop(sim, 2, [197, 45], store)
	Market.add_market(s, 2)
	var merchant := World.add_entity(sim, "caravan", "Moss Road carrier", [64, 46], 1)
	Inventory.create(s, merchant, 80)
	s.accounts[str(merchant)] = 5000
	s.money_initial += 5000
	s.routes = {"1": {"id": 1, "from": 1, "to": 2, "blocked": false, "risk": 0, "guards": 0, "travel_ticks": 600}}
	s.caravans = {str(merchant): {"id": merchant, "town": 1, "origin": 1, "destination": 2, "route": 1,
		"status": "Looking for profitable cargo", "depart_tick": 0, "arrival_tick": 0, "event_id": 0,
		"item": "", "quantity": 0, "in_transit": false, "deliveries": 0, "fidelity": "coarse"}}

static func dispatch(sim: RefCounted, caravan: Dictionary) -> bool:
	var s: Dictionary = sim.state
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
	for caravan in s.caravans.values():
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
