extends SceneTree
## Doorway assist: after repeated bumps beside a door the player is slid into the building, and never
## otherwise.
const Sim = preload("res://sim/core/simulation.gd")
const World = preload("res://sim/world/world_db.gd")
const DoorAssist = preload("res://sim/player/door_assist.gd")
const Orient = preload("res://sim/world/orient.gd")
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)
func press(sim: RefCounted, direction: Array) -> void:
	sim.state.player_control.next_move = 0
	sim.submit("move_player", {"direction": direction}); sim.step()
func house(s: Dictionary) -> Dictionary:
	for entity in s.entities.values():
		if entity.kind == "home" and entity.has("house_type") and int(entity.get("door_side", 2)) == 2: return entity
	return {}
func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	var home: Dictionary = house(s)
	check(not home.is_empty(), "A south-facing house exists")
	var door: Array = home.door
	var pc: Dictionary = s.player_control
	var player: Dictionary = s.entities[str(s.player)]
	# One bump alone does nothing special.
	player.cell = [door[0] - 2, door[1] + 1]
	for t in range(3): sim.step()
	press(sim, [0, -1])
	check(player.cell == [door[0] - 2, door[1] + 1] and pc.get("bump", {}).get("count", 0) == 1, "One bump just bumps")
	# The second bump starts the assist, and the next presses slide to the door and in.
	press(sim, [0, -1])
	check(int(pc.get("bump", {}).get("count", 0)) == 2, "The second bump is counted")
	var steps := 0
	for i in range(8):
		press(sim, [0, -1])
		steps += 1
		if World.inside_building(s, player.cell) == home.id: break
	check(World.inside_building(s, player.cell) == home.id, "Pushing at the wall slides the player into the doorway and inside (%d presses, at %s)" % [steps, str(player.cell)])
	check(steps <= 6, "...in a handful of steps")
	# Every step was a single cell.
	# Walking away does not engage it.
	player.cell = [door[0] - 3, door[1] + 2]; pc.erase("bump"); pc.erase("assist")
	press(sim, [0, 1]); press(sim, [0, 1])
	check(not pc.has("assist"), "Walking away never engages it")
	# Too far from a door: nothing.
	player.cell = [door[0] - 12, door[1] + 1]; pc.erase("bump"); pc.erase("assist")
	for t in range(3): sim.step()
	press(sim, [0, -1]); press(sim, [0, -1]); press(sim, [0, -1])
	check(not pc.has("assist"), "Far from any door it never engages")
	# Sneaking keeps the player's own control.
	player.cell = [door[0] - 2, door[1] + 1]; pc.erase("bump"); pc.erase("assist"); pc.crouching = true
	press(sim, [0, -1]); press(sim, [0, -1]); press(sim, [0, -1])
	check(not pc.has("assist") and player.cell == [door[0] - 2, door[1] + 1], "Sneaking is never assisted")
	pc.crouching = false
	# Turned off.
	pc.door_assist = false; pc.erase("bump")
	press(sim, [0, -1]); press(sim, [0, -1]); press(sim, [0, -1])
	check(player.cell == [door[0] - 2, door[1] + 1], "It can be turned off")
	pc.door_assist = true
	# Only one cell per step, and a reload keeps it.
	player.cell = [door[0] - 2, door[1] + 1]; pc.erase("bump"); pc.erase("assist")
	for t in range(3): sim.step()
	press(sim, [0, -1]); press(sim, [0, -1])
	var before: Array = player.cell.duplicate()
	press(sim, [0, -1])
	check(absi(player.cell[0] - before[0]) + absi(player.cell[1] - before[1]) <= 1, "Assist moves one cell per step, never a jump")
	var copy := Sim.new(); copy.restore(sim.snapshot())
	check(copy.state_hash() == sim.state_hash(), "Assist state survives a reload")
	print("Door assist: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
