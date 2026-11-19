extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Motion = preload("res://view/actors/animation_director.gd")
const Health = preload("res://sim/combat/body_health.gd")
const World = preload("res://sim/world/world_db.gd")
const TownLayout = preload("res://sim/world/town_layout.gd")
## A walkable straight run of `length` cells east of the town, all off the roads (or all on one).
func corridor(s: Dictionary, length: int, want_road: bool) -> Array:
	for y in range(-40, 120):
		for x in range(-40, 300):
			var clear: bool = true
			for dx in range(length):
				if not World.walkable(s, [x + dx, y]) or TownLayout.on_road(s, [x + dx, y]) != want_road or (want_road and TownLayout.road_kind(s, [x + dx, y]) != 2): clear = false; break
			if clear: return [x, y]
	return []
var failures: int=0
func check(value: bool,label: String) -> void:
	if not value: failures+=1; printerr("FAIL: "+label)
func _initialize() -> void:
	var walking:=Sim.new(); walking.start_game()
	var running:=Sim.new(); running.start_game()
	# Off the roads: five cells a second walking, ten running.
	var open_ground: Array = corridor(walking.state, 12, false)
	walking.state.entities[str(walking.state.player)].cell = open_ground.duplicate()
	running.state.entities[str(running.state.player)].cell = open_ground.duplicate()
	var walk_start: Array=walking.state.entities[str(walking.state.player)].cell.duplicate()
	for tick in range(6):
		walking.submit("move_player", {"direction":[1,0],"run":false}); walking.step()
		running.submit("move_player", {"direction":[1,0],"run":true}); running.step()
	var walked: int=walking.state.entities[str(walking.state.player)].cell[0]-walk_start[0]
	var ran: int=running.state.entities[str(running.state.player)].cell[0]-walk_start[0]
	check(walked==3 and ran==6,"Sprint travels twice the distance of walking over the same ticks")
	# On a road between the towns walking is about a third quicker.
	var road_walk:=Sim.new(); road_walk.start_game()
	var on_link: Array = corridor(road_walk.state, 16, true)
	check(not on_link.is_empty(), "A straight stretch of road between towns exists")
	if not on_link.is_empty():
		road_walk.state.entities[str(road_walk.state.player)].cell = on_link.duplicate()
		for tick in range(20):
			if road_walk.state.tick + 1 >= road_walk.state.player_control.next_move: road_walk.submit("move_player", {"direction":[1,0],"run":false})
			road_walk.step()
		var road_cells: int = road_walk.state.entities[str(road_walk.state.player)].cell[0] - on_link[0]
		check(road_cells >= 12 and road_cells <= 14, "Walking a road between towns is about 30%% quicker (%d cells in 20 ticks, 10 off the roads)" % road_cells)
	var blocked_cell: Array=[running.state.entities[str(running.state.player)].cell[0]+1,walk_start[1]]
	World.apply_mutation(running.state,blocked_cell,true)
	var stamina_before: int=running.state.player_health.stamina
	running.submit("move_player",{"direction":[1,0],"run":true}); running.step()
	check(running.state.player_health.stamina==stamina_before,"Running into a wall does not spend stamina")
	var sim:=Sim.new(); sim.start_game(); var s: Dictionary=sim.state
	var player: Dictionary=s.entities[str(s.player)]; var before: Array=player.cell.duplicate(); var stamina: int=s.player_health.stamina
	sim.submit("move_player",{"direction":[1,0],"run":true}); sim.step()
	check(player.cell[0]==before[0]+1 and s.player_control.running,"Shift run advances a movement step")
	check(s.player_health.stamina==stamina-1,"Running consumes stamina")
	var motion:=Motion.new(); motion.update(s,0.01,false,1); motion.update(s,0.1,false,1)
	check(Motion.action_for(s,player).action=="run","Run has a distinct animation state")
	for tick in range(3): sim.step()
	check(s.player_health.stamina>stamina-1 and not s.player_control.running,"Stamina recovers after release")
	s.player_health.stamina=0; var location: Array=player.cell.duplicate()
	sim.submit("move_player",{"direction":[1,0],"run":true}); sim.step()
	check(not s.player_control.running and Health.move_delay(s)>=1,"Empty stamina disables sprint")
	var main_scene=load("res://app/main.tscn").instantiate(); root.add_child(main_scene); await process_frame; main_scene.set_process(false)
	# Exercise the real input queue, fixed simulation clock and visual interpolation
	# together at 60 FPS; each frame after startup should advance the player.
	var live_state: Dictionary = main_scene.simulation.state
	var start_cell: Array = corridor(live_state, 14, false)
	check(not start_cell.is_empty(), "A clear walking corridor is available")
	if not start_cell.is_empty():
		live_state.entities[str(live_state.player)].cell = start_cell.duplicate()
		main_scene.get_node("WorldView").snap_visuals()
		var previous_x: float = main_scene.get_node("WorldView").motion.actors[str(live_state.player)].position.x
		var idle_frames: int = 0
		Input.action_press("walk_right")
		for frame in range(120):
			main_scene._process(1.0 / 60.0)
			var current_x: float = main_scene.get_node("WorldView").motion.actors[str(live_state.player)].position.x
			if frame >= 20 and current_x - previous_x < 0.001: idle_frames += 1
			previous_x = current_x
		Input.action_release("walk_right")
		check(idle_frames == 0, "Held walking moves continuously between grid steps")
		check(live_state.entities[str(live_state.player)].cell[0] - start_cell[0] == 10, "Held walking respects its five-cells-per-second cadence")
	var camera=main_scene.get_node("ObserverCamera"); var initial: float=camera.zoom.x
	var wheel:=InputEventMouseButton.new(); wheel.button_index=MOUSE_BUTTON_WHEEL_UP; wheel.pressed=true; main_scene._input(wheel)
	check(camera.zoom.x>initial,"Wheel zooms in")
	var magnify:=InputEventMagnifyGesture.new(); magnify.factor=1.25; main_scene._input(magnify)
	check(camera.zoom.x>initial,"Trackpad pinch zooms in")
	main_scene.player_panels.show_mode("inventory"); var heldzoom: float=camera.zoom.x
	var wheel_down:=InputEventMouseButton.new(); wheel_down.button_index=MOUSE_BUTTON_WHEEL_DOWN; wheel_down.pressed=true; main_scene._input(wheel_down)
	check(camera.zoom.x<heldzoom and main_scene.player_panels.visible,"Zoom works with inventory panel open")
	var walk_zoom: Vector2 = camera.zoom
	camera.adjust_zoom(0.001)
	var regional: Dictionary = main_scene.simulation.state
	var town_gap: int = regional.entities[str(regional.settlements["2"].warehouse)].cell[0] - regional.entities[str(regional.settlements["1"].warehouse)].cell[0]
	check(camera.get_viewport_rect().size.x / camera.zoom.x > town_gap * 24.0, "Regional zoom can frame both villages")
	camera.adjust_zoom(0.5)
	check(is_equal_approx(camera.zoom.x, 0.06), "Zoom stops at the regional limit")
	camera.zoom = walk_zoom
	main_scene.player_panels.show_mode("")
	var director = main_scene.get_node("WorldView").motion
	main_scene.get_node("WorldView").snap_visuals()
	director.update(main_scene.simulation.state,0.016,false,1)
	var player_key: String = str(main_scene.simulation.state.player)
	var anchor: Vector2 = director.actors[player_key].position
	main_scene.get_node("WorldView")._sync_characters()
	var figure = main_scene.get_node("WorldView").character_models[player_key]
	figure.set_pose({"position": anchor, "heading": 0.0, "move_direction": Vector2.RIGHT})
	var walk: PackedVector2Array = figure.leg_joints(-1, Vector2(0, -23), 0.0, true, false)
	var run: PackedVector2Array = figure.leg_joints(-1, Vector2(0, -23), 0.0, true, true)
	check(run[2].x > walk[2].x, "Run reaches farther on foot contact")
	walk = figure.leg_joints(-1, Vector2(0, -23), 0.47 * TAU, true, false)
	run = figure.leg_joints(-1, Vector2(0, -23), 0.47 * TAU, true, true)
	var trailing: PackedVector2Array = figure.leg_joints(1, Vector2(0, -23), 0.47 * TAU, true, true)
	check(run[2].y < walk[2].y and trailing[2].y < walk[2].y, "Sprint includes a brief airborne phase")
	var hash_before: String = main_scene.simulation.state_hash()
	director.player_aiming = true
	for angle in [0.0, PI / 4.0, PI / 2.0, PI, -PI / 2.0, -PI / 4.0]:
		director.player_aim_position = anchor + Vector2.from_angle(angle) * 100
		director.update(main_scene.simulation.state,0.016,false,1)
		check(absf(angle_difference(director.actors[player_key].heading, angle)) < 0.001,"Right-mouse aim follows cursor at each angle")
		main_scene.get_node("WorldView")._sync_characters()
		check(figure is Node2D and figure.get_child_count() == 0, "Character is drawn directly in 2D")
		check(figure.forward.is_equal_approx(Vector2.from_angle(angle)), "Drawn body turns with cursor heading")
	check(main_scene.simulation.state_hash() == hash_before,"Turning is presentation-only and does not change simulation")
	var down:=InputEventMouseButton.new(); down.button_index=MOUSE_BUTTON_RIGHT; down.pressed=true; main_scene._unhandled_input(down)
	check(main_scene.aiming,"Right mouse starts aiming")
	down.pressed=false; main_scene._input(down)
	check(not main_scene.aiming,"Right mouse release ends aiming even over UI")
	main_scene.queue_free(); await process_frame
	print("Player mobility/zoom: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
