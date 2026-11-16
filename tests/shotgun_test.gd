extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Shotgun = preload("res://sim/player/shotgun.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const World = preload("res://sim/world/world_db.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)
func effects(s: Dictionary) -> Array:
	return s.shotgun.effects.map(func(e: Dictionary) -> String: return e.kind)
func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	check(not Shotgun.owns(s), "Player starts without a shotgun")
	# The sheriff's office rack holds shotguns and shells.
	var office: int = 0
	for entity in s.entities.values():
		if entity.kind == "office" and entity.settlement == 1: office = entity.id
	check(office != 0 and Inventory.amount(s, office, "shotgun") >= 1 and Inventory.amount(s, office, "shell") >= 10, "Sheriff office rack stores shotguns and shells")
	check(Inventory.transfer(s, office, s.player, "shotgun", 1).ok and Inventory.transfer(s, office, s.player, "shell", 10).ok, "Player can take a shotgun and shells from the rack")
	sim.submit("shotgun_toggle"); sim.step()
	check(s.shotgun.equipped, "Shotgun can be readied")
	check(not Shotgun.can_fire(s), "Cannot fire unloaded")
	sim.submit("shotgun_reload"); 
	for tick in range(80): sim.step()
	check(s.shotgun.loaded == 5 and Inventory.amount(s, s.player, "shell") == 5, "Reload loads shells one at a time from inventory")
	var player: Dictionary = s.entities[str(s.player)]
	player.cell = [60, 60]
	# Ground impact: nothing in the way.
	sim.submit("shotgun_fire", {"direction": [0, 1000]}); sim.step()
	check(s.shotgun.loaded == 4 and s.shotgun.pellets.size() == Shotgun.PELLETS, "A blast fires a spread of pellets")
	for tick in range(15): sim.step()
	check(effects(s).has("ground") or s.shotgun.effects.size() == 0, "Pellets that miss raise ground dust")
	# Cooldown.
	sim.step(); 
	check(not Shotgun.can_fire(s) or s.tick - s.shotgun.last_shot >= Shotgun.COOLDOWN_TICKS, "Fire rate is limited")
	for tick in range(25): sim.step()
	# Wall impact.
	s.shotgun.pellets.clear(); s.shotgun.effects.clear()
	World.apply_mutation(s, [60, 63], true)
	s.world.building_walls["60,63"] = 0
	sim.submit("shotgun_fire", {"direction": [0, 1000]}); sim.step()
	for tick in range(12): sim.step()
	check(effects(s).has("wall"), "Pellets striking a wall make a wall effect: " + str(effects(s)))
	for tick in range(25): sim.step()
	# Body hit.
	s.shotgun.pellets.clear(); s.shotgun.effects.clear()
	s.world.building_walls.erase("60,63"); World.apply_mutation(s, [60, 63], false)
	var target_id: int = 0
	for npc in s.residents.values():
		target_id = npc.id; break
	s.entities[str(target_id)].cell = [60, 62]
	var health_before: int = s.residents[str(target_id)].health
	sim.submit("shotgun_fire", {"direction": [0, 1000]}); sim.step()
	for tick in range(8): sim.step()
	check(effects(s).has("blood") and s.residents[str(target_id)].health < health_before, "A hit shows a blood effect and costs health")
	# Tree impact.
	s.shotgun.pellets.clear(); s.shotgun.effects.clear(); s.shotgun.last_shot = -1000
	s.shotgun.loaded = 3
	var tree: Dictionary = {}
	for entity in s.entities.values():
		if entity.kind == "tree": tree = entity; break
	s.world.building_walls.clear(); s.world.fixture_cells.clear()
	player.cell = [tree.cell[0], tree.cell[1] - 3]
	sim.submit("shotgun_fire", {"direction": [0, 1000]}); sim.step()
	for tick in range(8): sim.step()
	check(effects(s).has("bark"), "Pellets striking a tree make bark splinters: " + str(effects(s)))
	# Stowing keeps the gun on the back.
	sim.submit("shotgun_toggle"); sim.step()
	check(not s.shotgun.equipped and Shotgun.owns(s), "Stowed shotgun stays in inventory (drawn on the back)")
	if failures == 0: print("Shotgun: PASS")
	quit(failures)
