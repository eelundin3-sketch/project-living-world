extends SceneTree
## Reputation per town: worked out each morning from what each town knows the player did. A
## witnessed killing in one town marks you there, not elsewhere until the news travels, and fades.
const Sim = preload("res://sim/core/simulation.gd")
const Law = preload("res://sim/law/law.gd")
const Reputation = preload("res://sim/factions/reputation.gd")
const Chronicle = preload("res://sim/world/chronicle.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)

func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	s.tick = 14400 + 6000
	Reputation.update(s)
	check(Reputation.value(s, 1) == 0 and Reputation.label(0) == "a Stranger", "Everyone starts as a stranger")
	var victim: Dictionary = {}
	for npc in s.residents.values():
		if npc.settlement == 1 and npc.occupation not in ["Sheriff", "Child"]: victim = npc; break
	s.entities[str(s.player)].cell = s.entities[str(victim.id)].cell.duplicate()
	Law.remember_crime(s, 1, "murder", int(victim.id))
	Law.remember_crime(s, 1, "murder", int(victim.id))
	Reputation.update(s)
	check(Reputation.value(s, 1) == -80, "Two killings in Alder Hollow: %d" % Reputation.value(s, 1))
	check(Reputation.label(Reputation.value(s, 1)) == "Feared", "...Feared there")
	check(Reputation.value(s, 2) == 0, "Reedbank hasn't heard (yet)")
	# News reaching another town (gossip marks the entry heard there).
	for entry in Chronicle.entries(s): if entry.kind == "murder": entry["heard_in"] = [2]
	Reputation.update(s)
	check(Reputation.value(s, 2) == -80, "Once the news reaches Reedbank, it counts there too")
	check(Reputation.summary(s).contains("Feared in Alder Hollow"), "The summary reads well: %s" % Reputation.summary(s))
	# Time softens it.
	s.tick += 42 * 14400
	Reputation.update(s)
	check(Reputation.value(s, 1) > -80 and Reputation.value(s, 1) < 0, "Six weeks on it has softened (%d)" % Reputation.value(s, 1))
	s.tick += 60 * 14400
	Reputation.update(s)
	check(Reputation.value(s, 1) == 0, "Twelve weeks on it has faded")
	# The morning update keeps it current in a running game, and it survives save/load.
	var run := Sim.new(); run.start_game()
	for i in range(14400 + 200): run.step()
	check(run.state.has("reputation"), "The morning update fills in the standing")
	var copy := Sim.new(); copy.restore(run.snapshot())
	for i in range(60): run.step(); copy.step()
	check(run.state_hash() == copy.state_hash(), "Save, load and continue gives the same world")
	print("Reputation: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
