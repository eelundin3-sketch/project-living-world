extends SceneTree
## Your look: dirt builds outdoors, the beard grows by the day, wounds bloody your clothes, a filthy
## customer pays more and a tidy one less, washing and a shave put it right (a shave costs coins,
## which go to the town), and old saves start clean.
const Sim = preload("res://sim/core/simulation.gd")
const Look = preload("res://sim/player/look.gd")
const Stalls = preload("res://sim/economy/stall_service.gd")
const BodyHealth = preload("res://sim/combat/body_health.gd")
const Context = preload("res://sim/player/context_actions.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)

func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	check(int(Look.of(s).dirt) == 0 and int(Look.of(s).beard) == 0, "You start clean and shaved")
	# Outdoors a while: dusty. A day on: a beard coming.
	var store: Array = s.entities[str(s.settlements["1"].warehouse)].cell
	s.entities[str(s.player)].cell = [store[0] + 2, store[1] + 6]
	var start_tick: int = int(s.tick)
	while int(s.tick) < (start_tick / 14400 + 1) * 14400 + 100:
		s.player_needs.hunger = 0; s.player_needs.thirst = 0; s.player_needs.fatigue = 0
		sim.step()
	check(int(Look.of(s).dirt) > 0, "Time outdoors makes you dusty (%d)" % Look.of(s).dirt)
	check(int(Look.of(s).beard) == 3, "A day's growth of beard (%d)" % Look.of(s).beard)
	# A cut bloodies your clothes.
	BodyHealth.injure(s, "left_forearm", 15, "cut")
	check(int(Look.of(s).blood) >= 20, "A wound shows on your clothes")
	# Prices: filthy pays more, tidy pays less.
	var keeper: Dictionary = {}
	for npc in s.residents.values():
		if npc.occupation not in ["Sheriff", "Child"]: keeper = npc; break
	Look.of(s).dirt = 100; Look.of(s).blood = 40
	check(Look.label(s) == "bloodied" and Look.price_pct(s) == 10, "A bloodied, filthy customer pays 10% more")
	var filthy_price: int = Stalls.price(s, int(keeper.settlement), "tool", true, int(keeper.id))
	# Wash at the well (it's by the storehouse), then a shave.
	s.entities[str(s.player)].cell = [store[0], store[1] + 6]
	check(load("res://sim/entities/needs.gd").near_water(s), "Standing at the well")
	Context.perform(sim, int(s.player), "wash")
	check(int(Look.of(s).dirt) == 0 and int(Look.of(s).blood) == 0, "Washing at the well gets you clean (%s)" % s.player_control.notice)
	var coins: int = int(s.accounts[str(s.player)])
	var treasury: int = int(s.accounts[str(s.settlements["1"].warehouse)])
	Look.of(s).beard = 80
	Context.perform(sim, int(s.player), "shave")
	check(int(Look.of(s).beard) == 0 and int(s.accounts[str(s.player)]) == coins - Look.SHAVE_COST and int(s.accounts[str(s.settlements["1"].warehouse)]) == treasury + Look.SHAVE_COST, "A shave costs 3 coins, paid to the town")
	var errors: Array = load("res://sim/diagnostics/invariants.gd").validate(s)
	check(errors.is_empty(), "Money is conserved (%s)" % str(errors))
	var clean_price: int = Stalls.price(s, int(keeper.settlement), "tool", true, int(keeper.id))
	check(clean_price < filthy_price, "Cleaned up, you pay less (%d against %d)" % [clean_price, filthy_price])
	# An old save without any look record starts clean.
	var old: Dictionary = sim.snapshot()
	old.player_status.erase("look")
	var loaded := Sim.new(); loaded.restore(old)
	check(int(Look.of(loaded.state).dirt) == 0, "An old save starts clean")
	var copy := Sim.new(); copy.restore(sim.snapshot())
	for i in range(300): sim.step(); copy.step()
	check(sim.state_hash() == copy.state_hash(), "Save, load and continue gives the same world")
	print("Look: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
