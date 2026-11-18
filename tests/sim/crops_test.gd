extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Crops = preload("res://sim/farming/crops.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Invariants = preload("res://sim/diagnostics/invariants.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	# Six visible stages, in order, from newly sown to harvest-ready.
	var plot := {"id": 1, "kind": "field", "state": "growing", "grown": 0, "rect": [0, 0, 4, 3]}
	var seen: Array = []
	for grown in [0, 5000, 16000, 27000, 38000, Crops.CYCLE_TICKS]:
		plot.grown = grown
		seen.append(Crops.stage(plot))
	check(seen == [0, 1, 2, 3, 4, 5], "Growth passes through six stages in order: " + str(seen))
	plot.grown = Crops.CYCLE_TICKS
	check(Crops.stage_name(plot) == "Ready to harvest", "Final stage is harvest-ready")
	# Growth is continuous and monotonic.
	var previous := -1
	for grown in range(0, Crops.CYCLE_TICKS + 1, 500):
		plot.grown = grown
		check(Crops.permille(plot) >= previous, "Permille never decreases")
		previous = Crops.permille(plot)
	# The starting field ripens, waits for the crew, is harvested into the farm store and resown.
	var field: Dictionary = Crops.plot_for_farm(s, s.farm)
	check(not field.is_empty() and Crops.stage(field) in [2, 3], "Starting field is mid-season: " + str(Crops.stage(field)))
	var rye_before: int = Inventory.amount(s, s.farm, "rye")
	var cycles := 0
	for tick in range(Crops.CYCLE_TICKS):
		sim.step()
		if field.harvests > 0: break
	check(field.harvests >= 1, "Field is harvested once ripe")
	check(Inventory.amount(s, s.farm, "rye") > rye_before or Inventory.amount(s, s.warehouse, "rye") > 0, "Harvest yields rye grain")
	check(field.grown < Crops.CYCLE_TICKS / 2, "Field is resown after harvest")
	check(Invariants.validate(s).is_empty(), "Invariants hold after harvest: " + str(Invariants.validate(s)))
	# Player can harvest a ripe field by hand.
	var manual := Sim.new(); manual.start_game(); var m: Dictionary = manual.state
	var f2: Dictionary = Crops.plot_for_farm(m, m.farm)
	f2.grown = Crops.CYCLE_TICKS
	check(Crops.harvest(m, f2) == Crops.expected_yield(f2) and f2.harvests == 1, "Manual harvest transfers the full yield")
	check(Crops.harvest(m, f2) == 0, "A freshly sown field cannot be harvested again")
	if failures == 0: print("Crops: PASS")
	quit(failures)
