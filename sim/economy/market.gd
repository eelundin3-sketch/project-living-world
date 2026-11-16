extends RefCounted
const World = preload("res://sim/world/world_db.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const BASE: Dictionary = {"log": 12, "food": 8, "plank": 7, "bandage": 6, "antiseptic": 12}
const TARGET: Dictionary = {"log": 100, "food": 100, "plank": 100, "bandage": 30, "antiseptic": 12}

static func initialize(s: Dictionary) -> void:
	s.accounts = {str(s.player): 1000}
	s.markets = {}
	s.money_initial = 1000
	s.trades = []
	for town in s.settlements.values():
		add_market(s, town.id)

static func add_market(s: Dictionary, town_id: int) -> void:
	var town: Dictionary = s.settlements[str(town_id)]
	s.accounts[str(town.warehouse)] = 10000
	s.money_initial += 10000
	s.markets[str(town_id)] = {"settlement": town_id, "store": town.warehouse, "last": {}, "history": [], "orders": []}

static func install_stalls(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	if not s.has("routes") or not s.has("markets") or s.world.get("stall_version", 0) >= 1: return
	for town in s.settlements.values():
		town.stalls = []
		var store: Dictionary = s.entities[str(town.warehouse)]
		for spec in [
			{"name": "Timber stall", "items": ["plank", "log"], "stock": {"log": 6}, "side": -1},
			{"name": "Provisions stall", "items": ["food", "bandage", "antiseptic"], "stock": {"food": 18, "bandage": 5, "antiseptic": 3}, "side": 1},
		]:
			var cell := _stall_cell(s, store.cell, spec.side)
			if cell.is_empty(): continue
			var id := World.add_entity(sim, "market_stall", spec.name, cell, town.id)
			var stall: Dictionary = s.entities[str(id)]
			stall.sale_items = spec.items.duplicate()
			town.stalls.append(id)
			Inventory.create(s, id, 120)
			var funds: int = mini(700, s.accounts.get(str(town.warehouse), 0))
			s.accounts[str(town.warehouse)] -= funds
			s.accounts[str(id)] = funds
			for item in spec.stock:
				var quantity: int = mini(spec.stock[item], Inventory.amount(s, town.warehouse, item))
				if quantity > 0: Inventory.transfer(s, town.warehouse, id, item, quantity)
	s.world.stall_version = 1

static func _stall_cell(s: Dictionary, store: Array, side: int) -> Array:
	for y_offset in [4, 5, 7, 9, 11]:
		for width in [7, 10, 13, 17]:
			var x: int = store[0] + side * width
			var y: int = store[1] + y_offset
			var rect := Rect2i(x - 1, y, 4, 2)
			var clear := true
			for cy in range(y, y + 2):
				for cx in range(x - 1, x + 3):
					if not World.walkable(s, [cx, cy]): clear = false
			for entity in s.entities.values():
				if entity.kind in ["tree", "farm"] and rect.has_point(Vector2i(entity.cell[0], entity.cell[1])): clear = false
				if entity.kind == "construction":
					var site: Dictionary = s.construction.get(str(entity.id), {})
					var definition: Dictionary = s.building_defs.get(site.get("definition", ""), {})
					if rect.intersects(World.plot_rect(entity, definition.get("kind", "home"))): clear = false
			if clear: return [x, y]
	return []

static func quote(s: Dictionary, town_id: int, item: String, buying: bool) -> int:
	if not BASE.has(item) or not s.markets.has(str(town_id)):
		return 0
	var stock: int = Inventory.amount(s, s.markets[str(town_id)].store, item)
	var estimate: int = clampi(int(BASE[item]) * int(TARGET[item]) / maxi(10, stock + int(TARGET[item]) / 2), 2, 100)
	return clampi(estimate + (1 if buying else -1), 1, 100)

static func transact(s: Dictionary, seller: int, buyer: int, item: String, quantity: int, price: int, town_id: int) -> Dictionary:
	if quantity <= 0 or price < 1 or price > 100 or seller == buyer or not BASE.has(item):
		return Inventory.result(false, "INVALID_ORDER")
	if not s.accounts.has(str(seller)) or not s.accounts.has(str(buyer)):
		return Inventory.result(false, "MISSING_ACCOUNT")
	var cost: int = quantity * price
	if int(s.accounts[str(buyer)]) < cost:
		return Inventory.result(false, "INSUFFICIENT_MONEY")
	var transfer := Inventory.transfer(s, seller, buyer, item, quantity)
	if not transfer.ok:
		return transfer
	s.accounts[str(buyer)] -= cost
	s.accounts[str(seller)] += cost
	var trade := {"tick": s.tick, "seller": seller, "buyer": buyer, "item": item, "quantity": quantity, "price": price, "settlement": town_id}
	s.trades.append(trade)
	if s.trades.size() > 64:
		s.trades.pop_front()
	var market: Dictionary = s.markets[str(town_id)]
	market.last[item] = price
	market.history.append(trade)
	if market.history.size() > 32:
		market.history.pop_front()
	return Inventory.result(true, "", [seller, buyer])

static func player_trade(sim: RefCounted, payload: Dictionary) -> Dictionary:
	var s: Dictionary = sim.state
	var town_id: int = int(payload.get("town", 1))
	var item: String = payload.get("item", "log")
	var buying: bool = payload.get("buy", false)
	var quantity: int = int(payload.get("quantity", 1))
	if not s.markets.has(str(town_id)) or not BASE.has(item):
		return Inventory.result(false, "UNKNOWN_MARKET_OR_ITEM")
	var store: int = s.markets[str(town_id)].store
	var cell: Array = s.entities[str(s.player)].cell
	var target: Array = s.entities[str(store)].cell
	if absi(cell[0] - target[0]) + absi(cell[1] - target[1]) > 6:
		return Inventory.result(false, "WALK_TO_STORE_TO_TRADE")
	var seller: int = store if buying else s.player
	var buyer: int = s.player if buying else store
	var result := transact(s, seller, buyer, item, quantity, quote(s, town_id, item, buying), town_id)
	if result.ok:
		sim.record("You %s %d %s at %d coins/unit" % ["bought" if buying else "sold", quantity, item, s.markets[str(town_id)].last[item]])
	return result

static func place_order(s: Dictionary, town_id: int, owner: int, item: String, quantity: int, limit_price: int, buy: bool, id: int) -> bool:
	if not s.markets.has(str(town_id)) or quantity <= 0 or limit_price < 1 or limit_price > 100 or not BASE.has(item):
		return false
	s.markets[str(town_id)].orders.append({"id": id, "owner": owner, "item": item, "quantity": quantity, "limit": limit_price, "buy": buy})
	return true

static func clear_market(s: Dictionary, town_id: int) -> int:
	var market: Dictionary = s.markets[str(town_id)]
	var bids: Array = market.orders.filter(func(o: Dictionary) -> bool: return o.buy)
	var asks: Array = market.orders.filter(func(o: Dictionary) -> bool: return not o.buy)
	bids.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.limit > b.limit or (a.limit == b.limit and a.id < b.id))
	asks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.limit < b.limit or (a.limit == b.limit and a.id < b.id))
	var count: int = 0
	for bid in bids:
		for ask in asks:
			if bid.item != ask.item or bid.owner == ask.owner or bid.limit < ask.limit or bid.quantity <= 0 or ask.quantity <= 0:
				continue
			var quantity: int = mini(bid.quantity, ask.quantity)
			if transact(s, ask.owner, bid.owner, bid.item, quantity, ask.limit, town_id).ok:
				bid.quantity -= quantity
				ask.quantity -= quantity
				count += 1
	# Orders are good-for-session; an unfunded order never reserves fictional goods.
	market.orders = []
	return count
