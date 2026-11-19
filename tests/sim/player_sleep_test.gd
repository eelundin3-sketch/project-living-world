extends SceneTree
## Click what you press: inside a building only the furniture or fixture clicked has actions, a bed
## offers Sleep, and sleeping rests the player until they are rested or do something.
const Sim = preload("res://sim/core/simulation.gd")
const Context = preload("res://sim/player/context_actions.gd")
const Sleep = preload("res://sim/player/sleep.gd")
const Law = preload("res://sim/law/law.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)
func ids(options: Array) -> Array:
	return options.map(func(o: Dictionary) -> String: return o.id)
func part_of(building: Dictionary, list_name: String, kind: String, for_whom: String = "") -> String:
	var items: Array = building.get(list_name, [])
	for index in range(items.size()):
		if items[index].kind == kind and (for_whom.is_empty() or str(items[index].get("for", "")) == for_whom):
			return ("furniture:%d" if list_name == "furniture" else "fixture:%d") % index
	return ""
func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	var office: Dictionary = {}
	for e in s.entities.values():
		if e.kind == "office" and int(e.settlement) == 1: office = e; break
	var prisoner_bed := part_of(office, "furniture", "bed", "prisoner")
	var rack := part_of(office, "fixtures", "weapon_rack")
	check(not prisoner_bed.is_empty() and not rack.is_empty(), "The office has a prisoner's bed and a weapon rack")
	# What a click offers depends on what was clicked.
	var bed_options := ids(Context.options(s, office.id, prisoner_bed))
	check(bed_options.has("sleep") and not bed_options.has("rack"), "The prisoner's bed offers Sleep, not the shotgun: " + str(bed_options))
	check(ids(Context.options(s, office.id, rack)).has("rack"), "The weapon rack offers the shotgun")
	check(Context.options(s, office.id, "").is_empty(), "Bare floor in a building offers nothing")
	check(Context.title(s, office.id, prisoner_bed) == "Bed" and Context.title(s, office.id, rack) == "Weapon rack", "The menu is titled with the thing clicked")
	var store: Dictionary = s.entities[str(s.warehouse)]
	check(ids(Context.options(s, store.id, part_of(store, "fixtures", "stockpile"))).has("trade"), "The storehouse stockpile offers trade")
	var lodge: Dictionary = s.entities[str(s.home)]
	var lodge_bed := part_of(lodge, "furniture", "bed")
	# Not tired: no sleep.
	s.player_needs.fatigue = 2
	check(not Context.options(s, lodge.id, lodge_bed).filter(func(o): return o.id == "sleep")[0].enabled, "Too fresh to sleep")
	# Tired: walk to the bed and lie down.
	s.player_needs.fatigue = 70
	s.tick = 14400 * 2 + 22 * 600   # ten at night
	sim.submit("context_action", {"target": lodge.id, "action": "sleep", "part": lodge_bed})
	for i in range(600):
		sim.step()
		if Sleep.asleep(s): break
	check(Sleep.asleep(s), "The player walks to the bed and falls asleep: " + str(s.player_control.notice))
	var tired_before: int = int(s.player_needs.fatigue)
	for i in range(300): sim.step()
	check(int(s.player_needs.fatigue) < tired_before - 5, "Sleeping rests the player (%d -> %d)" % [tired_before, s.player_needs.fatigue])
	# Save and load while asleep: the night continues the same.
	var copy := Sim.new(); copy.restore(sim.snapshot())
	for i in range(200): sim.step(); copy.step()
	check(copy.state_hash() == sim.state_hash(), "A night's sleep survives a reload")
	# A step wakes the player (and does not move them this time).
	var cell: Array = s.entities[str(s.player)].cell.duplicate()
	sim.submit("move_player", {"direction": [1, 0]}); sim.step()
	check(not Sleep.asleep(s) and s.entities[str(s.player)].cell == cell, "Moving gets the player up")
	# Sleeping on until rested.
	s.player_needs.fatigue = 20
	sim.submit("context_action", {"target": lodge.id, "action": "sleep", "part": lodge_bed})
	for i in range(3000):
		sim.step()
		if i > 50 and not Sleep.asleep(s): break
	check(not Sleep.asleep(s) and int(s.player_needs.fatigue) == 0, "The player wakes when rested: " + str(s.player_control.notice))
	# In jail: the prisoner's cot is in reach and can be slept on.
	var spot: Array = Law.cell_spot(office)
	s.entities[str(s.player)].cell = spot.duplicate()
	s.player_control.jail = {"office": office.id, "until": s.tick + 6000, "hours": 10, "rect": Law.cell_rect(office), "sheriff": 0, "town": 1, "crimes": []}
	office.cell_open = false
	s.player_needs.fatigue = 60
	sim.submit("context_action", {"target": office.id, "action": "sleep", "part": prisoner_bed})
	for i in range(200):
		sim.step()
		if Sleep.asleep(s): break
	check(Sleep.asleep(s), "A prisoner can sleep on the cot: " + str(s.player_control.notice))
	sim.submit("wake"); sim.step()
	check(not Sleep.asleep(s), "A key press wakes the player")
	print("Player sleep: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
