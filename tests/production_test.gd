extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Recipes = preload("res://sim/production/recipe_system.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
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
	print("Production: %s (100k cycles + live supply chain)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
