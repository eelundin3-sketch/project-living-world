extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	root.size = Vector2i(1280, 720)
	var samples: Array[float] = []
	var sim_samples: Array[float] = []
	var started := Time.get_ticks_usec()
	var previous: int = started
	var last_tick: int = -1
	while Time.get_ticks_usec() - started < 305000000:
		await process_frame
		var now := Time.get_ticks_usec()
		if now - started > 5000000:
			samples.append(float(now - previous) / 1000.0)
			if main.simulation.state.tick != last_tick:
				sim_samples.append(main.tick_ms)
		previous = now
		last_tick = main.simulation.state.tick
	samples.sort()
	sim_samples.sort()
	var results := {"engine": Engine.get_version_info().string, "cpu": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name(), "viewport": [1280, 720], "duration_seconds": 300, "frames": samples.size(), "p50_ms": percentile(samples, 0.5), "p95_ms": percentile(samples, 0.95), "p99_ms": percentile(samples, 0.99), "max_ms": samples[-1], "sim_p95_ms": percentile(sim_samples, 0.95), "memory_bytes": OS.get_static_memory_usage(), "nodes": get_node_count(), "chunks": main.simulation.state.world.chunks.size()}
	var file := FileAccess.open("res://docs/validation/frame_benchmark.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	file.close()
	print(JSON.stringify(results))
	main.queue_free()
	await process_frame
	quit(0)
func percentile(samples: Array[float], fraction: float) -> float:
	return samples[mini(samples.size() - 1, int(samples.size() * fraction))] if not samples.is_empty() else 0.0
