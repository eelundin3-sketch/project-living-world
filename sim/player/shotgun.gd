extends RefCounted
## Pump shotgun: ready/stow, shell-by-shell reloading, a spread of simulated pellets
## and the surface each pellet strikes. Everything is tick-based and deterministic;
## the view only reads `state.shotgun` to draw recoil, blasts and impact effects.
const World = preload("res://sim/world/world_db.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Wounds = preload("res://sim/player/wounds.gd")
const CAPACITY := 5
const PELLETS := 7
const PELLET_DAMAGE := 9
const RANGE_CELLS := 9
const COOLDOWN_TICKS := 18
const RELOAD_TICKS_PER_SHELL := 12
const SPEED_CELLS_PER_TICK := 2
const EFFECT_TICKS := 14
const BLOOM_PER_SHOT := 220       # spread grows with every shot (thousandths) ...
const BLOOM_MAX := 900
const BLOOM_DECAY := 25           # ... and settles by this much each tick
const SPREAD := 0.17
const Brawl = preload("res://sim/player/brawl.gd")

static func initialize(s: Dictionary) -> void:
	if not s.has("shotgun"):
		s.shotgun = {"equipped": false, "loaded": 0, "reloading": false, "reload_next": 0, "last_shot": -1000, "pellets": [], "effects": [], "kicks": 0, "bloom": 0, "last_dir": [0, 1000]}

static func owns(s: Dictionary) -> bool:
	return Inventory.amount(s, s.player, "shotgun") > 0

## Raise or lower the weapon. Lowered, it hangs on the character's back.
static func toggle(s: Dictionary) -> String:
	if not owns(s): return "You do not have a shotgun. The sheriff's office rack stores them."
	s.shotgun.equipped = not s.shotgun.equipped
	if not s.shotgun.equipped: s.shotgun.reloading = false
	return "Shotgun ready. R reloads, aim with the right mouse and click to fire." if s.shotgun.equipped else "Shotgun slung on your back."

static func start_reload(s: Dictionary) -> String:
	var gun: Dictionary = s.shotgun
	if not gun.equipped: return "Ready the shotgun first (its hotbar key)."
	if gun.loaded >= CAPACITY: return "The shotgun is full."
	if Inventory.amount(s, s.player, "shell") < 1: return "You have no shells."
	gun.reloading = true
	gun.reload_next = s.tick + RELOAD_TICKS_PER_SHELL
	return "Loading shells."

static func can_fire(s: Dictionary) -> bool:
	var gun: Dictionary = s.get("shotgun", {})
	return not gun.is_empty() and gun.equipped and gun.loaded > 0 and s.tick - int(gun.last_shot) >= COOLDOWN_TICKS

## Fires one blast. `direction` is a unit vector in thousandths (as the strike command uses).
static func fire(sim: RefCounted, direction: Array) -> bool:
	var s: Dictionary = sim.state
	if not can_fire(s) or direction.size() != 2: return false
	var gun: Dictionary = s.shotgun
	var origin: Array = load("res://sim/player/cover.gd").eye_cell(s).duplicate()   # leaning out of cover, the shot leaves from the corner
	var base: float = Vector2(direction[0], direction[1]).angle()
	gun.loaded -= 1
	gun.reloading = false  # firing interrupts loading, as with a pump gun
	gun.last_shot = s.tick
	gun.kicks += 1
	gun.bloom = mini(BLOOM_MAX, int(gun.get("bloom", 0)) + BLOOM_PER_SHOT)
	gun.last_dir = [int(direction[0]), int(direction[1])]
	Brawl.event(s, "gunshot", origin, gun.last_dir)
	for index in range(PELLETS):
		var spread: float = (float(sim.random_int("shotgun", -1000, 1000)) / 1000.0) * SPREAD * (1.0 + 1.5 * float(gun.get("bloom", 0)) / 1000.0)
		var angle: float = base + spread
		var reach: float = RANGE_CELLS - float(sim.random_int("shotgun", 0, 200)) / 100.0
		gun.pellets.append({"x": float(origin[0]) + 0.5 * cos(base), "y": float(origin[1]) + 0.5 * sin(base), "dx": cos(angle), "dy": sin(angle), "left": reach, "owner": s.player})
	_effect(s, "blast", origin, [roundi(cos(base) * 1000.0), roundi(sin(base) * 1000.0)])
	return true

static func _effect(s: Dictionary, kind: String, cell: Array, dir: Array = [0, 0]) -> void:
	s.shotgun.effects.append({"kind": kind, "cell": cell.duplicate(), "tick": s.tick, "dir": dir.duplicate()})
	if s.shotgun.effects.size() > 80: s.shotgun.effects.pop_front()

## What a pellet strikes at `cell`: "" means open air.
static func surface_at(s: Dictionary, cell: Array, owner: int) -> String:
	var key := World.cell_key(cell)
	for entity in s.entities.values():
		if entity.get("cell", []) == cell and entity.id != owner:
			if entity.kind in ["resident", "raider", "player"]: return "body"
			if entity.kind == "tree": return "tree"
	if s.world.get("building_walls", {}).has(key): return "wall"
	if s.world.get("fixture_cells", {}).has(key): return "wood"
	if s.world.blocked.has(key): return "stone"
	return ""

static func update(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	if not s.has("shotgun"): return
	var gun: Dictionary = s.shotgun
	if int(gun.get("bloom", 0)) > 0: gun.bloom = maxi(0, int(gun.bloom) - BLOOM_DECAY)
	while not gun.effects.is_empty() and s.tick - int(gun.effects[0].tick) > EFFECT_TICKS: gun.effects.pop_front()
	if gun.reloading and s.tick >= gun.reload_next:
		if gun.loaded < CAPACITY and Inventory.consume(s, s.player, "shell", 1):
			gun.loaded += 1
			gun.reload_next = s.tick + RELOAD_TICKS_PER_SHELL
		if gun.loaded >= CAPACITY or Inventory.amount(s, s.player, "shell") < 1: gun.reloading = false
	var live: Array = []
	for pellet in gun.pellets:
		var alive := true
		for step in range(SPEED_CELLS_PER_TICK):
			if pellet.left <= 0.0: alive = false; break
			pellet.x += pellet.dx * 0.5
			pellet.y += pellet.dy * 0.5
			pellet.left -= 0.5
			var cell: Array = [roundi(pellet.x), roundi(pellet.y)]
			var bounds: Array = s.world.get("bounds", [0, 0, 128, 96])
			if cell[0] < bounds[0] or cell[1] < bounds[1] or cell[0] >= bounds[2] or cell[1] >= bounds[3]: alive = false; break
			var surface := surface_at(s, cell, pellet.owner)
			if surface != "":
				_strike(sim, surface, cell, pellet)
				alive = false
				break
		if alive and pellet.left <= 0.0:
			_effect(s, "ground", [roundi(pellet.x), roundi(pellet.y)], [roundi(pellet.dx * 1000.0), roundi(pellet.dy * 1000.0)])
			alive = false
		if alive: live.append(pellet)
	gun.pellets = live

static func _strike(sim: RefCounted, surface: String, cell: Array, pellet: Dictionary) -> void:
	var s: Dictionary = sim.state
	var dir: Array = [roundi(pellet.dx * 1000.0), roundi(pellet.dy * 1000.0)]
	_effect(s, {"body": "blood", "tree": "bark", "wall": "wall", "wood": "wood", "stone": "spark"}[surface], cell, dir)
	if surface != "body": return
	for entity in s.entities.values():
		if entity.get("cell", []) == cell and entity.kind in ["resident", "raider", "player"]:
			var key := str(entity.id)
			var was_alive: bool = not s.residents.has(key) or s.residents[key].health > 0
			if s.residents.has(key) or entity.kind == "player":
				Wounds.shoot(sim, int(entity.id), cell, dir)
			var fighters: Dictionary = s.get("local_combat", {}).get("fighters", {})
			if fighters.has(key):
				fighters[key].health = maxi(0, int(fighters[key].health) - PELLET_DAMAGE)
				fighters[key].hit_tick = s.tick
			if s.residents.has(key) and was_alive and s.residents[key].health == 0:
				sim.record(entity.name + " was shot and is incapacitated.")
			break
