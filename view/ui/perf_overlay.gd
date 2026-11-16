extends Control
## Performance tab in the top-right corner for analysis. A collapsed tab shows the frame rate;
## click it (or press F4) for frame-time statistics, a frame graph, render counters, simulation
## and world figures. "Record" writes one CSV row per second to user://perf_log.csv.
signal toggled(expanded: bool)
const WINDOW := 240
const WIDTH := 268.0
const LOG_PATH := "user://perf_log.csv"
var main: Node
var expanded: bool = false
var frames: Array[float] = []   # milliseconds per frame, newest last
var recording: bool = false
var log_file: FileAccess
var log_timer: float = 0.0
var redraw_timer: float = 0.0
var stats: Dictionary = {}
var ticks_this_second: int = 0
var last_tick: int = -1
var tick_rate: float = 0.0
var tick_clock: float = 0.0
var hover: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Called once per rendered frame with the frame time in seconds.
func sample(delta: float) -> void:
	frames.append(delta * 1000.0)
	if frames.size() > WINDOW: frames.pop_front()
	tick_clock += delta
	if main != null and last_tick >= 0 and main.simulation.state.tick != last_tick: ticks_this_second += main.simulation.state.tick - last_tick
	if main != null: last_tick = main.simulation.state.tick
	if tick_clock >= 1.0:
		tick_rate = float(ticks_this_second) / tick_clock
		ticks_this_second = 0
		tick_clock = 0.0
		if recording: _write_row()
	redraw_timer += delta
	if redraw_timer >= (0.1 if expanded else 0.25):
		redraw_timer = 0.0
		_collect()
		queue_redraw()

func _percentile(sorted: Array, fraction: float) -> float:
	if sorted.is_empty(): return 0.0
	return sorted[clampi(int(float(sorted.size() - 1) * fraction), 0, sorted.size() - 1)]

func _collect() -> void:
	var sorted: Array = frames.duplicate()
	sorted.sort()
	var total := 0.0
	for value in frames: total += value
	var average: float = total / maxf(1.0, float(frames.size()))
	stats = {"fps": Performance.get_monitor(Performance.TIME_FPS), "avg": average, "p50": _percentile(sorted, 0.5), "p95": _percentile(sorted, 0.95), "p99": _percentile(sorted, 0.99),
		"max": sorted.back() if not sorted.is_empty() else 0.0, "min": sorted.front() if not sorted.is_empty() else 0.0,
		"fps_avg": 1000.0 / maxf(0.001, average), "fps_low": 1000.0 / maxf(0.001, _percentile(sorted, 0.99)),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), "objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"prims": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, "video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0}
	if main != null:
		var s: Dictionary = main.simulation.state
		var world: Node = main.get_node("WorldView")
		var camera: Camera2D = main.get_node("ObserverCamera")
		stats.merge({"tick": s.tick, "tick_ms": main.tick_ms, "tick_rate": tick_rate, "speed": main.clock.speed, "paused": main.clock.paused,
			"entities": s.entities.size(), "residents": s.get("residents", {}).size(), "depth_objects": world.depth_objects.size(), "decor": world.decor_nodes.size(),
			"characters": world.character_models.size(), "zoom": camera.zoom.x, "far": world.is_far()}, true)

func _write_row() -> void:
	if log_file == null: return
	log_file.store_line("%d,%.1f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d,%d,%.1f,%d,%d,%.2f" % [stats.get("tick", 0), stats.get("fps_avg", 0.0), stats.get("avg", 0.0), stats.get("p95", 0.0), stats.get("p99", 0.0), stats.get("max", 0.0), stats.get("tick_ms", 0.0),
		stats.get("draw_calls", 0), stats.get("objects", 0), stats.get("nodes", 0), stats.get("memory_mb", 0.0), stats.get("entities", 0), stats.get("depth_objects", 0), stats.get("zoom", 1.0)])
	log_file.flush()

func set_recording(value: bool) -> void:
	recording = value
	if recording:
		log_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
		if log_file == null: recording = false; return
		log_file.store_line("tick,fps,avg_ms,p95_ms,p99_ms,max_ms,sim_tick_ms,draw_calls,objects,nodes,memory_mb,entities,depth_objects,zoom")
	else:
		log_file = null  # closing the handle flushes the file

func _rects() -> Dictionary:
	var left := size.x - WIDTH - 10.0
	var rects := {"tab": Rect2(left, 10, WIDTH, 26)}
	if expanded:
		rects["record"] = Rect2(left + WIDTH - 82, 42, 76, 22)
	return rects

func _input(event: InputEvent) -> void:
	var rects := _rects()
	if event is InputEventMouseMotion:
		var found := ""
		for key in rects:
			if rects[key].has_point(event.position): found = key
		if found != hover: hover = found; queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if rects.has("record") and rects.record.has_point(event.position):
			set_recording(not recording); get_viewport().set_input_as_handled(); queue_redraw()
		elif rects.tab.has_point(event.position):
			set_expanded(not expanded); get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F4:
		set_expanded(not expanded)

func set_expanded(value: bool) -> void:
	expanded = value
	_collect()
	queue_redraw()
	toggled.emit(expanded)

static func tone(ms: float) -> Color:
	return Color("7fd16a") if ms <= 17.5 else (Color("e3c14f") if ms <= 33.5 else Color("e0654a"))

func _draw() -> void:
	if stats.is_empty(): return
	var font: Font = ThemeDB.fallback_font
	var rects := _rects()
	var tab: Rect2 = rects.tab
	var panel := Color(0.08, 0.07, 0.05, 0.9)
	var edge := Color("87734e")
	draw_rect(tab, panel)
	draw_rect(tab, Color("c79a3e") if hover == "tab" else edge, false, 1.5)
	var fps_color := tone(1000.0 / maxf(1.0, float(stats.fps)))
	draw_string(font, tab.position + Vector2(10, 18), "PERF", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f0e4c8"))
	draw_string(font, tab.position + Vector2(WIDTH - 118, 18), "%d fps" % int(stats.fps), HORIZONTAL_ALIGNMENT_RIGHT, 80, 14, fps_color)
	draw_string(font, tab.position + Vector2(WIDTH - 34, 18), "▾" if expanded else "▸", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c9bd9e"))
	if recording: draw_circle(tab.position + Vector2(62, 13), 4.5, Color("e0443a"))
	if not expanded: return
	var left := tab.position.x
	var body := Rect2(left, 40, WIDTH, 372)
	draw_rect(body, panel)
	draw_rect(body, edge, false, 1.0)
	var rec: Rect2 = rects.record
	draw_rect(rec, Color("7a2d27") if recording else Color("4a3a24"))
	draw_rect(rec, Color("c79a3e") if hover == "record" else edge, false, 1.0)
	draw_string(font, rec.position + Vector2(0, 15), "● Stop" if recording else "● Record", HORIZONTAL_ALIGNMENT_CENTER, rec.size.x, 12, Color("f0e4c8"))
	var y := 58.0
	var x := left + 10.0
	draw_string(font, Vector2(x, y), "FRAME  (last %d)" % frames.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c9bd9e"))
	y += 18
	_pair(font, x, y, "fps avg", "%.0f" % stats.fps_avg, tone(stats.avg)); _pair(font, x + 128, y, "1% low", "%.0f" % stats.fps_low, tone(stats.p99)); y += 16
	_pair(font, x, y, "avg ms", "%.1f" % stats.avg, tone(stats.avg)); _pair(font, x + 128, y, "p50 ms", "%.1f" % stats.p50, tone(stats.p50)); y += 16
	_pair(font, x, y, "p95 ms", "%.1f" % stats.p95, tone(stats.p95)); _pair(font, x + 128, y, "p99 ms", "%.1f" % stats.p99, tone(stats.p99)); y += 16
	_pair(font, x, y, "max ms", "%.1f" % stats.max, tone(stats.max)); _pair(font, x + 128, y, "cpu ms", "%.1f" % stats.process_ms, Color("f0e4c8")); y += 8
	# Frame-time graph: one bar per frame, with 60 fps and 30 fps guide lines.
	var graph := Rect2(x, y + 6, WIDTH - 20, 56)
	draw_rect(graph, Color(0, 0, 0, 0.4))
	var scale_ms := 40.0
	for guide in [16.7, 33.3]:
		var gy: float = graph.end.y - graph.size.y * guide / scale_ms
		draw_line(Vector2(graph.position.x, gy), Vector2(graph.end.x, gy), Color(1, 1, 1, 0.18), 1.0)
	var bar := graph.size.x / float(WINDOW)
	for index in range(frames.size()):
		var value: float = frames[index]
		var height: float = minf(graph.size.y, graph.size.y * value / scale_ms)
		draw_rect(Rect2(graph.position.x + index * bar, graph.end.y - height, maxf(1.0, bar - 0.2), height), tone(value))
	draw_string(font, graph.position + Vector2(2, 10), "60", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.5))
	y = graph.end.y + 18
	draw_string(font, Vector2(x, y), "RENDER", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c9bd9e")); y += 16
	_pair(font, x, y, "draws", str(stats.draw_calls), Color("f0e4c8")); _pair(font, x + 128, y, "objects", str(stats.objects), Color("f0e4c8")); y += 16
	_pair(font, x, y, "prims", str(stats.primitives), Color("f0e4c8")); _pair(font, x + 128, y, "nodes", str(stats.nodes), Color("f0e4c8")); y += 16
	_pair(font, x, y, "mem MB", "%.0f" % stats.memory_mb, Color("f0e4c8")); _pair(font, x + 128, y, "video MB", "%.0f" % stats.video_mb, Color("f0e4c8")); y += 22
	if stats.has("tick"):
		draw_string(font, Vector2(x, y), "SIMULATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c9bd9e")); y += 16
		_pair(font, x, y, "tick", str(stats.tick), Color("f0e4c8")); _pair(font, x + 128, y, "ticks/s", "%.1f" % stats.tick_rate, Color("f0e4c8")); y += 16
		_pair(font, x, y, "ms / tick", "%.2f" % stats.tick_ms, tone(stats.tick_ms * 4.0)); _pair(font, x + 128, y, "speed", ("paused" if stats.paused else "x%d" % stats.speed), Color("f0e4c8")); y += 22
		draw_string(font, Vector2(x, y), "WORLD", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c9bd9e")); y += 16
		_pair(font, x, y, "entities", str(stats.entities), Color("f0e4c8")); _pair(font, x + 128, y, "residents", str(stats.residents), Color("f0e4c8")); y += 16
		_pair(font, x, y, "sorted", str(stats.depth_objects), Color("f0e4c8")); _pair(font, x + 128, y, "characters", str(stats.characters), Color("f0e4c8")); y += 16
		_pair(font, x, y, "layers", str(stats.decor), Color("f0e4c8")); _pair(font, x + 128, y, "zoom", "%.2fx%s" % [stats.zoom, " map" if stats.far else ""], Color("f0e4c8")); y += 18
	draw_string(font, Vector2(x, y), "F4 toggles this tab" + ("  ·  " + ProjectSettings.globalize_path(LOG_PATH).get_file() if recording else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8f866f"))

func _pair(font: Font, x: float, y: float, label: String, value: String, color: Color) -> void:
	draw_string(font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a89d84"))
	draw_string(font, Vector2(x + 58, y), value, HORIZONTAL_ALIGNMENT_LEFT, 66, 11, color)
