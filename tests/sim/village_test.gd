extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Jobs = preload("res://sim/jobs/job_board.gd")
const Residents = preload("res://sim/entities/residents.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
const Save = preload("res://sim/persistence/save_manager.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	var sim := Sim.new(123)
	sim.start_village(20)
	Jobs.refresh(sim)
	var job_id: int = sim.state.jobs.values()[0].id
	var npcs: Array = sim.state.residents.values()
	check(Jobs.try_claim(sim.state, job_id, npcs[0].id), "First worker claims target")
	for npc in npcs.slice(1):
		check(not Jobs.try_claim(sim.state, job_id, npc.id), "Exclusive target")
	Jobs.release(sim.state, job_id, "CANCELLED")
	check(npcs[0].job == 0 and sim.state.jobs[str(job_id)].owner == 0, "Cancellation releases worker and target")
	for tick in range(1000):
		sim.step()
	check(sim.state.completed_jobs > 0 and Inventory.amount(sim.state, sim.state.warehouse, "log") > 0, "Gather carry deposit integration")
	var owned: Array = sim.state.jobs.values().filter(func(j: Dictionary) -> bool: return j.owner != 0)
	if not owned.is_empty():
		var job: Dictionary = owned[0]
		Residents.remove(sim, job.owner)
		check(job.owner == 0, "Removed worker releases lease")
	var a := Sim.new(77)
	a.start_village(20)
	for tick in range(50000):
		a.step()
		if tick % 1000 == 0:
			check(Checks.validate(a.state).is_empty(), "Soak invariants at %d: %s" % [tick, Checks.validate(a.state)])
	var saved := Save.save_state(a, OS.get_temp_dir().path_join("solo-test-save.dat"))
	check(saved.ok, "Save succeeds")
	var b := Sim.new()
	check(Save.load_into(b, OS.get_temp_dir().path_join("solo-test-save.dat")).ok, "Load succeeds")
	check(a.state_hash() == b.state_hash(), "Snapshot identity, needs, jobs and inventories")
	for tick in range(50800):
		a.step()
		b.step()
	check(a.state_hash() == b.state_hash(), "Seven-day continuation matches save/reload")
	check(Checks.validate(a.state).is_empty(), "Final conservation and lease invariants")
	print("Village: %s; tick=%d, deliveries=%d, hash=%s" % ["PASS" if failures == 0 else "FAIL", a.state.tick, a.state.completed_jobs, a.state_hash()])
	quit(0 if failures == 0 else 1)
