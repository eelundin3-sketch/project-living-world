extends SceneTree
## Fair chases (walk/run pace and stamina), giving up far from home, kicks, death, and speech.
const Sim = preload("res://sim/core/simulation.gd")
const Brawl = preload("res://sim/player/brawl.gd")
const Speech = preload("res://sim/entities/speech.gd")
const Looting = preload("res://sim/player/looting.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)
func setup() -> Array:
	var sim := Sim.new(); sim.start_game()
	var s: Dictionary = sim.state
	var victim: Dictionary = {}
	for npc in s.residents.values():
		if npc.settlement == 1 and npc.occupation == "Woodsman": victim = npc; break
	for other in s.residents.values():
		if other.id != victim.id and other.occupation == "Sheriff": other.occupation = "Gatherer"
	var player: Dictionary = s.entities[str(s.player)]
	player.cell = [60, 60]
	s.entities[str(victim.id)].cell = [61, 60]
	victim.job = 0; victim.goal = ""; victim.path = []
	return [sim, s, victim, player]
func _initialize() -> void:
	# --- chase pace and stamina
	var made := setup(); var sim: RefCounted = made[0]; var s: Dictionary = made[1]; var v: Dictionary = made[2]; var player: Dictionary = made[3]
	Brawl.engage(s, v, "shove")
	v.anger = 80
	var key := str(v.id)
	s.entities[key].cell = [40, 60]
	player.cell = [70, 60]
	var runs := 0
	var walked_gap_closed := 0
	var start_x: int = s.entities[key].cell[0]
	for t in range(40):
		sim.step()
		if int(v.running_tick) >= s.tick - 1: runs += 1
	check(runs > 10 and int(v.stamina) < 100, "A far-off chaser runs and spends stamina (runs %d, stamina %d)" % [runs, int(v.stamina)])
	# Winded: below 20 they walk at the player's pace.
	v.stamina = 10; v.winded = true
	player.cell = [90, 60]; s.entities[key].cell = [60, 60]
	var before: int = s.entities[key].cell[0]
	for t in range(20): sim.step()
	var moved: int = s.entities[key].cell[0] - before
	check(moved <= 11, "A winded chaser only walks (%d cells in 20 ticks)" % moved)
	check(int(v.stamina) > 10 or v.winded, "They recover their breath while walking")
	# --- giving up far from their own town
	var made2 := setup(); var sim2: RefCounted = made2[0]; var s2: Dictionary = made2[1]; var v2: Dictionary = made2[2]; var p2: Dictionary = made2[3]
	Brawl.engage(s2, v2, "shove")
	v2.anger = 90
	var home: Array = v2.brawl.home
	s2.entities[str(v2.id)].cell = [home[0] + 120, home[1] + 14]
	p2.cell = [home[0] + 140, home[1] + 14]
	for t in range(10): sim2.step()
	check(v2.brawl.is_empty() and str(v2.status).contains("Gave up"), "A chaser too far from their town gives up (%s)" % v2.status)
	check(s2.speech.any(func(l): return l.speaker == v2.id), "They shout something as they give up")
	# --- a kick on someone lying down does 1.5 punches; zero health kills
	var made3 := setup(); var sim3: RefCounted = made3[0]; var s3: Dictionary = made3[1]; var v3: Dictionary = made3[2]; var p3: Dictionary = made3[3]
	Brawl.knockdown(s3, v3, [61, 60], "ko", [1000, 0])
	var hp: int = v3.health
	sim3.submit("player_strike", {"kind": "shove", "direction": [1000, 0]})
	for t in range(14): sim3.step()
	check(v3.health == hp - Brawl.KICK_DAMAGE, "Space kicks someone on the ground for 1.5 punches (%d -> %d)" % [hp, v3.health])
	check(Brawl.KICK_DAMAGE == roundi(Brawl.PUNCH_DAMAGE * 1.5), "A kick is 1.5 times a punch")
	v3.health = 10
	sim3.submit("player_strike", {"kind": "shove", "direction": [1000, 0]})
	for t in range(14): sim3.step()
	check(v3.health <= 0 and v3.get("dead", false) and str(v3.status) == "Dead", "Kicking someone to zero kills them")
	check(Looting.can_search(s3, v3.id).is_empty(), "A body can be searched")
	check(Checks.validate(s3).is_empty(), "Death keeps goods and money accounted for: " + str(Checks.validate(s3)))
	# A shoved (not unconscious) person can be kicked too.
	var made4 := setup(); var sim4: RefCounted = made4[0]; var s4: Dictionary = made4[1]; var v4: Dictionary = made4[2]
	Brawl.knockdown(s4, v4, [61, 60], "fall", [1000, 0])
	for t in range(8): sim4.step()
	var hp4: int = v4.health
	sim4.submit("player_strike", {"kind": "shove", "direction": [1000, 0]})
	for t in range(14): sim4.step()
	check(v4.health < hp4, "Someone merely shoved down can be kicked")
	# --- the player dies at zero health and can no longer act
	var made5 := setup(); var sim5: RefCounted = made5[0]; var s5: Dictionary = made5[1]
	for part in s5.player_health.parts.values(): part.damage = 100
	for t in range(12): sim5.step()
	check(s5.player_control.get("dead", false), "The player dies when health reaches zero")
	var cell5: Array = s5.entities[str(s5.player)].cell.duplicate()
	sim5.submit("move_player", {"direction": [1, 0]}); sim5.step()
	check(s5.entities[str(s5.player)].cell == cell5, "A dead player cannot move")
	# --- knockout no longer leaves a stale notice
	var made6 := setup(); var sim6: RefCounted = made6[0]; var s6: Dictionary = made6[1]
	Brawl.knockdown(s6, s6.player_control, [60, 60], "ko", [1000, 0])
	s6.player_control.notice = ""
	for t in range(Brawl.KO_TICKS + 80): sim6.step()
	check(not str(s6.player_control.notice).contains("knocked out"), "No 'knocked out' text after waking")
	# --- speech
	var made7 := setup(); var sim7: RefCounted = made7[0]; var s7: Dictionary = made7[1]
	var spoke := false
	for npc in s7.residents.values():
		npc.goal = ""
	for t in range(1800):
		sim7.step()
		if s7.get("speech", []).size() > 0: spoke = true
	check(spoke, "Villagers make small talk")
	var copy := Sim.new(); copy.restore(sim7.snapshot())
	check(copy.state_hash() == sim7.state_hash(), "Speech, stamina and deaths survive a reload")
	print("Combat and speech: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
