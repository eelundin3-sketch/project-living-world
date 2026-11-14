extends RefCounted
## Only this service changes physical item stacks. Reservations promise free capacity.

static func create(state: Dictionary, id: int, capacity: int, items: Dictionary = {}) -> void:
	state.inventories[str(id)] = {"capacity": capacity, "items": items.duplicate(true), "reserved": {}}

static func amount(state: Dictionary, id: int, item: String) -> int:
	return int(state.inventories.get(str(id), {}).get("items", {}).get(item, 0))

static func used(inventory: Dictionary) -> int:
	var total: int = 0
	for quantity in inventory.items.values():
		total += int(quantity)
	return total

static func available(state: Dictionary, id: int, token: String = "") -> int:
	if not state.inventories.has(str(id)):
		return 0
	var inventory: Dictionary = state.inventories[str(id)]
	var total: int = used(inventory)
	for key in inventory.reserved:
		if key != token:
			total += int(inventory.reserved[key])
	return maxi(0, int(inventory.capacity) - total)

static func reserve(state: Dictionary, id: int, token: String, quantity: int) -> bool:
	if quantity < 0 or available(state, id, token) < quantity:
		return false
	state.inventories[str(id)].reserved[token] = quantity
	return true

static func release(state: Dictionary, id: int, token: String) -> void:
	if state.inventories.has(str(id)):
		state.inventories[str(id)].reserved.erase(token)

static func result(ok: bool, error: String = "", ids: Array = []) -> Dictionary:
	return {"ok": ok, "error_code": error, "changed_ids": ids}

static func transfer(state: Dictionary, source: int, destination: int, item: String, quantity: int, token: String = "") -> Dictionary:
	if quantity <= 0 or source == destination:
		return result(false, "INVALID_TRANSFER")
	if not state.inventories.has(str(source)) or not state.inventories.has(str(destination)):
		return result(false, "MISSING_INVENTORY")
	if amount(state, source, item) < quantity:
		return result(false, "INSUFFICIENT_STOCK")
	if available(state, destination, token) < quantity:
		return result(false, "DESTINATION_FULL")
	_change(state, source, item, -quantity)
	_change(state, destination, item, quantity)
	if not token.is_empty():
		release(state, destination, token)
	return result(true, "", [source, destination])

static func consume(state: Dictionary, id: int, item: String, quantity: int) -> bool:
	if quantity <= 0 or amount(state, id, item) < quantity:
		return false
	_change(state, id, item, -quantity)
	state.accounting.consumed[item] = int(state.accounting.consumed.get(item, 0)) + quantity
	return true

static func produce(state: Dictionary, id: int, item: String, quantity: int) -> bool:
	if quantity <= 0 or available(state, id) < quantity:
		return false
	_change(state, id, item, quantity)
	state.accounting.created[item] = int(state.accounting.created.get(item, 0)) + quantity
	return true

static func _change(state: Dictionary, id: int, item: String, delta: int) -> void:
	var items: Dictionary = state.inventories[str(id)].items
	items[item] = int(items.get(item, 0)) + delta
	if items[item] == 0:
		items.erase(item)

static func totals(state: Dictionary) -> Dictionary:
	var total: Dictionary = {}
	for inventory in state.inventories.values():
		for item in inventory.items:
			total[item] = int(total.get(item, 0)) + int(inventory.items[item])
	return total
