extends SceneTree
## Carrying weight: a heavy pack slows your walk, an overload stops you running and tires you,
## a backpack carries more, and none of it disturbs save/load.
const Sim = preload("res://sim/core/simulation.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Encumbrance = preload("res://sim/player/encumbrance.gd")
const Outfits = preload("res://sim/entities/outfits.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)

func _game() -> RefCounted:
	var sim := Sim.new(); sim.start_game()
	var s: Dictionary = sim.state
	s.player_needs.fatigue = 0; s.player_health.stamina = 100
	return sim

## Cells of a fixed route walked in `ticks` ticks.
func _walked(sim: RefCounted, ticks: int) -> int:
	var s: Dictionary = sim.state
	var start: Array = s.entities[str(s.player)].cell
	var goal: Array = []
	for dx in range(30, 50):
		for dy in [0, 1, -1, 2, -2]:
			var route := Nav.request_path(s, start, [start[0] + dx, start[1] + dy])
			if route.ok and route.path.size() >= 30: goal = [start[0] + dx, start[1] + dy]; break
		if not goal.is_empty(): break
	var route := Nav.request_path(s, start, goal)
	s.player_path = route.path
	var total: int = route.path.size()
	for i in range(ticks): sim.step()
	return total - s.player_path.size()

func _initialize() -> void:
	var sim := _game(); var s: Dictionary = sim.state
	check(Encumbrance.band(s) == 0, "The starting kit is a light load (%s)" % Encumbrance.describe(s, s.player))
	check(Encumbrance.limit_tenths(s, s.player) == Encumbrance.BASE_LIMIT + Encumbrance.PACK_BONUS, "The backpack you start with adds to what you can carry")
	var light: int = _walked(sim, 24)
	var heavy_sim := _game(); var hs: Dictionary = heavy_sim.state
	Inventory.produce(hs, hs.player, "log", 12)   # 72.0 on top of the kit: overloaded
	check(Encumbrance.band(hs) == 2, "Twelve logs overload you (%s)" % Encumbrance.describe(hs, hs.player))
	var heavy: int = _walked(heavy_sim, 24)
	check(heavy < light, "An overloaded walk covers less ground (%d cells against %d)" % [heavy, light])
	# Running is refused while overloaded, with a notice.
	hs.player_path = []
	hs.player_control.next_move = 0
	heavy_sim.submit("move_player", {"direction": [1, 0], "run": true}); heavy_sim.step()
	check(not bool(hs.player_control.get("running", false)), "No running under an overload")
	check(str(hs.player_control.notice).contains("run") or str(hs.player_control.notice).contains("hardly"), "...and you are told why (%s)" % hs.player_control.notice)
	check(int(heavy_sim.state.player_control.get("travel_run", false)) == 0 or not heavy_sim._can_run_route(), "A route can't be run either")
	# The condition icon shows it.
	var Needs = load("res://sim/entities/needs.gd")
	check(int(Needs.levels(hs).get("overloaded", 0)) == 2, "The Overloaded condition shows")
	# Overloaded tiredness builds faster than a light load's.
	var tired_light := _game(); var tired_heavy := _game()
	Inventory.produce(tired_heavy.state, tired_heavy.state.player, "log", 12)
	for sim_case in [tired_light, tired_heavy]:
		sim_case.state.player_needs.idle_ticks = 0
		for i in range(1200):
			sim_case.state.player_control.next_move = sim_case.state.tick + 1   # keep "moving"
			sim_case.step()
	check(int(tired_heavy.state.player_needs.fatigue) > int(tired_light.state.player_needs.fatigue), "An overload tires you faster (%d against %d)" % [tired_heavy.state.player_needs.fatigue, tired_light.state.player_needs.fatigue])
	# Without the backpack you carry less.
	Outfits.take_off(s, s.player, "pack")
	check(Encumbrance.limit_tenths(s, s.player) == Encumbrance.BASE_LIMIT, "Taking the backpack off lowers the limit")
	# Save, load and carry on: same world.
	var copy := Sim.new(); copy.restore(heavy_sim.snapshot())
	for i in range(80): heavy_sim.step(); copy.step()
	check(heavy_sim.state_hash() == copy.state_hash(), "Save, load and continue gives the same world")
	print("Encumbrance: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
