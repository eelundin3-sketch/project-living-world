extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
const Save = preload("res://sim/persistence/save_manager.gd")
var failures: int = 0
func _initialize() -> void:
	var a := Sim.new(987)
	a.start_game()
	a.submit("risk", {"value": 70}, 20000)
	a.submit("route_block", {"blocked": true}, 30000)
	a.submit("route_block", {"blocked": false}, 31000)
	a.submit("travel", {"town": 2}, 40000)
	a.submit("travel", {"town": 1}, 70000)
	a.submit("treaty", {"open": false}, 80000)
	a.submit("treaty", {"open": true}, 82000)
	for tick in range(50000):
		a.step()
		if tick % 1000 == 0:
			validate(a)
	var saved := Save.save_state(a, OS.get_temp_dir().path_join("lw-full-soak.save"))
	if not saved.ok:
		printerr(saved)
		quit(1)
		return
	var b := Sim.new()
	if not Save.load_into(b, OS.get_temp_dir().path_join("lw-full-soak.save")).ok:
		quit(1)
		return
	for tick in range(50800):
		a.step()
		b.step()
		if tick % 1000 == 0:
			validate(a)
	if a.state_hash() != b.state_hash():
		failures += 1
		printerr("FAIL: full-game reload divergence")
	validate(a)
	print("Full game seven-day soak: %s; tick=%d; deliveries=%d; buildings=%d; hash=%s" % ["PASS" if failures == 0 else "FAIL", a.state.tick, a.state.completed_jobs, a.state.completed_buildings, a.state_hash()])
	quit(0 if failures == 0 else 1)
func validate(sim: RefCounted) -> void:
	var errors := Checks.validate(sim.state)
	if not errors.is_empty():
		failures += 1
		printerr("FAIL @ %d: %s" % [sim.state.tick, errors])
