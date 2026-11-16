extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const World = preload("res://sim/world/world_db.gd")
const Planner = preload("res://sim/settlement/planner.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Fixtures = preload("res://sim/world/fixtures.gd")
const Director = preload("res://view/actors/animation_director.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	var sim := Sim.new(741)
	sim.start_game(12)
	var s: Dictionary = sim.state
	check(World.METERS_PER_CELL == 1.0 and s.world.meters_per_cell == 1.0, "Authoritative world cell measures one metre")
	var existing: Dictionary = s.entities[str(s.home)]
	var dimensions: Array = existing.footprint.slice(2, 4)
	check(dimensions == [17, 14], "House footprint stores metre dimensions as grid cells")
	var site_id: int = Planner.plan(sim, 1, "core:building/home")
	check(site_id != 0, "A buildable site can be planned on the cell grid")
	if site_id == 0:
		quit(1)
		return
	var site: Dictionary = s.construction[str(site_id)]
	var stages: Array = site.stages
	check(stages.map(func(stage: Dictionary) -> String: return stage.id) == ["walls", "floor", "door", "roof"], "Construction phases are explicit and ordered")
	check(site.total_units == site.work_ticks / Planner.WORK_PER_TILE and site.total_units > 350, "Every floor/wall/door/roof tile requires individual work")
	var builder: Dictionary = {}
	for npc in s.residents.values():
		if npc.settlement == 1 and npc.occupation == "Gatherer" and npc.job == 0:
			builder = npc
			break
	check(not builder.is_empty(), "A builder is available")
	if builder.is_empty():
		quit(1)
		return
	site.worker = builder.id
	var actor: Dictionary = s.entities[str(builder.id)]
	actor.cell = Fixtures.interaction_cell(s, site_id).duplicate()
	builder.goal = ""
	builder.hunger = 0
	builder.fatigue = 0
	var missing: int = site.cost - Inventory.amount(s, s.warehouse, "plank")
	if missing > 0: Inventory.produce(s, s.warehouse, "plank", missing)
	var first_delivery: int = site.cost / 2
	check(Inventory.transfer(s, s.warehouse, site_id, "plank", first_delivery).ok, "Partial delivery enters actual site inventory")
	s.tick += 2
	Planner.update(sim)
	check(site.progress == 0 and site.tile_work == 0 and Inventory.amount(s, site_id, "plank") == first_delivery, "Builder waits for full material delivery")
	check(Inventory.transfer(s, s.warehouse, site_id, "plank", site.cost - first_delivery).ok, "Resources can be staged at the site center")
	var pile_stance := Fixtures.interaction_cell(s, site_id)
	var plot := World.plot_rect(s.entities[str(site_id)], "home")
	var pile: Array = s.entities[str(site_id)].fixtures[0].rect
	check(absf(float(pile[1]) + 0.5 - plot.get_center().y) <= 2.0, "Supply pile is in the middle of the building")
	var first_wall: Array = stages[0].tiles[0]
	var carried_snapshot: Dictionary = {}
	var first_wall_snapshot: Dictionary = {}
	var work_by_stage: Dictionary = {}
	var returns: int = 0
	var loads: int = 0
	for step in range(60000):
		var old_phase: String = site.get("build_phase", "fetch")
		var old_progress: int = site.progress
		var old_tile := Planner.current_tile(site)
		s.tick += 2
		Planner.update(sim)
		var phase: String = site.get("build_phase", "")
		if old_phase == "fetch" and phase == "travel":
			loads += 1
			if loads == 1:
				check(actor.cell == pile_stance and Inventory.amount(s, builder.id, "plank") > 0, "Builder takes real material at the central pile")
		if phase == "travel" and actor.cell != pile_stance and carried_snapshot.is_empty():
			carried_snapshot = sim.snapshot()
		if old_phase == "return" and phase == "fetch" and actor.cell == pile_stance:
			returns += 1
		var piece := Planner.current_tile(site)
		if phase == "build" and not piece.is_empty() and piece.progress > 0.0 and piece.progress < 1.0 and not work_by_stage.has(piece.kind):
			work_by_stage[piece.kind] = true
			var cue := Director.action_for(s, actor)
			check(cue.action == "build" and cue.target_cell == piece.cell and cue.build_kind == piece.kind, "Builder's pose and visible structure share the active " + piece.kind + " tile")
			check(absi(actor.cell[0] - piece.cell[0]) + absi(actor.cell[1] - piece.cell[1]) == 1, "Builder works beside " + piece.kind)
			if piece.kind == "walls":
				check(World.walkable(s, piece.cell), "Unfinished wall does not block movement")
				first_wall_snapshot = sim.snapshot()
		if site.progress > old_progress and old_tile.kind == "walls" and old_tile.cell == first_wall:
			check(not World.walkable(s, first_wall), "Completed wall immediately blocks movement")
		if site.done: break
	check(site.done, "Walls-first construction completes without trapping the builder")
	check(work_by_stage.has_all(["walls", "floor", "door", "roof"]), "Every stage has a visible partial tile")
	check(loads == site.total_units and returns == site.total_units, "Every tile has one pickup trip and one return to the pile")
	check(not carried_snapshot.is_empty(), "The builder visibly travels carrying planks")
	check(World.walkable(s, s.entities[str(site_id)].cell), "The finished doorway remains open")
	check(Checks.validate(s).is_empty(), "Completed construction conserves materials")
	var restored := Sim.new()
	for snapshot in [carried_snapshot, first_wall_snapshot]:
		if snapshot.is_empty(): continue
		restored.restore(snapshot)
		check(restored.state_hash() == SimHash(snapshot), "Carried materials and partial tile survive restore")
	print("Construction stages: %s; tiles=%d; pickup trips=%d; return trips=%d" % ["PASS" if failures == 0 else "FAIL", site.total_units, loads, returns])
	quit(0 if failures == 0 else 1)

func SimHash(snapshot: Dictionary) -> String:
	return preload("res://sim/core/canonical.gd").hash_state(snapshot)
