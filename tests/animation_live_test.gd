extends SceneTree
const Character = preload("res://view/actors/drawn_character.gd")
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.world_audio.enabled = false
	main.world_audio.wind.stop()
	var observed: Dictionary = {}
	var sounds: Dictionary = {}
	for frame in range(6000):
		main.clock.advance(1.0 / 30.0, main.simulation)
		main.get_node("WorldView").animate(1.0 / 30.0, false, 1)
		var director = main.get_node("WorldView").motion
		for pose in director.actors.values():
			observed[pose.action] = true
		for cue in director.cues:
			sounds[cue.kind] = true
		if frame % 300 == 0:
			await process_frame
	for action in ["walk", "chop", "pickup", "carry", "drop", "saw", "build"]:
		if not observed.has(action):
			failures += 1
			printerr("FAIL: live animation missing " + action)
	for cue in ["step", "chop", "pickup", "drop", "saw"]:
		if not sounds.has(cue):
			failures += 1
			printerr("FAIL: live sound cue missing " + cue)
	var before: String = main.simulation.state_hash()
	var frozen: float = main.get_node("WorldView").motion.time
	for frame in range(30): main.get_node("WorldView").animate(0.033, true, 4)
	if before != main.simulation.state_hash() or frozen != main.get_node("WorldView").motion.time:
		failures += 1
		printerr("FAIL: paused presentation changed state")
	var figure := Character.new()
	root.add_child(figure)
	figure.setup(0, true, false)
	for step in range(33):
		var heading := float(step) * TAU / 32.0
		figure.set_pose({"heading": heading, "action": "idle"})
		if not figure.forward.is_equal_approx(Vector2.from_angle(heading)) or absf(figure.across.dot(figure.forward)) > 0.001:
			failures += 1
			printerr("FAIL: drawn body does not follow heading")
	_verify_blends(figure)
	figure.queue_free()
	print("Live animation: %s; actions=%s; sound cues=%s" % ["PASS" if failures == 0 else "FAIL", observed.keys(), sounds.keys()])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _verify_blends(figure: Node2D) -> void:
	var base := {"heading": 0.0, "phase": 0.42, "gait_phase": 0.76, "action": "idle"}
	figure.set_pose(base)
	for action in ["walk", "run", "walk", "idle", "pickup", "carry", "drop", "chop", "saw", "build", "harvest", "eat", "ready", "aim", "shoot", "punch", "shove", "hit", "stagger", "rest", "down", "idle"]:
		var next := base.duplicate()
		next.action = action
		next.moving = action in ["walk", "run", "carry"]
		next.cargo_item = "log"
		next.cargo_quantity = 2 if action in ["pickup", "carry", "drop"] else 0
		var before: Dictionary = figure.frame.duplicate(true)
		figure.set_pose(next, 1.0 / 60.0)
		_check(_same_joints(figure.frame, before), "No first-frame jump into " + action)
		figure.set_pose(next, 0.0)
		_check(_same_joints(figure.frame, before), "Paused pose blend holds for " + action)
		for i in range(12):
			figure.set_pose(next, 1.0 / 60.0)
		var settled: Dictionary = figure.frame.duplicate(true)
		figure.set_pose(next)
		_check(_same_joints(figure.frame, settled), "Blend reaches target pose for " + action)
	for running in [false, true]:
		var meters := 3.25 if running else 2.0
		var previous: PackedVector2Array = figure.leg_joints(-1, Vector2(0, -23), 0.1 * TAU, true, running)
		var current: PackedVector2Array = figure.leg_joints(-1, Vector2(0, -23), 0.2 * TAU, true, running)
		_check(is_equal_approx(current[2].x + 0.1 * meters * 24.0, previous[2].x), "Stance holds foot in world space")

func _same_joints(actual: Dictionary, expected: Dictionary) -> bool:
	for part in ["head", "chest", "hip", "left_arm", "right_arm", "left_leg", "right_leg", "origin", "tilt"]:
		if actual[part] != expected[part]: return false
	return true

func _check(ok: bool, label: String) -> void:
	if ok: return
	failures += 1
	printerr("FAIL: " + label)
