extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Recipes = preload("res://sim/production/recipe_system.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const World = preload("res://sim/world/world_db.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	var sim := Sim.new()
	sim.start_village(10)
	sim.enable_production()
	var s: Dictionary = sim.state
	var workshop: Dictionary = s.workshops.values()[0]
	check(not Recipes.start(s, workshop), "Shortage stops production")
	# Synthetic cycles use an explicit source/sink ledger, including cancellations.
	for cycle in range(100000):
		Inventory.produce(s, s.warehouse, "log", 2)
		check(Recipes.start(s, workshop), "Batch reserves input")
		if cycle % 3 == 0:
			check(Recipes.cancel(s, workshop), "Cancel returns inputs")
			check(not Recipes.finish(s, workshop), "Cancelled batch cannot produce")
			Inventory.consume(s, s.warehouse, "log", 2)
		else:
			workshop.progress = workshop.work_ticks
			check(Recipes.finish(s, workshop), "Commit batch")
			check(not Recipes.finish(s, workshop), "Cannot commit twice")
			Inventory.consume(s, workshop.id, "plank", 6)
	check(Checks.validate(s).is_empty(), "100k production cycles conserve accounted materials")
	Inventory.produce(s, s.warehouse, "log", 2)
	Recipes.start(s, workshop)
	s.recipes[workshop.recipe].output_quantity = 9
	workshop.progress = workshop.work_ticks
	Recipes.finish(s, workshop)
	check(Inventory.amount(s, workshop.id, "plank") == 6, "Active batch freezes its original recipe during reload")
	var live := Sim.new()
	live.start_village(10)
	live.enable_production()
	for tick in range(5000):
		live.step()
	check(Inventory.amount(live.state, live.state.warehouse, "plank") > 0, "Worker produces and delivers planks")
	check(Checks.validate(live.state).is_empty(), "Live production invariants")
	var market_sim := Sim.new()
	market_sim.start_game()
	var market_state: Dictionary = market_sim.state
	var market_workshop: Dictionary = market_state.workshops.values()[0]
	var stall: int = market_state.settlements["1"].stalls[0]
	Inventory.produce(market_state, market_state.warehouse, "log", 12)
	var bulk_loaded := false
	for tick in range(7500):
		market_sim.step()
		if Inventory.amount(market_state, market_workshop.id, "log") >= 6: bulk_loaded = true
		if Inventory.amount(market_state, stall, "plank") > 0: break
	check(bulk_loaded and market_workshop.completed >= 3, "Sawyer stocks bulk inputs and works several batches before selling")
	var stocked := Inventory.amount(market_state, stall, "plank")
	check(stocked >= 6, "Craft output reaches the timber stall in a bulk delivery")
	market_state.entities[str(market_state.player)].cell = World.Fixtures.interaction_cell(market_state, stall).duplicate()
	market_sim.submit("interact", {"target": stall})
	market_sim.step()
	# Someone comes to the counter first (stall_service.gd), then trade opens.
	var Stalls = load("res://sim/economy/stall_service.gd")
	for wait in range(300):
		if Stalls.staffed(market_state, market_state.entities[str(stall)]) and market_state.player_control.ui_target == stall: break
		market_sim.step()
	check(market_state.player_control.ui_target == stall, "F opens trade at the stall counter once someone is behind it")
	var balance: int = market_state.accounts[str(market_state.player)]
	market_sim.submit("person_trade", {"target": stall, "item": "plank", "buy": true})
	market_sim.step()
	check(Inventory.amount(market_state, stall, "plank") == stocked - 1 and Inventory.amount(market_state, market_state.player, "plank") == 1, "Purchase transfers actual stall stock")
	check(market_state.accounts[str(market_state.player)] < balance and Checks.validate(market_state).is_empty(), "Stall trade conserves all items and currency")
	var current := Sim.new()
	current.restore(market_sim.snapshot())
	check(current.state_hash() == market_sim.state_hash(), "Stall stock and workshop routing round-trip with the save")
	var pre_stalls := Sim.new()
	pre_stalls.start_village(18)
	pre_stalls.enable_production()
	pre_stalls.enable_economy()
	pre_stalls.enable_region()
	var old_totals := Inventory.totals(pre_stalls.state)
	var old_population: int = pre_stalls.state.residents.size()
	current.restore(pre_stalls.snapshot())
	check(current.state.settlements["1"].stalls.size() == 2, "Legacy save gains a marketplace")
	check(current.state.residents.size() == old_population and Inventory.totals(current.state) == old_totals, "Legacy market migration preserves residents and goods")
	check(Checks.validate(current.state).is_empty(), "Legacy market migration conserves funds")
	print("Production: %s (100k cycles + live supply chain)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
