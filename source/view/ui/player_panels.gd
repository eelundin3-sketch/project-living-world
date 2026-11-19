extends CanvasLayer
const Health = preload("res://sim/combat/body_health.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Market = preload("res://sim/economy/market.gd")
const BodyDiagram = preload("res://view/ui/body_diagram.gd")
const Outfits = preload("res://sim/entities/outfits.gd")
const HealthWindow = preload("res://view/ui/health_window.gd")
const InventoryWindow = preload("res://view/ui/inventory_window.gd")
const TradeWindow = preload("res://view/ui/trade_window.gd")
var trade_window: Control
var inventory_window: Control
var inventory_moved := false
var loot_window: Control
var loot_moved := false
var health_window: Control
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
	# The health screen is its own window with its own look.
	var health_anchor := Control.new()
	health_anchor.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	health_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(health_anchor)
	health_window = HealthWindow.new()
	health_window.simulation = simulation
	health_window.visible = false
	health_anchor.add_child(health_window)
	health_window.close_requested.connect(func() -> void: show_mode(""))
	health_window.minimize_requested.connect(minimize_window)
	# The inventory is a small draggable window at the left; the world stays visible around it.
	inventory_window = InventoryWindow.new()
	inventory_window.simulation = simulation
	inventory_window.visible = false
	add_child(inventory_window)
	inventory_window.close_requested.connect(func() -> void: show_mode(""))
	inventory_window.minimize_requested.connect(minimize_window)
	loot_window = InventoryWindow.new()
	loot_window.simulation = simulation
	loot_window.visible = false
	add_child(loot_window)
	loot_window.close_requested.connect(func() -> void: show_mode(""))
	loot_window.minimize_requested.connect(minimize_window)
	trade_window = TradeWindow.new()
	trade_window.simulation = simulation
	trade_window.visible = false
	add_child(trade_window)
	trade_window.close_requested.connect(func() -> void: show_mode(""))
	trade_window.minimize_requested.connect(minimize_window)
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
	return mode == "health" and visible and health_window != null and health_window.scrolls_list_at(point)

func minimize_window() -> void:
	if mode.is_empty(): return
	minimized = true
	treatment_menu.hide()
	_apply_visibility()
	dock_button.text = "▲  " + {"inventory": "Inventory", "health": "Health", "loot": "Searching", "wardrobe": "Clothes"}.get(mode, "Trading")
	dock_button.visible = true

func restore_window() -> void:
	minimized = false
	dock_button.visible = false
	visible = not mode.is_empty()
	_apply_visibility()
func _apply_visibility() -> void:
	var shown := not minimized and not mode.is_empty()
	panel.visible = shown and mode not in ["health", "inventory", "loot", "wardrobe", "trade"]
	shade.visible = shown and mode not in ["inventory", "loot", "wardrobe"]
	shade.color = Color(0.02, 0.03, 0.035, 0.55) if mode == "health" else Color(0.02, 0.03, 0.025, 0.62)
	if health_window != null: health_window.visible = shown and mode == "health"
	if inventory_window != null: inventory_window.visible = shown and mode in ["inventory", "loot", "wardrobe"]
	if loot_window != null: loot_window.visible = shown and mode == "loot"
	if trade_window != null:
		var opening_trade: bool = shown and mode == "trade" and not trade_window.visible
		trade_window.visible = shown and mode == "trade"
		if opening_trade: trade_window.position = trade_window.home_position()

func show_mode(value: String) -> void:
	treatment_menu.hide()
	var opening_health := value == "health" and mode != "health"
	var kneels := func(m: String) -> bool: return m in ["inventory", "loot", "wardrobe"]
	if simulation != null and kneels.call(value) != kneels.call(mode):
		simulation.submit("rummage", {"open": kneels.call(value)})
	mode = value
	minimized = false
	dock_button.visible = false
	visible = not mode.is_empty()
	_apply_visibility()
	if inventory_window != null:
		inventory_window.simulation = simulation
		loot_window.simulation = simulation
		var opening: bool = mode in ["inventory", "loot", "wardrobe"] and not inventory_window.visible
		if opening and not inventory_moved: inventory_window.position = inventory_window.home_position()
		if mode == "loot" and not loot_moved: loot_window.position = inventory_window.position + Vector2(inventory_window.size.x + 18.0, 0.0)
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
	if health_window != null: health_window.select_part(part)
	refresh()
func add_button(parent: Node,text: String,callback: Callable) -> Button:
	var button:=Button.new(); button.text=text; button.pressed.connect(callback); parent.add_child(button); return button
func rebuild() -> void:
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	rows.clear(); wound_labels.clear(); collect_buttons.clear(); cached_mode=mode
	var is_health := mode == "health"
	var half_size := Vector2(264, 251) if is_health else (Vector2(305, 350) if mode == "inventory" else Vector2(430, 325))
	panel.offset_left = -half_size.x
	panel.offset_right = half_size.x
	panel.offset_top = -half_size.y
	panel.offset_bottom = half_size.y
	panel.add_theme_stylebox_override("panel", health_style if is_health else standard_style)
	shade.color = Color(0.03, 0.04, 0.045, 0.27) if is_health else Color(0.02, 0.03, 0.025, 0.62)
	if is_health:
		pass   # drawn by the health window
	elif mode in ["loot", "wardrobe"]:
		loot_signature = ""   # rows are built from the live contents in _refresh_loot
	elif mode == "inventory":
		pass   # the grid draws itself
	else:
		if mode != "inventory":
			# Haggle once a visit; the terms show in the summary line.
			var talk_row := HBoxContainer.new(); list.add_child(talk_row)
			add_button(talk_row, "Haggle", func() -> void: simulation.submit("haggle", {"target": target}))
		for item in ["log","plank","food","rye","bandage","antiseptic","cartridge","rifle","shell","shotgun","tool","ore"]:
			var row:=HBoxContainer.new(); list.add_child(row)
			var label:=Label.new(); label.custom_minimum_size=Vector2(270,45); row.add_child(label); rows[item]=label
			if mode=="inventory":
				add_button(row,"Hold",func() -> void: simulation.submit("hold_item",{"item":item}))
				for slot in range(4):
					var hotbar_button := add_button(row,str(slot + 1),func() -> void: simulation.submit("hotbar_assign",{"slot":slot,"item":item}))
					hotbar_button.tooltip_text = "Put %s on hotbar slot %d" % [item,slot + 1]
					hotbar_button.custom_minimum_size = Vector2(28,24)
			else:
				add_button(row,"Buy 1",func() -> void: simulation.submit("person_trade",{"target":target,"item":item,"buy":true,"quantity":1}))
				add_button(row,"Buy 5",func() -> void: simulation.submit("person_trade",{"target":target,"item":item,"buy":true,"quantity":5}))
				add_button(row,"Sell 1",func() -> void: simulation.submit("person_trade",{"target":target,"item":item,"buy":false,"quantity":1}))
				add_button(row,"Sell all",func() -> void: simulation.submit("person_trade",{"target":target,"item":item,"buy":false,"quantity":-1}))
				collect_buttons.append(add_button(row,"Collect",func() -> void: simulation.submit("take_item",{"target":target,"item":item})))
		if mode=="inventory": add_button(list,"Stow held item · hands empty",func() -> void: simulation.submit("hold_item",{"item":""}))
func refresh() -> void:
	if simulation==null or not simulation.state.has("player_control"): return
	var s: Dictionary=simulation.state
	var pc: Dictionary=s.player_control
	if pc.ui_nonce!=last_nonce:
		last_nonce=pc.ui_nonce; target=pc.ui_target; var wanted := str(pc.get("ui_kind","trade"))
		if (wanted in ["inventory", "loot", "wardrobe"]) != (mode in ["inventory", "loot", "wardrobe"]):
			simulation.submit("rummage", {"open": wanted in ["inventory", "loot", "wardrobe"]})
		mode=wanted; minimized=false; dock_button.visible=false; visible=true
		if mode == "trade": trade_window.tab = str(pc.get("ui_tab", "trade"))   # Talk opens on the Talk tab
		if mode == "loot" and not loot_moved: loot_window.position = inventory_window.position + Vector2(inventory_window.size.x + 18.0, 0.0)
	if mode.is_empty(): return
	if cached_mode!=mode: rebuild()
	_apply_visibility()
	dock_button.visible = minimized
	var is_health := mode == "health"
	diagram.visible = is_health
	meter_column.visible = is_health
	healthy_toggle.visible = is_health
	treatment_bar.visible = is_health
	scroll.visible = false
	if is_health:
		health_window.simulation = simulation
		if health_window.selected_part != selected_part and Health.PARTS.has(selected_part): health_window.selected_part = selected_part
		health_window.refresh(s)
		selected_part = health_window.selected_part
	elif mode in ["inventory", "wardrobe"]:
		inventory_window.refresh(s)
		if inventory_window.position != inventory_window.home_position(): inventory_moved = true
	elif mode == "loot":
		var e: Dictionary = s.entities.get(str(target), {})
		if e.is_empty(): show_mode(""); return
		var is_chest: bool = e.kind == "chest"
		var npc: Dictionary = s.get("residents", {}).get(str(target), {})
		var heading: String = String(e.name) if is_chest else ("%s (dead)" if not npc.is_empty() and npc.health <= 0 else "%s") % e.name
		loot_window.configure(heading, int(target), true, not is_chest)
		inventory_window.refresh(s)
		loot_window.refresh(s)
		if inventory_window.position != inventory_window.home_position(): inventory_moved = true
		if loot_window.position != inventory_window.position + Vector2(inventory_window.size.x + 18.0, 0.0): loot_moved = true
	elif mode == "trade":
		if not s.entities.has(str(target)): show_mode(""); return
		trade_window.simulation = simulation
		trade_window.show_for(target)
		trade_window.refresh(s)
	else:
		var e: Dictionary=s.entities.get(str(target),{})
		if e.is_empty(): show_mode(""); return
		title.text="INTERACT · "+e.name
		for button in collect_buttons: button.visible=e.kind in ["stash","sawmill"]
		var npc: Dictionary=s.get("residents",{}).get(str(target),{})
		var Stalls = load("res://sim/economy/stall_service.gd")
		var terms: Dictionary = pc.get("trade_terms", {})
		var pct: int = int(terms.get("pct", 0)) if int(terms.get("target", 0)) == target else 0
		var terms_text: String = "" if pct == 0 else ("  ·  Haggled: %d%% off" % -pct if pct < 0 else "  ·  Annoyed: %d%% dearer" % pct)
		var keeper: Dictionary = Stalls.counterpart(s, target)
		var who: String = String(s.entities.get(str(keeper.get("id", 0)), {}).get("name", "")) if not keeper.is_empty() else ""
		var first_line: String = ("“I’m %s.”\n" % npc.get("status","available").to_lower()) if not npc.is_empty() else (("%s is minding the stall.\n" % who) if not who.is_empty() else "Village supplies · buy or sell goods.\n")
		summary.text=first_line+"You: %d coins · Other party: %d coins%s" % [s.accounts.get(str(s.player),0),s.accounts.get(str(target),0),terms_text]
		for item in rows:
			rows[item].get_parent().visible = e.kind != "market_stall" or item in e.sale_items
			rows[item].text="%s · You %d / Here %d\nBuy %d · Sell %d coins" % [item.capitalize(),Inventory.amount(s,s.player,item),Inventory.amount(s,target,item),Stalls.price(s,int(e.settlement),item,true,target),Stalls.price(s,int(e.settlement),item,false,target)]
		detail.text = "Goods come from this stall’s stock. Stay at the counter to trade." if e.kind == "market_stall" else "Stay nearby to trade. People trade personal goods; work cargo is unavailable."
		notice.text=pc.notice
func _part_name(part: String) -> String:
	return part.replace("_", " ").capitalize()

func _is_injured(wound: Dictionary) -> bool:
	return wound.damage > 0 or wound.infection > 0 or wound.bandage != "none"

