extends RefCounted
## Fist fights between the player and residents: anger, retaliation, knockdowns, knockouts and
## blood on the ground. Everything is simulation state; the view only reads `state.brawl`
## and each person's `knock`, `attack` and `brawl` records.
const World = preload("res://sim/world/world_db.gd")
const Jobs = preload("res://sim/jobs/job_board.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const BodyHealth = preload("res://sim/player/body_health.gd")
const Society = preload("res://sim/factions/society.gd")
const Households = preload("res://sim/entities/households.gd")
const FALL_TICKS := 14           # the drop to the ground
const SHOVE_LIE_TICKS := 16      # lying stunned after a shove
const KO_TICKS := 420            # lying unconscious after too many blows (about 42 s at 1x)
const RISE_TICKS := 26           # getting back to their feet
const HIT_WINDOW := 700
const ANGER_PUNCH := 55
const ANGER_SHOVE := 55          # a shove irritates exactly as much as a punch
const HOSTILE_AT := 50           # anger at which someone fights back
const PUNCH_DAMAGE := 9
const KO_HEALTH := 20            # health below this and the person is out cold
const OFFENCE_MEMORY := 3000     # how long a first offence is remembered (about 5 minutes at 1x)
const BEAT_DAMAGE := 22          # what one punch of a furious beating does to the player's body
const BLEED_TICKS := 900         # a cut keeps bleeding this long unless it is bandaged
const EXHAUST_LIE_TICKS := 26    # lying winded after running the stamina bar dry
const ATTACK_TICKS := 10
const ATTACK_IMPACT := 3
const BLOOD_LIFETIME := 36000    # about 2.5 game days
const MAX_BLOOD := 96
## Where a punch lands, weighted: mostly the face and body, sometimes a raised forearm or hand.
const PLAYER_PARTS: Array[String] = ["head", "head", "head", "upper_torso", "upper_torso", "lower_torso", "right_forearm", "left_forearm", "right_hand", "neck"]
## Body regions for villagers (who have no per-part health): only a blow to the face draws blood.
const NPC_PARTS: Array[String] = ["head", "head", "head", "upper_torso", "upper_torso", "lower_torso", "arm"]

static func initialize(s: Dictionary) -> void:
	if s.has("player_control") and not s.has("brawl"):
		s.brawl = {"blood": [], "events": [], "serial": 0}

static func event(s: Dictionary, kind: String, cell: Array, direction: Array = [0, 0]) -> void:
	if not s.has("brawl"): return
	s.brawl.serial += 1
	s.brawl.events.append({"serial": s.brawl.serial, "kind": kind, "cell": cell.duplicate(), "tick": s.tick, "dir": direction.duplicate()})
	if s.brawl.events.size() > 40: s.brawl.events.pop_front()

static func add_blood(s: Dictionary, cell: Array, direction: Array, size: int = 1) -> void:
	if not s.has("brawl"): return
	s.brawl.blood.append({"cell": cell.duplicate(), "tick": s.tick, "seed": (s.tick * 31 + cell[0] * 17 + cell[1] * 7) % 9973, "dir": direction.duplicate(), "size": size})
	if s.brawl.blood.size() > MAX_BLOOD: s.brawl.blood.pop_front()

static func knocked(s: Dictionary, holder: Dictionary) -> bool:
	var knock: Dictionary = holder.get("knock", {})
	return not knock.is_empty() and s.tick < int(knock.rise_until)

static func player_down(s: Dictionary) -> bool:
	return s.has("player_control") and knocked(s, s.player_control)

## True while a resident is lying down, fighting or mid-attack: other behaviour pauses.
static func busy(s: Dictionary, npc: Dictionary) -> bool:
	return knocked(s, npc) or not npc.get("brawl", {}).is_empty() or not npc.get("attack", {}).is_empty()

## How they go down depends on the blow: knocked backward off a hard hit, pitched forward when
## pushed away from the viewer, spread out by a heavy shove, and curled or slumped when out cold.
static func fall_style(s: Dictionary, cell: Array, kind: String, direction: Array) -> String:
	var seed_value: int = absi(s.tick * 31 + int(cell[0]) * 17 + int(cell[1]) * 7)
	var options: Array
	if kind == "ko":
		options = ["curled", "slump", "back", "front", "side", "sprawl"]
	elif absi(int(direction[1])) > absi(int(direction[0])) and int(direction[1]) < 0:
		options = ["front", "front", "side", "sprawl"]       # pushed away from the viewer: pitches forward
	elif absi(int(direction[1])) > absi(int(direction[0])):
		options = ["back", "back", "sprawl", "side"]          # pushed toward the viewer: falls backward
	else:
		options = ["back", "side", "sprawl", "back", "slump"] # pushed sideways
	return options[seed_value % options.size()]

static func knockdown(s: Dictionary, holder: Dictionary, cell: Array, kind: String, direction: Array = [0, 0], style: String = "") -> void:
	var lie: int = KO_TICKS if kind == "ko" else (EXHAUST_LIE_TICKS if kind == "exhaust" else SHOVE_LIE_TICKS)
	var side: int = 1 if int(direction[0]) > 0 else (-1 if int(direction[0]) < 0 else (1 if (s.tick + int(cell[0])) % 2 == 0 else -1))
	holder.knock = {"kind": kind, "start": s.tick, "down_until": s.tick + FALL_TICKS + lie, "rise_until": s.tick + FALL_TICKS + lie + RISE_TICKS,
		"style": style if not style.is_empty() else fall_style(s, cell, kind, direction), "side": side,
		"dir": [signi(int(direction[0])), signi(int(direction[1]))]}
	event(s, "fall", cell, direction)
	if holder == s.get("player_control", null) and s.has("player_health") and not s.player_health.treatment.is_empty():
		s.player_health.treatment = {}
		s.player_health.notice = "Treatment interrupted."

## The player's blow lands on a resident.
static func on_player_hit(sim: RefCounted, npc: Dictionary, victim: Dictionary, kind: String, direction: Array) -> void:
	var s: Dictionary = sim.state
	Households.wake(s, npc)
	if npc.job != 0: Jobs.release(s, npc.job, "INTERRUPTED_BY_FIGHT")
	npc.goal = ""
	npc.path = []
	npc.work_path = []
	# Every blow is an offence. The first sends them after the player to shove them down and walk
	# off; a second, while the first is fresh, is answered with a beating.
	if s.tick - int(npc.get("last_offence", -99999)) > OFFENCE_MEMORY: npc.offences = 0
	npc.offences = int(npc.get("offences", 0)) + 1
	npc.last_offence = s.tick
	var was_down: bool = knocked(s, npc)
	npc.anger = mini(100, int(npc.get("anger", 0)) + (ANGER_PUNCH if kind == "punch" else ANGER_SHOVE))
	if kind == "punch":
		npc.health = maxi(1, int(npc.health) - PUNCH_DAMAGE)
		# Blunt damage: a bruise where the blow lands. A punch to the face can split a lip or bloody a nose.
		var landed: String = NPC_PARTS[sim.random_int("brawl", 0, NPC_PARTS.size() - 1)]
		var bruises: Dictionary = npc.get("bruises", {})
		bruises[landed] = int(bruises.get(landed, 0)) + 1
		npc.bruises = bruises
		npc.last_bruise = landed
		if landed == "head": add_blood(s, victim.cell, direction, 1)
		event(s, "punch_hit", victim.cell, direction)
		if int(npc.health) < KO_HEALTH and not was_down:
			knockdown(s, npc, victim.cell, "ko", direction)
			npc.status = "Knocked out"
			npc.brawl = {}
			npc.anger = 40
			add_blood(s, victim.cell, direction, 2)
		elif not was_down:
			npc.status = "Staggered by a punch"
	else:
		if not was_down: knockdown(s, npc, victim.cell, "fall", direction)
		npc.status = "Knocked to the ground"
		event(s, "shove_hit", victim.cell, direction)
	if s.has("factions"): Society.remember(s, npc.id, "assault", s.player, "The traveller struck me.", -25)
	var mode := "beat" if int(npc.offences) >= 2 else "shove"
	if not npc.get("brawl", {}).is_empty(): npc.brawl.mode = mode
	if int(npc.anger) >= HOSTILE_AT and not knocked(s, npc):
		if npc.get("brawl", {}).is_empty():
			engage(s, npc, mode)
			s.player_control.notice = ("%s is furious and comes at you!" if mode == "beat" else "%s is angry and storms after you!") % s.entities[str(npc.id)].name
		# The law steps in: any sheriff nearby joins the fight against the aggressor.
		for other in s.residents.values():
			if other.id == npc.id or other.occupation != "Sheriff" or other.settlement != npc.settlement or busy(s, other) or other.health <= 0: continue
			var gap := Vector2(s.entities[str(other.id)].cell[0] - victim.cell[0], s.entities[str(other.id)].cell[1] - victim.cell[1])
			if gap.length() <= 24.0:
				other.anger = 60
				engage(s, other, "shove")
				other.status = "Stopping the fight"
				s.player_control.notice = "The sheriff comes to break up the fight!"

## Turns a resident hostile toward the player: they drop their work and fight until it burns out.
static func engage(s: Dictionary, npc: Dictionary, mode: String = "shove") -> void:
	Households.wake(s, npc)
	if npc.job != 0: Jobs.release(s, npc.job, "INTERRUPTED_BY_FIGHT")
	npc.goal = ""
	npc.path = []
	npc.brawl = {"target": s.player, "since": s.tick, "next_attack": s.tick + 14, "path_tick": -100, "mode": mode, "landed": false}
	npc.status = "Angry at the traveller"

static func update(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	if not s.has("brawl"): return
	var blood: Array = s.brawl.blood
	while not blood.is_empty() and s.tick - int(blood[0].tick) > BLOOD_LIFETIME: blood.pop_front()
	var control: Dictionary = s.player_control
	if not control.get("knock", {}).is_empty() and s.tick >= int(control.knock.rise_until):
		if control.knock.kind == "ko": BodyHealth.revive(s)
		control.knock = {}
	if not control.get("knock", {}).is_empty() and s.tick == int(control.knock.down_until): event(s, "get_up", s.entities[str(s.player)].cell)
	var player: Dictionary = s.entities[str(s.player)]
	_exhaustion(s, control, player)
	if s.tick % 30 == 0: _bleed(s, player)
	for key in s.residents.keys():
		var npc: Dictionary = s.residents[key]
		var cell: Array = s.entities[key].cell
		var knock: Dictionary = npc.get("knock", {})
		if not knock.is_empty():
			if s.tick == int(knock.down_until): event(s, "get_up", cell)
			if s.tick >= int(knock.rise_until):
				if knock.kind == "ko": npc.health = maxi(int(npc.health), KO_HEALTH + 5)
				npc.knock = {}
				npc.status = "Back on their feet"
				npc.work_pause_until = s.tick + 20
				# Someone shoved down while angry gets up and goes after the player.
				if int(npc.get("anger", 0)) >= HOSTILE_AT and npc.get("brawl", {}).is_empty() and not player_down(s):
					engage(s, npc, "beat" if int(npc.get("offences", 0)) >= 2 else "shove")
					s.player_control.notice = "%s gets up, angry!" % s.entities[str(npc.id)].name
			continue
		# Someone who was robbed while out cold comes round furious and goes after the thief.
		if npc.get("grudge", false) and npc.get("sleeping", {}).is_empty() and npc.get("brawl", {}).is_empty():
			npc.grudge = false
			npc.anger = 70
			engage(s, npc, "beat")
			s.player_control.notice = "%s has realised they were robbed!" % s.entities[str(npc.id)].name
		if s.tick % 100 == 0:
			if int(npc.get("anger", 0)) > 0 and npc.get("brawl", {}).is_empty(): npc.anger = maxi(0, int(npc.anger) - 3)
			if npc.health < 100 and npc.health > 0: npc.health = mini(100, int(npc.health) + 1)
		var fight: Dictionary = npc.get("brawl", {})
		if fight.is_empty(): continue
		if npc.health <= 0 or s.get("local_combat", {}).get("fighters", {}).has(key):
			npc.brawl = {}
			continue
		var attack: Dictionary = npc.get("attack", {})
		if not attack.is_empty():
			_advance_attack(sim, npc, attack, cell, player)
			continue
		var gap := Vector2(player.cell[0] - cell[0], player.cell[1] - cell[1])
		# Give up when the traveller is far away, has been floored, or the anger has burned out.
		if gap.length() > 30.0 or int(npc.get("anger", 0)) < 25 or player_down(s) or s.tick - int(fight.since) > 1800:
			npc.brawl = {}
			npc.anger = mini(int(npc.get("anger", 0)), 35)
			npc.status = "Cooled off"
			continue
		npc.status = "Fighting the traveller"
		if gap.length() > 1.5:
			# Charge in at a run while far away, then close the last few cells carefully.
			if s.tick % (1 if gap.length() > 4.0 else 2) != 0: continue
			if s.tick - int(fight.path_tick) >= 8 or npc.path.is_empty():
				var goal: Array = player.cell.duplicate()
				var route := Nav.request_path(s, cell, goal)
				fight.path_tick = s.tick
				npc.path = route.path if route.ok else []
			if not npc.path.is_empty():
				var next: Array = npc.path.pop_front()
				if World.walkable(s, next) and next != player.cell: s.entities[key].cell = next
		elif s.tick >= int(fight.next_attack):
			var kind := "punch" if str(fight.get("mode", "shove")) == "beat" else "shove"
			npc.attack = {"kind": kind, "start": s.tick, "impact": s.tick + ATTACK_IMPACT, "end": s.tick + ATTACK_TICKS, "resolved": false, "direction": [signi(player.cell[0] - cell[0]), signi(player.cell[1] - cell[1])]}

## Running the stamina bar all the way to empty drops the player face first; they lie winded and get up.
static func _exhaustion(s: Dictionary, control: Dictionary, player: Dictionary) -> void:
	var health: Dictionary = s.get("player_health", {})
	if health.is_empty() or int(health.stamina) > 0 or player_down(s): return
	if int(control.get("running_tick", -100)) < s.tick - 1: return
	health.winded = true
	health.exhausted = true
	control.running = false
	control.travel_run = false
	control.pending = {}
	s.player_path = []
	var direction: Array = control.get("last_dir", [0, 1])
	knockdown(s, control, player.cell, "exhaust", direction, "front")
	control.notice = "You are out of breath and collapse!"

## A bleeding wound (the player's, or a villager's cut) leaves drops on the ground until it is bandaged.
static func _bleed(s: Dictionary, player: Dictionary) -> void:
	for part in s.get("player_health", {}).get("parts", {}).values():
		if part.bleeding:
			add_blood(s, player.cell, [0, 0], 1)
			break
	for key in s.residents.keys():
		if int(s.residents[key].get("bleeding_until", 0)) > s.tick:
			add_blood(s, s.entities[key].cell, [0, 0], 1)

static func _advance_attack(sim: RefCounted, npc: Dictionary, attack: Dictionary, cell: Array, player: Dictionary) -> void:
	var s: Dictionary = sim.state
	if not attack.resolved and s.tick >= attack.impact:
		attack.resolved = true
		var near: bool = absi(player.cell[0] - cell[0]) <= 1 and absi(player.cell[1] - cell[1]) <= 1
		if near and not player_down(s):
			_hit_player(sim, npc, attack, player)
			npc.brawl.landed = true
	if s.tick >= attack.end:
		npc.attack = {}
		if str(npc.brawl.get("mode", "shove")) == "shove" and npc.brawl.get("landed", false):
			# Satisfied once the traveller is on the ground: they turn and walk away.
			npc.brawl = {}
			npc.anger = mini(int(npc.get("anger", 0)), 30)
			npc.status = "Walked away"
			npc.work_pause_until = s.tick + 40
		else:
			npc.brawl.next_attack = s.tick + 10 + sim.random_int("brawl", 0, 12)

static func _hit_player(sim: RefCounted, npc: Dictionary, attack: Dictionary, player: Dictionary) -> void:
	var s: Dictionary = sim.state
	var control: Dictionary = s.player_control
	var direction: Array = attack.direction
	control.impact_until = s.tick + 12
	control.impact_kind = attack.kind
	control.unarmed = {}
	if attack.kind == "punch":
		var part: String = PLAYER_PARTS[sim.random_int("brawl", 0, PLAYER_PARTS.size() - 1)]
		BodyHealth.injure(s, part, BEAT_DAMAGE, "bruise")
		if part == "head" and sim.random_int("brawl", 0, 99) < 40: add_blood(s, player.cell, direction, 1)
		event(s, "punch_hit", player.cell, direction)
		if BodyHealth.overall(s) < KO_HEALTH:
			knockdown(s, control, player.cell, "ko", direction)
			control.notice = "You are knocked out!"
		else:
			control.notice = "%s punches you." % s.entities[str(npc.id)].name
	else:
		var destination: Array = [player.cell[0] + attack.direction[0], player.cell[1] + attack.direction[1]]
		if World.walkable(s, destination): player.cell = destination
		knockdown(s, control, player.cell, "fall", direction)
		event(s, "shove_hit", player.cell, direction)
		control.notice = "%s shoves you to the ground." % s.entities[str(npc.id)].name
	s.player_path = []

## Gives a hand to someone who was shoved down: they start getting up right away.
static func help_up(s: Dictionary, npc: Dictionary) -> void:
	var knock: Dictionary = npc.get("knock", {})
	if knock.is_empty() or knock.kind != "fall" or s.tick >= int(knock.down_until): return
	knock.down_until = s.tick
	knock.rise_until = s.tick + RISE_TICKS
	npc.anger = maxi(0, int(npc.get("anger", 0)) - 20)
	event(s, "get_up", s.entities[str(npc.id)].cell)
