extends SceneTree
## Townspeople as witnesses: an unseen crime puts nobody on the books, a crime a villager saw is
## filed once they reach a sheriff (and never if they are stopped), and the sheriff knows the
## culprit by the clothes described: change enough of them and he doesn't.
const Sim = preload("res://sim/core/simulation.gd")
const Law = preload("res://sim/law/law.gd")
const Reports = preload("res://sim/law/witness_reports.gd")
const Outfits = preload("res://sim/entities/outfits.gd")
const Brawl = preload("res://sim/combat/brawl.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)

## A fresh mid-morning world, a victim far from every sheriff, everyone else moved out of sight.
func _scene() -> Array:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	s.tick = 14400 + 6000
	var victim: Dictionary = {}
	for npc in s.residents.values():
		npc.sleeping = {}
		if victim.is_empty() and npc.settlement == 1 and npc.occupation not in ["Sheriff", "Child", "Trader"]: victim = npc
	var far: Array = [s.entities[str(s.settlements["1"].warehouse)].cell[0] + 40, s.entities[str(s.settlements["1"].warehouse)].cell[1] + 30]
	var spot: Array = []
	for dy in range(0, 12):
		for dx in range(0, 12):
			if spot.is_empty() and load("res://sim/world/world_db.gd").walkable(s, [far[0] + dx, far[1] + dy]): spot = [far[0] + dx, far[1] + dy]
	for npc in s.residents.values():
		if npc.id != victim.id and npc.occupation != "Sheriff": s.entities[str(npc.id)].cell = [spot[0] - 60, spot[1] - 60]
	s.entities[str(victim.id)].cell = spot.duplicate()
	s.entities[str(s.player)].cell = [spot[0] + 1, spot[1]]
	return [sim, s, victim, spot]

func _initialize() -> void:
	# 1. Nobody saw it: a sleeping victim is robbed and wakes to nothing; nobody knows who.
	var scene: Array = _scene(); var sim = scene[0]; var s: Dictionary = scene[1]; var victim: Dictionary = scene[2]
	victim.sleeping = {"since": s.tick}
	Law.crime(s, 1, "theft", int(victim.id))
	check(Law.wanted_hours(s, 1) == 0, "An unseen theft puts nobody on the books")
	check(s.law.get("hidden", []).size() == 1, "...it is kept as an unsolved crime")
	# 2. The victim saw it: they run to the sheriff, and only then are you wanted.
	scene = _scene(); sim = scene[0]; s = scene[1]; victim = scene[2]
	Law.crime(s, 1, "theft", int(victim.id))
	check(Law.wanted_hours(s, 1) == 0, "Not wanted the moment it happens")
	check(not victim.get("reporting", {}).is_empty(), "The victim runs to tell the sheriff")
	var filed_at := -1
	for i in range(1500):
		sim.step()
		if Law.wanted_hours(s, 1) > 0: filed_at = i; break
	check(filed_at > 0, "...and once they reach him you are wanted (after %d ticks)" % filed_at)
	check(victim.get("reporting", {}).is_empty(), "...then they go back to their day")
	# 3. Recognised by your clothes: change three pieces and he doesn't know you.
	check(Law.recognised(s, 1), "Dressed as described, the sheriff knows you")
	var worn: Dictionary = Outfits.worn(s, int(s.player))
	var changed: Dictionary = worn.duplicate()
	for slot in ["hat", "vest", "shirt", "pants"]:
		if not str(worn.get(slot, "")).is_empty(): changed[slot] = Outfits.key(slot, (Outfits.variant_of(str(worn[slot])) + 1) % 3)
	Outfits.dress(s, int(s.player), changed)
	check(not Law.recognised(s, 1), "In different clothes he doesn't")
	# 4. Stopped on the way: knock the witness down and the news never arrives.
	scene = _scene(); sim = scene[0]; s = scene[1]; victim = scene[2]
	Law.crime(s, 1, "assault", int(victim.id))
	sim.step(); sim.step()
	Brawl.knockdown(s, victim, s.entities[str(victim.id)].cell, "ko")
	for i in range(1500): sim.step()
	check(Law.wanted_hours(s, 1) == 0, "A witness stopped on the way never tells")
	# 5. A sheriff who sees it himself knows you by face, whatever you wear.
	scene = _scene(); sim = scene[0]; s = scene[1]; victim = scene[2]
	var sheriff: Dictionary = Law.sheriffs(s, 1)[0]
	s.entities[str(sheriff.id)].cell = [scene[3][0] + 4, scene[3][1]]
	Law.crime(s, 1, "assault", int(victim.id))
	check(Law.wanted_hours(s, 1) > 0 and Law.recognised(s, 1), "Seen by the sheriff himself: wanted at once, known by face")
	# Save, load and continue mid-report.
	scene = _scene(); sim = scene[0]; s = scene[1]; victim = scene[2]
	Law.crime(s, 1, "theft", int(victim.id))
	for i in range(20): sim.step()
	var copy := Sim.new(); copy.restore(sim.snapshot())
	for i in range(200): sim.step(); copy.step()
	check(sim.state_hash() == copy.state_hash(), "Save, load and continue mid-report gives the same world")
	print("Witnesses: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
