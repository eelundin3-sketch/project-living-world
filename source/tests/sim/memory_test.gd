extends SceneTree
## Memories that matter: a crime is written in the chronicle with who saw it, the victim, their
## family and the witnesses remember it, memories fade (a killing never does), and how people feel
## moves prices. A death the player had no hand in no longer turns the town against them.
const Sim = preload("res://sim/core/simulation.gd")
const Law = preload("res://sim/law/law.gd")
const Society = preload("res://sim/factions/society.gd")
const Chronicle = preload("res://sim/world/chronicle.gd")
const Stalls = preload("res://sim/economy/stall_service.gd")
const Brawl = preload("res://sim/combat/brawl.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)

func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	s.tick = 14400 + 6000   # day two, mid-morning: people are up
	for npc in s.residents.values(): npc.sleeping = {}
	var player: int = int(s.player)
	# A victim who lives with family, and a bystander.
	var victim: Dictionary = {}
	for npc in s.residents.values():
		var household: Dictionary = s.households.get(str(npc.get("household", "")), {})
		if npc.occupation not in ["Sheriff", "Child"] and household.get("members", []).size() >= 2: victim = npc; break
	check(not victim.is_empty(), "Found a victim with family")
	var family: int = 0
	for id in s.households[victim.household].members:
		if int(id) != int(victim.id): family = int(id); break
	var bystander: Dictionary = {}
	for npc in s.residents.values():
		if npc.id != victim.id and int(npc.id) != family and npc.settlement == victim.settlement and npc.occupation != "Child": bystander = npc; break
	var spot: Array = s.entities[str(victim.id)].cell
	s.entities[str(player)].cell = [spot[0] + 1, spot[1]]
	s.entities[str(bystander.id)].cell = [spot[0] + 3, spot[1]]
	# Before: nobody minds you.
	check(Society.opinion(s, int(victim.id), player) == 0, "A stranger starts at 0")
	Law.crime(s, int(victim.settlement), "theft", int(victim.id))
	var entry: Dictionary = Chronicle.entries(s)[-1]
	check(entry.kind == "theft" and int(entry.actor) == player and int(entry.victim) == int(victim.id), "The theft is in the chronicle")
	check(int(bystander.id) in entry.witnesses, "...with the bystander as a witness (%s)" % str(entry.witnesses))
	check(Society.opinion(s, int(victim.id), player) == -25, "The victim remembers being robbed (%d)" % Society.opinion(s, int(victim.id), player))
	check(Society.opinion(s, family, player) < 0 and Society.opinion(s, family, player) > -25, "Their family remembers it at half strength (%d)" % Society.opinion(s, family, player))
	check(Society.opinion(s, int(bystander.id), player) < 0, "The witness thinks less of you (%d)" % Society.opinion(s, int(bystander.id), player))
	check(Stalls.feeling_pct(s, int(victim.id)) == 0, "One theft: no price change yet")
	Law.crime(s, int(victim.settlement), "theft", int(victim.id))
	check(Society.opinion(s, int(victim.id), player) == -50, "A second theft deepens the grudge rather than adding a new memory (%d)" % Society.opinion(s, int(victim.id), player))
	check(victim.memories.filter(func(m): return m.kind == "robbed").size() == 1, "...as one memory")
	check(Stalls.feeling_pct(s, int(victim.id)) == 15, "A grudge puts 15% on their prices")
	# Haggling reads the same feeling (it used to read a record as a number).
	victim.relations[str(player)]["trust"] = 5
	s.player_control.trade_terms = {}
	Stalls.haggle(sim, int(victim.id))
	check(bool(s.player_control.trade_terms.get("haggled", false)), "Haggling works with someone who remembers you")
	# Time heals, except a killing.
	s.tick += 22 * 14400
	check(Society.opinion(s, int(victim.id), player) == 5, "Three weeks on, the theft has faded (%d)" % Society.opinion(s, int(victim.id), player))
	Law.remember_crime(s, int(victim.settlement), "murder", family)
	s.tick += 60 * 14400
	check(Society.opinion(s, int(victim.id), player) <= -55, "A killing in the family is never forgotten (%d)" % Society.opinion(s, int(victim.id), player))
	# A death the player had nothing to do with doesn't count against them.
	var other: Dictionary = {}
	for npc in s.residents.values():
		if npc.settlement == bystander.settlement and npc.id != bystander.id and npc.id != victim.id and int(npc.id) != family and npc.health > 0: other = npc; break
	var before: int = Society.opinion(s, int(bystander.id), player)
	Brawl.kill(sim, other, "fever")
	check(Society.opinion(s, int(bystander.id), player) == before, "An unrelated death changes nothing about you")
	check(Chronicle.entries(s)[-1].kind == "death" and str(Chronicle.entries(s)[-1].cause) == "fever", "...but the death is in the chronicle")
	# The chronicle never grows without bound; memories stay within 16.
	for i in range(260): Chronicle.record(s, "test", 1, 0, 0, spot)
	check(Chronicle.entries(s).size() == Chronicle.MAX, "The chronicle keeps the last %d entries" % Chronicle.MAX)
	for i in range(30): Society.remember(s, int(victim.id), "gift" if i % 2 == 0 else "helped", int(s.residents.keys()[i % s.residents.size()]), "kindness")
	check(victim.memories.size() <= 16, "Memories stay within 16")
	check(victim.memories.any(func(m): return m.kind == "killed_kin"), "...and the strongest (a killing) is never pushed out")
	# Binding someone's wound is remembered kindly, by them and their family.
	var patient: Dictionary = bystander
	load("res://sim/combat/bleeding.gd").open_wound(s, patient)
	load("res://sim/inventory/inventory_store.gd").produce(s, int(s.player), "bandage", 1)
	var before_help: int = Society.opinion(s, int(patient.id), player)
	load("res://sim/player/context_actions.gd").perform(sim, int(patient.id), "bandage")
	check(not load("res://sim/combat/bleeding.gd").bleeding(patient), "Bandaging stops their bleeding")
	check(Society.opinion(s, int(patient.id), player) >= before_help + 39, "...and they remember you saved them (%d -> %d)" % [before_help, Society.opinion(s, int(patient.id), player)])
	var errors: Array = load("res://sim/diagnostics/invariants.gd").validate(s)
	check(errors.is_empty(), "World invariants hold (%s)" % str(errors))
	# Save, load and continue.
	var copy := Sim.new(); copy.restore(sim.snapshot())
	for i in range(80): sim.step(); copy.step()
	check(sim.state_hash() == copy.state_hash(), "Save, load and continue gives the same world")
	print("Memory: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
