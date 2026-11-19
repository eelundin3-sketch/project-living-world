extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Brawl = preload("res://sim/combat/brawl.gd")
const Health = preload("res://sim/combat/body_health.gd")
const Invariants = preload("res://sim/diagnostics/invariants.gd")
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
		if other.id != victim.id and other.occupation == "Sheriff": other.occupation = "Gatherer"   # keep the law out of these duels
	var player: Dictionary = s.entities[str(s.player)]
	player.cell = [60, 60]
	s.entities[str(victim.id)].cell = [61, 60]
	victim.job = 0; victim.goal = ""; victim.path = []
	return [sim, s, victim, player]
func punch(sim: RefCounted) -> void:
	sim.submit("player_strike", {"kind": "punch", "direction": [1000, 0]})
	for t in range(12): sim.step()
func _initialize() -> void:
	var made := setup(); var sim: RefCounted = made[0]; var s: Dictionary = made[1]; var victim: Dictionary = made[2]; var player: Dictionary = made[3]
	var key := str(victim.id)
	var health: int = victim.health
	punch(sim)
	check(not str(victim.get("last_bruise", "")).is_empty() and int(victim.bruises[victim.last_bruise]) >= 1, "A punch leaves a bruise where it lands")
	check((s.brawl.blood.size() >= 1) == (victim.last_bruise == "head"), "Only a blow to the face draws blood")
	check(victim.health < health, "A punch hurts")
	check(int(victim.anger) >= Brawl.ANGER_PUNCH, "A punch makes them angry")
	check(s.brawl.events.any(func(e: Dictionary) -> bool: return e.kind == "punch_hit"), "A punch lands as a sound event")
	check(not victim.get("brawl", {}).is_empty(), "Someone punched fights back")
	# They come at the player and hit back.
	player.cell = [60, 60]
	s.entities[key].cell = [64, 60]
	var hurt_before: int = 0
	for part in s.player_health.parts.values(): hurt_before += part.damage
	var hit_back := false
	for t in range(260):
		sim.step()
		if s.brawl.events.any(func(e: Dictionary) -> bool: return e.kind in ["punch_hit", "shove_hit"] and e.tick > s.tick - 3 and e.cell == player.cell): hit_back = true
		if hit_back: break
		player.cell = [60, 60]
	var hurt_after: int = 0
	for part in s.player_health.parts.values(): hurt_after += part.damage
	check(hit_back or hurt_after > hurt_before or Brawl.player_down(s), "The angry villager walks up and hits the player")
	# Beating someone until their health is below 20% knocks them out; they lie still and then get up.
	var made2 := setup(); var sim2: RefCounted = made2[0]; var s2: Dictionary = made2[1]; var v2: Dictionary = made2[2]
	var punches := 0
	while punches < 20 and v2.get("knock", {}).is_empty():
		s2.entities[str(v2.id)].cell = [61, 60]
		v2.brawl = {}
		s2.player_control.punch_end = -1000   # plain straight punches: the combo chain has its own test
		sim2.submit("player_strike", {"kind": "punch", "direction": [1000, 0]})
		for t in range(12): sim2.step()
		punches += 1
	check(not v2.get("knock", {}).is_empty() and v2.knock.kind == "ko", "Health below 20% knocks them out")
	check(v2.health < Brawl.KO_HEALTH and punches > 3, "The knockout comes from health, not from a punch count (%d punches, health %d)" % [punches, v2.health])
	check(v2.knock.has("style") and Brawl.knocked(s2, v2), "A knockout has a lying style")
	var down_until: int = v2.knock.down_until
	while s2.tick < down_until - 2: sim2.step()
	check(Brawl.knocked(s2, v2), "They stay down while unconscious")
	while s2.tick < v2.knock.get("rise_until", 0) + 2: sim2.step()
	check(v2.get("knock", {}).is_empty(), "They get back up afterwards")
	check(v2.health >= 20 and v2.health > 0, "A beating never kills")
	# A shove drops them briefly.
	var made3 := setup(); var sim3: RefCounted = made3[0]; var s3: Dictionary = made3[1]; var v3: Dictionary = made3[2]
	sim3.submit("player_strike", {"kind": "shove", "direction": [1000, 0]})
	for t in range(8): sim3.step()
	check(not v3.get("knock", {}).is_empty() and v3.knock.kind == "fall", "A shove knocks them to the ground")
	for t in range(60): sim3.step()
	check(v3.get("knock", {}).is_empty(), "Shoved people get back up")
	# Falls use different lying styles depending on the blow.
	var styles: Dictionary = {}
	for dir in [[1000, 0], [-1000, 0], [0, 1000], [0, -1000]]:
		for n in range(8):
			s3.tick += 7
			styles[Brawl.fall_style(s3, [60 + n, 60], "fall", dir)] = true
	for n in range(8): styles[Brawl.fall_style(s3, [60 + n, 60], "ko", [1000, 0])] = true
	check(styles.size() >= 5, "Several lying styles are used: " + str(styles.keys()))
	# The player can be shoved down and cannot act until up.
	var made4 := setup(); var sim4: RefCounted = made4[0]; var s4: Dictionary = made4[1]
	Brawl.knockdown(s4, s4.player_control, [60, 60], "fall", [1000, 0])
	var start_cell: Array = s4.entities[str(s4.player)].cell.duplicate()
	sim4.submit("move_player", {"direction": [1, 0]}); sim4.step()
	check(s4.entities[str(s4.player)].cell == start_cell, "A fallen player cannot move")
	for t in range(70): sim4.step()
	sim4.submit("move_player", {"direction": [1, 0]}); sim4.step()
	check(s4.entities[str(s4.player)].cell != start_cell, "The player can move again after getting up")
	check(Invariants.validate(s4).is_empty(), "Invariants hold: " + str(Invariants.validate(s4)))
	# A shove irritates exactly as much as a punch.
	var made5 := setup(); var sim5: RefCounted = made5[0]; var s5: Dictionary = made5[1]; var v5: Dictionary = made5[2]
	sim5.submit("player_strike", {"kind": "shove", "direction": [1000, 0]})
	for t in range(8): sim5.step()
	check(int(v5.anger) >= Brawl.ANGER_PUNCH and int(v5.offences) == 1, "A shove makes them as angry as a punch")
	# First offence: they chase, shove the player down and walk away. A second one means a beating.
	s5.entities[str(v5.id)].cell = [64, 60]
	var shoved := false
	for t in range(300):
		sim5.step()
		if s5.brawl.events.any(func(e: Dictionary) -> bool: return e.kind == "shove_hit" and e.cell == s5.entities[str(s5.player)].cell and e.tick > 20): shoved = true
		if v5.get("brawl", {}).is_empty() and shoved: break
		if not Brawl.player_down(s5): s5.entities[str(s5.player)].cell = s5.entities[str(s5.player)].cell
	check(shoved, "The angry villager runs after the player and shoves them down")
	check(v5.get("brawl", {}).is_empty(), "After the shove they walk away")
	var made6 := setup(); var sim6: RefCounted = made6[0]; var s6: Dictionary = made6[1]; var v6: Dictionary = made6[2]
	sim6.submit("player_strike", {"kind": "punch", "direction": [1000, 0]})
	for t in range(12): sim6.step()
	s6.entities[str(v6.id)].cell = [61, 60]
	sim6.submit("player_strike", {"kind": "shove", "direction": [1000, 0]})
	for t in range(12): sim6.step()
	check(int(v6.offences) == 2, "Two offences are counted")
	check(str(v6.get("brawl", {}).get("mode", "")) == "beat", "A second offence is answered with a beating")
	s6.entities[str(v6.id)].cell = [62, 60]
	for t in range(900):
		sim6.step()
		if Brawl.player_down(s6) and s6.player_control.knock.kind == "ko": break
	check(Brawl.player_down(s6) and s6.player_control.knock.kind == "ko", "The beating knocks the player unconscious")
	var cuts := 0
	for part in s6.player_health.parts.values(): if part.wound == "cut": cuts += 1
	check(cuts == 0, "Punches leave bruises, not cuts")
	check(Health.overall(s6) < Brawl.KO_HEALTH, "The player's health bar fell below 20 percent (%d)" % Health.overall(s6))
	# Open cuts leave blood on the ground until bandaged.
	var made7 := setup(); var sim7: RefCounted = made7[0]; var s7: Dictionary = made7[1]
	var blood_before: int = s7.brawl.blood.size()
	Health.injure(s7, "left_forearm", 12, "cut")
	for t in range(95): sim7.step()
	check(s7.brawl.blood.size() >= blood_before + 2, "A bleeding player drops blood")
	s7.player_health.parts.left_forearm.bleeding = false
	var blood_mid: int = s7.brawl.blood.size()
	for t in range(95): sim7.step()
	check(s7.brawl.blood.size() == blood_mid, "A bandaged wound stops dripping")
	# Running the stamina bar dry drops the player face first; they cannot sprint again until recovered.
	var made8 := setup(); var sim8: RefCounted = made8[0]; var s8: Dictionary = made8[1]
	s8.player_health.stamina = 2
	for t in range(3):
		sim8.submit("move_player", {"direction": [1, 0], "run": true}); sim8.step(); sim8.step()
	check(Brawl.player_down(s8) and s8.player_control.knock.get("style", "") == "front", "Running on empty makes the player fall forward")
	check(Health.is_winded(s8), "The player is winded after collapsing")
	for t in range(80): sim8.step()
	check(not Brawl.player_down(s8) and Health.is_winded(s8), "They get up still winded")
	var stamina_then: int = s8.player_health.stamina
	for t in range(260): sim8.step()
	check(not Health.is_winded(s8) and s8.player_health.stamina >= Health.RECOVER_AT, "Winded ends once stamina is back to halfway")
	# Shift runs a click-to-walk route: faster than walking.
	var made9 := setup(); var sim9: RefCounted = made9[0]; var s9: Dictionary = made9[1]
	var walker: Array = s9.entities[str(s9.player)].cell.duplicate()
	var made10 := setup(); var sim10: RefCounted = made10[0]; var s10: Dictionary = made10[1]
	sim9.submit("walk_to", {"cell": [walker[0] - 30, walker[1]]}); sim10.submit("walk_to", {"cell": [walker[0] - 30, walker[1]]})
	sim10.submit("travel_run", {"run": true})
	for t in range(40): sim9.step(); sim10.step()
	var walked: int = absi(s9.entities[str(s9.player)].cell[0] - walker[0])
	var ran: int = absi(s10.entities[str(s10.player)].cell[0] - walker[0])
	check(ran > walked + 5, "Shift makes a route run faster (walked %d, ran %d)" % [walked, ran])
	check(s10.player_health.stamina < 100, "Running a route spends stamina")
	if failures == 0: print("Brawl: PASS")
	quit(failures)
