extends Control
## The health screen, kept deliberately plain: how you are (one bar and three numbers), your own
## figure with a dot on every injured part, and one list of injuries. Pick an injury and it opens in
## place with the treatments you can do right now; while one runs, a progress line replaces them.
## Everything here only reads the simulation and submits commands.
const Health = preload("res://sim/player/body_health.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Outfits = preload("res://sim/entities/outfits.gd")
const BodyDiagram = preload("res://view/ui/body_diagram.gd")

signal close_requested
signal minimize_requested

const WINDOW := Vector2(840, 560)
const BG := Color("101417")
const LINE := Color("222d33")
const TEXT := Color("e9eef1")
const MUTED := Color("8b99a5")
const FAINT := Color("56646f")
const ACCENT := Color("56c2a6")
const WARN := Color("e8a54b")
const DANGER := Color("e8574f")
const BRUISE := Color("a58ae0")
const GOOD := Color("74d08f")
const TREATMENTS: Array[String] = ["bandage", "disinfect", "remove"]
const FIGURE := Rect2(28, 104, 250, 430)
const LIST := Rect2(310, 112, 502, 424)
const ROW := 52.0
const OPEN_EXTRA := 96.0

var simulation: RefCounted
var selected_part: String = "head"
var show_all: bool = false
var scroll: float = 0.0
var hover: String = ""
var rows: Dictionary = {}       # part -> Rect2 of the visible row (window pixels)
var buttons: Dictionary = {}    # id -> Rect2
var listed: Array[String] = []
var diagram: Control
var bold: FontVariation
var clock: float = 0.0

func _ready() -> void:
	custom_minimum_size = WINDOW
	size = WINDOW
	set_anchors_preset(Control.PRESET_CENTER)
	position = -WINDOW * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	bold = FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.6
	diagram = BodyDiagram.new()
	diagram.position = FIGURE.position
	diagram.size = FIGURE.size
	diagram.transparent = true
	diagram.minimal = true
	add_child(diagram)
	diagram.part_selected.connect(select_part)
	diagram.treatment_requested.connect(select_part)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	clock += delta
	if simulation != null and not simulation.state.get("player_health", {}).get("treatment", {}).is_empty():
		_sync_figure(simulation.state)
		queue_redraw()

# --- public helpers (also used by the tests) --------------------------------------------------

func select_part(part: String) -> void:
	if not Health.PARTS.has(part): return
	selected_part = part
	if simulation != null: refresh(simulation.state)

func action_problem(action: String) -> String:
	if simulation == null: return "Unavailable"
	var s: Dictionary = simulation.state
	if _unconscious(s): return "You are unconscious."
	if not s.player_health.treatment.is_empty(): return "Already treating a wound."
	if action == "bandage" and Inventory.amount(s, s.player, "bandage") < 1: return "You have no bandages."
	if action == "disinfect" and Inventory.amount(s, s.player, "antiseptic") < 1: return "You have no antiseptic."
	return Health.treatment_problem(s, selected_part, action)

func press_action(action: String) -> bool:
	if not action_problem(action).is_empty(): return false
	simulation.submit("treat_body", {"part": selected_part, "action": action})
	return true

func status_text(part: String) -> String:
	return _status(simulation.state.player_health.parts[part])[0]

func scrolls_list_at(point: Vector2) -> bool:
	return is_visible_in_tree() and Rect2(global_position + LIST.position, LIST.size).has_point(point)

func refresh(s: Dictionary) -> void:
	if not s.has("player_health"): return
	var parts: Dictionary = s.player_health.parts
	listed.clear()
	for part in Health.PARTS:
		if show_all or _injured(parts[part]): listed.append(part)
	# Keep the selection on something that still needs attention.
	if not listed.has(selected_part) and not listed.is_empty(): selected_part = listed[0]
	diagram.parts = parts
	diagram.selected = selected_part if listed.has(selected_part) else ""
	diagram.player_id = s.player
	diagram.outfit = Outfits.worn(s, s.player)
	_sync_figure(s)
	diagram.queue_redraw()
	_layout_rows()
	queue_redraw()

func _sync_figure(s: Dictionary) -> void:
	var treatment: Dictionary = s.player_health.treatment
	if treatment.is_empty():
		diagram.set_treatment("", "", 0.0)
		return
	var started: int = int(treatment.get("start", int(treatment.finish) - 30))
	var progress: float = clampf(float(s.tick - started) / maxf(1.0, float(int(treatment.finish) - started)), 0.0, 1.0)
	diagram.set_treatment(str(treatment.part), str(treatment.action), progress)

func _row_height(part: String) -> float:
	return ROW + (OPEN_EXTRA if part == selected_part else 0.0)

func _content_height() -> float:
	var total := 0.0
	for part in listed: total += _row_height(part) + 6.0
	return total

func _layout_rows() -> void:
	rows.clear()
	scroll = clampf(scroll, 0.0, maxf(0.0, _content_height() - LIST.size.y))
	var y: float = LIST.position.y - scroll
	for part in listed:
		var height := _row_height(part)
		var rect := Rect2(LIST.position.x, y, LIST.size.x, height)
		if rect.end.y > LIST.position.y and rect.position.y < LIST.end.y: rows[part] = rect
		y += height + 6.0

# --- state helpers ---------------------------------------------------------------------------

func _unconscious(s: Dictionary) -> bool:
	var knock: Dictionary = s.get("player_control", {}).get("knock", {})
	return bool(s.get("player_control", {}).get("dead", false)) or (not knock.is_empty() and s.tick < int(knock.get("rise_until", 0)))

func _injured(wound: Dictionary) -> bool:
	return not wound.is_empty() and (int(wound.damage) > 0 or int(wound.infection) > 0 or wound.bandage != "none")

func _part_name(part: String) -> String:
	return part.replace("_", " ").capitalize()

## One word for how a part is doing, and its colour.
func _status(wound: Dictionary) -> Array:
	if wound.bleeding: return ["Bleeding", DANGER]
	if int(wound.infection) > 0: return ["Infected", WARN]
	if wound.bandage == "dirty": return ["Dirty bandage", WARN]
	if wound.bandage == "clean": return ["Bandaged", GOOD]
	if wound.wound == "bruise": return ["Bruised", BRUISE]
	if wound.wound == "cut": return ["Cut", DANGER]
	if wound.wound == "sprain": return ["Sprained", WARN]
	return ["Healthy", FAINT]

# --- input ------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if simulation == null: return
	if event is InputEventMouseMotion:
		var over := _hit(event.position)
		if over != hover:
			hover = over
			queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and LIST.has_point(event.position):
			scroll += -40.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 40.0
			_layout_rows()
			queue_redraw()
			accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT: return
		var key := _hit(event.position)
		if key.begins_with("row:"): select_part(key.substr(4))
		elif key.begins_with("act:"): press_action(key.substr(4))
		elif key == "show_all":
			show_all = not show_all
			refresh(simulation.state)
		elif key == "close": close_requested.emit()
		elif key == "minimize": minimize_requested.emit()
		accept_event()

func _hit(point: Vector2) -> String:
	for id in buttons:
		if (buttons[id] as Rect2).has_point(point): return id
	if LIST.has_point(point):
		for part in rows:
			if (rows[part] as Rect2).has_point(point): return "row:" + part
	return ""

# --- drawing ----------------------------------------------------------------------------------

func _box(rect: Rect2, color: Color, radius: float = 8.0, border: Color = Color(0, 0, 0, 0), width: int = 0, shadow: int = 0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	style.anti_aliasing = true
	if width > 0:
		style.border_color = border
		style.set_border_width_all(width)
	if shadow > 0:
		style.shadow_color = Color(0, 0, 0, 0.45)
		style.shadow_size = shadow
		style.shadow_offset = Vector2(0, 6)
	draw_style_box(style, rect)

func _text(at: Vector2, text: String, font_size: int, color: Color, heavy: bool = false, width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(bold if heavy else ThemeDB.fallback_font, at, text, align, width, font_size, color)

func _bar(rect: Rect2, fill: float, color: Color) -> void:
	_box(rect, Color(1, 1, 1, 0.07), rect.size.y * 0.5)
	if fill > 0.001: _box(Rect2(rect.position, Vector2(maxf(rect.size.y, rect.size.x * clampf(fill, 0.0, 1.0)), rect.size.y)), color, rect.size.y * 0.5)

func _draw() -> void:
	if simulation == null or not simulation.state.has("player_health"): return
	var s: Dictionary = simulation.state
	var health: Dictionary = s.player_health
	buttons.clear()
	_box(Rect2(Vector2.ZERO, WINDOW), BG, 16.0, LINE, 1, 26)
	_draw_header(s, health)
	_draw_list(s, health)

func _draw_header(s: Dictionary, health: Dictionary) -> void:
	var value: int = Health.overall(s)
	var pain: int = Health.pain(s)
	var bleeding := 0
	var injured := 0
	for part in Health.PARTS:
		var wound: Dictionary = health.parts[part]
		if wound.bleeding: bleeding += 1
		if _injured(wound): injured += 1
	var condition: Array = ["Healthy", GOOD]
	if injured > 0: condition = ["Lightly hurt", ACCENT] if value >= 85 else (["Injured", WARN] if value >= 55 else ["Badly hurt", DANGER])
	if Health.incapacitated(s): condition = ["Critical", DANGER]
	if bool(s.player_control.get("dead", false)): condition = ["Dead", DANGER]
	elif _unconscious(s): condition = ["Unconscious", DANGER]
	_text(Vector2(32, 46), "Health", 24, TEXT, true)
	_text(Vector2(32 + 82, 46), condition[0], 15, condition[1])
	# The one bar, then three plain numbers.
	var bar := Rect2(32, 66, 300, 8)
	_bar(bar, float(value) / 100.0, GOOD if value >= 60 else (WARN if value >= 30 else DANGER))
	_text(Vector2(344, 74), "%d%%" % value, 13, TEXT, true)
	var x := 430.0
	for entry in [["Pain", "—" if pain == 0 else str(pain), WARN if pain > 0 else FAINT], ["Bleeding", "—" if bleeding == 0 else str(bleeding), DANGER if bleeding > 0 else FAINT], ["Stamina", str(int(health.stamina)), Color("5aa9d6")]]:
		_text(Vector2(x, 40), String(entry[0]).to_upper(), 10, FAINT, true)
		_text(Vector2(x, 66), entry[1], 18, entry[2], true)
		x += 92.0
	for entry in [["minimize", WINDOW.x - 80.0], ["close", WINDOW.x - 44.0]]:
		var rect := Rect2(entry[1], 24, 28, 28)
		buttons[entry[0]] = rect
		if hover == entry[0]: _box(rect, Color(1, 1, 1, 0.08), 7.0)
		var c := rect.get_center()
		if entry[0] == "close":
			draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), MUTED, 1.8, true)
			draw_line(c + Vector2(5, -5), c + Vector2(-5, 5), MUTED, 1.8, true)
		else:
			draw_line(c + Vector2(-6, 3), c + Vector2(6, 3), MUTED, 1.8, true)
	draw_line(Vector2(32, 92), Vector2(WINDOW.x - 32, 92), LINE, 1.0)

func _draw_list(s: Dictionary, health: Dictionary) -> void:
	if _unconscious(s):
		_text(Vector2(LIST.position.x, LIST.position.y + 190), "You are unconscious.", 18, MUTED, false, LIST.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(LIST.position.x, LIST.position.y + 216), "Wounds can be treated once you come round.", 13, FAINT, false, LIST.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		return
	var toggle := Rect2(LIST.end.x - 110, 98, 110, 20)
	buttons["show_all"] = toggle
	_text(toggle.position + Vector2(0, 14), "Hide healthy" if show_all else "Show all parts", 11, ACCENT if hover == "show_all" else FAINT, false, toggle.size.x, HORIZONTAL_ALIGNMENT_RIGHT)
	if listed.is_empty():
		_text(Vector2(LIST.position.x, LIST.position.y + 190), "No injuries", 20, TEXT, true, LIST.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(LIST.position.x, LIST.position.y + 216), "Nothing needs treating.", 13, FAINT, false, LIST.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		return
	for part in rows:
		var rect: Rect2 = rows[part]
		var wound: Dictionary = health.parts[part]
		var open: bool = part == selected_part
		if rect.position.y < LIST.position.y - 1.0 or rect.end.y > LIST.end.y + 1.0:
			# Half-scrolled rows would spill over the header: only draw whole rows.
			if rect.position.y < LIST.position.y - 1.0 or rect.position.y + ROW > LIST.end.y + 1.0: continue
		var lit: bool = hover == "row:" + part
		if open: _box(rect, Color(1, 1, 1, 0.045), 10.0, Color(ACCENT, 0.5), 1)
		elif lit: _box(rect, Color(1, 1, 1, 0.03), 10.0)
		var status: Array = _status(wound)
		_text(rect.position + Vector2(16, 24), _part_name(part), 15, TEXT, true)
		_text(rect.position + Vector2(0, 24), status[0], 13, status[1], false, rect.size.x - 16, HORIZONTAL_ALIGNMENT_RIGHT)
		_bar(Rect2(rect.position + Vector2(16, 36), Vector2(rect.size.x - 32, 4)), float(wound.damage) / 100.0, status[1] if int(wound.damage) > 0 else FAINT)
		if open: _draw_actions(s, health, wound, rect)

func _draw_actions(s: Dictionary, health: Dictionary, wound: Dictionary, row: Rect2) -> void:
	var top: float = row.position.y + ROW + 6.0
	var treatment: Dictionary = health.treatment
	if not treatment.is_empty():
		var started: int = int(treatment.get("start", int(treatment.finish) - 30))
		var span: float = maxf(1.0, float(int(treatment.finish) - started))
		var progress: float = clampf(float(s.tick - started) / span, 0.0, 1.0)
		var verb: String = {"bandage": "Bandaging", "disinfect": "Cleaning", "remove": "Taking the bandage off"}.get(str(treatment.action), "Treating")
		_text(Vector2(row.position.x + 16, top + 18), "%s %s…" % [verb, _part_name(str(treatment.part)).to_lower()], 14, TEXT)
		_text(Vector2(row.position.x, top + 18), "%.1f s" % (maxf(0.0, float(int(treatment.finish) - s.tick)) / 10.0), 13, MUTED, false, row.size.x - 16, HORIZONTAL_ALIGNMENT_RIGHT)
		_bar(Rect2(row.position.x + 16, top + 30, row.size.x - 32, 6), progress, ACCENT)
		_text(Vector2(row.position.x + 16, top + 62), "Moving cancels the treatment.", 12, FAINT)
		return
	var labels := {"bandage": "Replace bandage" if wound.bandage == "dirty" else "Bandage", "disinfect": "Clean wound", "remove": "Remove bandage"}
	var counts := {"bandage": Inventory.amount(s, s.player, "bandage"), "disinfect": Inventory.amount(s, s.player, "antiseptic")}
	var x: float = row.position.x + 16
	var any := false
	var reason := ""
	for action in TREATMENTS:
		var problem := action_problem(action)
		if not problem.is_empty():
			if reason.is_empty() and action != "remove": reason = problem
			continue
		var label: String = labels[action] + ("  ×%d" % int(counts[action]) if counts.has(action) else "")
		var width: float = ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 32.0
		var rect := Rect2(x, top + 14, width, 38)
		buttons["act:" + action] = rect
		var primary: bool = action == "bandage"
		var lit: bool = hover == "act:" + action
		_box(rect, (ACCENT.darkened(0.1) if lit else ACCENT) if primary else (Color(1, 1, 1, 0.1) if lit else Color(1, 1, 1, 0.05)), 9.0, Color(ACCENT, 0.5) if not primary else Color(0, 0, 0, 0), 1 if not primary else 0)
		_text(rect.position + Vector2(0, 24), label, 14, Color("0e1417") if primary else TEXT, true, width, HORIZONTAL_ALIGNMENT_CENTER)
		x += width + 10.0
		any = true
	if not any:
		_text(Vector2(row.position.x + 16, top + 36), reason if not reason.is_empty() else "Nothing to do for this one.", 13, MUTED)
