extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Save = preload("res://sim/persistence/save_manager.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
func _initialize() -> void:
	var rows: Array = []
	var failed: bool = false
	for population in [20, 100, 300]:
		var sim := Sim.new(417)
		sim.start_village(population)
		for warmup in range(1000):
			sim.step()
		var samples: Array[float] = []
		for tick in range(6000):
			var start := Time.get_ticks_usec()
			sim.step()
			samples.append(float(Time.get_ticks_usec() - start) / 1000.0)
		samples.sort()
		var save_start := Time.get_ticks_usec()
		Save.save_state(sim, OS.get_temp_dir().path_join("lw-benchmark.save"))
		var save_ms := float(Time.get_ticks_usec() - save_start) / 1000.0
		var file := FileAccess.open(OS.get_temp_dir().path_join("lw-benchmark.save"), FileAccess.READ)
		var size := file.get_length()
		file.close()
		var row := {"population": population, "ticks": 6000, "p50_ms": samples[3000], "p95_ms": samples[5700], "p99_ms": samples[5940], "max_ms": samples[-1], "save_ms": save_ms, "save_bytes": size, "memory_bytes": OS.get_static_memory_usage(), "invariants": Checks.validate(sim.state)}
		rows.append(row)
		print(JSON.stringify(row))
		failed = failed or not row.invariants.is_empty() or row.p99_ms > 100.0
	var output := FileAccess.open("res://docs/simulation_benchmark.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "cpu": OS.get_processor_name(), "os": OS.get_name(), "rows": rows}, "  "))
	output.close()
	quit(1 if failed else 0)
