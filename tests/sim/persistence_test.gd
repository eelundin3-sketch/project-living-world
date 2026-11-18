extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Save = preload("res://sim/persistence/save_manager.gd")
const Canonical = preload("res://sim/core/canonical.gd")
const Content = preload("res://sim/production/content_loader.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	var sim := Sim.new()
	sim.start_game()
	var path := OS.get_temp_dir().path_join("solo-recovery.save")
	check(Save.save_state(sim, path).ok, "First atomic save")
	var original := sim.state_hash()
	sim.step()
	check(Save.save_state(sim, path).ok, "Second save keeps backup")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var({"format": 2, "engine": Engine.get_version_info().string, "hash": "broken", "state": sim.snapshot()}, false)
	file.close()
	var recovered := Sim.new()
	var result := Save.load_into(recovered, path)
	check(result.ok and result.get("recovered_backup", false), "Corrupt primary recovers backup")
	check(recovered.state_hash() == original, "Backup state is exact")
	var old: Dictionary = sim.snapshot()
	old.format_version = 1
	file = FileAccess.open(OS.get_temp_dir().path_join("solo-legacy.save"), FileAccess.WRITE)
	file.store_var({"format": 1, "engine": Engine.get_version_info().string, "hash": Canonical.hash_state(old), "state": old}, false)
	file.close()
	var migrated := Save.read_state(OS.get_temp_dir().path_join("solo-legacy.save"))
	check(migrated.ok and migrated.state.format_version == 2 and migrated.state.tick == old.tick, "V1 migration preserves gameplay state")
	var valid := Content.read_recipe("res://content/recipes/example_mod.json")
	check(valid.ok and valid.recipe.output_quantity == 8, "External data recipe accepted")
	sim.submit("load_recipe", {"path": "res://content/recipes/example_mod.json"})
	sim.step()
	check(sim.state.recipes.has("mod:recipe/efficient_planks"), "Command installs content without code changes")
	var bad: Dictionary = sim.snapshot()
	bad.inventories[str(bad.player)].items.food = -1
	check(not Save.validate_schema(bad).is_empty(), "Malformed inventory rejected before restore")
	print("Persistence/content: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
