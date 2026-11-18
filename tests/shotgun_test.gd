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
	call_deferred("run")

func run() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	check(Shotgun.owns(s) and not s.shotgun.equipped, "The player starts with a shotgun, lowered")
	check(Inventory.amount(s, s.player, "shell") == 10, "...and ten shells")
	Inventory.consume(s, s.player, "shotgun", 1); Inventory.consume(s, s.player, "shell", 10)   # the rest of this test takes them from the rack
	# The sheriff's office rack holds shotguns and shells.
	var office: int = 0
	for entity in s.entities.values():
		if entity.kind == "office" and entity.settlement == 1: office = entity.id
	check(office != 0 and Inventory.amount(s, office, "shotgun") >= 1 and Inventory.amount(s, office, "shell") >= 10, "Sheriff office rack stores shotguns and shells")
	check(Inventory.transfer(s, office, s.player, "shotgun", 1).ok and Inventory.transfer(s, office, s.player, "shell", 10).ok, "Player can take a shotgun and shells from the rack")
	for npc in s.residents.values():
		if npc.occupation == "Sheriff": npc.occupation = "Gatherer"   # no law in this test: it is only about pellets
	sim.submit("shotgun_toggle"); sim.step()
	check(s.shotgun.equipped, "Shotgun can be readied")
	check(not Shotgun.can_fire(s), "Cannot fire unloaded")
	sim.submit("shotgun_reload"); 
	for tick in range(80): sim.step()
	check(s.shotgun.loaded == 5 and Inventory.amount(s, s.player, "shell") == 5, "Reload loads shells one at a time from inventory")
	var player: Dictionary = s.entities[str(s.player)]
	player.cell = [60, 60]
	# Ground impact needs open ground ahead: the layout of the towns changes, so look for a clear spot.
	for x in range(40, 120, 3):
		for y in range(60, 100, 3):
			var clear := true
			for step in range(1, 10):
				if Shotgun.surface_at(s, [x, y + step], s.player) != "": clear = false; break
			if clear and World.walkable(s, [x, y]):
				player.cell = [x, y]
				break
		if player.cell != [60, 60]: break
	# Ground impact: nothing in the way.
	sim.submit("shotgun_fire", {"direction": [0, 1000]}); sim.step()
	check(s.shotgun.loaded == 4 and s.shotgun.pellets.size() == Shotgun.PELLETS, "A blast fires a spread of pellets")
	check(int(s.shotgun.bloom) > 0, "Firing builds up bloom (%d)" % int(s.shotgun.bloom))
	for tick in range(15): sim.step()
	check(effects(s).has("ground") or s.shotgun.effects.size() == 0, "Pellets that miss raise ground dust")
	player.cell = [60, 60]   # back to the fixed spot the wall, body and tree checks below are laid out around
	check(int(s.shotgun.bloom) == 0, "The bloom settles back to nothing")
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
	await _check_controls()
	if failures == 0: print("Shotgun: PASS")
	quit(failures)

func _check_controls() -> void:
	var main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.world_audio.enabled = false
	main.world_audio.wind.stop()
	var sim: RefCounted = main.simulation
	var s: Dictionary = sim.state
	Inventory.produce(s, s.player, "shotgun", 1)
	sim.submit("shotgun_toggle")
	sim.step()
	s.shotgun.loaded = 2
	var key := str(s.player)
	s.entities[key].cell = [60, 60]
	World.apply_mutation(s, [61, 60], false)
	var world = main.get_node("WorldView")
	world.snap_visuals()
	main._process(0.016)
	check(world.motion.actors[key].action == "gun_carry", "Equipping the shotgun holds it lowered at rest")
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	main._unhandled_input(left)
	main._process(0.016)
	check(not world.motion.player_aiming and world.motion.actors[key].action == "gun_carry", "Left mouse alone leaves the shotgun lowered")
	check(s.shotgun.loaded == 2 and not s.commands.any(func(command: Dictionary) -> bool: return command.kind == "shotgun_fire"), "Left mouse alone cannot fire")
	main.context_menu.close()
	left.pressed = false
	main._input(left)
	s.entities[key].cell = [61, 60]
	main._process(0.016)
	check(world.motion.actors[key].moving and world.motion.actors[key].action == "gun_carry", "Walking retains the lowered weapon pose")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	main._unhandled_input(right)
	main._process(0.016)
	check(world.motion.actors[key].moving and world.motion.actors[key].action == "aim", "Right mouse raises the gun while walking")
	check(s.shotgun.loaded == 2, "Aiming does not fire")
	left.pressed = true
	main._unhandled_input(left)
	sim.step()
	main._process(0.016)
	check(s.shotgun.loaded == 1 and world.motion.actors[key].action == "shoot", "Left press while aiming fires once and shows recoil while moving")
	main._process(0.016)
	check(s.shotgun.loaded == 1, "Holding the left button does not repeat a shot")
	right.pressed = false
	main._input(right)
	main._process(0.016)
	check(world.motion.actors[key].action == "gun_carry", "Releasing right mouse lowers the gun even while left is held")
	right.pressed = true
	main._unhandled_input(right)
	main._process(0.016)
	check(main.aiming, "A quick second aim press works with the shotgun equipped")
	main.queue_free()
	await process_frame
