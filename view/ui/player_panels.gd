extends CanvasLayer
const Health = preload("res://sim/player/body_health.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Market = preload("res://sim/economy/market.gd")
const BodyDiagram = preload("res://view/ui/body_diagram.gd")
const Outfits = preload("res://sim/entities/outfits.gd")
var simulation: RefCounted
var mode: String = ""
var selected_part: String = "head"
var target: int = 0
var last_nonce: int = 0
var shade: ColorRect
var panel: PanelContainer
var title: Label
var summary: Label
var notice: Label
var detail: Label
var body: Control
var list: VBoxContainer
var diagram: Control
var treatment_bar: HBoxContainer
var scroll: ScrollContainer
var health_style: StyleBoxFlat
var standard_style: StyleBoxFlat
var health_meter: TextureProgressBar
var meter_column: VBoxContainer
var healthy_toggle: CheckButton
var empty_wounds: Label
var treatment_menu: PopupMenu
var treatment_part: String
var treatment_button: Button
var wound_labels: Dictionary = {}
## Minimized: the window is hidden, play continues, and a small tab bottom-left restores it.
var minimized: bool = false
var loot_signature: String = ""
var dock_layer: CanvasLayer
var dock_button: Button
const TREATMENTS: Array[String] = ["bandage", "disinfect", "remove"]
var rows: Dictionary = {}
var collect_buttons: Array[Button] = []
var cached_mode: String = ""
func _ready() -> void:
	layer=10
	shade=ColorRect.new(); shade.color=Color(0.02,0.03,0.025,0.62); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(shade)
	panel=PanelContainer.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left=-430; panel.offset_right=430; panel.offset_top=-325; panel.offset_bottom=325
	var style:=StyleBoxFlat.new(); style.bg_color=Color("17221f"); style.border_color=Color("a68d5f"); style.set_border_width_all(2); style.set_corner_radius_all(8); style.content_margin_left=20; style.content_margin_right=20; style.content_margin_top=16; style.content_margin_bottom=16
	standard_style = style
	health_style = StyleBoxFlat.new()
	health_style.bg_color = Color("191c1e")
	health_style.border_color = Color("606669")
	health_style.set_border_width_all(1)
	health_style.content_margin_left = 15
	health_style.content_margin_right = 15
	health_style.content_margin_top = 12
	health_style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel",style); add_child(panel)
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",10); panel.add_child(column)
	var header:=HBoxContainer.new(); column.add_child(header)
	title=Label.new(); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; title.add_theme_font_size_override("font_size",24); header.add_child(title)
	var minimize:=Button.new(); minimize.text="– Minimize"; minimize.tooltip_text="Hide this window and keep playing; click the tab at the bottom left to bring it back"; minimize.pressed.connect(minimize_window); header.add_child(minimize)
	var close:=Button.new(); close.text="Close · Esc"; close.pressed.connect(func() -> void: show_mode("")); header.add_child(close)
	dock_layer = CanvasLayer.new(); dock_layer.layer = 9; add_child(dock_layer)
	dock_button = Button.new(); dock_button.visible = false; dock_button.focus_mode = Control.FOCUS_NONE
	dock_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); dock_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dock_button.offset_left = 14; dock_button.offset_top = -52; dock_button.offset_right = 190; dock_button.offset_bottom = -16
	dock_button.pressed.connect(restore_window); dock_layer.add_child(dock_button)
	body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 13)
	column.add_child(body)
	diagram = BodyDiagram.new()
	diagram.part_selected.connect(select_part)
	diagram.treatment_requested.connect(_open_treatment)
	body.add_child(diagram)
	_build_meter()
	var status_column := VBoxContainer.new()
	status_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_column.add_theme_constant_override("separation", 7)
	body.add_child(status_column)
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_column.add_child(summary)
	healthy_toggle = CheckButton.new()
	healthy_toggle.text = "Show healthy areas"
	healthy_toggle.toggled.connect(func(_active: bool) -> void: refresh())
	status_column.add_child(healthy_toggle)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status_column.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size.y = 36
	column.add_child(detail)
	treatment_bar = HBoxContainer.new()
	column.add_child(treatment_bar)
	treatment_button = add_button(treatment_bar, "Treatment ▾", func() -> void: _open_treatment(selected_part, true))
	var hint := Label.new()
	hint.text = "Right-click a body part for treatment"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("bec5c4"))
	treatment_bar.add_child(hint)
	treatment_menu = PopupMenu.new()
	treatment_menu.id_pressed.connect(func(id: int) -> void:
		simulation.submit("treat_body", {"part": treatment_part, "action": TREATMENTS[id]}))
	panel.add_child(treatment_menu)
	notice=Label.new(); notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; notice.custom_minimum_size.y=42; notice.add_theme_color_override("font_color",Color("dec58e")); column.add_child(notice)
	show_mode("")
func _build_meter() -> void:
	meter_column = VBoxContainer.new()
	meter_column.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(meter_column)
	health_meter = TextureProgressBar.new()
	health_meter.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	health_meter.texture_under = _meter_texture(Color("383d40"), Color("0f1011"))
	health_meter.texture_progress = _meter_texture(Color("f0eee4"), Color("787e81"))
	health_meter.tooltip_text = "Overall body health"
	meter_column.add_child(health_meter)
	var heart := Label.new()
	heart.text = "♥"
	heart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heart.add_theme_color_override("font_color", Color("db919a"))
	heart.add_theme_font_size_override("font_size", 23)
	meter_column.add_child(heart)

func _meter_texture(top: Color, bottom: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([top, bottom])
	var texture := GradientTexture2D.new()
	texture.width = 17
	texture.height = 228
	texture.fill_to = Vector2(0, 1)
	texture.gradient = gradient
	return texture

func _open_treatment(part: String, from_button: bool = false) -> void:
	if mode != "health" or not Health.PARTS.has(part): return
	selected_part = part
	treatment_part = part
	refresh()
	var state: Dictionary = simulation.state
	var limb: Dictionary = state.player_health.parts[part]
	treatment_menu.clear()
	var labels := ["Replace dirty bandage" if limb.bandage == "dirty" else "Apply bandage", "Clean wound", "Remove bandage"]
	for index in range(TREATMENTS.size()):
		var problem := Health.treatment_problem(state, part, TREATMENTS[index])
		treatment_menu.add_item(labels[index], index)
		treatment_menu.set_item_disabled(index, not problem.is_empty())
		treatment_menu.set_item_tooltip(index, problem)
	var point := Vector2i(get_viewport().get_mouse_position()) + Vector2i(6, 6)
	if from_button:
		point = Vector2i(treatment_button.global_position + Vector2(0, treatment_button.size.y))
	treatment_menu.popup(Rect2i(point, Vector2i.ZERO))

func scrolls_health_list_at(point: Vector2) -> bool:
	return mode == "health" and visible and scroll.get_v_scroll_bar().visible and scroll.get_global_rect().has_point(point)

func minimize_window() -> void:
	if mode.is_empty(): return
	minimized = true
	visible = false
	treatment_menu.hide()
	dock_button.text = "▲  " + {"inventory": "Inventory", "health": "Health", "loot": "Searching", "wardrobe": "Clothes"}.get(mode, "Trading")
	dock_button.visible = true

func restore_window() -> void:
	minimized = false
	dock_button.visible = false
	visible = not mode.is_empty()

func show_mode(value: String) -> void:
	treatment_menu.hide()
	var opening_health := value == "health" and mode != "health"
	mode = value
	minimized = false
	dock_button.visible = false
	visible = not mode.is_empty()
	if simulation == null: return
	if opening_health and simulation.state.has("player_health"):
		var parts: Dictionary = simulation.state.player_health.parts
		if not _is_injured(parts[selected_part]):
			for part in Health.PARTS:
				if _is_injured(parts[part]):
					selected_part = part
					break
	refresh()
func toggle(value: String) -> void:
	# While minimized, the same key brings the window back instead of closing it.
	if minimized and mode == value: restore_window()
	else: show_mode("" if mode==value else value)
func select_part(part: String) -> void:
	if not Health.PARTS.has(part): return
	selected_part = part
	refresh()
	if mode == "health" and rows[part].visible:
		scroll.ensure_control_visible.call_deferred(rows[part])
func add_button(parent: Node,text: String,callback: Callable) -> Button:
	var button:=Button.new(); button.text=text; button.pressed.connect(callback); parent.add_child(button); return button
func rebuild() -> void:
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	rows.clear(); wound_labels.clear(); collect_buttons.clear(); cached_mode=mode
	var is_health := mode == "health"
	var half_size := Vector2(264, 251) if is_health else Vector2(430, 325)
	panel.offset_left = -half_size.x
	panel.offset_right = half_size.x
	panel.offset_top = -half_size.y
	panel.offset_bottom = half_size.y
	panel.add_theme_stylebox_override("panel", health_style if is_health else standard_style)
	shade.color = Color(0.03, 0.04, 0.045, 0.27) if is_health else Color(0.02, 0.03, 0.025, 0.62)
	if is_health:
		empty_wounds = Label.new()
		empty_wounds.text = "No injuries to treat."
		list.add_child(empty_wounds)
		for part in Health.PARTS:
			var button := add_button(list, "", func() -> void: select_part(part))
			button.custom_minimum_size.y = 44
			button.toggle_mode = true
			var selected_style := StyleBoxFlat.new()
			selected_style.bg_color = Color("363c40")
			selected_style.set_corner_radius_all(3)
			button.add_theme_stylebox_override("pressed", selected_style)
			button.add_theme_stylebox_override("hover_pressed", selected_style)
			button.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
					button.accept_event()
					_open_treatment(part))
			var labels := VBoxContainer.new()
			labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
			labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			labels.offset_left = 9
			labels.offset_top = 3
			labels.add_theme_constant_override("separation", 0)
			button.add_child(labels)
			var name_label := Label.new()
			name_label.text = _part_name(part)
			labels.add_child(name_label)
			var wound := Label.new()
			wound.add_theme_font_size_override("font_size", 13)
			labels.add_child(wound)
			rows[part] = button
			wound_labels[part] = wound
	elif mode in ["loot", "wardrobe"]:
		loot_signature = ""   # rows are built from the live contents in _refresh_loot
	else:
		for item in ["log","plank","food","rye","bandage","antiseptic","shell","shotgun","tool","ore"]:
			var row:=HBoxContainer.new(); list.add_child(row)
			var label:=Label.new(); label.custom_minimum_size=Vector2(270,45); row.add_child(label); rows[item]=label
			if mode=="inventory":
				add_button(row,"Hold",func() -> void: simulation.submit("hold_item",{"item":item}))
				for slot in range(4):
					var hotbar_button := add_button(row,str(slot + 1),func() -> void: simulation.submit("hotbar_assign",{"slot":slot,"item":item}))
					hotbar_button.tooltip_text = "Put %s on hotbar slot %d" % [item,slot + 1]
					hotbar_button.custom_minimum_size = Vector2(28,24)
			else:
				add_button(row,"Buy 1",func() -> void: simulation.submit("person_trade",{"target":target,"item":item,"buy":true}))
				add_button(row,"Sell 1",func() -> void: simulation.submit("person_trade",{"target":target,"item":item,"buy":false}))
				collect_buttons.append(add_button(row,"Collect",func() -> void: simulation.submit("take_item",{"target":target,"item":item})))
		if mode=="inventory": add_button(list,"Stow held item · hands empty",func() -> void: simulation.submit("hold_item",{"item":""}))
func refresh() -> void:
	if simulation==null or not simulation.state.has("player_control"): return
	var s: Dictionary=simulation.state
	var pc: Dictionary=s.player_control
	if pc.ui_nonce!=last_nonce:
		last_nonce=pc.ui_nonce; target=pc.ui_target; mode=str(pc.get("ui_kind","trade")); loot_signature=""; minimized=false; dock_button.visible=false; visible=true
	if mode.is_empty(): return
	if cached_mode!=mode: rebuild()
	dock_button.visible = minimized
	var is_health := mode == "health"
	diagram.visible = is_health
	meter_column.visible = is_health
	healthy_toggle.visible = is_health
	treatment_bar.visible = is_health
	if is_health:
		_refresh_health(s)
	elif mode in ["loot", "wardrobe"]:
		_refresh_loot(s, pc)
	elif mode=="inventory":
		title.text="YOUR INVENTORY · I"
		var inv: Dictionary=s.inventories[str(s.player)]
		summary.text="Backpack: %d / %d   ·   %d coins\nHolding: %s" % [Inventory.used(inv),inv.capacity,s.accounts.get(str(s.player),0),"nothing" if pc.held_item.is_empty() else "%d %s" % [pc.held_quantity,pc.held_item]]
		for item in rows: rows[item].text="%s   × %d" % [item.capitalize(),Inventory.amount(s,s.player,item)]
		detail.text="Hold an item, close this panel, then press F to put it down.\nBandages and antiseptic are used from the H health screen."
		notice.text=pc.notice
	else:
		var e: Dictionary=s.entities.get(str(target),{})
		if e.is_empty(): show_mode(""); return
		title.text="INTERACT · "+e.name
		for button in collect_buttons: button.visible=e.kind in ["stash","sawmill"]
		var npc: Dictionary=s.get("residents",{}).get(str(target),{})
		summary.text=("“I’m %s.”\n" % npc.get("status","available").to_lower() if not npc.is_empty() else "Village supplies · buy or sell goods.\n")+"You: %d coins · Other party: %d coins" % [s.accounts.get(str(s.player),0),s.accounts.get(str(target),0)]
		for item in rows:
			rows[item].get_parent().visible = e.kind != "market_stall" or item in e.sale_items
			rows[item].text="%s · You %d / Here %d\nBuy %d · Sell %d coins" % [item.capitalize(),Inventory.amount(s,s.player,item),Inventory.amount(s,target,item),Market.quote(s,e.settlement,item,true),Market.quote(s,e.settlement,item,false)]
		detail.text = "Goods come from this stall’s stock. Stay at the counter to trade." if e.kind == "market_stall" else "Stay nearby to trade. People trade personal goods; work cargo is unavailable."
		notice.text=pc.notice

func _part_name(part: String) -> String:
	return part.replace("_", " ").capitalize()

func _is_injured(wound: Dictionary) -> bool:
	return wound.damage > 0 or wound.infection > 0 or wound.bandage != "none"

func _refresh_health(s: Dictionary) -> void:
	var health: Dictionary = s.player_health
	title.text = "Health"
	var value := Health.overall(s)
	var pain := Health.pain(s)
	health_meter.value = value
	health_meter.tooltip_text = "Overall health · %d%%" % value
	var condition := "Healthy"
	var injuries: Array[String] = []
	for part in Health.PARTS:
		var wound: Dictionary = health.parts[part]
		if _is_injured(wound):
			injuries.append(part)
	if not injuries.is_empty(): condition = "Minor injuries" if value >= 90 else ("Injured" if value >= 65 else "Severe injuries")
	if Health.incapacitated(s): condition = "Critical injuries"
	summary.text = "Overall body status
%s · %d%%
%s · Stamina %d/%d" % [
		condition, value, "No pain" if pain == 0 else "Pain %d/100" % pain,
		health.stamina, health.stamina_max,
	]
	diagram.parts = health.parts
	diagram.selected = selected_part
	diagram.player_id = s.player
	diagram.outfit = Outfits.worn(s, s.player)
	diagram.queue_redraw()
	empty_wounds.visible = injuries.is_empty() and not healthy_toggle.button_pressed
	for part in Health.PARTS:
		var data: Dictionary = health.parts[part]
		var statuses: PackedStringArray = []
		var color := Color("bcc4c3")
		if data.bandage == "dirty":
			statuses.append("Dirty bandage")
			color = Color("e5a271")
		elif data.bandage == "clean":
			statuses.append("Bandaged")
			color = Color("9dd391")
		elif data.wound != "none":
			statuses.append(data.wound.capitalize())
			color = Color("e4adb1")
		if data.bleeding:
			statuses.append("Bleeding")
			color = Color("f29996")
		if data.infection > 0:
			statuses.append("Infection %d%%" % data.infection)
			if not data.bleeding and data.bandage != "dirty": color = Color("e5a271")
		var label: Label = wound_labels[part]
		label.text = "Healthy" if statuses.is_empty() else " · ".join(statuses)
		label.add_theme_color_override("font_color", color)
		rows[part].visible = healthy_toggle.button_pressed or injuries.has(part)
		rows[part].set_pressed_no_signal(part == selected_part)
	var limb: Dictionary = health.parts[selected_part]
	detail.text = "%s · %d%% damage   |   %d bandages · %d antiseptic" % [
		_part_name(selected_part), limb.damage, Inventory.amount(s, s.player, "bandage"),
		Inventory.amount(s, s.player, "antiseptic"),
	]
	treatment_button.disabled = not health.treatment.is_empty()
	notice.text = health.notice
	if not health.treatment.is_empty():
		notice.text += "  %.1f seconds remaining." % (maxi(0, health.treatment.finish - s.tick) / 10.0)

## The search / chest / wardrobe window: live rows for what is worn and what is carried, each with
## the buttons that act on it. Rebuilt only when the contents change.
func _refresh_loot(s: Dictionary, pc: Dictionary) -> void:
	var e: Dictionary = s.entities.get(str(target), {})
	if e.is_empty(): show_mode(""); return
	var wardrobe: bool = mode == "wardrobe"
	var chest: bool = e.kind == "chest"
	var items: Dictionary = s.inventories.get(str(target), {}).get("items", {}).duplicate()
	var outfit: Dictionary = Outfits.worn(s, target)
	var coins: int = int(s.get("accounts", {}).get(str(target), 0)) if not wardrobe and not chest else 0
	var pack: Dictionary = s.inventories[str(s.player)].items.duplicate()
	var signature := str([mode, target, items, outfit, coins, pack if wardrobe else {}])
	title.text = "YOUR CLOTHES" if wardrobe else (("OPEN · " + e.name.to_upper()) if chest else ("SEARCHING · " + e.name.to_upper()))
	var npc: Dictionary = s.get("residents", {}).get(str(target), {})
	summary.text = ("%s is %s.\n" % [e.name, "out cold" if not npc.is_empty() and not npc.get("knock", {}).is_empty() else "asleep"] if not npc.is_empty() and not wardrobe else "") + "Your pack: %d / %d" % [Inventory.used(s.inventories[str(s.player)]), s.inventories[str(s.player)].capacity]
	detail.text = "Take what you want. They will not forget it." if not chest and not wardrobe else ("Wear a piece to change how you look; spares stay in your pack." if wardrobe else "Take what you need; chests refill only when you put things in.")
	notice.text = pc.notice
	if signature == loot_signature: return
	loot_signature = signature
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	if wardrobe or not chest:
		_loot_header("You are wearing" if wardrobe else "Wearing")
		for slot in Outfits.SLOTS:
			var item: String = str(outfit.get(slot, ""))
			var buttons: Array = []
			if not item.is_empty():
				if wardrobe: buttons.append(["Take off", func() -> void: simulation.submit("take_off", {"slot": slot})])
				else:
					buttons.append(["Take", func() -> void: simulation.submit("loot_strip", {"target": target, "slot": slot, "wear": false})])
					buttons.append(["Take & wear", func() -> void: simulation.submit("loot_strip", {"target": target, "slot": slot, "wear": true})])
			_loot_row("%s:  %s" % [Outfits.SLOT_NAMES[slot], Outfits.label(item) if not item.is_empty() else "nothing"], buttons, item.is_empty())
	var shown: Dictionary = pack if wardrobe else items
	_loot_header("In your pack" if wardrobe else ("Inside" if chest else "Carrying"))
	var any := false
	for item in shown:
		if int(shown[item]) <= 0: continue
		if wardrobe and not Outfits.is_clothing(item): continue
		any = true
		var buttons: Array = []
		if wardrobe: buttons.append(["Wear", func() -> void: simulation.submit("wear_item", {"item": item})])
		else:
			buttons.append(["Take", func() -> void: simulation.submit("loot_take", {"target": target, "item": item})])
			if Outfits.is_clothing(item): buttons.append(["Take & wear", func() -> void: _take_and_wear(item)])
		_loot_row("%s  × %d" % [Outfits.label(item), int(shown[item])], buttons)
	if not any: _loot_row("nothing" if not wardrobe else "no spare clothes", [], true)
	if coins > 0: _loot_row("Coins:  %d" % coins, [["Take", func() -> void: simulation.submit("loot_coins", {"target": target})]])
	if not wardrobe:
		var all_row := HBoxContainer.new(); list.add_child(all_row)
		add_button(all_row, "Take everything", func() -> void: simulation.submit("loot_all", {"target": target}))

func _take_and_wear(item: String) -> void:
	simulation.submit("loot_take", {"target": target, "item": item})
	simulation.submit("wear_item", {"item": item})

func _loot_header(text: String) -> void:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("c9bd9e"))
	list.add_child(label)

func _loot_row(text: String, buttons: Array, dim: bool = false) -> void:
	var row := HBoxContainer.new()
	list.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(300, 30)
	if dim: label.add_theme_color_override("font_color", Color("807a68"))
	row.add_child(label)
	for entry in buttons: add_button(row, entry[0], entry[1])
