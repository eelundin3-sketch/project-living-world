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
const EQUIPMENT: Array[Array] = [["hat", "Hat"], ["shirt", "Shirt"], ["pants", "Trousers"], ["boots", "Shoes"], ["pack", "Backpack"]]
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
var drop_target: String = ""   # where a dragged item would land, for highlighting

## The picture that follows the pointer while an item is dragged.
class DragIcon extends Control:
	var item: String = ""
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 26.0, Color(0.06, 0.08, 0.07, 0.75))
		if Outfits.is_clothing(item): ItemIcons.draw_clothing(self, Outfits.slot_of(item), Outfits.color(item), Vector2.ZERO, 1.0)
		else: ItemIcons.draw(self, item, Vector2.ZERO, 1.0)

func _init() -> void:
	custom_minimum_size = Vector2(GRID_LEFT + COLUMNS * PITCH - GAP, ROWS * PITCH - GAP)
	size = custom_minimum_size
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
	# The window shows only the grid and the clothing squares; actions are double-click,
	# right-click and the number keys over an item (see the hover card).
	info.visible = false
	action_row.visible = false

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
				var held_now: String = str(simulation.state.player_control.get("held_item", ""))
				if Outfits.is_clothing(item): simulation.submit("wear_item", {"item": item})
				elif item == held_now: simulation.submit("hold_item", {"item": ""})
				else: simulation.submit("hold_item", {"item": item})
		signature = ""
		refresh(simulation.state)
		accept_event()

# --- drag and drop -------------------------------------------------------------------------
# Drag an item onto its clothing square to put it on, a worn piece back into the grid to take it
# off, or an item onto a hotbar slot (the bottom bar accepts the same drag data).
func _get_drag_data(at_position: Vector2) -> Variant:
	if simulation == null: return null
	var key := _hit(at_position)
	var data: Dictionary = {}
	if key.begins_with("item:"):
		data = {"type": "lw_item", "item": key.substr(5), "from": "grid", "slot": ""}
	elif key.begins_with("slot:"):
		var worn: String = str(Outfits.worn(simulation.state, simulation.state.player).get(key.substr(5), ""))
		if worn.is_empty(): return null
		data = {"type": "lw_item", "item": worn, "from": "slot", "slot": key.substr(5)}
	else:
		return null
	var holder := Control.new()
	var icon := DragIcon.new()
	icon.item = data.item
	holder.add_child(icon)
	set_drag_preview(holder)
	return data

func _drop_key(at_position: Vector2, data: Variant) -> String:
	if not (data is Dictionary) or data.get("type", "") != "lw_item": return ""
	for index in range(EQUIPMENT.size()):
		if _slot_rect(index).has_point(at_position):
			var slot: String = EQUIPMENT[index][0]
			return "slot:" + slot if data.from == "grid" and Outfits.slot_of(str(data.item)) == slot else ""
	var grid_area := Rect2(Vector2(GRID_LEFT, 0), Vector2(COLUMNS * PITCH, ROWS * PITCH))
	if grid_area.has_point(at_position) and data.from == "slot": return "grid"
	return ""

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var key := _drop_key(at_position, data)
	if key != drop_target:
		drop_target = key
		queue_redraw()
	return not key.is_empty()

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var key := _drop_key(at_position, data)
	drop_target = ""
	if key.begins_with("slot:"): simulation.submit("wear_item", {"item": data.item})
	elif key == "grid": simulation.submit("take_off", {"slot": data.slot})
	signature = ""
	queue_redraw()

## Number keys 1-4 put the item under the pointer on that hotbar slot.
func _input(event: InputEvent) -> void:
	if simulation == null or not is_visible_in_tree() or not hover.begins_with("item:"): return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
		var slot: int = [KEY_1, KEY_2, KEY_3, KEY_4].find(event.physical_keycode)
		simulation.submit("hotbar_assign", {"slot": slot, "item": hover.substr(5)})
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and not hover.is_empty():
		hover = ""
		queue_redraw()
	if what == NOTIFICATION_DRAG_END and not drop_target.is_empty():
		drop_target = ""
		queue_redraw()

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
		if drop_target == key: draw_rect(rect.grow(1), Color("74d08f"), false, 2.5)
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
	if drop_target == "grid": draw_rect(Rect2(Vector2(GRID_LEFT - 3, -3), Vector2(COLUMNS * PITCH + 2, ROWS * PITCH + 2)), Color("74d08f"), false, 2.0)
	if get_viewport().gui_is_dragging(): return
	_draw_hover_card(s, font, outfit)

## A small card under the pointer: what the item is and what you can do with it.
func _draw_hover_card(s: Dictionary, font: Font, outfit: Dictionary) -> void:
	if hover.is_empty(): return
	var title := ""
	var hint := ""
	var anchor := Rect2()
	if hover.begins_with("item:"):
		var item: String = hover.substr(5)
		var index: int = stacks.find(item)
		if index < 0: return
		anchor = _cell_rect(index)
		title = "%s × %d" % [Outfits.label(item) if Outfits.is_clothing(item) else item.capitalize(), Inventory.amount(s, s.player, item)]
		hint = "Double-click to wear" if Outfits.is_clothing(item) else "Double-click to hold · 1-4: hotbar"
	elif hover.begins_with("slot:"):
		var worn: String = str(outfit.get(hover.substr(5), ""))
		if worn.is_empty(): return
		for index in range(EQUIPMENT.size()):
			if EQUIPMENT[index][0] == hover.substr(5): anchor = _slot_rect(index)
		title = Outfits.label(worn)
		hint = "Double-click to take off"
	var width: float = maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x) + 18.0
	var at := Vector2(clampf(anchor.position.x, 0.0, size.x - width), anchor.end.y + 4.0)
	if at.y + 40.0 > size.y: at.y = anchor.position.y - 44.0
	draw_rect(Rect2(at + Vector2(2, 3), Vector2(width, 40)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(at, Vector2(width, 40)), Color("101614"))
	draw_rect(Rect2(at, Vector2(width, 40)), GOLD, false, 1.0)
	draw_string(font, at + Vector2(9, 17), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f0e4c8"))
	draw_string(font, at + Vector2(9, 32), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a89c7e"))
