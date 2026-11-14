extends RefCounted
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const World = preload("res://sim/world/world_db.gd")
const Nav = preload("res://sim/movement/navigation.gd")

static func initialize(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	s.recipes = JSON.parse_string(FileAccess.get_file_as_string("res://content/recipes/core.json")).recipes
	s.workshops = {}
	add_workshop(sim, 1, [67, 43], s.warehouse)

static func add_workshop(sim: RefCounted, settlement: int, cell: Array, store: int) -> int:
	var id := World.add_entity(sim, "sawmill", "Timber workshop", cell, settlement)
	Inventory.create(sim.state, id, 100)
	sim.state.workshops[str(id)] = {"id": id, "settlement": settlement, "store": store, "recipe": "core:recipe/planks", "worker": 0,
		"progress": 0, "work_ticks": 40, "batch": 0, "completed": 0, "active": false, "status": "Waiting for logs", "enabled": true}
	return id

static func assign_worker(s: Dictionary, workshop: Dictionary) -> void:
	if s.residents.has(str(workshop.worker)):
		return
	workshop.worker = 0
	for npc in s.residents.values():
		if npc.settlement == workshop.settlement and npc.occupation == "Gatherer" and npc.get("migration", {}).is_empty() and npc.job == 0:
			npc.occupation = "Sawyer"
			workshop.worker = npc.id
			return

static func start(s: Dictionary, workshop: Dictionary, source: int = 0) -> bool:
	if workshop.active:
		return false
	var recipe: Dictionary = workshop.get("batch_recipe", s.recipes[workshop.recipe]) if workshop.active else s.recipes[workshop.recipe]
	var moved := Inventory.transfer(s, workshop.store if source == 0 else source, workshop.id, recipe.input, recipe.input_quantity)
	if not moved.ok:
		workshop.status = "Stopped: " + moved.error_code + " (logs)"
		return false
	workshop.batch_recipe = recipe.duplicate(true)
	workshop.batch += 1
	workshop.progress = 0
	workshop.active = true
	workshop.work_ticks = recipe.work_ticks
	workshop.status = "Sawing reserved logs"
	return true

static func finish(s: Dictionary, workshop: Dictionary) -> bool:
	if not workshop.active or workshop.progress < workshop.work_ticks:
		return false
	var recipe: Dictionary = workshop.get("batch_recipe", s.recipes[workshop.recipe]) if workshop.active else s.recipes[workshop.recipe]
	if Inventory.amount(s, workshop.id, recipe.input) < recipe.input_quantity:
		workshop.status = "Reserved inputs missing"
		return false
	if Inventory.available(s, workshop.id) + int(recipe.input_quantity) < int(recipe.output_quantity):
		workshop.status = "Output full"
		return false
	# Commit point: prevalidated consume and produce, synchronously and exactly once.
	Inventory.consume(s, workshop.id, recipe.input, recipe.input_quantity)
	Inventory.produce(s, workshop.id, recipe.output, recipe.output_quantity)
	workshop.active = false
	workshop.completed += 1
	workshop.output_item = recipe.output
	workshop.progress = 0
	workshop.status = "Batch complete"
	return true

static func cancel(s: Dictionary, workshop: Dictionary) -> bool:
	if not workshop.active:
		return false
	var recipe: Dictionary = workshop.get("batch_recipe", s.recipes[workshop.recipe]) if workshop.active else s.recipes[workshop.recipe]
	var moved := Inventory.transfer(s, workshop.id, workshop.store, recipe.input, recipe.input_quantity)
	if not moved.ok:
		workshop.status = "Cancellation awaiting storage capacity"
		return false
	workshop.active = false
	workshop.progress = 0
	workshop.status = "Batch cancelled; inputs returned"
	return true

static func work_at(s: Dictionary, npc: Dictionary, destination: int) -> bool:
	var actor: Dictionary = s.entities[str(npc.id)]
	var target: Array = s.entities[str(destination)].cell
	if actor.cell == target:
		return true
	if npc.get("work_destination", 0) != destination or npc.get("work_revision", -1) != s.world.nav_revision or npc.get("work_from", []) != actor.cell:
		var route := Nav.request_path(s, actor.cell, target)
		if not route.ok:
			npc.status = "Work: " + route.error_code
			return false
		npc.work_path = route.path
		npc.work_destination = destination
		npc.work_revision = s.world.nav_revision
	if not npc.get("work_path", []).is_empty():
		actor.cell = npc.work_path.pop_front()
	npc.work_from = actor.cell.duplicate()
	return false

static func update(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	if s.tick % 2 != 0:
		return
	for workshop in s.workshops.values():
		assign_worker(s, workshop)
		if workshop.worker == 0 or not workshop.enabled:
			continue
		var npc: Dictionary = s.residents[str(workshop.worker)]
		if npc.job != 0 or not npc.goal.is_empty() or npc.hunger >= 60 or npc.fatigue >= 75:
			workshop.status = "Worker attending to needs"
			continue
		var recipe: Dictionary = workshop.get("batch_recipe", s.recipes[workshop.recipe]) if workshop.active else s.recipes[workshop.recipe]
		var output_item: String = workshop.get("output_item", recipe.output)
		var outputs: int = Inventory.amount(s, workshop.id, output_item)
		if not workshop.active and outputs == 0 and Inventory.amount(s, workshop.store, recipe.output) < 300:
			if Inventory.amount(s, npc.id, recipe.input) >= recipe.input_quantity:
				if not work_at(s, npc, workshop.id):
					npc.status = "Carrying inputs to sawmill"
					continue
				start(s, workshop, npc.id)
				npc.work_cargo = false
			else:
				if work_at(s, npc, workshop.store):
					var pickup := Inventory.transfer(s, workshop.store, npc.id, recipe.input, recipe.input_quantity)
					if pickup.ok:
						npc.work_cargo = true
						workshop.status = "Worker hauling inputs"
					else:
						workshop.status = "Stopped: " + pickup.error_code + " (inputs)"
				continue
		if not work_at(s, npc, workshop.id):
			npc.status = "Walking to sawmill"
			continue
		if outputs > 0:
			if Inventory.transfer(s, workshop.id, npc.id, output_item, mini(outputs, Inventory.available(s, npc.id))).ok:
				npc.production_delivery = true
				continue
		if workshop.active:
			workshop.progress += 2
			npc.status = "Sawing logs into planks"
			finish(s, workshop)
