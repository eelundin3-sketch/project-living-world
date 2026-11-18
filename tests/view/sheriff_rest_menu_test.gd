extends SceneTree
## Sheriffs' look and names, the inventory kneel, beds, the rifle's low-ready hold and the title screen.
const Sim = preload("res://sim/core/simulation.gd")
const Outfits = preload("res://sim/entities/outfits.gd")
const Households = preload("res://sim/entities/households.gd")
const Director = preload("res://view/actors/animation_director.gd")
const Character = preload("res://view/actors/drawn_character.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var sim := Sim.new(); sim.start_game()
	var s: Dictionary = sim.state
	var sheriffs := 0
	for npc in s.residents.values():
		if npc.occupation != "Sheriff": continue
		sheriffs += 1
		check(String(s.entities[str(npc.id)].name).begins_with("Sheriff "), "A sheriff is called Sheriff <surname>: " + s.entities[str(npc.id)].name)
		check(Outfits.worn(s, npc.id).hat == Outfits.SHERIFF.hat and Outfits.worn(s, npc.id).vest == Outfits.SHERIFF.vest, "A sheriff wears the hat and the badge vest")
	check(sheriffs >= 2, "Each town has its sheriff (%d)" % sheriffs)
	var copy := Sim.new(); copy.restore(sim.snapshot())
	check(copy.state_hash() == sim.state_hash(), "Sheriffs' names and outfits survive a reload unchanged")
	# The inventory kneel is a sim flag that any step cancels.
	sim.submit("rummage", {"open": true}); sim.step()
	check(s.player_control.rummaging, "Opening the inventory starts rummaging")
	sim.submit("move_player", {"direction": [1, 0]}); sim.step()
	check(not s.player_control.rummaging, "Moving ends it")
	# Beds: the sleeper's spot is the middle of the mattress art.
	check(Director.bed_center([10, 10, 3, 2], 3) == Vector2(10 * 24 - 12 + 36, 10 * 24 - 12 + 19.5), "Horizontal bed centre")
	check(Director.bed_center([10, 10, 2, 3], 0) == Vector2(10 * 24 - 12 + 20.5, 10 * 24 - 12 + 35), "Vertical bed centre")
	var any_bed := false
	for npc in s.residents.values():
		var info: Dictionary = Households.bed_info(s, npc)
		if not info.is_empty():
			any_bed = true
			check(info.has("rect") and info.rect.size() == 4, "A bed tells the sleeper its rectangle")
			break
	check(any_bed, "Someone has a bed")
	# Poses: low-ready rifle from the right chest down across to the left; rummaging puts the pack down.
	var figure := Character.new(); root.add_child(figure); figure.setup(0, true, false)
	figure.set_pose({"position": Vector2.ZERO, "heading": PI / 2.0, "action": "gun_carry", "moving": false})
	check(figure.frame.stock.x < figure.frame.muzzle.x and figure.frame.stock.y < figure.frame.muzzle.y, "Low ready: barrel angled down across the body")
	figure.set_pose({"position": Vector2.ZERO, "heading": PI / 2.0, "action": "rummage", "rummage_t": 1.6, "backpack": true, "moving": false})
	check(float(figure.frame.pack_move) > 0.95 and float(figure.frame.pack_open) > 0.9, "Rummaging: the pack is on the ground and open")
	check(figure.frame.hip.y > -24.0, "Rummaging: down on one knee")
	figure.set_pose({"position": Vector2.ZERO, "heading": PI / 2.0, "action": "idle", "age": 0.85, "moving": false})
	var chest_a: Vector2 = figure.frame.chest
	figure.set_pose({"position": Vector2.ZERO, "heading": PI / 2.0, "action": "idle", "age": 2.55, "moving": false})
	check(chest_a.distance_to(figure.frame.chest) > 0.3, "Standing still, the chest rises and falls")
	figure.queue_free()
	# The title screen only appears when the game is launched, not when tests build the scene.
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main)
	await process_frame; await process_frame
	check(not main.menu_active and main.menu == null, "No title screen inside tests")
	main.queue_free(); await process_frame
	print("Sheriff, rest and menu: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
