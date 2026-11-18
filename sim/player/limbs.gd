extends RefCounted
## Arms and legs for everyone, the player and villagers alike. Each limb is `ok`, `hurt` or
## `disabled`. A disabled limb stays disabled until it has healed: it switches off at DISABLED_AT
## damage and only comes back once the damage is below RECOVER_AT.
##   both legs disabled  -> crawl      one leg disabled -> limp (slow, no running)
##   an arm disabled     -> that hand is useless: no punching with it, no aiming or firing the
##                          two-handed shotgun, no carrying or looting with it
## The player's damage lives in `player_health.parts`; a villager's in `npc.wounds[limb]`.
const BodyHealth = preload("res://sim/player/body_health.gd")
const LIMB_PARTS := {
	"left_arm": ["left_upper_arm", "left_forearm", "left_hand"],
	"right_arm": ["right_upper_arm", "right_forearm", "right_hand"],
	"left_leg": ["left_thigh", "left_shin", "left_foot"],
	"right_leg": ["right_thigh", "right_shin", "right_foot"]}
const LIMBS: Array[String] = ["left_arm", "right_arm", "left_leg", "right_leg"]
const HURT_AT := 25
const DISABLED_AT := 60
const RECOVER_AT := 30
const NPC_HEAL_EVERY := 100       # ticks per point of a villager's natural healing

static func _flags(s: Dictionary) -> Dictionary:
	if not s.has("limbs"): s.limbs = {}
	return s.limbs

static func damage(s: Dictionary, id: int, limb: String) -> int:
	if id == int(s.get("player", -1)):
		if not s.has("player_health"): return 0
		var worst := 0
		for part in LIMB_PARTS[limb]: worst = maxi(worst, int(s.player_health.parts[part].damage))
		return worst
	return int(s.get("residents", {}).get(str(id), {}).get("wounds", {}).get(limb, 0))

static func disabled(s: Dictionary, id: int, limb: String) -> bool:
	return bool(s.get("limbs", {}).get(str(id), {}).get(limb, false))

static func state(s: Dictionary, id: int, limb: String) -> String:
	if disabled(s, id, limb): return "disabled"
	return "hurt" if damage(s, id, limb) >= HURT_AT else "ok"

static func legs_down(s: Dictionary, id: int) -> int:
	return (1 if disabled(s, id, "left_leg") else 0) + (1 if disabled(s, id, "right_leg") else 0)

## "walk", "limp" or "crawl".
static func mode(s: Dictionary, id: int) -> String:
	match legs_down(s, id):
		2: return "crawl"
		1: return "limp"
	return "walk"

static func crawling(s: Dictionary, id: int) -> bool:
	return mode(s, id) == "crawl"

## True when `side` ("left" or "right") has a working arm.
static func arm_ok(s: Dictionary, id: int, side: String) -> bool:
	return not disabled(s, id, side + "_arm")

static func arms_ok(s: Dictionary, id: int) -> int:
	return (1 if arm_ok(s, id, "left") else 0) + (1 if arm_ok(s, id, "right") else 0)

## Both hands are needed to hold up and fire the shotgun.
static func can_aim(s: Dictionary, id: int) -> bool:
	return arms_ok(s, id) == 2

## Ticks a villager or the player needs per cell moved: 2 walking, 4 limping, 12 crawling.
static func step_ticks(s: Dictionary, id: int) -> int:
	match mode(s, id):
		"crawl": return 12
		"limp": return 4
	return 2

## Adds wound damage to a limb of a villager (the player's goes through BodyHealth.injure).
static func wound_npc(s: Dictionary, id: int, limb: String, amount: int) -> void:
	var npc: Dictionary = s.get("residents", {}).get(str(id), {})
	if npc.is_empty() or not LIMB_PARTS.has(limb): return
	if not npc.has("wounds"): npc.wounds = {}
	npc.wounds[limb] = clampi(int(npc.wounds.get(limb, 0)) + amount, 0, 100)
	refresh(s, id)

## Applies the hysteresis rule to one person's limbs. Returns true if anything changed.
static func refresh(s: Dictionary, id: int) -> bool:
	var flags: Dictionary = _flags(s)
	var mine: Dictionary = flags.get(str(id), {})
	var changed := false
	for limb in LIMBS:
		var level := damage(s, id, limb)
		var was: bool = bool(mine.get(limb, false))
		var now: bool = level >= DISABLED_AT or (was and level >= RECOVER_AT)
		if now != was:
			changed = true
			if now: mine[limb] = true
			else: mine.erase(limb)
	if mine.is_empty(): flags.erase(str(id))
	else: flags[str(id)] = mine
	return changed

## Every 10 ticks: villagers heal slowly and everyone's flags follow their damage.
static func update(s: Dictionary) -> void:
	if s.tick % 10 != 0: return
	if s.has("player") and s.has("player_health"):
		var announced := disabled(s, s.player, "left_arm") or disabled(s, s.player, "right_arm") or legs_down(s, s.player) > 0
		refresh(s, s.player)
		var after := disabled(s, s.player, "left_arm") or disabled(s, s.player, "right_arm") or legs_down(s, s.player) > 0
		if announced and not after: s.player_control.notice = "Your limbs are working again."
	for key in s.get("residents", {}).keys():
		var npc: Dictionary = s.residents[key]
		if not npc.has("wounds"): continue
		if s.tick % NPC_HEAL_EVERY == 0:
			for limb in npc.wounds.keys():
				npc.wounds[limb] = maxi(0, int(npc.wounds[limb]) - 1)
				if int(npc.wounds[limb]) == 0: npc.wounds.erase(limb)
		refresh(s, int(key))
		if npc.wounds.is_empty(): npc.erase("wounds")

## What the player cannot do right now because of an arm, or "".
static func action_problem(s: Dictionary, kind: String) -> String:
	if not s.has("player"): return ""
	var id: int = int(s.player)
	var left := disabled(s, id, "left_arm")
	var right := disabled(s, id, "right_arm")
	match kind:
		"shotgun_fire", "shotgun_toggle", "shotgun_reload":
			if left or right: return "You cannot handle the shotgun with a useless arm."
		"loot_take", "loot_all", "loot_coins", "loot_strip", "loot_give", "take_item", "hold_item", "person_trade":
			if left and right: return "Both your arms are useless."
		"treat_body":
			if left and right: return "Both your arms are useless."
	return ""
