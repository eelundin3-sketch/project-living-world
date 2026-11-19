extends SceneTree
## Gossip: witnesses know first, chats pass news on (sometimes bigger), traders carry it to the
## next town, families share it, a town that has heard counts it in your reputation there, and
## asking for news gets the real story. Stale news is forgotten.
const Sim = preload("res://sim/core/simulation.gd")
const Law = preload("res://sim/law/law.gd")
const Gossip = preload("res://sim/entities/gossip.gd")
const Chronicle = preload("res://sim/world/chronicle.gd")
const Stalls = preload("res://sim/economy/stall_service.gd")
const Reputation = preload("res://sim/factions/reputation.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)

func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	s.tick = 14400 + 6000
	var town1: Array = []
	var town2: Array = []
	for npc in s.residents.values():
		npc.sleeping = {}
		if npc.occupation in ["Child", "Trader"]: continue
		if npc.settlement == 1: town1.append(npc)
		if npc.settlement == 2: town2.append(npc)
	var victim: Dictionary = town1[0]
	var witness: Dictionary = town1[1]
	var stranger: Dictionary = town1[2]
	var spot: Array = s.entities[str(victim.id)].cell
	s.entities[str(s.player)].cell = [spot[0] + 1, spot[1]]
	s.entities[str(witness.id)].cell = [spot[0] + 3, spot[1]]
	s.entities[str(stranger.id)].cell = [spot[0] + 200, spot[1] + 200]
	Law.crime(s, 1, "assault", int(victim.id))
	var entry: Dictionary = Chronicle.entries(s)[-1]
	check(Gossip.knows(witness, int(entry.id)) and Gossip.knows(victim, int(entry.id)), "The witness and the victim know at once")
	check(not Gossip.knows(stranger, int(entry.id)), "Someone far off doesn't")
	# Asking the witness for news gets the story.
	var said: String = Stalls.news(s, witness)
	check(said.contains(String(s.entities[str(victim.id)].name)), "Ask for news: \"%s\"" % said)
	# A chat passes it on.
	var passed := false
	for i in range(30):
		Gossip.chat(sim, witness, stranger)
		if Gossip.knows(stranger, int(entry.id)): passed = true; break
	check(passed, "A chat passes the news on")
	# A trader takes it along to the next town.
	var trader: Dictionary = town2[0]
	Gossip.pack(s, trader, 1)
	check(Gossip.knows(trader, int(entry.id)), "A trader leaving town takes the news")
	Gossip.unpack(s, trader, 2)
	var told: int = town2.filter(func(n): return Gossip.knows(n, int(entry.id))).size()
	check(told >= 2, "...and tells it at the next market (%d heard)" % told)
	# Families share; when a third of a town has heard, the town knows, and it counts against you.
	check(not 2 in entry.get("heard_in", []), "Reedbank doesn't 'know' yet")
	for npc in town2.slice(0, ceili(town2.size() / 3.0) + 1): Gossip.learn(s, int(npc.id), int(entry.id), 1)
	Gossip.daily(s)
	check(2 in entry.get("heard_in", []), "Once a third have heard, Reedbank knows")
	Reputation.update(s)
	check(Reputation.value(s, 2) < 0, "...and your standing there drops (%d)" % Reputation.value(s, 2))
	# Stories grow: a fresh story passed along a chain of chats, many times, sometimes comes out bigger.
	var biggest := 0
	for trial in range(30):
		var story: Dictionary = Chronicle.record(s, "theft", 1, int(s.player), int(victim.id), [0, 0])
		var chain: Array = town1.slice(3, 9)
		for npc in chain: npc.rumours = npc.get("rumours", []).filter(func(r): return int(r.event) != int(story.id))
		Gossip.learn(s, int(chain[0].id), int(story.id), 0)
		for hop in range(chain.size() - 1):
			for attempt in range(10):
				Gossip.chat(sim, chain[hop], chain[hop + 1])
				if Gossip.knows(chain[hop + 1], int(story.id)): break
		for npc in chain:
			for rumour in npc.get("rumours", []):
				if int(rumour.event) == int(story.id): biggest = maxi(biggest, int(rumour.level))
	check(biggest >= 1, "Stories grow in the telling (biggest telling %d)" % biggest)
	check(Gossip.describe(s, entry, 2) != Gossip.describe(s, entry, 0), "A bigger telling reads bigger: %s" % Gossip.describe(s, entry, 2))
	# Two weeks on, it's old news.
	s.tick += 15 * 14400
	Gossip.daily(s)
	check(not Gossip.knows(witness, int(entry.id)), "Old news is forgotten")
	# Save, load and continue.
	var copy := Sim.new(); copy.restore(sim.snapshot())
	for i in range(200): sim.step(); copy.step()
	check(sim.state_hash() == copy.state_hash(), "Save, load and continue gives the same world")
	print("Gossip: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
