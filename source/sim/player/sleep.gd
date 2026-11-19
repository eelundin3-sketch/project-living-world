extends RefCounted
## The player sleeping in a bed. Click a bed and choose Sleep: the player walks to it, lies down
## and rests far faster than standing idle. They wake when rested, at six in the morning, when
## hurt, or as soon as they do anything. The interface runs the clock fast while they sleep
## (that is view state; the simulation only sees ticks).
const World = preload("res://sim/world/world_db.gd")
const Brawl = preload("res://sim/combat/brawl.gd")
const Law = preload("res://sim/law/law.gd")
const DAY_TICKS := 14400
const HOUR_TICKS := 600
const RECOVER_EVERY := 30   # ticks per point of tiredness while asleep: exhausted to rested in about five hours
const WAKE_HOUR := 6
const TIRED_ENOUGH := 10    # below this there is no sleep to be had

static func asleep(s: Dictionary) -> bool:
	return not s.get("player_control", {}).get("sleeping", {}).is_empty()

static func bed(s: Dictionary, building_id: int, index: int) -> Dictionary:
	var building: Dictionary = s.entities.get(str(building_id), {})
	var items: Array = building.get("furniture", [])
	if index < 0 or index >= items.size() or items[index].kind != "bed": return {}
	return items[index]

## Why the player cannot sleep in this bed right now ("" when they can).
static func problem(s: Dictionary, building_id: int, index: int) -> String:
	var item := bed(s, building_id, index)
	if item.is_empty(): return "That is not a bed."
	for npc in s.get("residents", {}).values():
		if npc.get("sleeping", {}).get("bed_rect", []) == item.rect: return "Someone is already asleep in it."
	if int(s.get("player_needs", {}).get("fatigue", 0)) < TIRED_ENOUGH: return "You are not tired."
	return ""

## Lie down in the bed (the player has walked up to it).
static func lie_down(s: Dictionary, building_id: int, index: int) -> void:
	var pc: Dictionary = s.player_control
	var reason := problem(s, building_id, index)
	if not reason.is_empty():
		pc.notice = reason
		return
	var item := bed(s, building_id, index)
	s.player_path = []
	pc.pending = {}
	pc.sleeping = {"building": building_id, "index": index, "bed_rect": item.rect.duplicate(), "rot": int(item.get("rot", 0)), "since": s.tick}
	pc.notice = "You lie down and close your eyes."

static func wake(s: Dictionary, notice: String) -> void:
	if not asleep(s): return
	s.player_control.sleeping = {}
	s.player_control.notice = notice

## Every tick: rest, and wake up when it is time.
static func update(s: Dictionary) -> void:
	if not asleep(s): return
	var needs: Dictionary = s.get("player_needs", {})
	var pc: Dictionary = s.player_control
	if s.tick % RECOVER_EVERY == 0 and not needs.is_empty(): needs.fatigue = maxi(0, int(needs.fatigue) - 1)
	if Brawl.player_down(s) or Law.restrained(s) or int(pc.get("impact_until", 0)) > s.tick:
		wake(s, "You are woken roughly!")
	elif not needs.is_empty() and int(needs.fatigue) == 0:
		wake(s, "You wake up rested.")
	elif s.tick % DAY_TICKS == WAKE_HOUR * HOUR_TICKS and s.tick - int(pc.sleeping.since) > HOUR_TICKS:
		wake(s, "Morning. You get up.")
