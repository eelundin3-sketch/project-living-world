extends SceneTree
## The region: towns joined by a road, trade carried by a walking trader (a real villager; see
## trader_test for the trips themselves), levels of detail, and a save that continues exactly.
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
	# The real game: a world built by the smaller test setups (start_village + enable_region) lacks
	# the version markers a new game carries, so loading one would run the old-save upgrades.
	var sim := Sim.new()
	sim.start_game()
	var s: Dictionary = sim.state
	check(s.settlements.size() >= 2 and s.routes.has("1"), "The region has a second town and a road to it")
	var trader: Dictionary = {}
	for key in s.caravans: check(s.residents.has(key), "Trade is carried by villagers, not an abstract cart")
	check(not s.caravans.is_empty(), "A villager takes up trading while prices differ")
	if not s.caravans.is_empty():
		trader = s.caravans.values()[0]
		var totals := Inventory.totals(s)
		s.routes["1"].blocked = true
		check(not Regional.dispatch(sim, trader) and trader.status == "Route blocked", "A blocked road keeps the trader at home")
		check(Inventory.totals(s) == totals, "Waiting on a blocked road moves no goods")
		s.routes["1"].blocked = false
	for tick in range(100):
		sim.step()
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
	var deliveries: int = int(trader.get("deliveries", 0))
	print("Regional: %s; trader deliveries=%d" % ["PASS" if failures == 0 else "FAIL", deliveries])
	quit(0 if failures == 0 else 1)
