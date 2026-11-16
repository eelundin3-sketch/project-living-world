extends SceneTree
## The walking trader (a villager, only while prices pay) and a market tent for every seller.
const Sim = preload("res://sim/core/simulation.gd")
const Traders = preload("res://sim/economy/traders.gd")
const Market = preload("res://sim/economy/market.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void:
	var sim := Sim.new(); sim.start_game()
	var s: Dictionary = sim.state
	var carts := 0
	for e in s.entities.values(): if e.kind == "caravan": carts += 1
	check(carts == 0, "No abstract cart travels the roads")
	check(s.caravans.size() == 1, "One villager has taken up trading while prices differ")
	var trader_id: int = int(s.caravans.keys()[0])
	check(s.residents.has(str(trader_id)) and s.residents[str(trader_id)].occupation == "Trader", "The trader is a real villager")
	# Every seller keeps a tent.
	for npc in s.residents.values():
		if Market.SELLER_GOODS.has(npc.occupation):
			check(int(npc.get("tent", 0)) != 0 and s.entities.has(str(npc.tent)) and s.entities[str(npc.tent)].keeper == npc.id, "%s the %s has a market tent" % [s.entities[str(npc.id)].name, npc.occupation])
	# The trader walks the road a cell at a time and sells at the far market.
	var trip: Dictionary = s.caravans[str(trader_id)]
	var cells: Dictionary = {}
	var sold_before: int = int(trip.deliveries)
	var left := false
	for t in range(6000):
		sim.step()
		if trip.in_transit:
			left = true
			cells[str(s.entities[str(trader_id)].cell)] = true
		if left and int(trip.deliveries) > sold_before: break
	check(left and cells.size() > 50, "The trader walks the road (%d cells)" % cells.size())
	check(int(trip.deliveries) > sold_before, "The trader sells her load at another market")
	check(Checks.validate(s).is_empty(), "Goods and money are conserved: " + str(Checks.validate(s)))
	var copy := Sim.new(); copy.restore(sim.snapshot())
	check(copy.state_hash() == sim.state_hash(), "A trip in progress survives a reload")
	# With no price worth the walk she goes home, gives up and her tent is packed away.
	for town in s.settlements.values():
		for item in Traders.GOODS: s.inventories[str(town.warehouse)].items[item] = 0
	for t in range(9000):
		sim.step()
		if not s.caravans.has(str(trader_id)): break
	check(not s.caravans.has(str(trader_id)) and s.residents[str(trader_id)].occupation != "Trader", "Without profit the trader takes up other work")
	for t in range(700): sim.step()
	var trader_tents := 0
	for e in s.entities.values():
		if e.get("keeper", 0) == trader_id and e.sale_items == Market.SELLER_GOODS["Trader"]: trader_tents += 1
	var now: String = s.residents[str(trader_id)].occupation
	check(trader_tents == 0, "Her trader's tent is packed away or now sells her new trade's goods (%s)" % now)
	print("Trader: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
