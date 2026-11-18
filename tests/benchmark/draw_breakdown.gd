extends SceneTree
## Which layers cost render time: hides one group at a time at zoom 0.5 and reports draw calls
## and render CPU. A diagnostic for the performance work, not a test.
var main: Node
func _initialize() -> void: call_deferred("run")
func _measure(perf: Control, label: String) -> void:
	for warm in range(20): await process_frame
	var calls := 0
	var cpu := 0.0
	var started := Time.get_ticks_usec()
	var frames := 0
	for i in range(60):
		await process_frame
		frames += 1
		if i % 6 == 0:
			perf._collect()
			calls += int(perf.stats.draw_calls); cpu += float(perf.stats.get("render_cpu_ms", 0.0))
	print("%-28s draws %5d  render_cpu %6.2f ms  frame %5.1f ms" % [label, calls / 10, cpu / 10.0, float(Time.get_ticks_usec() - started) / 1000.0 / frames])
func run() -> void:
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	var zoom := float(OS.get_environment("SOLO_ZOOM")) if OS.get_environment("SOLO_ZOOM") != "" else 0.5
	main.get_node("ObserverCamera").zoom = Vector2.ONE * zoom
	var view: Node2D = main.get_node("WorldView")
	var perf: Control = main.perf
	for warm in range(60): await process_frame
	await _measure(perf, "everything")
	view.shadows.visible = false
	await _measure(perf, "no shadows")
	view.shadows.visible = true
	view.background.visible = false
	await _measure(perf, "no background (grass)")
	view.background.visible = true
	view.landscape.visible = false
	await _measure(perf, "no landscape shader")
	view.landscape.visible = true
	for kind in ["tree", "wall", "furniture", "fixture", "rock", "door"]:
		for node in view.depth_objects.values(): if node.object_kind == kind: node.visible = false
		await _measure(perf, "no " + kind)
		for node in view.depth_objects.values(): node.visible = true
	for node in view.character_models.values(): node.visible = false
	await _measure(perf, "no characters")
	for node in view.character_models.values(): node.visible = true
	for node in view.decor_nodes.values(): node.visible = false
	await _measure(perf, "no decor (floors/plaza)")
	quit(0)
