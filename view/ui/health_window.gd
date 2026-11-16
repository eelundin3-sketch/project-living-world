extends Control
## The health screen: the player's own figure with wounds marked where they are, a list of injury
## cards, and a detail panel for the selected body part with its treatments. While a treatment runs
## the figure acts it out and a progress card replaces the buttons. Everything here only reads the
## simulation and submits commands.
const Health = preload("res://sim/player/body_health.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Outfits = preload("res://sim/entities/outfits.gd")
const BodyDiagram = preload("res://view/ui/body_diagram.gd")

signal close_requested
signal minimize_requested

const WINDOW := Vector2(960, 600)
const BG := Color("0f1418")
const CARD := Color("161e24")
const CARD_HI := Color("1f2b34")
const LINE := Color("2a3742")
const TEXT := Color("e9eef1")
const MUTED := Color("8a99a6")
const FAINT := Color("5d6b77")
const ACCENT := Color("56c2a6")
const WARN := Color("e8a54b")
const DANGER := Color("e8574f")
const BRUISE := Color("a07ad8")
const GOOD := Color("74d08f")
const CLOTH := Color("ece6d6")
const TREATMENTS: Array[String] = ["bandage", "disinfect", "remove"]
const LIST := Rect2(316, 136, 300, 444)
const DETAIL := Rect2(632, 96, 308, 484)
const FIGURE := Rect2(20, 96, 280, 484)
const CARD_HEIGHT := 64.0
const CARD_GAP := 8.0

var simulation: RefCounted
var selected_part: String = "head"
var show_all: bool = false
var scroll: float = 0.0
var hover: String = ""
var cards: Dictionary = {}      # part -> Rect2 (visible list cards, in window pixels)
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
	bold.variation_embolden = 0.65
	diagram = BodyDiagram.new()
	diagram.position = FIGURE.position + Vector2(20, 18)
	diagram.size = Vector2(FIGURE.size.x - 40, FIGURE.size.y - 76)
	diagram.transparent = true
	add_child(diagram)
	diagram.part_selected.connect(select_part)
	diagram.treatment_requested.connect(select_part)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	clock += delta
	if simulation != null and not simulation.state.get("player_health", {}).get("treatment", {}).is_empty():
		_sync_figure(simulation.state)
		queue_redraw()

## Public helpers (also used by tests).
func select_part(part: String) -> void:
	if not Health.PARTS.has(part): return
	selected_part = part
	if simulation != null: refresh(simulation.state)

func action_problem(action: String) -> String:
	if simulation == null: return "Unavailable"
	var s: Dictionary = simulation.state
	if _unconscious(s): return "You are unconscious."
	if not s.player_health.treatment.is_empty(): return "Already treating a wound."
	if action == "bandage" and Inventory.amount(s, s.player, "bandage") < 1: return "No bandages in your inventory."
	if action == "disinfect" and Inventory.amount(s, s.player, "antiseptic") < 1: return "No antiseptic in your inventory."
	return Health.treatment_problem(s, selected_part, action)

func press_action(action: String) -> bool:
	if not action_problem(action).is_empty(): return false
	simulation.submit("treat_body", {"part": selected_part, "action": action})
	return true

func status_text(part: String) -> String:
	return " · ".join(_chips(simulation.state.player_health.parts[part]).map(func(chip: Array) -> String: return chip[0]))

func scrolls_list_at(point: Vector2) -> bool:
	return is_visible_in_tree() and Rect2(global_position + LIST.position, LIST.size).has_point(point)

func refresh(s: Dictionary) -> void:
	if not s.has("player_health"): return
	var parts: Dictionary = s.player_health.parts
	listed.clear()
	for part in Health.PARTS:
		if show_all or _injured(parts[part]): listed.append(part)
	if not _injured(parts.get(selected_part, {})) and not show_all:
		for part in listed:
			selected_part = part
			break
	diagram.parts = parts
	diagram.selected = selected_part
	diagram.player_id = s.player
	diagram.outfit = Outfits.worn(s, s.player)
	_sync_figure(s)
	diagram.queue_redraw()
	_layout_cards()
	queue_redraw()

func _sync_figure(s: Dictionary) -> void:
	var treatment: Dictionary = s.player_health.treatment
	if treatment.is_empty():
		diagram.set_treatment("", "", 0.0)
		return
	var started: int = int(treatment.get("start", int(treatment.finish) - 30))
	var progress: float = clampf((float(s.tick - started) + clock * 0.0) / maxf(1.0, float(int(treatment.finish) - started)), 0.0, 1.0)
	diagram.set_treatment(str(treatment.part), str(treatment.action), progress)

func _layout_cards() -> void:
	cards.clear()
	var max_scroll: float = maxf(0.0, listed.size() * (CARD_HEIGHT + CARD_GAP) - LIST.size.y)
	scroll = clampf(scroll, 0.0, max_scroll)
	for index in range(listed.size()):
		var top: float = LIST.position.y + index * (CARD_HEIGHT + CARD_GAP) - scroll
		var rect := Rect2(LIST.position.x, top, LIST.size.x, CARD_HEIGHT)
		if rect.end.y > LIST.position.y and rect.position.y < LIST.end.y: cards[listed[index]] = rect

# --- state helpers ---------------------------------------------------------------------------

func _unconscious(s: Dictionary) -> bool:
	var knock: Dictionary = s.get("player_control", {}).get("knock", {})
	return not knock.is_empty() and s.tick < int(knock.get("rise_until", 0))

func _injured(wound: Dictionary) -> bool:
	return not wound.is_empty() and (int(wound.damage) > 0 or int(wound.infection) > 0 or wound.bandage != "none")

func _part_name(part: String) -> String:
	return part.replace("_", " ").capitalize()

## Status pills for a body part: [text, colour].
func _chips(wound: Dictionary) -> Array:
	var chips: Array = []
	if wound.wound == "bruise": chips.append(["Bruise", BRUISE])
	elif wound.wound == "cut": chips.append(["Cut", DANGER])
	elif wound.wound == "sprain": chips.append(["Sprain", WARN])
	if wound.bleeding: chips.append(["Bleeding", DANGER])
	if wound.bandage == "clean": chips.append(["Bandaged", GOOD])
	elif wound.bandage == "dirty": chips.append(["Dirty bandage", WARN])
	if int(wound.infection) > 0: chips.append(["Infection %d%%" % int(wound.infection), WARN])
	if chips.is_empty(): chips.append(["Healthy", FAINT])
	return chips

func _severity(wound: Dictionary) -> Array:
	var damage: int = int(wound.damage)
	if wound.bleeding: return ["Bleeding — needs a bandage", DANGER]
	if damage >= 60: return ["Severe", DANGER]
	if damage >= 30: return ["Moderate", WARN]
	if damage > 0: return ["Minor", ACCENT]
	return ["Healthy", GOOD]

func _accent(wound: Dictionary) -> Color:
	if wound.bleeding: return DANGER
	if wound.bandage == "dirty" or int(wound.infection) > 0: return WARN
	if wound.bandage == "clean": return GOOD
	if wound.wound == "bruise": return BRUISE
	if int(wound.damage) > 0: return WARN
	return FAINT

# --- input ----------------------------------------------------------------------------------

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
			scroll += -36.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 36.0
			_layout_cards()
			queue_redraw()
			accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT: return
		var key := _hit(event.position)
		if key.begins_with("card:"): select_part(key.substr(5))
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
		for part in cards:
			if (cards[part] as Rect2).has_point(point): return "card:" + part
	return ""

# --- drawing --------------------------------------------------------------------------------

func _box(rect: Rect2, color: Color, radius: float = 12.0, border: Color = Color(0, 0, 0, 0), width: int = 0, shadow: int = 0) -> void:
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

func _pill(at: Vector2, text: String, color: Color) -> float:
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 16.0
	_box(Rect2(at, Vector2(width, 19)), Color(color, 0.16), 9.5, Color(color, 0.45), 1)
	_text(at + Vector2(8, 14), text, 11, color.lightened(0.15))
	return width

func _draw() -> void:
	if simulation == null or not simulation.state.has("player_health"): return
	var s: Dictionary = simulation.state
	var health: Dictionary = s.player_health
	buttons.clear()
	# Window
	_box(Rect2(Vector2.ZERO, WINDOW), BG, 18.0, LINE, 1, 28)
	_box(Rect2(Vector2(1, 1), Vector2(WINDOW.x - 2, 78)), Color("131a1f"), 17.0)
	_draw_header(s, health)
	draw_line(Vector2(20, 84), Vector2(WINDOW.x - 20, 84), LINE, 1.0)
	_draw_figure_card(s, health)
	_draw_list(s, health)
	_draw_detail(s, health)

func _draw_header(s: Dictionary, health: Dictionary) -> void:
	var value: int = Health.overall(s)
	var pain: int = Health.pain(s)
	var bleeding := 0
	var injured := 0
	for part in Health.PARTS:
		var wound: Dictionary = health.parts[part]
		if wound.bleeding: bleeding += 1
		if _injured(wound): injured += 1
	var condition: Array = ["In good health", GOOD]
	if injured > 0: condition = ["Minor injuries", ACCENT] if value >= 85 else (["Injured", WARN] if value >= 55 else ["Badly hurt", DANGER])
	if Health.incapacitated(s): condition = ["Critical condition", DANGER]
	if _unconscious(s): condition = ["Unconscious", DANGER]
	_text(Vector2(28, 38), "HEALTH", 22, TEXT, true)
	_text(Vector2(28, 62), condition[0], 14, condition[1])
	# Vitals
	var x := 300.0
	var vitals: Array = [
		["Health", "%d%%" % value, float(value) / 100.0, GOOD if value >= 60 else (WARN if value >= 30 else DANGER)],
		["Pain", "None" if pain == 0 else str(pain), float(pain) / 100.0, WARN if pain < 40 else DANGER],
		["Bleeding", "None" if bleeding == 0 else "%d wound%s" % [bleeding, "" if bleeding == 1 else "s"], minf(1.0, bleeding / 3.0), DANGER],
		["Stamina", "%d" % int(health.stamina), float(health.stamina) / maxf(1.0, float(health.stamina_max)), Color("5aa9d6")]]
	for vital in vitals:
		var rect := Rect2(x, 16, 134, 50)
		_box(rect, CARD, 10.0, LINE, 1)
		_text(rect.position + Vector2(12, 20), vital[0].to_upper(), 10, MUTED, true)
		_text(rect.position + Vector2(12, 20), vital[1], 13, TEXT, true, rect.size.x - 24, HORIZONTAL_ALIGNMENT_RIGHT)
		_bar(Rect2(rect.position + Vector2(12, 32), Vector2(rect.size.x - 24, 6)), vital[2], vital[3])
		x += 144.0
	# Window controls
	for entry in [["minimize", WINDOW.x - 88.0], ["close", WINDOW.x - 48.0]]:
		var rect := Rect2(entry[1], 26, 32, 32)
		buttons[entry[0]] = rect
		_box(rect, CARD_HI if hover == entry[0] else CARD, 8.0, LINE, 1)
		var c := rect.get_center()
		if entry[0] == "close":
			draw_line(c + Vector2(-6, -6), c + Vector2(6, 6), TEXT, 2.0, true)
			draw_line(c + Vector2(6, -6), c + Vector2(-6, 6), TEXT, 2.0, true)
		else:
			draw_line(c + Vector2(-7, 4), c + Vector2(7, 4), TEXT, 2.0, true)

func _draw_figure_card(s: Dictionary, health: Dictionary) -> void:
	_box(FIGURE, CARD, 14.0, LINE, 1)
	# A soft spotlight behind the figure.
	var centre := FIGURE.position + Vector2(FIGURE.size.x * 0.5, FIGURE.size.y * 0.45)
	for ring in range(6):
		draw_circle(centre, 120.0 - ring * 18.0, Color(0.34, 0.76, 0.65, 0.012 + ring * 0.006))
	# Legend
	var y := FIGURE.end.y - 26.0
	var x := FIGURE.position.x + 18.0
	var font: Font = ThemeDB.fallback_font
	var total := 0.0
	var legend: Array = [["Bruise", BRUISE], ["Cut", DANGER], ["Bandage", CLOTH], ["Infected", WARN]]
	for entry in legend: total += font.get_string_size(entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 32.0
	x = FIGURE.position.x + (FIGURE.size.x - total + 18.0) * 0.5
	for entry in legend:
		draw_circle(Vector2(x + 5, y - 4), 4.5, entry[1])
		_text(Vector2(x + 14, y), entry[0], 11, MUTED)
		x += font.get_string_size(entry[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 32.0

func _draw_list(s: Dictionary, health: Dictionary) -> void:
	_text(Vector2(LIST.position.x + 2, 118), "INJURIES", 12, MUTED, true)
	var count := 0
	for part in Health.PARTS:
		if _injured(health.parts[part]): count += 1
	_pill(Vector2(LIST.position.x + 70, 104), str(count), ACCENT if count == 0 else WARN)
	var toggle := Rect2(LIST.end.x - 92, 102, 92, 22)
	buttons["show_all"] = toggle
	_text(toggle.position + Vector2(0, 15), "Hide healthy" if show_all else "Show all parts", 11, ACCENT if hover == "show_all" else MUTED, false, toggle.size.x, HORIZONTAL_ALIGNMENT_RIGHT)
	if listed.is_empty():
		var box := Rect2(LIST.position, Vector2(LIST.size.x, 150))
		_box(box, CARD, 14.0, LINE, 1)
		draw_circle(box.position + Vector2(box.size.x * 0.5, 50), 20.0, Color(GOOD, 0.16))
		draw_polyline(PackedVector2Array([box.position + Vector2(box.size.x * 0.5 - 9, 50), box.position + Vector2(box.size.x * 0.5 - 2, 57), box.position + Vector2(box.size.x * 0.5 + 10, 43)]), GOOD, 3.0, true)
		_text(box.position + Vector2(0, 100), "No injuries", 16, TEXT, true, box.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		_text(box.position + Vector2(0, 122), "You are in good shape.", 12, MUTED, false, box.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		return
	for part in cards:
		var rect: Rect2 = cards[part]
		var wound: Dictionary = health.parts[part]
		var chosen: bool = part == selected_part
		var lit: bool = hover == "card:" + part
		var clip_top: float = maxf(rect.position.y, LIST.position.y)
		var clip_bottom: float = minf(rect.end.y, LIST.end.y)
		if clip_bottom - clip_top < 20.0: continue
		_box(rect, CARD_HI if chosen or lit else CARD, 12.0, ACCENT if chosen else LINE, 2 if chosen else 1)
		_box(Rect2(rect.position + Vector2(8, 12), Vector2(4, rect.size.y - 24)), _accent(wound), 2.0)
		_text(rect.position + Vector2(22, 25), _part_name(part), 15, TEXT, true)
		_text(rect.position + Vector2(0, 25), "%d%%" % int(wound.damage) if int(wound.damage) > 0 else "", 13, MUTED, false, rect.size.x - 16, HORIZONTAL_ALIGNMENT_RIGHT)
		if int(wound.damage) > 0: _bar(Rect2(rect.end.x - 72, rect.position.y + 33, 56, 4), float(wound.damage) / 100.0, _accent(wound))
		var x := rect.position.x + 22.0
		for chip in _chips(wound):
			if x > rect.end.x - 90: break
			x += _pill(Vector2(x, rect.position.y + 36), chip[0], chip[1]) + 6.0

func _draw_detail(s: Dictionary, health: Dictionary) -> void:
	_box(DETAIL, CARD, 14.0, LINE, 1)
	var wound: Dictionary = health.parts[selected_part]
	var left := DETAIL.position.x + 22.0
	var inner := DETAIL.size.x - 44.0
	var y := DETAIL.position.y
	_text(Vector2(left, y + 40), _part_name(selected_part), 21, TEXT, true)
	var severity: Array = _severity(wound)
	_text(Vector2(left, y + 62), severity[0], 13, severity[1])
	_bar(Rect2(left, y + 74, inner, 8), float(wound.damage) / 100.0, _accent(wound) if int(wound.damage) > 0 else GOOD)
	var rows: Array = [
		["Wound", "None" if wound.wound == "none" else String(wound.wound).capitalize()],
		["Bleeding", "Yes" if wound.bleeding else "No"],
		["Dressing", {"none": "None", "clean": "Clean bandage", "dirty": "Dirty — replace it"}.get(wound.bandage, "None")],
		["Infection", "None" if int(wound.infection) == 0 else "%d%%" % int(wound.infection)]]
	var row_y := y + 112.0
	for row in rows:
		_text(Vector2(left, row_y), row[0], 13, MUTED)
		var tone := TEXT
		if row[0] == "Bleeding" and wound.bleeding: tone = DANGER
		elif row[0] == "Dressing" and wound.bandage == "dirty": tone = WARN
		elif row[0] == "Infection" and int(wound.infection) > 0: tone = WARN
		_text(Vector2(left, row_y), row[1], 13, tone, true, inner, HORIZONTAL_ALIGNMENT_RIGHT)
		draw_line(Vector2(left, row_y + 10), Vector2(left + inner, row_y + 10), Color(LINE, 0.6), 1.0)
		row_y += 28.0
	_text(Vector2(left, y + 242), "TREATMENT", 12, MUTED, true)
	var treatment: Dictionary = health.treatment
	if _unconscious(s):
		var banner := Rect2(left, y + 256, inner, 96)
		_box(banner, Color(DANGER, 0.12), 12.0, Color(DANGER, 0.5), 1)
		_text(banner.position + Vector2(0, 40), "You are unconscious", 16, DANGER.lightened(0.2), true, banner.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		_text(banner.position + Vector2(0, 64), "Wounds can be treated once you come round.", 12, MUTED, false, banner.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	elif not treatment.is_empty():
		_draw_progress(s, treatment, Rect2(left, y + 256, inner, 118))
	else:
		var labels := {"bandage": "Replace bandage" if wound.bandage == "dirty" else "Apply bandage", "disinfect": "Clean wound", "remove": "Remove bandage"}
		var supplies := {"bandage": Inventory.amount(s, s.player, "bandage"), "disinfect": Inventory.amount(s, s.player, "antiseptic"), "remove": -1}
		var by := y + 256.0
		var reason := ""
		for action in TREATMENTS:
			var rect := Rect2(left, by, inner, 46)
			var problem := action_problem(action)
			var enabled: bool = problem.is_empty()
			buttons["act:" + action] = rect
			var lit: bool = hover == "act:" + action and enabled
			var primary: bool = action == "bandage" and enabled
			var fill: Color = (ACCENT.darkened(0.15) if lit else Color(ACCENT, 0.85)) if primary else (CARD_HI.lightened(0.06) if lit else CARD_HI)
			if not enabled: fill = Color(CARD_HI, 0.45)
			_box(rect, fill, 10.0, Color(ACCENT, 0.6) if enabled and not primary else Color(0, 0, 0, 0), 1 if enabled and not primary else 0)
			_action_icon(action, rect.position + Vector2(24, 23), Color("0f1418") if primary else (TEXT if enabled else FAINT))
			_text(rect.position + Vector2(46, 29), labels[action], 14, Color("0f1418") if primary else (TEXT if enabled else FAINT), true)
			if int(supplies[action]) >= 0:
				_text(rect.position + Vector2(0, 29), "× %d" % int(supplies[action]), 13, Color("0f1418") if primary else (MUTED if enabled else FAINT), true, rect.size.x - 16, HORIZONTAL_ALIGNMENT_RIGHT)
			if not enabled and reason.is_empty() and action != "remove": reason = problem
			if hover == "act:" + action and not enabled: reason = problem
			by += 54.0
		if not reason.is_empty(): _text(Vector2(left, by + 12), reason, 12, WARN)
	var notice: String = str(health.get("notice", ""))
	if not notice.is_empty() and treatment.is_empty():
		_text(Vector2(left, DETAIL.end.y - 16), notice, 11, FAINT, false, inner)

func _draw_progress(s: Dictionary, treatment: Dictionary, rect: Rect2) -> void:
	var started: int = int(treatment.get("start", int(treatment.finish) - 30))
	var span: float = maxf(1.0, float(int(treatment.finish) - started))
	var progress: float = clampf(float(s.tick - started) / span, 0.0, 1.0)
	_box(rect, Color(ACCENT, 0.10), 12.0, Color(ACCENT, 0.55), 1)
	var verb: String = {"bandage": "Bandaging", "disinfect": "Cleaning", "remove": "Removing the bandage from"}.get(str(treatment.action), "Treating")
	_text(rect.position + Vector2(18, 32), "%s %s" % [verb, _part_name(str(treatment.part)).to_lower()], 15, TEXT, true)
	_bar(Rect2(rect.position + Vector2(18, 50), Vector2(rect.size.x - 36, 10)), progress, ACCENT)
	# A moving sheen on the bar so it reads as active.
	var sheen: float = fposmod(clock * 0.8, 1.0)
	var bar_width: float = (rect.size.x - 36) * progress
	if bar_width > 12: draw_rect(Rect2(rect.position + Vector2(18 + bar_width * sheen - 6, 50), Vector2(12, 10)), Color(1, 1, 1, 0.18))
	var seconds: float = maxf(0.0, float(int(treatment.finish) - s.tick) / 10.0)
	_text(rect.position + Vector2(18, 84), "%.1f s left" % seconds, 13, MUTED)
	_text(rect.position + Vector2(18, 104), "Moving cancels the treatment.", 12, FAINT)

func _action_icon(action: String, c: Vector2, ink: Color) -> void:
	match action:
		"bandage":
			draw_circle(c, 8.5, ink)
			draw_circle(c, 3.5, Color(0, 0, 0, 0.35))
			draw_line(c + Vector2(-8, 3), c + Vector2(-14, 9), ink, 4.0, true)
		"disinfect":
			draw_rect(Rect2(c + Vector2(-5, -3), Vector2(10, 12)), ink)
			draw_rect(Rect2(c + Vector2(-2.5, -9), Vector2(5, 6)), ink)
			draw_line(c + Vector2(-2.5, 3), c + Vector2(2.5, 3), Color(0, 0, 0, 0.45), 1.5)
			draw_line(c + Vector2(0, 0.5), c + Vector2(0, 5.5), Color(0, 0, 0, 0.45), 1.5)
		"remove":
			draw_arc(c, 7.5, 0.4, TAU - 0.4, 18, ink, 2.5, true)
			draw_line(c + Vector2(7, -3), c + Vector2(12, -8), ink, 2.5, true)
