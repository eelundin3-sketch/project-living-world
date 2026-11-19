extends RefCounted
## How the player looks. Hair and beard grow by the day; clothes get dusty outdoors and at work,
## muddy on wet roads, bloody from wounds and from carrying the dead, and soaked in the rain.
## People react: a filthy or bloodied stranger pays more and gets cold looks (sheriffs keep an
## eye on you); a clean, shaved, fully dressed one pays a little less and haggles better. Wash at
## a well, pay for a shave at the storehouse, change your clothes. Integer values 0-100.
const PlayerStatus = preload("res://sim/player/player_status.gd")
const DAY := 14400
const SHAVE_COST := 3

static func of(s: Dictionary) -> Dictionary:
	var look: Dictionary = PlayerStatus.part(s, "look", {})
	for key in ["hair", "beard", "dirt", "blood", "wet"]:
		if not look.has(key): look[key] = 0
	return look

## Every 100 ticks (and once a day for the hair).
static func update(s: Dictionary) -> void:
	if not s.has("player_control") or s.tick % 100 != 0: return
	var look: Dictionary = of(s)
	if s.tick % DAY == 0:
		look.hair = mini(100, int(look.hair) + 1)
		look.beard = mini(100, int(look.beard) + 3)
	var Needs = load("res://sim/entities/needs.gd")
	var outdoors: bool = not Needs.indoors(s)
	var raining: bool = Needs.weather_kind(s) == "rain"
	var pc: Dictionary = s.player_control
	if outdoors and s.tick % 300 == 0: look.dirt = mini(100, int(look.dirt) + 1)
	if not pc.get("work", {}).is_empty(): look.dirt = mini(100, int(look.dirt) + 1)
	if outdoors and raining and load("res://sim/movement/pace.gd").bonus(s, s.entities[str(s.player)].cell) > 0:
		look.dirt = mini(100, int(look.dirt) + 2)   # mud on the roads
	if outdoors and raining: look.wet = mini(100, int(look.wet) + 10)
	else: look.wet = maxi(0, int(look.wet) - (5 if not outdoors else 2))

static func bloodied(s: Dictionary, amount: int) -> void:
	var look: Dictionary = of(s)
	look.blood = mini(100, int(look.blood) + amount)

## -100..30: how presentable you are.
static func score(s: Dictionary) -> int:
	var look: Dictionary = of(s)
	var worn: Dictionary = load("res://sim/entities/outfits.gd").worn(s, int(s.player))
	var dressed: bool = ["hat", "vest", "shirt", "pants", "boots"].all(func(slot): return not str(worn.get(slot, "")).is_empty())
	return clampi(20 - int(look.dirt) / 2 - int(look.blood) - (10 if int(look.beard) > 70 else 0) + (10 if dressed else 0), -100, 30)

static func label(s: Dictionary) -> String:
	var value: int = score(s)
	if value <= -40: return "filthy" if int(of(s).blood) < 30 else "bloodied"
	if value < 0: return "scruffy"
	if value >= 30: return "well turned out"
	return "presentable"

## Price change (percent) a keeper puts on you for how you look.
static func price_pct(s: Dictionary) -> int:
	var value: int = score(s)
	return 10 if value <= -40 else (-5 if value >= 30 else 0)

static func wash(s: Dictionary) -> String:
	var look: Dictionary = of(s)
	look.dirt = 0
	look.blood = 0
	look.wet = 60   # you come up dripping
	return "You wash at the well: clean, if wet."

static func shave(s: Dictionary) -> String:
	var town: Dictionary = {}
	var cell: Array = s.entities[str(s.player)].cell
	for candidate in s.get("settlements", {}).values():
		var store: Array = s.entities[str(candidate.warehouse)].cell
		if absi(store[0] - cell[0]) + absi(store[1] - cell[1]) <= 12: town = candidate
	if town.is_empty(): return "There's nobody to shave you out here."
	if int(s.accounts.get(str(s.player), 0)) < SHAVE_COST: return "A shave and haircut costs %d coins." % SHAVE_COST
	s.accounts[str(s.player)] -= SHAVE_COST
	s.accounts[str(town.warehouse)] = int(s.accounts.get(str(town.warehouse), 0)) + SHAVE_COST
	var look: Dictionary = of(s)
	look.beard = 0
	look.hair = 0
	return "A shave and a haircut, %d coins. You look like a new man." % SHAVE_COST
