extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Regional = preload("res://sim/economy/regional_trade.gd")
const Fidelity = preload("res://sim/world/fidelity.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
const Save = preload("res://sim/persistence/save_manager.gd")
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
	sim.enable_region()
	var s: Dictionary = sim.state
	var caravan: Dictionary = s.caravans.values()[0]
	Inventory.produce(s, s.warehouse, "log", 200)
	var totals := Inventory.totals(s)
	check(Regional.dispatch(sim, caravan), "Profitable route dispatch")
	check(Inventory.amount(s, caravan.id, caravan.item) == 20 and Inventory.totals(s) == totals, "Single custody in transit")
	s.routes["1"].blocked = true
	for tick in range(600):
		sim.step()
	check(caravan.in_transit and caravan.status.contains("Waiting"), "Route blockage delays arrival without duplicating cargo")
	s.routes["1"].blocked = false
	for tick in range(100):
		sim.step()
	check(not caravan.in_transit and caravan.deliveries > 0, "Arrival sells actual cargo")
	var inventories: Dictionary = s.inventories.duplicate(true)
	var residents: Dictionary = s.residents.duplicate(true)
	Fidelity.transition(s, 1, "aggregate")
	Fidelity.transition(s, 1, "coarse")
	Fidelity.transition(s, 1, "detailed")
	check(s.inventories == inventories, "LOD roundtrip preserves exact goods")
	for key in residents:
		check(s.residents[key].id == residents[key].id and s.residents[key].hunger == residents[key].hunger, "LOD preserves identity and needs")
	Save.save_state(sim, OS.get_temp_dir().path_join("solo-region.save"))
	var replay := Sim.new()
	check(Save.load_into(replay, OS.get_temp_dir().path_join("solo-region.save")).ok, "Regional save loads")
	for tick in range(10000):
		sim.step()
		replay.step()
	check(sim.state_hash() == replay.state_hash(), "Regional/LOD deterministic continuation")
	check(Checks.validate(s).is_empty(), "Regional resource invariants")
	print("Regional: %s; caravan deliveries=%d" % ["PASS" if failures == 0 else "FAIL", caravan.deliveries])
	quit(0 if failures == 0 else 1)
