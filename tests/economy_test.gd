extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Market = preload("res://sim/economy/market.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	var sim := Sim.new()
	sim.start_village(20)
	sim.enable_production()
	sim.enable_economy()
	var s: Dictionary = sim.state
	# Three 385-tile homes require over a thousand round trips from the pile.
	for tick in range(80000):
		sim.step()
		if s.completed_buildings >= 3: break
	check(s.completed_buildings >= 3 and s.settlements["1"].housing >= 20, "Demand builds homes with delivered planks")
	check(Checks.validate(s).is_empty(), "Construction conserves accounted goods")
	var before: int = s.accounts[str(s.player)]
	var stock: int = Inventory.amount(s, s.warehouse, "log")
	check(Market.player_trade(sim, {"buy": true, "item": "log", "quantity": 1}).ok, "Player buys at nearby store")
	check(s.accounts[str(s.player)] < before and Inventory.amount(s, s.warehouse, "log") == stock - 1, "Real money and goods move")
	check(Market.player_trade(sim, {"buy": false, "item": "log", "quantity": 1}).ok, "Player sells to real buyer")
	var old_price := Market.quote(s, 1, "log", false)
	Inventory.consume(s, s.warehouse, "log", Inventory.amount(s, s.warehouse, "log"))
	check(Market.quote(s, 1, "log", false) > old_price, "Shortage increases executable bid")
	var funds: int = 0
	for amount in s.accounts.values():
		funds += amount
	check(funds == s.money_initial, "Currency conserved")
	check(not Market.transact(s, s.warehouse, s.player, "food", 10000, 100, 1).ok, "Unfunded order rejected")
	Inventory.produce(s, s.player, "log", 2)
	Market.place_order(s, 1, s.player, "log", 2, 5, false, sim.new_id())
	Market.place_order(s, 1, s.warehouse, "log", 2, 10, true, sim.new_id())
	check(Market.clear_market(s, 1) == 1 and s.markets["1"].last.log == 5, "Bid/ask matching at actual trade price")
	print("Economy: %s; completed homes=%d" % ["PASS" if failures == 0 else "FAIL", s.completed_buildings])
	quit(0 if failures == 0 else 1)
