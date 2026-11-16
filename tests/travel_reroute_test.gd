extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const World = preload("res://sim/world/world_db.gd")
const Nav = preload("res://sim/movement/navigation.gd")
func _initialize() -> void:
	var sim := Sim.new()
	sim.start_game()
	var s: Dictionary = sim.state
	var player: Dictionary = s.entities[str(s.player)]
	var destination: Array = [player.cell[0] + 4, player.cell[1]]
	var route := Nav.request_path(s, player.cell, destination)
	if not route.ok or route.path.size() < 2:
		printerr("FAIL: unable to prepare route")
		quit(1)
		return
	s.player_path = route.path
	s.player_travel_goal = destination
	World.apply_mutation(s, s.player_path[0], true)
	for tick in range(60): sim.step()
	if player.cell != destination:
		printerr("FAIL: player did not reroute around a newly blocked cell")
		quit(1)
		return
	print("Travel rerouting: PASS")
	quit(0)
