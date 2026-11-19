extends RefCounted
## Unarmed actions and impacts are simulation state, independent of rendering.
const Spatial = preload("res://sim/world/spatial.gd")
const World = preload("res://sim/world/world_db.gd")
const Jobs = preload("res://sim/jobs/job_board.gd")
const Health = preload("res://sim/combat/body_health.gd")
const Actions = preload("res://sim/player/player_actions.gd")
const Combat = preload("res://sim/combat/local_combat.gd")
const Brawl = preload("res://sim/combat/brawl.gd")
const Limbs = preload("res://sim/combat/limbs.gd")
const ACTION_TICKS: int = 10
const IMPACT_DELAY: int = 3
const REACTION_TICKS: int = 12
## Pressing punch again in time throws the next punch of the chain, in a different way.
const STYLES: Array[String] = ["straight", "cross", "hook", "uppercut", "haymaker"]
const COMBO_WINDOW := 14          # ticks after one punch ends in which the next continues the chain
const BUFFER_TICKS := 2           # a press this close to the end of a punch is accepted early
## Damage multiplier, how long the whole action lasts, and the front cone (dot product) each one hits.
const STYLE_DATA := {
	"straight": {"damage": 1.0, "ticks": 10, "cone": 0.70, "reach": 1.42},
	"cross": {"damage": 1.15, "ticks": 10, "cone": 0.70, "reach": 1.5},
	"hook": {"damage": 1.2, "ticks": 11, "cone": 0.35, "reach": 1.42},
	"uppercut": {"damage": 1.4, "ticks": 12, "cone": 0.70, "reach": 1.2},
	"haymaker": {"damage": 1.7, "ticks": 16, "cone": 0.70, "reach": 1.55}}

static func begin(s: Dictionary, kind: String, direction: Array) -> bool:
	if kind not in ["punch", "shove"] or direction.size() != 2 or not direction[0] is int or not direction[1] is int: return false
	if not s.has("player_control") or Health.incapacitated(s): return false
	if kind == "punch" and Limbs.arms_ok(s, s.player) == 0:
		s.player_control.notice = "Both your arms are useless."
		return false
	if Limbs.crawling(s, s.player):
		s.player_control.notice = "You cannot fight while crawling."
		return false
	if not s.player_health.get("treatment", {}).is_empty():
		s.player_health.notice = "Finish treatment before fighting."
		return false
	var control: Dictionary = s.player_control
	if s.tick < int(control.get("unarmed_cooldown", 0)) - (BUFFER_TICKS if kind == "punch" else 0): return false
	var dx: int = clampi(direction[0], -1000, 1000)
	var dy: int = clampi(direction[1], -1000, 1000)
	if dx == 0 and dy == 0: return false
	# A shove aimed at someone already on the ground becomes a kick.
	if kind == "shove" and downed_target(s, [dx, dy]) != 0: kind = "kick"
	var style := "straight"
	var length: int = ACTION_TICKS
	if kind == "punch":
		var here: Array = s.entities[str(s.player)].cell
		var last: Array = control.get("combo_cell", here)
		var step: int = int(control.get("combo", -1))
		var fresh: bool = s.tick - int(control.get("punch_end", -1000)) > COMBO_WINDOW or absi(here[0] - last[0]) + absi(here[1] - last[1]) > 1
		step = 0 if fresh else (step + 1) % STYLES.size()
		# With only one arm working the chain is just straight and cross.
		if Limbs.arms_ok(s, s.player) < 2: step = step % 2
		style = STYLES[step]
		length = int(STYLE_DATA[style].ticks)
		control.combo = step
		control.combo_cell = here.duplicate()
	Actions.stop(s)
	control.held_item = ""
	control.held_quantity = 0
	s.player_path = []
	control.unarmed_cooldown = s.tick + length
	control.punch_end = s.tick + length
	control.unarmed = {"kind": kind, "style": style, "direction": [dx, dy], "start": s.tick, "impact": s.tick + IMPACT_DELAY, "end": s.tick + length, "resolved": false}
	control.notice = "Punching." if kind != "punch" else ("%s." % style.capitalize())
	if kind == "shove": control.notice = "Shoving."
	if kind == "kick": control.notice = "Kicking."
	return true

static func update(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	var action: Dictionary = s.get("player_control", {}).get("unarmed", {})
	if action.is_empty(): return
	if not action.resolved and s.tick >= action.impact:
		action.resolved = true
		_resolve(sim, action)
	if s.tick >= action.end: s.player_control.unarmed = {}

## The nearest villager lying down (knocked out or shoved over, still alive) within reach and
## roughly in the direction aimed, or 0.
static func downed_target(s: Dictionary, direction: Array) -> int:
	var origin: Array = s.entities[str(s.player)].cell
	var aim := Vector2(direction[0], direction[1]).normalized()
	var best := 0
	var best_distance := 100.0
	for npc in s.get("residents", {}).values():
		if npc.health <= 0 or not Brawl.knocked(s, npc): continue
		var difference := Vector2(s.entities[str(npc.id)].cell[0] - origin[0], s.entities[str(npc.id)].cell[1] - origin[1])
		var distance: float = difference.length()
		if distance > 1.6 or (distance > 0.01 and difference.normalized().dot(aim) < 0.55): continue
		if distance < best_distance or (is_equal_approx(distance, best_distance) and npc.id < best):
			best = npc.id
			best_distance = distance
	return best

static func _resolve(sim: RefCounted, action: Dictionary) -> void:
	var s: Dictionary = sim.state
	if action.kind == "kick":
		var target: int = downed_target(s, action.direction)
		if target == 0:
			s.player_control.notice = "Nobody on the ground in reach."
			return
		var downed: Dictionary = s.residents[str(target)]
		Brawl.on_player_kick(sim, downed, s.entities[str(target)], action.direction)
		s.player_control.notice = "Kicked " + str(s.entities[str(target)].name) + (" to death." if downed.health <= 0 else ".")
		return
	var origin: Array = s.entities[str(s.player)].cell
	var direction := Vector2(action.direction[0], action.direction[1]).normalized()
	var best: int = 0
	var best_distance: float = 100.0
	for actor_key in Spatial.actor_keys(s):
		var entity: Dictionary = s.entities.get(actor_key, {})
		if entity.get("kind", "") not in ["resident", "raider"] or not entity.has("cell"): continue
		var npc: Dictionary = s.get("residents", {}).get(str(entity.id), {})
		var fighter: Dictionary = s.get("local_combat", {}).get("fighters", {}).get(str(entity.id), {})
		if not npc.is_empty() and (npc.health <= 0 or not npc.get("migration", {}).is_empty() or Brawl.knocked(s, npc)): continue
		if not fighter.is_empty() and fighter.health <= 0: continue
		var difference := Vector2(entity.cell[0] - origin[0], entity.cell[1] - origin[1])
		var distance: float = difference.length()
		var style_data: Dictionary = STYLE_DATA.get(str(action.get("style", "straight")), STYLE_DATA.straight) if action.kind == "punch" else STYLE_DATA.straight
		if distance > float(style_data.reach) or (distance > 0.01 and difference.normalized().dot(direction) < float(style_data.cone)): continue
		if not World.walkable(s, entity.cell): continue
		if difference.x != 0 and difference.y != 0 and not World.walkable(s, [origin[0] + int(difference.x), origin[1]]) and not World.walkable(s, [origin[0], origin[1] + int(difference.y)]): continue
		if distance < best_distance or (is_equal_approx(distance, best_distance) and (best == 0 or entity.id < best)):
			best = entity.id
			best_distance = distance
	if best == 0:
		s.player_control.notice = "No one in reach."
		return
	var victim: Dictionary = s.entities[str(best)]
	var npc: Dictionary = s.get("residents", {}).get(str(best), {})
	var fighter: Dictionary = s.get("local_combat", {}).get("fighters", {}).get(str(best), {})
	if not npc.is_empty() and fighter.is_empty():
		# A villager: anger, blood, knockdowns and retaliation are handled by the brawl module.
		npc.work_pause_until = maxi(int(npc.get("work_pause_until", 0)), s.tick + REACTION_TICKS)
		npc.impact_until = s.tick + REACTION_TICKS
		npc.impact_kind = action.kind
		Brawl.on_player_hit(sim, npc, victim, action.kind, action.direction, str(action.get("style", "straight")))
	elif not npc.is_empty():
		npc.impact_until = s.tick + REACTION_TICKS
		npc.impact_kind = action.kind
	if not fighter.is_empty(): fighter.impact_until = s.tick + REACTION_TICKS
	if action.kind == "punch":
		if not fighter.is_empty(): Combat._damage(sim, best, 10)
	else:
		var step: Array = [signi(action.direction[0]), 0] if absi(action.direction[0]) >= absi(action.direction[1]) else [0, signi(action.direction[1])]
		var destination: Array = [victim.cell[0] + step[0], victim.cell[1] + step[1]]
		var occupied: bool = false
		occupied = not Spatial.actors_at(s, destination).is_empty()
		if not occupied:
			for other in s.entities.values():
				if other.get("kind", "") == "caravan" and other.get("cell", []) == destination: occupied = true; break
		if not occupied and World.walkable(s, destination): World.move_record(s, victim, destination)
		if not fighter.is_empty(): fighter.path = []; fighter.path_revision = -1
	if not fighter.is_empty(): fighter.hit_tick = s.tick
	s.player_control.notice = ("Punched " if action.kind == "punch" else "Shoved ") + str(victim.name) + "."
	if action.kind == "punch" and str(action.get("style", "straight")) != "straight": s.player_control.notice = "%s hits %s." % [str(action.style).capitalize(), str(victim.name)]
