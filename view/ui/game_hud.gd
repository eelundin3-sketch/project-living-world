extends CanvasLayer
signal action(kind: String)
var heading: Label
var stats: Label
var inspector: RichTextLabel
var events: RichTextLabel
var notice: Label
var market: VBoxContainer
var root_control: Control
var pause_button: Button
var trade_info: Label
var observer_panel: VBoxContainer
var large_text: bool = false

func _ready() -> void:
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	var top := _panel(root_control, Vector2(16, 16), Vector2(570, 122))
	var column := VBoxContainer.new()
	top.add_child(column)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 23)
	column.add_child(heading)
	stats = Label.new()
	stats.add_theme_font_size_override("font_size", 14)
	column.add_child(stats)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	for item in [["Pause", "pause"], ["1×", "speed1"], ["2×", "speed2"], ["4×", "speed4"], ["Save", "save"], ["Load", "load"], ["Follow", "follow"]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(func() -> void: action.emit(item[1]))
		buttons.add_child(button)
		if item[1] == "pause":
			pause_button = button
	var side := _panel(root_control, Vector2.ZERO, Vector2(310, 650))
	side.get_parent().set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	side.get_parent().offset_left = -326
	side.get_parent().offset_right = -16
	side.get_parent().offset_top = 16
	side.get_parent().offset_bottom = 666
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 620)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	var sidebar := VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sidebar)
	var title := Label.new()
	title.text = "FIELD NOTES"
	title.add_theme_font_size_override("font_size", 18)
	sidebar.add_child(title)
	inspector = RichTextLabel.new()
	inspector.bbcode_enabled = true
	inspector.custom_minimum_size = Vector2(280, 280)
	inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(inspector)
	market = VBoxContainer.new()
	sidebar.add_child(market)
	trade_info = Label.new()
	trade_info.add_theme_font_size_override("font_size", 13)
	market.add_child(trade_info)
	for item in ["log", "food", "plank"]:
		var row := HBoxContainer.new()
		market.add_child(row)
		var label := Label.new()
		label.text = item.capitalize()
		label.custom_minimum_size.x = 65
		row.add_child(label)
		_add_button(row, "Buy 1", "buy:" + item)
		_add_button(row, "Sell 1", "sell:" + item)
	_add_button(sidebar, "Walk to the other village", "travel")
	var options := HBoxContainer.new()
	sidebar.add_child(options)
	_add_button(options, "Larger text", "large_text")
	_add_button(options, "Observer tools", "observer")
	observer_panel = VBoxContainer.new()
	sidebar.add_child(observer_panel)
	observer_panel.visible = false
	for option in [["Open / close road", "road"], ["Toggle road danger", "risk"], ["Toggle trade treaty", "treaty"], ["Cancel selected batch", "cancel_batch"], ["Load recipe.json", "mod"]]:
		_add_button(observer_panel, option[0], option[1])
	var bindings := HBoxContainer.new()
	observer_panel.add_child(bindings)
	for direction in ["up", "left", "down", "right"]:
		_add_button(bindings, direction.capitalize(), "bind:walk_" + direction)
	var cancel := Button.new()
	cancel.text = "Cancel selected worker's job"
	cancel.pressed.connect(func() -> void: action.emit("cancel"))
	sidebar.add_child(cancel)
	var bottom := _panel(root_control, Vector2.ZERO, Vector2(720, 156))
	bottom.get_parent().set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.get_parent().offset_left = 16
	bottom.get_parent().offset_right = 736
	bottom.get_parent().offset_top = -172
	bottom.get_parent().offset_bottom = -16
	var footer := VBoxContainer.new()
	bottom.add_child(footer)
	notice = Label.new()
	notice.text = "WASD walk · Click inspect · Wheel zoom · Space pause · F5 save · F9 load"
	notice.add_theme_font_size_override("font_size", 13)
	footer.add_child(notice)
	events = RichTextLabel.new()
	events.bbcode_enabled = true
	events.custom_minimum_size = Vector2(680, 96)
	footer.add_child(events)

func _panel(parent: Control, position_value: Vector2, minimum: Vector2) -> MarginContainer:
	var panel := PanelContainer.new()
	panel.position = position_value
	panel.custom_minimum_size = minimum
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172821")
	style.border_color = Color("687157")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	# Return panel's content, while callers place the panel through this helper below.
	return margin

func refresh(sim: RefCounted, clock: RefCounted, selected: int, frame_ms: float) -> void:
	var s: Dictionary = sim.state
	var day: int = s.tick / 14400 + 1
	var minute: int = (s.tick / 10) % 1440
	heading.text = "ALDER HOLLOW  /  Day %d · %02d:%02d" % [day, minute / 60, minute % 60]
	var stock: Dictionary = s.inventories[str(s.warehouse)].items
	stats.text = "%d residents   •   %d logs   %d food   %d planks\nTick %d · %s · %d deliveries · sim %.2f ms" % [s.residents.size(), stock.get("log", 0), stock.get("food", 0), stock.get("plank", 0), s.tick, "Paused" if clock.paused else "%d×" % clock.speed, s.completed_jobs, frame_ms]
	pause_button.text = "Resume" if clock.paused else "Pause"
	if s.has("markets"):
		var town_id: int = 1 if s.entities[str(s.player)].cell[0] < 122 else 2
		var town: Dictionary = s.settlements[str(town_id)]
		var MarketService = preload("res://sim/economy/market.gd")
		trade_info.text = "%s · You: %d coins
Ask / bid: logs %d/%d · food %d/%d
Planks %d/%d · Trade within 6 cells" % [town.name, s.accounts[str(s.player)], MarketService.quote(s, town_id, "log", true), MarketService.quote(s, town_id, "log", false), MarketService.quote(s, town_id, "food", true), MarketService.quote(s, town_id, "food", false), MarketService.quote(s, town_id, "plank", true), MarketService.quote(s, town_id, "plank", false)]
	var lines: Array[String] = []
	if selected != 0 and s.entities.has(str(selected)):
		var entity: Dictionary = s.entities[str(selected)]
		lines.append("[b]%s[/b]\n%s · ID %d\nCell %s" % [entity.get("name", "Test entity"), entity.get("kind", "test"), entity.id, str(entity.get("cell", []))])
		if s.inventories.has(str(selected)):
			var inventory: Dictionary = s.inventories[str(selected)]
			lines.append("\n[b]Possessions[/b]  (capacity %d)" % inventory.capacity)
			for item in inventory.items:
				lines.append("%s  %d" % [item.capitalize(), inventory.items[item]])
			if inventory.items.is_empty():
				lines.append("Empty")
		if s.residents.has(str(selected)):
			var npc: Dictionary = s.residents[str(selected)]
			lines.append("\n[b]%s[/b]\nHunger %d/100 · Fatigue %d/100\n%s · %s" % [npc.status, npc.hunger, npc.fatigue, npc.occupation, npc.fidelity])
			lines.append("Skill %d · Trust in you %d" % [npc.skill, npc.relations.get(str(s.player), {}).get("trust", 0)])
			if npc.job != 0:
				var job: Dictionary = s.jobs[str(npc.job)]
				lines.append("Job %d: %s\nTarget %d → store %d\nLease to tick %d" % [job.id, job.state, job.target, job.destination, job.lease_until])
			for memory in npc.memories.slice(-3):
				lines.append("• " + str(memory.get("text", "")))
		if s.has("workshops") and s.workshops.has(str(selected)):
			var workshop: Dictionary = s.workshops[str(selected)]
			lines.append("\n[b]Sawmill[/b]\n%s\nBatch work: %d/%d\n2 logs → 6 planks" % [workshop.status, workshop.progress, workshop.get("work_ticks", 40)])
		if s.has("construction") and s.construction.has(str(selected)):
			var site: Dictionary = s.construction[str(selected)]
			lines.append("\nConstruction: %s\nWork %d/%d\nRequires %d planks" % [site.status, site.progress, site.work_ticks, site.cost])
		if entity.kind == "warehouse" and s.has("settlements"):
			var town: Dictionary = s.settlements[str(entity.settlement)]
			lines.append("\nHousing %d / population %d\nPolicy: %s\nSimulation: %s" % [town.housing, town.population, town.policy, town.fidelity])
			if s.has("markets"):
				lines.append("Last executed prices: " + str(s.markets[str(town.id)].last))
		if s.has("caravans") and s.caravans.has(str(selected)):
			var caravan: Dictionary = s.caravans[str(selected)]
			lines.append("\n%s\nArrival tick %d\nDeliveries %d" % [caravan.status, caravan.arrival_tick, caravan.deliveries])
	else:
		lines.append("[b]A village with its own rhythm[/b]\n\nClick a resident, tree, field or building to inspect it.\n\nResidents harvest resources, carry them to storage, and interrupt work to eat or rest.\n\nFollow a worker's highlighted path to trace the supply chain.")
	inspector.text = "\n".join(lines)
	var recent: Array[String] = []
	for entry in s.history.slice(-4):
		recent.append("[color=#aeb99c]%06d[/color]  %s" % [entry.tick, entry.text])
	events.text = "\n".join(recent)

func _add_button(parent: Control, text: String, command: String) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func() -> void: action.emit(command))
	parent.add_child(button)

func toggle_observer() -> void:
	observer_panel.visible = not observer_panel.visible

func toggle_large_text() -> void:
	large_text = not large_text
	inspector.add_theme_font_size_override("normal_font_size", 20 if large_text else 16)
	events.add_theme_font_size_override("normal_font_size", 18 if large_text else 14)
