extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Jobs = preload("res://sim/jobs/job_board.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const World = preload("res://sim/world/world_db.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	var sim := Sim.new()
	sim.start_village(1)
	var s: Dictionary = sim.state
	var npc: Dictionary = s.residents.values()[0]
	var target: int = 0
	for entity in s.entities.values():
		if entity.kind == "tree":
			target = entity.id
			break
	for cycle in range(1000):
		Jobs.refresh(sim)
		var job: Dictionary = {}
		for entry in s.jobs.values():
			if entry.target == target:
				job = entry
		check(not job.is_empty(), "Gather job exists")
		s.tick += 100
		check(Jobs.try_claim(s, job.id, npc.id), "Claim repeated gather job")
		var safety: int = 0
		while npc.job != 0 and safety < 500:
			s.tick += 2
			Jobs.advance(sim, npc.id)
			safety += 1
			if cycle % 3 == 0 and safety == 3:
				Jobs.release(s, job.id, "TEST_INTERRUPTION")
				check(s.inventories[str(s.warehouse)].reserved.is_empty(), "Interruption releases capacity")
				s.tick += 100
				check(Jobs.try_claim(s, job.id, npc.id), "Interrupted target can be reclaimed")
		check(safety < 500, "Gather completes within bounded time")
		check(Inventory.transfer(s, s.warehouse, target, "log", 5).ok, "Fixture returns delivered logs to source")
		check(Checks.validate(s).is_empty(), "Every transfer/cancellation conserves goods")
	check(s.completed_jobs == 1000, "1000 completed jobs with interruptions")
	Jobs.refresh(sim)
	var job: Dictionary = s.jobs.values()[0]
	s.tick += 100
	check(Jobs.try_claim(s, job.id, npc.id), "Lease fixture claims")
	s.tick = job.lease_until
	Jobs.refresh(sim)
	check(job.owner == 0 and npc.job == 0, "Lease expiry releases both sides")
	s.tick += 100
	var cell: Array = s.entities[str(job.target)].cell
	World.apply_mutation(s, cell, true)
	check(not Jobs.try_claim(s, job.id, npc.id), "Unreachable target does not lock worker")
	check(s.inventories[str(s.warehouse)].reserved.is_empty(), "Path failure releases destination reservation")
	World.apply_mutation(s, cell, false)
	s.tick += 100
	check(Jobs.try_claim(s, job.id, npc.id), "Path recovery permits reclaim")
	World.apply_mutation(s, cell, true)
	Jobs.advance(sim, npc.id)
	check(npc.job == 0 and job.owner == 0, "Changed navigation releases active job")
	print("Interruptions: %s; %d completed jobs" % ["PASS" if failures == 0 else "FAIL", s.completed_jobs])
	quit(0 if failures == 0 else 1)
