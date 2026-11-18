extends SceneTree
const Simulation = preload("res://sim/core/simulation.gd")
const Clock = preload("res://sim/core/sim_clock.gd")
const Canonical = preload("res://sim/core/canonical.gd")
var failures: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	var a := Simulation.new(17)
	var b := Simulation.new(17)
	for sim in [a, b]:
		for due in [1, 10, 100, 99999]:
			sim.submit("spawn_test", {}, due)
		var first: int = sim.schedule("fixture", 5)
		var second: int = sim.schedule("fixture", 5)
		for tick in range(100000):
			sim.step()
		check(sim.state.event_results == [first, second], "Equal-time events run once in ID order")
	check(a.state_hash() == b.state_hash(), "100,000 tick replay")
	var ids: Dictionary = {}
	for index in range(100000):
		var id: int = a.new_id()
		check(not ids.has(id), "Unique ID")
		ids[id] = true
	var c := Simulation.new(17)
	var d := Simulation.new(17)
	c.submit("spawn_test")
	d.submit("spawn_test")
	var clock_c := Clock.new()
	var clock_d := Clock.new()
	for index in range(10000):
		clock_c.advance(0.1, c)
		clock_d.advance(0.03, d)
		clock_d.advance(0.07, d)
	check(c.state.tick == 10000 and c.state_hash() == d.state_hash(), "Render delta independence")
	clock_c.paused = true
	var before: String = c.state_hash()
	clock_c.advance(5.0, c)
	check(before == c.state_hash(), "Paused state remains unchanged")
	check(Canonical.encode({"b": 2, "a": 1}) == Canonical.encode({"a": 1, "b": 2}), "Canonical key ordering")
	print("Kernel: %s (100k replay, IDs, events, frame cadence, pause)" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
