extends RefCounted
## Physical and emotional condition model shared by the player and residents.
## Everything is derived from authoritative state; the HUD only reads `levels()`.
const BodyHealth = preload("res://sim/combat/body_health.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")

## Severity thresholds (levels 1..4) for 0-100 gauges.
const GAUGE_STEPS: Array[int] = [35, 55, 75, 90]
const PAIN_STEPS: Array[int] = [8, 22, 42, 66]
const MOOD_STEPS: Array[int] = [60, 45, 30, 15]  # mood falls; lower is worse
const ORDER: Array[String] = ["bleeding", "pain", "hungry", "thirsty", "tired", "stressed", "unhappy", "wet", "cold"]

static func initialize(s: Dictionary) -> void:
	if not s.has("player") or not s.has("player_health") or s.has("player_needs"): return
	s.player_needs = {"hunger": 10, "thirst": 12, "fatigue": 5, "idle_ticks": 0, "stress": 0, "mood": 80}

## Adds thirst and mood to residents created before those needs existed.
static func upgrade(s: Dictionary) -> void:
	initialize(s)
	for npc in s.get("residents", {}).values():
		if not npc.has("thirst"): npc.thirst = clampi(int(npc.get("hunger", 10)) / 2, 0, 100)
		if not npc.has("mood"): npc.mood = 70

static func level_for(value: int, steps: Array[int], falling: bool = false) -> int:
	var level := 0
	for index in range(steps.size()):
		if (value <= steps[index]) if falling else (value >= steps[index]): level = index + 1
	return level

static func mood_value(hunger: int, thirst: int, fatigue: int, pain: int, stress: int, comfort: int = 0) -> int:
	return clampi(92 - (hunger + thirst + fatigue) / 5 - pain / 2 - stress / 3 + comfort, 0, 100)

static func weather_kind(s: Dictionary) -> String:
	return str(s.get("weather", {}).get("kind", "clear"))

static func is_night(s: Dictionary) -> bool:
	var minute: int = (s.tick / 10) % 1440
	return minute < 330 or minute >= 1230

static func bleeding_parts(s: Dictionary) -> int:
	var count := 0
	for part in s.get("player_health", {}).get("parts", {}).values():
		if part.bleeding: count += 1
	return count

static func indoors(s: Dictionary) -> bool:
	var cell: Array = s.entities[str(s.player)].cell
	for entity in s.entities.values():
		if entity.has("footprint"):
			var f: Array = entity.footprint
			if cell[0] >= f[0] and cell[1] >= f[1] and cell[0] < f[0] + f[2] and cell[1] < f[1] + f[3]: return true
	return false

## Player condition levels, 0 (absent) to 4 (severe), keyed by indicator id.
static func levels(s: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ORDER: result[key] = 0
	if not s.has("player_needs"): return result
	var needs: Dictionary = s.player_needs
	var pain: int = BodyHealth.pain(s) if s.has("player_health") else 0
	var bleeding: int = bleeding_parts(s)
	result.hungry = level_for(needs.hunger, GAUGE_STEPS)
	result.thirsty = level_for(needs.thirst, GAUGE_STEPS)
	result.tired = level_for(needs.fatigue, GAUGE_STEPS)
	result.pain = level_for(pain, PAIN_STEPS)
	result.bleeding = mini(4, bleeding + 1) if bleeding > 0 else 0
	result.stressed = level_for(needs.stress, [15, 35, 60, 85])
	result.unhappy = level_for(needs.mood, MOOD_STEPS, true)
	var outdoors: bool = not indoors(s)
	var weather: String = weather_kind(s)
	result.wet = 2 if outdoors and weather == "rain" else (1 if outdoors and weather == "fog" else 0)
	var cold := 0
	if outdoors and weather == "snow": cold += 2
	if is_night(s): cold += 1
	result.cold = mini(4, cold) if outdoors else 0
	return result

static func label(key: String, level: int) -> String:
	var names := {"bleeding": ["", "Bleeding", "Bleeding", "Heavy bleeding", "Severe bleeding"],
		"pain": ["", "Aching", "In pain", "Hurting badly", "Agony"],
		"hungry": ["", "Peckish", "Hungry", "Very hungry", "Starving"],
		"thirsty": ["", "A little thirsty", "Thirsty", "Very thirsty", "Parched"],
		"tired": ["", "Drowsy", "Tired", "Exhausted", "Near collapse"],
		"stressed": ["", "Uneasy", "Anxious", "Stressed", "Panicked"],
		"unhappy": ["", "Gloomy", "Unhappy", "Miserable", "Despairing"],
		"wet": ["", "Damp", "Soaked", "", ""],
		"cold": ["", "Chilly", "Cold", "Freezing", "Freezing"]}
	return names[key][clampi(level, 0, 4)]

static func hint(key: String) -> String:
	return {"bleeding": "Press H and bandage the wound.", "pain": "Treat injuries (H) or rest.",
		"hungry": "Press E to eat food from your inventory.", "thirsty": "Press Q to drink near a well barrel at a storehouse or lodge.",
		"tired": "Stand still to rest, ideally at home.", "stressed": "Get away from danger.",
		"unhappy": "Eat, drink, rest and heal to feel better.", "wet": "Step indoors.", "cold": "Step indoors."}.get(key, "")

## True when a drinking spot (storehouse or lodge barrel) is within three cells.
static func near_water(s: Dictionary) -> bool:
	var cell: Array = s.entities[str(s.player)].cell
	for town in s.get("settlements", {}).values():
		# The market-square well sits in front of each storehouse.
		var store: Array = s.entities[str(town.warehouse)].cell
		if absi(store[0] - cell[0]) <= 3 and absi(store[1] + 6 - cell[1]) <= 3: return true
	for entity in s.entities.values():
		if entity.get("kind", "") in ["warehouse", "home"]:
			var door: Array = entity.get("door", entity.cell)
			if absi(door[0] - cell[0]) <= 3 and absi(door[1] - cell[1]) <= 3: return true
	return false

static func eat(s: Dictionary) -> String:
	if not s.has("player_needs"): return ""
	if Inventory.amount(s, s.player, "food") < 1: return "You have no food to eat."
	if s.player_needs.hunger < 20: return "You are not hungry."
	Inventory.consume(s, s.player, "food", 1)
	s.player_needs.hunger = maxi(0, s.player_needs.hunger - 45)
	return "You eat. Hunger eases."

static func drink(s: Dictionary) -> String:
	if not s.has("player_needs"): return ""
	if not near_water(s): return "Stand beside a storehouse or lodge to drink from its barrel."
	if s.player_needs.thirst < 15: return "You are not thirsty."
	s.player_needs.thirst = maxi(0, s.player_needs.thirst - 60)
	return "You drink deeply."

## Advances player needs once per tick; gauges change every 100 ticks.
static func update(s: Dictionary) -> void:
	if not s.has("player_needs"): return
	var needs: Dictionary = s.player_needs
	var control: Dictionary = s.get("player_control", {})
	var moving: bool = s.tick < int(control.get("next_move", 0)) + 3
	needs.idle_ticks = 0 if moving else int(needs.idle_ticks) + 1
	# The player's gauges move more slowly than residents': roughly one meal and two drinks a day.
	# Prisoners are fed and watered (their gauges hold while they are in custody).
	var in_custody: bool = not control.get("jail", {}).is_empty()
	if s.tick % 250 == 0 and not in_custody: needs.hunger = mini(100, needs.hunger + 1)
	if s.tick % 150 == 0 and not in_custody: needs.thirst = mini(100, needs.thirst + 1)
	if s.tick % 200 == 0:
		var tired_step: int = 2 if control.get("running", false) else 1
		if needs.idle_ticks > 60: needs.fatigue = maxi(0, needs.fatigue - 3)
		else: needs.fatigue = mini(100, needs.fatigue + tired_step)
	# Stress rises near armed hostiles or fresh injuries and fades afterwards.
	if s.tick % 10 == 0:
		var threat := 0
		var cell: Array = s.entities[str(s.player)].cell
		for entity in s.entities.values():
			if entity.get("kind", "") == "raider":
				var distance: int = absi(entity.cell[0] - cell[0]) + absi(entity.cell[1] - cell[1])
				if distance < 14: threat = maxi(threat, 100 - distance * 6)
		if bleeding_parts(s) > 0: threat = maxi(threat, 45)
		needs.stress = clampi(needs.stress + (maxi(1, threat / 20) if threat > needs.stress else -1), 0, 100)
		var pain: int = BodyHealth.pain(s) if s.has("player_health") else 0
		needs.mood = mood_value(needs.hunger, needs.thirst, needs.fatigue, pain, needs.stress, 6 if indoors(s) else 0)
