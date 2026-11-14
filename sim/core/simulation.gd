extends RefCounted
const Canonical = preload("res://sim/core/canonical.gd")
const Streams = preload("res://sim/core/random_streams.gd")
const World = preload("res://sim/world/world_db.gd")
const Residents = preload("res://sim/entities/residents.gd")
const Jobs = preload("res://sim/jobs/job_board.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Recipes = preload("res://sim/production/recipe_system.gd")
const Planner = preload("res://sim/settlement/planner.gd")
const Market = preload("res://sim/economy/market.gd")
const Regional = preload("res://sim/economy/regional_trade.gd")
const Fidelity = preload("res://sim/world/fidelity.gd")
const Society = preload("res://sim/factions/society.gd")
const Risk = preload("res://sim/factions/risk_system.gd")
const Content = preload("res://sim/production/content_loader.gd")
const Navigation = preload("res://sim/movement/navigation.gd")
var state: Dictionary

func _init(seed_value: int = 417) -> void:
	state = {"format_version": 2, "content_version": 1, "seed": seed_value,
		"tick": 0, "next_id": 1, "commands": [], "events": [], "rng": {},
		"entities": {}, "history": [], "event_results": [], "ticks_per_minute": 10}

func start_village(population: int = 10) -> void:
	World.seed_world(self)
	Jobs.initialize(state)
	Residents.spawn(self, population)
	record("Welcome to Alder Hollow. Residents work without your direction.")

func enable_production() -> void:
	Recipes.initialize(self)

func enable_economy() -> void:
	Planner.initialize(self)
	Market.initialize(state)

func enable_region() -> void:
	Regional.initialize(self)

func enable_society() -> void:
	Society.initialize(state)
	Risk.initialize(state)

func start_game(population: int = 20) -> void:
	start_village(population)
	enable_production()
	enable_economy()
	enable_region()
	enable_society()

func new_id() -> int:
	var result: int = state.next_id
	state.next_id += 1
	return result

func submit(kind: String, payload: Dictionary = {}, due_tick: int = -1) -> int:
	if kind == "load_recipe":
		var loaded := Content.read_recipe(payload.get("path", "user://recipe.json"))
		kind = "install_recipe" if loaded.ok else "reject_recipe"
		payload = {"recipe": loaded.recipe} if loaded.ok else {"error": loaded.error}
	var id := new_id()
	state.commands.append({"id": id, "due": maxi(state.tick + 1, due_tick), "kind": kind, "payload": payload.duplicate(true)})
	return id

func schedule(kind: String, due_tick: int, payload: Dictionary = {}) -> int:
	var id := new_id()
	state.events.append({"id": id, "due": maxi(state.tick + 1, due_tick), "kind": kind, "payload": payload.duplicate(true)})
	return id

func random_int(stream: String, low: int, high: int) -> int:
	return Streams.next_int(state.rng, state.seed, stream, low, high)

func step() -> void:
	state.tick += 1
	_drain("commands", true)
	_drain("events", false)
	if state.has("residents"):
		if state.tick % 2 == 0 and not state.get("player_path", []).is_empty():
			var next: Array = state.player_path.pop_front()
			if World.walkable(state, next):
				state.entities[str(state.player)].cell = next
			else:
				state.player_path = []
		if state.tick % 10 == 0:
			Jobs.refresh(self)
		if state.has("routes"):
			Fidelity.update(state)
			Regional.update(self)
		Residents.update(self)
		if state.has("factions"):
			Society.update(self)
			Risk.update(self)
		if state.has("workshops"):
			Recipes.update(self)
		if state.has("construction"):
			Planner.update(self)
		if state.has("markets") and state.tick % 300 == 0:
			for town_id in state.markets:
				Market.clear_market(state, int(town_id))
		if state.tick % 14400 == 0:
			for entity in state.entities.values():
				if entity.kind == "farm":
					Inventory.produce(state, entity.id, "food", mini(200, Inventory.available(state, entity.id)))
				elif entity.kind == "tree":
					Inventory.produce(state, entity.id, "log", mini(2, Inventory.available(state, entity.id)))
			record("A new day: crops ripened and woodland grew.")

func _drain(queue_name: String, is_command: bool) -> void:
	state[queue_name].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.due < b.due or (a.due == b.due and a.id < b.id))
	while not state[queue_name].is_empty() and state[queue_name][0].due <= state.tick:
		var entry: Dictionary = state[queue_name].pop_front()
		if is_command:
			apply_command(entry)
		else:
			apply_event(entry)

func apply_command(entry: Dictionary) -> void:
	if entry.kind == "move_player" and state.has("player"):
		state.player_path = []
		var direction: Array = entry.payload.get("direction", [0, 0])
		if direction.size() == 2 and abs(direction[0]) + abs(direction[1]) == 1:
			var cell: Array = state.entities[str(state.player)].cell
			var next: Array = [cell[0] + direction[0], cell[1] + direction[1]]
			if World.walkable(state, next):
				state.entities[str(state.player)].cell = next
	elif entry.kind == "cancel_job" and state.has("jobs"):
		Jobs.release(state, int(entry.payload.get("id", 0)), "CANCELLED")
	elif entry.kind == "trade" and state.has("markets"):
		var result := Market.player_trade(self, entry.payload)
		if not result.ok:
			record("Trade rejected: " + result.error_code)
		elif state.has("factions") and not entry.payload.get("buy", false):
			Society.helpful_trade(self, int(entry.payload.get("town", 1)), entry.payload.get("item", "log"))
	elif entry.kind == "cancel_production" and state.has("workshops"):
		var key := str(entry.payload.get("id", 0))
		if state.workshops.has(key):
			Recipes.cancel(state, state.workshops[key])
	elif entry.kind == "route_block" and state.has("routes"):
		state.routes["1"].blocked = bool(entry.payload.get("blocked", false))
		record("Moss Road " + ("closed" if state.routes["1"].blocked else "reopened"))
	elif entry.kind == "treaty" and state.has("treaty"):
		state.treaty.open_trade = bool(entry.payload.get("open", true))
		state.treaty.since = state.tick
		record("Councils " + ("reopened regional trade" if state.treaty.open_trade else "suspended regional trade"))
	elif entry.kind == "risk" and state.has("routes"):
		state.routes["1"].risk = clampi(int(entry.payload.get("value", 0)), 0, 100)
		record("Moss Road danger is now %d/100" % state.routes["1"].risk)
	elif entry.kind == "migrate" and state.has("factions"):
		Society.migrate(self, int(entry.payload.get("id", 0)), int(entry.payload.get("destination", 2)))
	elif entry.kind == "travel" and state.has("settlements"):
		var town: Dictionary = state.settlements.get(str(entry.payload.get("town", 1)), {})
		if not town.is_empty():
			var route := Navigation.request_path(state, state.entities[str(state.player)].cell, state.entities[str(town.warehouse)].cell)
			if route.ok:
				state.player_path = route.path
	elif entry.kind == "install_recipe" and state.has("recipes"):
		var result: Dictionary = {"ok": true, "recipe": entry.payload.recipe}
		if result.ok:
			var recipe: Dictionary = result.recipe
			state.recipes[recipe.id] = recipe
			for workshop in state.workshops.values():
				if not workshop.active:
					workshop.recipe = recipe.id
			record("Loaded recipe " + recipe.id + "; idle sawmills now use it")
		else:
			record("Recipe rejected: " + result.error)
	elif entry.kind == "reject_recipe":
		record("Recipe rejected: " + str(entry.payload.get("error", "Invalid recipe")))
	elif entry.kind == "spawn_test":
		var id := new_id()
		state.entities[str(id)] = {"id": id, "value": random_int("test", 0, 9999)}
	else:
		record("Rejected command: " + entry.kind)

func apply_event(entry: Dictionary) -> void:
	if entry.kind == "caravan_arrival" and state.has("caravans"):
		Regional.arrive(self, entry)
	elif entry.kind == "migration_arrival" and state.has("factions"):
		Society.arrive(self, entry)
	elif entry.kind == "encounter" and state.has("conflicts"):
		Risk.resolve(self, entry)
	state.event_results.append(entry.id)
	if state.event_results.size() > 64:
		state.event_results.pop_front()

func record(message: String) -> void:
	state.history.append({"tick": state.tick, "text": message})
	if state.history.size() > 64:
		state.history.pop_front()

func snapshot() -> Dictionary:
	return state.duplicate(true)

func restore(snapshot_data: Dictionary) -> void:
	state = snapshot_data.duplicate(true)

func state_hash() -> String:
	return Canonical.hash_state(state)
