extends RefCounted
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const World = preload("res://sim/world/world_db.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const Professions = preload("res://sim/settlement/professions.gd")

static func initialize(state: Dictionary) -> void:
	state.jobs = {}
	state.job_archive = []
	state.completed_jobs = 0

static func refresh(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	for key in s.jobs.keys():
		var job: Dictionary = s.jobs[key]
		if job.owner != 0 and (not s.residents.has(str(job.owner)) or job.lease_until <= s.tick):
			release(s, job.id, "LEASE_EXPIRED")
	var targets: Dictionary = {}
	for job in s.jobs.values():
		targets[str(job.target)] = true
	for entity in s.entities.values():
		if entity.kind not in ["tree", "farm", "ore"] or targets.has(str(entity.id)):
			continue
		var item: String = "log" if entity.kind == "tree" else ("ore" if entity.kind == "ore" else "food" if Inventory.amount(s, entity.id, "food") >= 1 else "rye")
		if Inventory.amount(s, entity.id, item) < 1:
			continue
		var destination: int = s.warehouse
		if s.has("settlements") and s.settlements.has(str(entity.settlement)):
			destination = s.settlements[str(entity.settlement)].warehouse
		var id: int = sim.new_id()
		s.jobs[str(id)] = {"id": id, "kind": "gather", "target": entity.id,
			"destination": destination, "item": item, "quantity": 5, "owner": 0,
			"state": "OPEN", "lease_until": 0, "retry_count": 0, "retry_at": 0,
			"reason": "", "progress": 0, "settlement": entity.settlement}

static func release(state: Dictionary, job_id: int, reason: String) -> void:
	if not state.jobs.has(str(job_id)):
		return
	var job: Dictionary = state.jobs[str(job_id)]
	Inventory.release(state, job.destination, str(job.id))
	if state.residents.has(str(job.owner)):
		var npc: Dictionary = state.residents[str(job.owner)]
		if npc.job == job_id:
			npc.job = 0
			npc.path = []
			npc.status = reason
	job.owner = 0
	job.state = "OPEN"
	job.lease_until = 0
	job.reason = reason
	job.retry_count += 1
	job.retry_at = state.tick + 40
	job.progress = 0

static func try_claim(state: Dictionary, job_id: int, npc_id: int) -> bool:
	if state.get("player_control",{}).get("work",{}).get("target",0) == state.jobs.get(str(job_id),{}).get("target",-1): return false
	if not state.jobs.has(str(job_id)) or not state.residents.has(str(npc_id)):
		return false
	var job: Dictionary = state.jobs[str(job_id)]
	var npc: Dictionary = state.residents[str(npc_id)]
	if job.owner != 0 or npc.job != 0 or job.retry_at > state.tick:
		return false
	var target: Dictionary = state.entities.get(str(job.target), {})
	if target.is_empty():
		return false
	var quantity: int = mini(job.quantity, Inventory.amount(state, job.target, job.item))
	if quantity <= 0 or Inventory.available(state, npc_id) < quantity:
		return false
	if not Inventory.reserve(state, job.destination, str(job.id), quantity):
		job.reason = "STORE_FULL"
		job.retry_at = state.tick + 100
		return false
	var route := Nav.request_path(state, state.entities[str(npc_id)].cell, source_stance(state, job))
	if not route.ok:
		Inventory.release(state, job.destination, str(job.id))
		job.reason = route.error_code
		job.retry_at = state.tick + 100
		job.retry_count += 1
		return false
	job.owner = npc_id
	job.quantity = quantity
	job.state = "MOVING_TO_SOURCE"
	job.lease_until = state.tick + (150 if npc.fidelity == "aggregate" else 50)
	npc.job = job.id
	npc.path = route.path
	npc.nav_revision = state.world.nav_revision
	npc.status = "Gathering " + job.item
	return true

static func assign(state: Dictionary, npc_id: int) -> bool:
	var npc: Dictionary = state.residents[str(npc_id)]
	var cell: Array = state.entities[str(npc_id)].cell
	var candidates: Array = []
	for job in state.jobs.values():
		if job.owner == 0 and job.retry_at <= state.tick and job.settlement == npc.settlement and Inventory.amount(state, job.destination, job.item) < (800 if job.item == "log" else 200):
			if not Professions.gathers(npc, state.entities[str(job.target)].kind): continue
			var target: Array = state.entities[str(job.target)].cell
			var distance: int = absi(cell[0] - target[0]) + absi(cell[1] - target[1])
			var threshold: int = 200 if state.get("settlements", {}).get(str(npc.settlement), {}).get("policy", "") == "Food first" else 100
			var priority: int = 100 if job.item == "food" and Inventory.amount(state, job.destination, "food") < threshold else 0
			candidates.append({"id": job.id, "score": priority - distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.score > b.score or (a.score == b.score and a.id < b.id))
	for candidate in candidates:
		if try_claim(state, candidate.id, npc_id):
			return true
	npc.status = "No reachable work / store full"
	return false

static func advance(sim: RefCounted, npc_id: int) -> void:
	var s: Dictionary = sim.state
	var npc: Dictionary = s.residents[str(npc_id)]
	if not s.jobs.has(str(npc.job)):
		npc.job = 0
		return
	var job: Dictionary = s.jobs[str(npc.job)]
	job.lease_until = s.tick + (150 if npc.fidelity == "aggregate" else 50)
	var actor: Dictionary = s.entities[str(npc_id)]
	if npc.nav_revision != s.world.nav_revision:
		var goal: Array = World.Fixtures.interaction_cell(s, job.destination) if job.state in ["MOVING_TO_DEST", "DEPOSITING"] else source_stance(s, job)
		var keeps: bool = (npc.path.is_empty() and actor.cell == goal) or (not npc.path.is_empty() and npc.path.back() == goal and Nav.still_clear(s, npc.path))
		var route := {"ok": true, "path": npc.path} if keeps else Nav.request_path(s, actor.cell, goal)
		if not route.ok:
			release(s, job.id, route.error_code)
			return
		npc.path = route.path
		npc.nav_revision = s.world.nav_revision
	if not npc.path.is_empty():
		actor.cell = npc.path.pop_front()
		return
	match job.state:
		"MOVING_TO_SOURCE":
			job.state = "WORKING"
			npc.status = "Harvesting " + job.item
		"WORKING":
			job.progress += 2
			if job.progress < 20:
				return
			var tree: Dictionary = state_entity(s, job.target)
			if tree.get("kind", "") == "tree" and not tree.get("felled", false):
				tree.felled = true  # chopped down: it falls and its wood is hauled from the trunk
				tree.felled_tick = s.tick
			job.state = "PICKING_UP"
			job.progress = 0
			npc.status = "Picking up " + job.item
		"PICKING_UP":
			job.progress += 2
			if job.progress < 6:
				return
			var moved := Inventory.transfer(s, job.target, npc_id, job.item, job.quantity)
			if not moved.ok:
				release(s, job.id, moved.error_code)
				return
			var route := Nav.request_path(s, actor.cell, World.Fixtures.interaction_cell(s, job.destination))
			if not route.ok:
				release(s, job.id, route.error_code)
				return
			npc.path = route.path
			job.state = "MOVING_TO_DEST"
			npc.status = "Hauling %d %s" % [job.quantity, job.item]
		"MOVING_TO_DEST":
			job.state = "DEPOSITING"
			job.progress = 0
			npc.status = "Putting down " + job.item
		"DEPOSITING":
			job.progress += 2
			if job.progress < 6:
				return
			var moved := Inventory.transfer(s, npc_id, job.destination, job.item, job.quantity, str(job.id))
			if not moved.ok:
				release(s, job.id, moved.error_code)
				return
			job.state = "DONE"
			s.completed_jobs += 1
			npc.skill = mini(100, npc.skill + 1)
			s.job_archive.append(job.duplicate(true))
			if s.job_archive.size() > 64:
				s.job_archive.pop_front()
			s.jobs.erase(str(job.id))
			npc.job = 0
			npc.status = "Delivered " + job.item
			if s.completed_jobs % 10 == 0:
				sim.record("Workers completed %d deliveries" % s.completed_jobs)

static func advance_many(sim: RefCounted, npc_id: int, actions: int) -> void:
	# Aggregate travel/work algebraically, crossing only transaction boundaries.
	# The same record owns cargo and reservations throughout the coarse interval.
	var s: Dictionary = sim.state
	var npc: Dictionary = s.residents[str(npc_id)]
	while actions > 0 and npc.job != 0:
		var job: Dictionary = s.jobs[str(npc.job)]
		job.lease_until = s.tick + 150
		if npc.nav_revision != s.world.nav_revision:
			advance(sim, npc_id)
			actions -= 1
			continue
		if not npc.path.is_empty():
			var distance: int = mini(actions, npc.path.size())
			s.entities[str(npc_id)].cell = npc.path[distance - 1]
			npc.path = npc.path.slice(distance)
			actions -= distance
			continue
		if job.state == "WORKING" and job.progress < 18:
			var work: int = mini(actions, (18 - int(job.progress)) / 2)
			job.progress += work * 2
			actions -= work
			if actions == 0:
				break
		advance(sim, npc_id)
		actions -= 1

static func source_stance(s: Dictionary, job: Dictionary) -> Array:
	var cell: Array = s.entities[str(job.target)].cell
	if not World.walkable(s, cell):
		return cell
	for offset in [[0, 1], [-1, 0], [1, 0], [0, -1]]:
		var stance: Array = [cell[0] + offset[0], cell[1] + offset[1]]
		if World.walkable(s, stance):
			return stance
	return cell

static func state_entity(s: Dictionary, id: int) -> Dictionary:
	return s.entities.get(str(id), {})
