extends RefCounted
const Inventory = preload("res://sim/inventory/inventory_store.gd")

static func validate(s: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not s.has("inventories"):
		return errors
	var live_ids: Dictionary = {}
	for store_name in ["entities", "jobs"]:
		for key in s.get(store_name, {}):
			var record: Dictionary = s[store_name][key]
			if str(record.id) != key or live_ids.has(record.id) or record.id >= s.next_id:
				errors.append("Invalid or duplicate identity")
			live_ids[record.id] = true
	for entry in s.commands + s.events:
		if live_ids.has(entry.id) or entry.id >= s.next_id:
			errors.append("Duplicate queue identity")
		live_ids[entry.id] = true
	var totals := Inventory.totals(s)
	for id in s.inventories:
		var inventory: Dictionary = s.inventories[id]
		if not s.entities.has(id):
			errors.append("Inventory has no physical owner: " + id)
		if Inventory.used(inventory) > inventory.capacity:
			errors.append("Capacity exceeded: " + id)
		var reserved: int = 0
		for quantity in inventory.reserved.values():
			reserved += quantity
		if Inventory.used(inventory) + reserved > inventory.capacity:
			errors.append("Capacity over-reserved: " + id)
		for quantity in inventory.items.values():
			if quantity < 0:
				errors.append("Negative inventory: " + id)
	var items: Dictionary = s.accounting.initial.duplicate()
	items.merge(s.accounting.created, true)
	items.merge(s.accounting.consumed, true)
	for item in items:
		var expected: int = int(s.accounting.initial.get(item, 0)) + int(s.accounting.created.get(item, 0)) - int(s.accounting.consumed.get(item, 0))
		if int(totals.get(item, 0)) != expected:
			errors.append("Material mismatch: " + item)
	var claims: Dictionary = {}
	for job in s.get("jobs", {}).values():
		if not s.entities.has(str(job.target)) or not s.inventories.has(str(job.destination)):
			errors.append("Dangling job target/destination")
		if job.owner != 0:
			if claims.has(job.target):
				errors.append("Double claim")
			claims[job.target] = job.owner
			if not s.residents.has(str(job.owner)) or s.residents[str(job.owner)].job != job.id:
				errors.append("Dangling job owner")
			if job.lease_until <= s.tick:
				errors.append("Expired live lease")
	for npc in s.get("residents", {}).values():
		if npc.hunger < 0 or npc.hunger > 100 or npc.fatigue < 0 or npc.fatigue > 100 or npc.get("thirst", 0) < 0 or npc.get("thirst", 0) > 100:
			errors.append("Invalid needs")
		if npc.job != 0 and not s.jobs.has(str(npc.job)):
			errors.append("Dangling NPC job")
		if not s.entities.has(str(npc.id)) or not s.inventories.has(str(npc.id)):
			errors.append("Missing resident identity/inventory")
	if s.has("accounts"):
		var money: int = 0
		for value in s.accounts.values():
			if value < 0:
				errors.append("Negative money")
			money += value
		if money != s.money_initial:
			errors.append("Currency mismatch")
	var event_ids: Dictionary = {}
	for event in s.events:
		if event_ids.has(event.id):
			errors.append("Duplicate pending event")
		event_ids[event.id] = true
	for npc in s.get("residents", {}).values():
		if npc.fidelity not in ["detailed", "coarse", "aggregate"]:
			errors.append("Invalid simulation fidelity")
		if npc.memories.size() > 16 or npc.relations.size() > 32:
			errors.append("Unbounded social state")
		for memory in npc.memories:
			if not s.entities.has(str(memory.subject)):
				errors.append("Dangling memory subject")
	for caravan in s.get("caravans", {}).values():
		if caravan.in_transit and not event_ids.has(caravan.event_id):
			errors.append("Caravan missing arrival event")
	return errors
