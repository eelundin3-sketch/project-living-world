extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const World = preload("res://sim/world/world_db.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + message)
func _initialize() -> void:
	var first := Sim.new(417)
	first.start_game()
	var second := Sim.new(417)
	second.start_game()
	check(first.state_hash() == second.state_hash(), "Grove generation is seeded and deterministic")
	var s: Dictionary = first.state
	var occupied: Dictionary = {}
	var dense: int = 0
	for e in s.entities.values():
		if e.get("kind", "") != "tree": continue
		var key := World.cell_key(e.cell)
		check(not occupied.has(key), "Tree locations are unique")
		occupied[key] = true
		if e.name == "Woodland tree":
			dense += 1
			check(absi(e.cell[1] - 48) >= 3, "New groves leave the road clear")
			check(World.inside_building(s, e.cell) == 0, "New trees do not occupy buildings")
	check(dense == 160, "Both towns receive dense forest stands")
	check(Nav.request_path(s, [62,49], [180,46]).ok, "Village road remains navigable")
	check(Checks.validate(s).is_empty(), "New harvestable wood is accounted for")
	var site_id := World.add_entity(first, "construction", "Existing worksite", [30, 21], 1)
	Inventory.create(s, site_id, 30)
	s.construction[str(site_id)] = {"id": site_id, "definition": "core:building/home"}
	var protected_plot := World.footprint([30, 21], "home").grow(1)
	var next_before: int = s.next_id
	var older: Dictionary = first.snapshot()
	older.world.forest_version = 2
	var migrated := Sim.new()
	migrated.restore(older)
	check(migrated.state.world.forest_version == 4 and Checks.validate(migrated.state).is_empty(), "Older saves upgrade with accounted forest growth")
	for e in migrated.state.entities.values():
		if e.get("kind", "") == "tree" and e.id >= next_before:
			check(not protected_plot.has_point(Vector2i(e.cell[0],e.cell[1])), "Migration preserves active construction plots")
	var once: String = migrated.state_hash()
	migrated.restore(migrated.snapshot())
	check(migrated.state_hash() == once, "Forest upgrade happens only once")
	print("Forest groves: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
