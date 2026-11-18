extends SceneTree
## Headless benchmark of the real game world (three towns, woodlands, sheriffs, construction),
## not the small test village. Records per-step times and where the time goes, per system.
## Run: godot --headless --path . --script res://tests/benchmark/full_game_benchmark.gd
## SOLO_BENCH_TICKS sets the length of the idle phase (default 3000 = five game minutes).
const Sim = preload("res://sim/core/simulation.gd")
const Probe = preload("res://sim/diagnostics/perf_probe.gd")
const Save = preload("res://sim/persistence/save_manager.gd")

func _phase(sim: RefCounted, name: String, ticks: int) -> Dictionary:
	Probe.take()
	var samples: Array[float] = []
	var started := Time.get_ticks_usec()
	for tick in range(ticks):
		var start := Time.get_ticks_usec()
		sim.step()
		samples.append(float(Time.get_ticks_usec() - start) / 1000.0)
	var wall := float(Time.get_ticks_usec() - started) / 1000.0
	samples.sort()
	var probe := Probe.take()
	var systems: Dictionary = {}
	for key in probe.totals:
		systems[key] = {"avg_ms": snappedf(float(probe.totals[key]) / 1000.0 / ticks, 0.001), "worst_ms": snappedf(float(probe.worst[key]) / 1000.0, 0.01)}
	var at := func(fraction: float) -> float: return snappedf(samples[clampi(int((samples.size() - 1) * fraction), 0, samples.size() - 1)], 0.001)
	var row := {"phase": name, "ticks": ticks, "total_ms": snappedf(wall, 0.1), "p50_ms": at.call(0.5), "p95_ms": at.call(0.95), "p99_ms": at.call(0.99), "p999_ms": at.call(0.999), "max_ms": snappedf(samples[-1], 0.01),
		"astar_calls": int(probe.counters.get("astar_calls", 0)), "astar_nodes": int(probe.counters.get("astar_nodes", 0)), "systems": systems}
	print(JSON.stringify(row))
	return row

func _initialize() -> void:
	var ticks := int(OS.get_environment("SOLO_BENCH_TICKS")) if OS.get_environment("SOLO_BENCH_TICKS") != "" else 3000
	var setup_start := Time.get_ticks_usec()
	var sim := Sim.new(417)
	sim.start_game()
	var setup_ms := float(Time.get_ticks_usec() - setup_start) / 1000.0
	print("setup_ms %.0f, entities %d, residents %d, jobs %d" % [setup_ms, sim.state.entities.size(), sim.state.residents.size(), sim.state.get("jobs", {}).size()])
	var rows: Array = []
	rows.append(_phase(sim, "warmup", 200))
	rows.append(_phase(sim, "idle", ticks))
	# A shot in town: villagers take cover and sheriffs respond.
	sim.submit("shotgun_toggle")
	sim.step()
	sim.submit("shotgun_fire", {"direction": [1000, 0]})
	rows.append(_phase(sim, "after_shot", 300))
	var save_start := Time.get_ticks_usec()
	Save.save_state(sim, OS.get_temp_dir().path_join("solo-full-benchmark.save"))
	var save_ms := float(Time.get_ticks_usec() - save_start) / 1000.0
	print("save_ms %.0f" % save_ms)
	var label := OS.get_environment("SOLO_BENCH_LABEL")
	if label != "":
		var output := FileAccess.open("res://docs/validation".path_join("full_game_benchmark_%s.json" % label), FileAccess.WRITE)
		output.store_string(JSON.stringify({"label": label, "engine": Engine.get_version_info().string, "cpu": OS.get_processor_name(), "setup_ms": setup_ms, "save_ms": save_ms, "jobs": sim.state.get("jobs", {}).size(), "rows": rows}, "  "))
		output.close()
	quit(0)
