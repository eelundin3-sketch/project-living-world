extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Brawl = preload("res://sim/player/brawl.gd")
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
	check(s.brawl.blood.size() >= 1, "A punch leaves blood on the ground")
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
	# Five punches knock them out; they lie still and then get up.
	var made2 := setup(); var sim2: RefCounted = made2[0]; var s2: Dictionary = made2[1]; var v2: Dictionary = made2[2]
	for i in range(Brawl.KO_HITS):
		s2.entities[str(v2.id)].cell = [61, 60]
		v2.brawl = {}
		sim2.submit("player_strike", {"kind": "punch", "direction": [1000, 0]})
		for t in range(12): sim2.step()
	check(not v2.get("knock", {}).is_empty() and v2.knock.kind == "ko", "Too many punches knock them out")
	check(v2.knock.has("style") and Brawl.knocked(s2, v2), "A knockout has a lying style")
	var down_until: int = v2.knock.down_until
	while s2.tick < down_until - 2: sim2.step()
	check(Brawl.knocked(s2, v2), "They stay down while unconscious")
	while s2.tick < v2.knock.get("rise_until", 0) + 2: sim2.step()
	check(v2.get("knock", {}).is_empty(), "They get back up afterwards")
	check(v2.health >= 20, "A beating never kills")
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
	for t in range(40): sim4.step()
	sim4.submit("move_player", {"direction": [1, 0]}); sim4.step()
	check(s4.entities[str(s4.player)].cell != start_cell, "The player can move again after getting up")
	check(Invariants.validate(s4).is_empty(), "Invariants hold: " + str(Invariants.validate(s4)))
	if failures == 0: print("Brawl: PASS")
	quit(failures)
