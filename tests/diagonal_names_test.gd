extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const World = preload("res://sim/world/world_db.gd")
const Names = preload("res://sim/entities/names.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void:
	# Diagonal movement: each WASD pair moves one cell on both axes.
	var cases := {"W+A": [-1, -1], "W+D": [1, -1], "S+A": [-1, 1], "S+D": [1, 1]}
	for label in cases:
		var sim := Sim.new(); sim.start_game()
		var player: Dictionary = sim.state.entities[str(sim.state.player)]
		var start: Array = player.cell.duplicate()
		sim.submit("move_player", {"direction": cases[label], "run": false}); sim.step()
		check(player.cell == [start[0] + cases[label][0], start[1] + cases[label][1]], label + " moves diagonally")
	# A diagonal may not slip between two blocked corner cells.
	var sim := Sim.new(); sim.start_game()
	var p: Dictionary = sim.state.entities[str(sim.state.player)]
	var origin: Array = p.cell.duplicate()
	World.apply_mutation(sim.state, [origin[0] + 1, origin[1]], true)
	sim.submit("move_player", {"direction": [1, 1], "run": false}); sim.step()
	check(p.cell == origin, "Diagonal cannot cut a blocked corner")
	# Names: every resident, the player and raiders are unique across the whole map.
	var full := Sim.new(); full.start_game()
	var seen: Dictionary = {}
	for entity in full.state.entities.values():
		if entity.kind in ["resident", "player"]:
			check(not seen.has(entity.name), "Unique name " + entity.name)
			seen[entity.name] = true
			check(entity.name.contains(" "), "Name has first and last part: " + entity.name)
	check(seen.size() >= 16, "Both settlements and the player are named")
	for index in range(250):
		var id := World.add_entity(full, "resident", Names.generate(full), [10, 10], 1)
		var name_value: String = full.state.entities[str(id)].name
		check(not seen.has(name_value), "No repeat after many draws: " + name_value)
		seen[name_value] = true
	# Determinism: same seed gives the same names.
	var again := Sim.new(); again.start_game()
	var twin := Sim.new(); twin.start_game()
	check(twin.state.entities[str(twin.state.player)].name == again.state.entities[str(again.state.player)].name, "Same seed gives same names")
	if failures == 0: print("Diagonals and names: PASS")
	quit(failures)
