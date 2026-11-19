extends Control
## A 6x6 grid of item stacks, with clothing squares down its left side (hat, shirt, trousers, shoes,
## backpack). The player's own inventory uses it, and so does the loot window for a searched person
## or a chest ("foreign" mode): goods are taken by dragging them into your own grid (or onto a
## clothing square to put them on), or by double-clicking. Chests also accept goods dragged in.
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
## The equipment squares, top to bottom, and the outfit slot each one stands for.
const EQUIPMENT: Array[Array] = [["hat", "Hat"], ["shirt", "Shirt"], ["pants", "Trousers"], ["boots", "Shoes"], ["pack", "Backpack"]]
const PREFERRED: Array[String] = ["rifle", "cartridge", "shotgun", "shell", "tool", "bandage", "antiseptic", "food", "rye", "log", "plank", "ore"]
const GOLD := Color("c79a3e")
const WELL := Color("0f1715")
const WELL_LIT := Color("1d2a27")

var simulation: RefCounted
var selected: String = ""       # "item:<name>" or "slot:<outfit slot>"
var hover: String = ""
var stacks: Array[String] = []
var signature: String = ""
var last_click_msec: int = -10000
var last_click_key: String = ""
var drop_target: String = ""    # where a dragged item would land, for highlighting
var drop_action: String = ""
## Whose goods this grid shows: 0 is the player.
var owner_id: int = 0
var foreign: bool = false
var show_slots: bool = true
var grid_left: float = GRID_LEFT

## The picture that follows the pointer while an item is dragged.
class DragIcon extends Control:
	var item: String = ""
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 26.0, Color(0.06, 0.08, 0.07, 0.75))
		if item == "coins":
			draw_circle(Vector2.ZERO, 9.0, Color("e0b648"))
		elif Outfits.is_clothing(item): ItemIcons.draw_clothing(self, Outfits.slot_of(item), Outfits.color(item), Vector2.ZERO, 1.0)
		else: ItemIcons.draw(self, item, Vector2.ZERO, 1.0)

func _init() -> void:
	custom_minimum_size = Vector2(GRID_LEFT + COLUMNS * PITCH - GAP, ROWS * PITCH - GAP)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

## Chests have no clothing squares, so their grid sits flush left.
func set_layout(with_slots: bool) -> void:
	show_slots = with_slots
	grid_left = GRID_LEFT if with_slots else 0.0
	custom_minimum_size = Vector2(grid_left + COLUMNS * PITCH - GAP, ROWS * PITCH - GAP)
	size = custom_minimum_size
	signature = ""
	queue_redraw()

func _owner(s: Dictionary) -> int:
	return s.player if owner_id == 0 else owner_id

func _slot_rect(index: int) -> Rect2:
	var total: float = EQUIPMENT.size() * PITCH
	var top: float = (ROWS * PITCH - total) * 0.5
	return Rect2(Vector2(0, top + index * PITCH), Vector2(SLOT_WIDTH, CELL))

func _cell_rect(index: int) -> Rect2:
	return Rect2(Vector2(grid_left + (index % COLUMNS) * PITCH, (index / COLUMNS) * PITCH), Vector2(CELL, CELL))

func _grid_area() -> Rect2:
	return Rect2(Vector2(grid_left, 0), Vector2(COLUMNS * PITCH, ROWS * PITCH))

func _stack_list(s: Dictionary) -> Array[String]:
	var who: int = _owner(s)
	var items: Dictionary = s.inventories.get(str(who), {}).get("items", {})
	var result: Array[String] = []
	if foreign and int(s.get("accounts", {}).get(str(who), 0)) > 0 and s.entities.get(str(who), {}).get("kind", "") != "chest": result.append("coins")
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

func _count(s: Dictionary, item: String) -> int:
	if item == "coins": return int(s.get("accounts", {}).get(str(_owner(s)), 0))
	return Inventory.amount(s, _owner(s), item)

func refresh(s: Dictionary) -> void:
	stacks = _stack_list(s)
	var outfit: Dictionary = Outfits.worn(s, _owner(s)) if show_slots else {}
	if selected.begins_with("item:") and not stacks.has(selected.substr(5)): selected = ""
	if selected.begins_with("slot:") and str(outfit.get(selected.substr(5), "")).is_empty(): selected = ""
	var held: String = str(s.player_control.get("held_item", ""))
	var next_signature := str([stacks, s.inventories.get(str(_owner(s)), {}).get("items", {}), outfit, selected, held, s.get("hotbar", {}).get("slots", []), s.get("accounts", {}).get(str(_owner(s)), 0)])
	if next_signature == signature: return
	signature = next_signature
	queue_redraw()

func _hit(point: Vector2) -> String:
	if show_slots:
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
		if quick and foreign:
			if key.begins_with("slot:"): simulation.submit("loot_strip", {"target": owner_id, "slot": key.substr(5), "wear": false})
			elif key == "item:coins": simulation.submit("loot_coins", {"target": owner_id})
			else: simulation.submit("loot_take", {"target": owner_id, "item": key.substr(5)})
		elif quick:
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
func _get_drag_data(at_position: Vector2) -> Variant:
	if simulation == null: return null
	var key := _hit(at_position)
	var data: Dictionary = {}
	var who: int = _owner(simulation.state)
	if key.begins_with("item:"):
		data = {"type": "solo_item", "item": key.substr(5), "from": "grid", "slot": "", "owner": who}
	elif key.begins_with("slot:"):
		var worn: String = str(Outfits.worn(simulation.state, who).get(key.substr(5), ""))
		if worn.is_empty(): return null
		data = {"type": "solo_item", "item": worn, "from": "slot", "slot": key.substr(5), "owner": who}
	else:
		return null
	var holder := Control.new()
	var icon := DragIcon.new()
	icon.item = data.item
	holder.add_child(icon)
	set_drag_preview(holder)
	return data

## Where a dragged item would land on this grid: {"target": "grid"|"slot:<slot>", "action": ...}.
func _drop_info(at_position: Vector2, data: Variant) -> Dictionary:
	if not (data is Dictionary) or data.get("type", "") != "solo_item" or simulation == null: return {}
	var s: Dictionary = simulation.state
	var source: int = int(data.get("owner", s.player))
	var from_here: bool = source == _owner(s)
	var item: String = str(data.item)
	var over_grid: bool = _grid_area().has_point(at_position)
	var slot_hit := ""
	if show_slots:
		for index in range(EQUIPMENT.size()):
			if _slot_rect(index).has_point(at_position): slot_hit = EQUIPMENT[index][0]
	if not foreign:
		if from_here:   # your own goods moving about your own windows
			if not slot_hit.is_empty():
				return {"target": "slot:" + slot_hit, "action": "wear"} if data.from == "grid" and Outfits.slot_of(item) == slot_hit else {}
			return {"target": "grid", "action": "take_off"} if over_grid and data.from == "slot" else {}
		# Something dragged in from a searched person or a chest.
		if item == "coins": return {"target": "grid", "action": "coins"} if over_grid or not slot_hit.is_empty() else {}
		if data.from == "slot":
			if not slot_hit.is_empty() and slot_hit == str(data.slot): return {"target": "slot:" + slot_hit, "action": "strip_wear"}
			return {"target": "grid", "action": "strip"} if over_grid else {}
		if not slot_hit.is_empty() and Outfits.slot_of(item) == slot_hit: return {"target": "slot:" + slot_hit, "action": "take_wear"}
		return {"target": "grid", "action": "take"} if over_grid else {}
	# A searched person or chest: only chests accept goods.
	if source == s.player and data.from == "grid" and over_grid and s.entities.get(str(owner_id), {}).get("kind", "") == "chest":
		return {"target": "grid", "action": "give"}
	return {}

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var info := _drop_info(at_position, data)
	var key: String = str(info.get("target", ""))
	if key != drop_target:
		drop_target = key
		queue_redraw()
	drop_action = str(info.get("action", ""))
	return not info.is_empty()

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var info := _drop_info(at_position, data)
	drop_target = ""
	var source: int = int(data.get("owner", simulation.state.player))
	match str(info.get("action", "")):
		"wear": simulation.submit("wear_item", {"item": data.item})
		"take_off": simulation.submit("take_off", {"slot": data.slot})
		"take": simulation.submit("loot_take", {"target": source, "item": data.item})
		"take_wear":
			simulation.submit("loot_take", {"target": source, "item": data.item})
			simulation.submit("wear_item", {"item": data.item})
		"strip": simulation.submit("loot_strip", {"target": source, "slot": data.slot, "wear": false})
		"strip_wear": simulation.submit("loot_strip", {"target": source, "slot": data.slot, "wear": true})
		"coins": simulation.submit("loot_coins", {"target": source})
		"give": simulation.submit("loot_give", {"target": owner_id, "item": data.item})
	signature = ""
	queue_redraw()

## Number keys 1-4 put the item under the pointer on that hotbar slot (your own grid only).
func _input(event: InputEvent) -> void:
	if simulation == null or foreign or not is_visible_in_tree() or not hover.begins_with("item:"): return
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

func _coins(c: Vector2) -> void:
	for offset in [Vector2(-6, 4), Vector2(5, 3), Vector2(-1, -4)]:
		draw_circle(c + offset, 8.0, Color("e0b648"))
		draw_arc(c + offset, 8.0, 0.0, TAU, 18, Color("7a5a1c"), 1.2, true)
		draw_arc(c + offset, 4.6, 0.0, TAU, 14, Color("a9822a"), 1.0, true)

func _frame(rect: Rect2, lit: bool, active: bool) -> void:
	draw_rect(rect.grow(2), Color("3b2a1d"))
	draw_rect(rect, WELL_LIT if lit else WELL)
	draw_rect(rect, GOLD if active else Color("5d4a30"), false, 2.5 if active else 1.5)

func _draw() -> void:
	if simulation == null: return
	var s: Dictionary = simulation.state
	var font: Font = ThemeDB.fallback_font
	var outfit: Dictionary = Outfits.worn(s, _owner(s)) if show_slots else {}
	var held: String = str(s.player_control.get("held_item", "")) if not foreign else ""
	for index in range(EQUIPMENT.size() if show_slots else 0):
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
		var count: int = _count(s, item)
		var centre := rect.get_center() + Vector2(0, -3)
		if item == "coins": _coins(centre)
		elif Outfits.is_clothing(item): ItemIcons.draw_clothing(self, Outfits.slot_of(item), Outfits.color(item), centre, 1.0)
		else: ItemIcons.draw(self, item, centre, 1.0)
		if count > 1: draw_string(font, rect.position + Vector2(rect.size.x - 30, rect.size.y - 5), str(count), HORIZONTAL_ALIGNMENT_RIGHT, 26, 13, Color("f0e4c8"))
		var hotbar_index: int = slots.find(item) if not foreign else -1
		if hotbar_index >= 0: draw_string(font, rect.position + Vector2(4, 13), str(hotbar_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffd98a"))
		if item == held and not held.is_empty(): draw_string(font, rect.position + Vector2(4, rect.size.y - 5), "held", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("9fd18a"))
	if drop_target == "grid": draw_rect(Rect2(Vector2(grid_left - 3, -3), Vector2(COLUMNS * PITCH + 2, ROWS * PITCH + 2)), Color("74d08f"), false, 2.0)
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
		title = "%s × %d" % [Outfits.label(item) if Outfits.is_clothing(item) else item.capitalize(), _count(s, item)]
		hint = "Double-click or drag to take" if foreign else ("Double-click to wear" if Outfits.is_clothing(item) else "Double-click to hold · 1-4: hotbar")
	elif hover.begins_with("slot:"):
		var worn: String = str(outfit.get(hover.substr(5), ""))
		if worn.is_empty(): return
		for index in range(EQUIPMENT.size()):
			if EQUIPMENT[index][0] == hover.substr(5): anchor = _slot_rect(index)
		title = Outfits.label(worn)
		hint = "Double-click or drag to take" if foreign else "Double-click to take off"
	var width: float = maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x) + 18.0
	var at := Vector2(clampf(anchor.position.x, 0.0, size.x - width), anchor.end.y + 4.0)
	if at.y + 40.0 > size.y: at.y = anchor.position.y - 44.0
	draw_rect(Rect2(at + Vector2(2, 3), Vector2(width, 40)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(at, Vector2(width, 40)), Color("101614"))
	draw_rect(Rect2(at, Vector2(width, 40)), GOLD, false, 1.0)
	draw_string(font, at + Vector2(9, 17), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f0e4c8"))
	draw_string(font, at + Vector2(9, 32), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a89c7e"))
