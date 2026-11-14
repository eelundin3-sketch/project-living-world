extends RefCounted
const World = preload("res://sim/world/world_db.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Jobs = preload("res://sim/jobs/job_board.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const NAMES: Array[String] = ["Ada", "Bram", "Cora", "Darin", "Edda", "Finn", "Galen", "Hana", "Ivo", "Juna", "Kira", "Leif", "Mara", "Neri", "Orin", "Pia", "Quin", "Runa", "Soren", "Tavi"]

static func spawn(sim: RefCounted, count: int, settlement: int = 1, origin: Array = [60, 49]) -> void:
	var s: Dictionary = sim.state
	if not s.has("residents"):
		s.residents = {}
	var columns: int = 20 if count > 40 else 5
	for index in range(count):
		var id := World.add_entity(sim, "resident", NAMES[index % NAMES.size()] + (" II" if settlement == 2 else ""), [origin[0] + index % columns, origin[1] + index / columns], settlement)
		s.residents[str(id)] = {"id": id, "settlement": settlement, "hunger": sim.random_int("needs", 5, 35), "fatigue": sim.random_int("needs", 0, 25),
			"health": 100, "job": 0, "path": [], "nav_revision": 0, "goal": "", "status": "Available", "retry_at": 0,
			"fidelity": "detailed", "occupation": "Gatherer", "memories": [], "relations": {}, "skill": 0}
		Inventory.create(s, id, 10)

static func update(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	for key in s.residents:
		var npc: Dictionary = s.residents[key]
		if not npc.get("migration", {}).is_empty():
			continue
		if s.tick % 100 == 0:
			npc.hunger = mini(100, npc.hunger + 1)
			npc.fatigue = mini(100, npc.fatigue + 1)
		var cadence: int = 2 if npc.fidelity == "detailed" else (10 if npc.fidelity == "coarse" else 100)
		if (npc.fidelity == "detailed" and s.tick % 10 == npc.id % 10) or (npc.fidelity != "detailed" and s.tick % cadence == 0):
			_decide(sim, npc)
		if s.tick % cadence == 0:
			if npc.job != 0:
				Jobs.advance_many(sim, npc.id, cadence / 2)
			elif not npc.goal.is_empty():
				var actions: int = cadence / 2
				var distance: int = mini(actions, npc.path.size())
				if distance > 0 and npc.nav_revision == s.world.nav_revision:
					s.entities[str(npc.id)].cell = npc.path[distance - 1]
					npc.path = npc.path.slice(distance)
					actions -= distance
				if actions > 0:
					if npc.goal == "rest" and npc.path.is_empty():
						npc.fatigue = maxi(10, npc.fatigue - actions + 1)
					_need_action(sim, npc)

static func _destination(s: Dictionary, npc: Dictionary, kind: String) -> int:
	if s.has("settlements"):
		return s.settlements[str(npc.settlement)][kind]
	return s[kind]

static func _decide(sim: RefCounted, npc: Dictionary) -> void:
	var s: Dictionary = sim.state
	if npc.retry_at > s.tick:
		return
	if npc.hunger >= 60 or npc.fatigue >= 75:
		if npc.job != 0:
			Jobs.release(s, npc.job, "INTERRUPTED_FOR_NEEDS")
		if npc.goal.is_empty():
			set_goal(s, npc, "eat" if npc.hunger >= 60 else "rest")
		return
	if npc.job != 0 or not npc.goal.is_empty():
		return
	if npc.occupation == "Builder" or npc.get("work_cargo", false):
		return
	if Inventory.used(s.inventories[str(npc.id)]) > 0:
		set_goal(s, npc, "deposit")
	elif npc.occupation == "Gatherer":
		Jobs.assign(s, npc.id)

static func set_goal(s: Dictionary, npc: Dictionary, goal: String) -> void:
	var target: int = _destination(s, npc, "home" if goal == "rest" else "warehouse")
	var route := Nav.request_path(s, s.entities[str(npc.id)].cell, s.entities[str(target)].cell)
	if not route.ok:
		npc.status = goal + ": " + route.error_code
		npc.retry_at = s.tick + 100
		return
	npc.path = route.path
	npc.nav_revision = s.world.nav_revision
	npc.goal = goal
	npc.status = {"eat": "Going to eat", "rest": "Going home to rest", "deposit": "Returning carried goods"}[goal]

static func _need_action(sim: RefCounted, npc: Dictionary) -> void:
	var s: Dictionary = sim.state
	if npc.nav_revision != s.world.nav_revision:
		var goal: String = npc.goal
		npc.goal = ""
		set_goal(s, npc, goal)
		return
	if not npc.path.is_empty():
		s.entities[str(npc.id)].cell = npc.path.pop_front()
		return
	match npc.goal:
		"eat":
			var store: int = _destination(s, npc, "warehouse")
			var food_source: int = npc.id if Inventory.amount(s, npc.id, "food") > 0 else store
			if Inventory.consume(s, food_source, "food", 1):
				npc.hunger = maxi(0, npc.hunger - 45)
				npc.status = "Ate from communal stores"
			else:
				npc.status = "Hungry: store has no food"
				npc.retry_at = s.tick + 100
			npc.goal = ""
		"rest":
			npc.fatigue = maxi(0, npc.fatigue - 1)
			npc.status = "Resting at home"
			if npc.fatigue <= 10:
				npc.goal = ""
		"deposit":
			var store: int = _destination(s, npc, "warehouse")
			var items: Dictionary = s.inventories[str(npc.id)].items.duplicate()
			for item in items:
				var moved := Inventory.transfer(s, npc.id, store, item, items[item])
				if not moved.ok:
					npc.status = "Carrying goods: " + moved.error_code
					npc.retry_at = s.tick + 100
					break
			npc.goal = ""
			npc.production_delivery = false

static func remove(sim: RefCounted, id: int) -> void:
	var s: Dictionary = sim.state
	if not s.residents.has(str(id)):
		return
	var npc: Dictionary = s.residents[str(id)]
	if npc.job != 0:
		Jobs.release(s, npc.job, "WORKER_REMOVED")
	# Keep the inventory at its exact cell as a recoverable stash, never destroy goods.
	s.entities[str(id)].kind = "stash"
	s.entities[str(id)].name += "'s belongings"
	s.residents.erase(str(id))
