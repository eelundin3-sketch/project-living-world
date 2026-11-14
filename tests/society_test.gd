extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Society = preload("res://sim/factions/society.gd")
const Risk = preload("res://sim/factions/risk_system.gd")
const Regional = preload("res://sim/economy/regional_trade.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	var sim := Sim.new()
	sim.start_game()
	var s: Dictionary = sim.state
	var npc: Dictionary = s.residents.values()[0]
	for index in range(100):
		Society.remember(s, npc.id, "trade", s.player, "Helpful trade", 5)
	check(npc.memories.size() == 16 and npc.relations[str(s.player)].trust == 100, "Bounded memories and trust")
	var goods: Dictionary = s.inventories[str(npc.id)].duplicate(true)
	check(Society.migrate(sim, npc.id, 2), "Migration schedules")
	for tick in range(600):
		sim.step()
	check(npc.settlement == 2 and s.inventories[str(npc.id)] == goods, "Migration preserves identity and possessions")
	s.treaty.open_trade = false
	var caravan: Dictionary = s.caravans.values()[0]
	caravan.in_transit = false
	check(not Regional.dispatch(sim, caravan), "Treaty suspends departures")
	var event := {"id": sim.new_id(), "payload": {"actor": npc.id, "threat": 100, "fidelity": npc.fidelity}}
	Inventory.produce(s, npc.id, "food", 4)
	Risk.resolve(sim, event)
	var after: String = sim.state_hash()
	Risk.resolve(sim, event)
	check(after == sim.state_hash(), "Conflict resolves once")
	check(npc.health < 100, "Non-graphic conflict changes health")
	var replay := Sim.new()
	replay.restore(sim.snapshot())
	for tick in range(3000):
		sim.step()
		replay.step()
	check(sim.state_hash() == replay.state_hash(), "Social consequences deterministic")
	print("Society/risk: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
