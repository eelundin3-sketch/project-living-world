extends Control
## The player's inventory: a 6x6 grid of item stacks, with four clothing squares down its left side
## (hat, shirt, trousers and shoes from top to bottom). Click an item for what it can do, double-click
## or right-click clothing to wear it, and click a worn piece to take it off.
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Outfits = preload("res://sim/entities/outfits.gd")
const ItemIcons = preload("res://view/ui/item_icons.gd")
const COLUMNS := 6
const ROWS := 6
const CELL := 56.0
const GAP := 4.0
const PITCH := CELL + GAP
const SLOT_WIDTH := 64.0
const GRID_LEFT := SLOT_WIDTH + 22.0
## The four equipment squares, top to bottom, and the outfit slot each one stands for.
const EQUIPMENT: Array[Array] = [["hat", "Hat"], ["shirt", "Shirt"], ["pants", "Trousers"], ["boots", "Shoes"]]
const PREFERRED: Array[String] = ["shotgun", "shell", "tool", "bandage", "antiseptic", "food", "rye", "log", "plank", "ore"]
const GOLD := Color("c79a3e")
const WELL := Color("0f1715")
const WELL_LIT := Color("1d2a27")
var simulation: RefCounted
var selected: String = ""       # "item:<name>" or "slot:<outfit slot>"
var hover: String = ""
var stacks: Array[String] = []
var action_row: HBoxContainer
var info: Label
var signature: String = ""
var last_click_msec: int = -10000
var last_click_key: String = ""

func _init() -> void:
	custom_minimum_size = Vector2(GRID_LEFT + COLUMNS * PITCH, ROWS * PITCH + 92.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	info = Label.new()
	info.position = Vector2(0, ROWS * PITCH + 6.0)
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", Color("dec58e"))
	info.size = Vector2(custom_minimum_size.x, 26)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info)
	action_row = HBoxContainer.new()
	action_row.position = Vector2(0, ROWS * PITCH + 36.0)
	action_row.add_theme_constant_override("separation", 6)
	add_child(action_row)

func _slot_rect(index: int) -> Rect2:
	var total: float = EQUIPMENT.size() * PITCH
	var top: float = (ROWS * PITCH - total) * 0.5
	return Rect2(Vector2(0, top + index * PITCH), Vector2(SLOT_WIDTH, CELL))

func _cell_rect(index: int) -> Rect2:
	return Rect2(Vector2(GRID_LEFT + (index % COLUMNS) * PITCH, (index / COLUMNS) * PITCH), Vector2(CELL, CELL))

func _stack_list(s: Dictionary) -> Array[String]:
	var items: Dictionary = s.inventories[str(s.player)].items
	var result: Array[String] = []
	for item in PREFERRED:
		if int(items.get(item, 0)) > 0: result.append(item)
	var clothes: Array = []
	var others: Array = []
	for item in items.keys():
		if int(items[item]) <= 0 or PREFERRED.has(item): continue
		if Outfits.is_clothing(str(item)): clothes.append(str(item))
		else: others.append(str(item))
	clothes.sort()
	others.sort()
	for item in clothes + others:
		if result.size() < COLUMNS * ROWS: result.append(item)
	return result

func refresh(s: Dictionary) -> void:
	stacks = _stack_list(s)
	var outfit: Dictionary = Outfits.worn(s, s.player)
	if selected.begins_with("item:") and not stacks.has(selected.substr(5)): selected = ""
	if selected.begins_with("slot:") and str(outfit.get(selected.substr(5), "")).is_empty(): selected = ""
	var held: String = str(s.player_control.get("held_item", ""))
	var next_signature := str([stacks, s.inventories[str(s.player)].items, outfit, selected, held, s.get("hotbar", {}).get("slots", [])])
	if next_signature == signature: return
	signature = next_signature
	_rebuild_actions(s, outfit)
	queue_redraw()

func _rebuild_actions(s: Dictionary, outfit: Dictionary) -> void:
	for child in action_row.get_children():
		action_row.remove_child(child)
		child.queue_free()
	info.text = "Select an item, or a worn piece of clothing."
	if selected.begins_with("item:"):
		var item: String = selected.substr(5)
		var count: int = Inventory.amount(s, s.player, item)
		info.text = "%s × %d" % [Outfits.label(item) if Outfits.is_clothing(item) else item.capitalize(), count]
		if Outfits.is_clothing(item):
			_button("Wear", func() -> void: simulation.submit("wear_item", {"item": item}))
		else:
			_button("Hold", func() -> void: simulation.submit("hold_item", {"item": item}))
			var tag := Label.new()
			tag.text = "  Hotbar:"
			action_row.add_child(tag)
			for slot in range(4):
				var key_button := _button(str(slot + 1), func() -> void: simulation.submit("hotbar_assign", {"slot": slot, "item": item}))
				key_button.custom_minimum_size = Vector2(30, 0)
				key_button.tooltip_text = "Put %s on hotbar slot %d" % [item, slot + 1]
	elif selected.begins_with("slot:"):
		var slot: String = selected.substr(5)
		var worn: String = str(outfit.get(slot, ""))
		info.text = "Wearing: %s" % Outfits.label(worn)
		_button("Take off", func() -> void: simulation.submit("take_off", {"slot": slot}))
	if not str(s.player_control.get("held_item", "")).is_empty():
		var stow := _button("Stow held item", func() -> void: simulation.submit("hold_item", {"item": ""}))
		stow.tooltip_text = "Hands empty"

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	action_row.add_child(button)
	return button

func _hit(point: Vector2) -> String:
	for index in range(EQUIPMENT.size()):
		if _slot_rect(index).has_point(point): return "slot:" + EQUIPMENT[index][0]
	for index in range(stacks.size()):
		if _cell_rect(index).has_point(point): return "item:" + stacks[index]
	return ""

func _gui_input(event: InputEvent) -> void:
	if simulation == null: return
	if event is InputEventMouseMotion:
		var over := _hit(event.position)
		if over != hover:
			hover = over
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var key := _hit(event.position)
		if key.is_empty():
			selected = ""
			signature = ""
			refresh(simulation.state)
			return
		var now := Time.get_ticks_msec()
		var twice: bool = key == last_click_key and now - last_click_msec < 400
		last_click_key = key
		last_click_msec = now
		selected = key
		var quick: bool = twice or event.button_index == MOUSE_BUTTON_RIGHT
		if quick:
			if key.begins_with("slot:"):
				simulation.submit("take_off", {"slot": key.substr(5)})
			else:
				var item: String = key.substr(5)
				if Outfits.is_clothing(item): simulation.submit("wear_item", {"item": item})
				else: simulation.submit("hold_item", {"item": item})
		signature = ""
		refresh(simulation.state)
		accept_event()

func _frame(rect: Rect2, lit: bool, active: bool) -> void:
	draw_rect(rect.grow(2), Color("3b2a1d"))
	draw_rect(rect, WELL_LIT if lit else WELL)
	draw_rect(rect, GOLD if active else Color("5d4a30"), false, 2.5 if active else 1.5)

func _draw() -> void:
	if simulation == null: return
	var s: Dictionary = simulation.state
	var font: Font = ThemeDB.fallback_font
	var outfit: Dictionary = Outfits.worn(s, s.player)
	var held: String = str(s.player_control.get("held_item", ""))
	for index in range(EQUIPMENT.size()):
		var slot: String = EQUIPMENT[index][0]
		var rect := _slot_rect(index)
		var item: String = str(outfit.get(slot, ""))
		var key := "slot:" + slot
		_frame(rect, hover == key, selected == key)
		var centre := rect.get_center()
		if item.is_empty():
			ItemIcons.draw_clothing(self, slot, Color("6e6652"), centre, 0.28)
		else:
			ItemIcons.draw_clothing(self, slot, Outfits.color(item), centre, 1.0)
		draw_string(font, rect.position + Vector2(0, rect.size.y - 4), EQUIPMENT[index][1], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 10, Color("a89c7e", 0.9 if item.is_empty() else 0.65))
	var slots: Array = s.get("hotbar", {}).get("slots", [])
	for index in range(COLUMNS * ROWS):
		var rect := _cell_rect(index)
		var filled: bool = index < stacks.size()
		var key: String = "item:" + stacks[index] if filled else ""
		_frame(rect, filled and hover == key, filled and selected == key)
		if not filled: continue
		var item: String = stacks[index]
		var count: int = Inventory.amount(s, s.player, item)
		var centre := rect.get_center() + Vector2(0, -3)
		if Outfits.is_clothing(item): ItemIcons.draw_clothing(self, Outfits.slot_of(item), Outfits.color(item), centre, 1.0)
		else: ItemIcons.draw(self, item, centre, 1.0)
		if count > 1: draw_string(font, rect.position + Vector2(rect.size.x - 26, rect.size.y - 5), str(count), HORIZONTAL_ALIGNMENT_RIGHT, 22, 13, Color("f0e4c8"))
		var hotbar_index: int = slots.find(item)
		if hotbar_index >= 0: draw_string(font, rect.position + Vector2(4, 13), str(hotbar_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffd98a"))
		if item == held: draw_string(font, rect.position + Vector2(4, rect.size.y - 5), "held", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("9fd18a"))
