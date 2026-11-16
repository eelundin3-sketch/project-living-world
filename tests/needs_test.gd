extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Needs = preload("res://sim/entities/needs.gd")
const Invariants = preload("res://sim/diagnostics/invariants.gd")
const Save = preload("res://sim/persistence/save_manager.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	var calm: Dictionary = Needs.levels(s)
	check(calm.hungry == 0 and calm.thirsty == 0 and calm.tired == 0 and calm.pain == 0, "A fresh character has no condition indicators")
	s.player_needs.hunger = 80; s.player_needs.thirst = 92; s.player_needs.fatigue = 60
	var levels: Dictionary = Needs.levels(s)
	check(levels.hungry == 3 and levels.thirsty == 4 and levels.tired == 2, "Hunger, thirst and tiredness map to severity levels")
	sim.submit("debug_injury", {"part": "left_shin", "damage": 40, "kind": "cut"}); sim.step()
	levels = Needs.levels(s)
	check(levels.pain >= 1 and levels.bleeding >= 2, "Injury produces pain and bleeding indicators")
	# Eating needs food; drinking needs a barrel.
	var food_before: int = s.inventories[str(s.player)].items.get("food", 0)
	sim.submit("eat"); sim.step()
	check(s.player_needs.hunger == 35 and s.inventories[str(s.player)].items.get("food", 0) == food_before - 1, "Eating consumes food and lowers hunger")
	var player: Dictionary = s.entities[str(s.player)]
	player.cell = [10, 10]
	sim.submit("drink"); sim.step()
	check(s.player_needs.thirst >= 90, "Cannot drink away from a well barrel")
	player.cell = s.entities[str(s.warehouse)].cell.duplicate()
	sim.submit("drink"); sim.step()
	check(s.player_needs.thirst <= 40, "Drinking beside the storehouse quenches thirst")
	# Mood tracks the other needs.
	s.player_needs.hunger = 95; s.player_needs.thirst = 95; s.player_needs.fatigue = 95; s.player_needs.stress = 80
	for tick in range(20): sim.step()
	check(Needs.levels(s).unhappy >= 3 and s.player_needs.mood < 35, "Neglected needs make the character unhappy")
	# Residents thirst, drink and stay within bounds over several days.
	var village := Sim.new(); village.start_game()
	for tick in range(14400 * 3): village.step()
	var drank := false
	for npc in village.state.residents.values():
		check(npc.thirst >= 0 and npc.thirst <= 100, "Resident thirst bounded")
		if npc.thirst < 60: drank = true
	check(drank, "Residents relieve thirst")
	check(Invariants.validate(village.state).is_empty(), "Invariants hold with thirst: " + str(Invariants.validate(village.state)))
	# Round trip through a save keeps needs and unique names.
	var copy := Sim.new(); copy.restore(village.snapshot())
	check(copy.state_hash() == village.state_hash(), "Restored state hash matches")
	check(copy.state.names_used.size() >= 16, "Name registry survives restore")
	if failures == 0: print("Needs: PASS")
	quit(failures)
