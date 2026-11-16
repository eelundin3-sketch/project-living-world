extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Unarmed = preload("res://sim/player/unarmed.gd")
const World = preload("res://sim/world/world_db.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
const Motion = preload("res://view/actors/animation_director.gd")
const Jobs = preload("res://sim/jobs/job_board.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var sim := Sim.new(712)
	sim.start_game()
	var s: Dictionary = sim.state
	var npc: Dictionary = s.residents.values()[0]
	var target: Dictionary = s.entities[str(npc.id)]
	s.entities[str(s.player)].cell = [110, 80]
	target.cell = [111, 80]
	World.apply_mutation(s, [110, 80], false)
	World.apply_mutation(s, [111, 80], false)
	World.apply_mutation(s, [112, 80], false)
	npc.health = 100
	Jobs.refresh(sim)
	var job: Dictionary = s.jobs.values()[0]
	check(Jobs.try_claim(s, job.id, npc.id), "Target can have a job when struck")
	check(Unarmed.begin(s, "punch", [1000, 0]), "Punch starts with a direction")
	var director := Motion.new()
	director.update(s, 0.016, false, 1)
	var before_phase: float = director.actors[str(s.player)].phase
	director.update(s, 0.016, false, 1)
	check(director.actors[str(s.player)].phase > before_phase, "Punch animation moves between simulation ticks")
	check(not Unarmed.begin(s, "punch", [1000, 0]), "Attack cooldown rejects repeated strikes")
	for i in range(2): s.tick += 1; Unarmed.update(sim)
	check(npc.health == 100, "Punch does not damage before the impact frame")
	s.tick += 1; Unarmed.update(sim)
	check(npc.health == 100 - 6 and npc.impact_until > s.tick, "Punch damages and staggers a person in front")
	check(npc.job == 0 and job.owner == 0, "Impact releases a worker's job and reservation")
	check(Motion.action_for(s, target).action == "hit", "Damage produces a hit pose")
	var saved: Dictionary = sim.snapshot()
	var copy := Sim.new(); copy.restore(saved)
	check(copy.state_hash() == sim.state_hash(), "Attack and reaction state survive restore")
	for i in range(12): s.tick += 1; Unarmed.update(sim)
	check(Unarmed.begin(s, "shove", [1000, 0]), "Shove starts after cooldown")
	for i in range(3): s.tick += 1; Unarmed.update(sim)
	check(target.cell == [112, 80] and npc.health == 100 - 6, "Shove pushes a person without punch damage")
	check(Motion.action_for(s, target).action in ["fall", "stagger"], "Shove makes the person fall")
	for i in range(12): s.tick += 1; Unarmed.update(sim)
	target.cell = [111, 80]
	World.apply_mutation(s, [112, 80], true)
	check(Unarmed.begin(s, "shove", [1000, 0]), "Second shove starts")
	for i in range(3): s.tick += 1; Unarmed.update(sim)
	check(target.cell == [111, 80], "Shove cannot push a person into a wall")
	for i in range(12): s.tick += 1; Unarmed.update(sim)
	check(Unarmed.begin(s, "punch", [-1000, 0]), "Punch in opposite direction starts")
	for i in range(3): s.tick += 1; Unarmed.update(sim)
	check(npc.health == 100 - 6, "Punch does not hit a person behind the player")
	check(Checks.validate(s).is_empty(), "Unarmed impacts preserve inventory and job invariants")
	var main = load("res://app/main.tscn").instantiate()
	root.add_child(main); await process_frame; main.set_process(false)
	var left := InputEventMouseButton.new(); left.button_index = MOUSE_BUTTON_LEFT; left.pressed = true
	main._unhandled_input(left)
	main._process(0.016)
	check(main.pointer_held and main.action_pointer.active and main.get_node("WorldView").motion.player_ready, "Left hold displays the pointer and ready stance")
	var player_pose: Dictionary = main.get_node("WorldView").motion.actors[str(main.simulation.state.player)]
	check(player_pose.action == "ready", "Held pointer produces a ready pose")
	left.pressed = false; main._input(left)
	main._process(0.016)
	check(not main.pointer_held and not main.action_pointer.active, "Releasing left hides the pointer")
	var right := InputEventMouseButton.new(); right.button_index = MOUSE_BUTTON_RIGHT; right.pressed = true
	main._unhandled_input(right)
	left.pressed = true; main._unhandled_input(left)
	check(main.simulation.state.commands.any(func(command: Dictionary) -> bool: return command.kind == "player_strike" and command.payload.kind == "punch"), "Right hold plus left press queues one punch")
	var space := InputEventKey.new(); space.physical_keycode = KEY_SPACE; space.pressed = true
	main._unhandled_input(space)
	check(not main.clock.paused and main.simulation.state.commands.any(func(command: Dictionary) -> bool: return command.kind == "player_strike" and command.payload.kind == "shove"), "Space queues a shove")
	var pause_key := InputEventKey.new(); pause_key.physical_keycode = KEY_P; pause_key.pressed = true
	main._unhandled_input(pause_key)
	check(main.clock.paused, "P pauses the game")
	main.queue_free(); await process_frame
	print("Unarmed controls: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
