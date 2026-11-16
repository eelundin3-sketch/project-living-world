extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Motion = preload("res://view/actors/animation_director.gd")
const Jobs = preload("res://sim/jobs/job_board.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
func _initialize() -> void:
	var sim := Sim.new()
	sim.start_game()
	var trees: Array = sim.state.entities.values().filter(func(e: Dictionary) -> bool: return e.kind == "tree")
	check(trees.size() == 580, "580 trees including dense groves across both settlements")
	var positions: Dictionary = {}
	for tree in trees:
		check(not positions.has(str(tree.cell)), "Unique tree cells")
		positions[str(tree.cell)] = true
	var motion := Motion.new()
	motion.update(sim.state, 0.016, false, 1)
	check(motion.cues.is_empty(), "Initial snapshot emits no historic sounds")
	var before := sim.state_hash()
	for frame in range(30): motion.update(sim.state, 0.016, false, 1)
	check(before == sim.state_hash(), "Presentation never mutates simulation")
	check(motion.cues.is_empty(), "Idle actors emit no footsteps")
	var frozen: float = motion.time
	motion.update(sim.state, 1, true, 4)
	check(motion.time == frozen and motion.cues.is_empty(), "Pause freezes wind and audio cues")
	var npc: Dictionary = sim.state.residents.values()[5]
	Jobs.refresh(sim)
	var job: Dictionary = sim.state.jobs.values().filter(func(j: Dictionary) -> bool: return j.item == "log")[0]
	check(Jobs.try_claim(sim.state, job.id, npc.id), "Animation fixture claims actual job")
	var visited: Dictionary = {}
	var old_amount := Inventory.amount(sim.state, npc.id, "log")
	var completed: bool = false
	for step in range(500):
		sim.state.tick += 2
		Jobs.advance(sim, npc.id)
		if npc.job == 0:
			completed = true
			break
		visited[job.state] = true
		var action := Motion.action_for(sim.state, sim.state.entities[str(npc.id)])
		if job.state == "PICKING_UP":
			check(action.action == "pickup" and Inventory.amount(sim.state, npc.id, "log") == old_amount, "Pickup anticipates atomic transfer")
		if job.state == "MOVING_TO_DEST":
			check(Inventory.amount(sim.state, npc.id, "log") == old_amount + 5, "Carried logs physically belong to worker")
		if job.state == "DEPOSITING":
			check(action.action == "drop" and Inventory.amount(sim.state, npc.id, "log") == old_amount + 5, "Drop pose precedes deposit commit")
	check(completed and visited.has_all(["WORKING", "PICKING_UP", "MOVING_TO_DEST", "DEPOSITING"]), "Readable full gathering sequence completes")
	check(Checks.validate(sim.state).is_empty(), "Handling phases conserve materials")
	motion.reset()
	motion.update(sim.state, 0, false, 1)
	var key := str(sim.state.player)
	sim.state.entities[key].cell[0] += 1
	var footsteps: int = 0
	for frame in range(20):
		motion.update(sim.state, 0.016, false, 1)
		for cue in motion.cues:
			if cue.kind == "step": footsteps += 1
	check(footsteps > 0, "Footstep cues follow travelled distance")
	motion.update(sim.state, 0.016, true, 1)
	check(motion.cues.is_empty(), "Paused contact cannot replay sound")
	for name in ["step_grass", "step_wood", "chop", "saw", "pickup", "drop", "fall", "wind"]:
		var audio: AudioStream = load("res://content/audio/" + name + ".wav")
		check(audio != null and audio.get_length() > 0, "Playable original sound: " + name)
	print("Animation/audio: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
