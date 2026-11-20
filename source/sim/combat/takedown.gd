extends RefCounted
## Silent takedowns. Crouched, right behind someone who hasn't noticed you, you can kill them
## without a sound, or just knock them out. No gunshot, no shout: nobody hears it. Whoever SEES it
## (awake, in line of sight, a sheriff included) knows, and runs to tell (witness_reports.gd); if
## nobody does, nobody knows who did it.
const Brawl = preload("res://sim/combat/brawl.gd")

## Why a takedown isn't possible right now ("" when it is).
static func problem(s: Dictionary, npc: Dictionary) -> String:
	if npc.is_empty() or int(npc.get("health", 0)) <= 0 or Brawl.knocked(s, npc): return "They're already down."
	var pc: Dictionary = s.get("player_control", {})
	if not bool(pc.get("crouching", false)): return "Crouch (C) and creep up behind them."
	var me: Array = s.entities[str(s.player)].cell
	var them: Array = s.entities[str(npc.id)].cell
	if maxi(absi(me[0] - them[0]), absi(me[1] - them[1])) > 1: return "Get right behind them."
	if not aware_of_player(s, npc).is_empty(): return aware_of_player(s, npc)
	return ""

## Whether `npc` is paying attention to the player ("" when they aren't): anyone already after
## you, frightened, arresting or reporting is alert, and anyone walking toward you sees you coming.
static func aware_of_player(s: Dictionary, npc: Dictionary) -> String:
	if not npc.get("brawl", {}).is_empty() or not npc.get("arrest", {}).is_empty(): return "They're watching you."
	if not npc.get("fear", {}).is_empty() or not npc.get("reporting", {}).is_empty(): return "They're on their guard."
	if not npc.get("sleeping", {}).is_empty(): return ""   # asleep: as unaware as it gets
	var path: Array = npc.get("path", [])
	if path.is_empty(): return ""   # standing at their work, back half-turned
	var them: Array = s.entities[str(npc.id)].cell
	var me: Array = s.entities[str(s.player)].cell
	var heading := Vector2(path[0][0] - them[0], path[0][1] - them[1])
	var to_me := Vector2(me[0] - them[0], me[1] - them[1])
	if heading.length() > 0.0 and heading.normalized().dot(to_me.normalized()) > 0.3: return "They'd see you coming."
	return ""

## `lethal`: a killing; otherwise they're knocked out cold. Returns the notice.
static func perform(sim: RefCounted, npc: Dictionary, lethal: bool) -> String:
	var s: Dictionary = sim.state
	var why: String = problem(s, npc)
	if not why.is_empty(): return why
	var name: String = String(s.entities[str(npc.id)].name)
	var town: int = int(npc.settlement)
	var Law = load("res://sim/law/law.gd")
	if lethal:
		Brawl.kill(sim, npc, "killed silently")
		Law.crime(s, town, "murder", int(npc.id), true)
		return "You kill %s without a sound." % name
	Brawl.knockdown(s, npc, s.entities[str(npc.id)].cell, "ko")
	Law.crime(s, town, "assault", int(npc.id), true)
	return "You choke %s out. They'll come round in a while." % name
