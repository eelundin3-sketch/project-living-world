extends RefCounted
const Names = preload("res://sim/entities/names.gd")
const Sheriff = preload("res://sim/law/sheriff.gd")
## Deterministic local encounters. All damage and projectile travel are simulated.
const World = preload("res://sim/world/world_db.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
const Jobs = preload("res://sim/jobs/job_board.gd")

static func initialize(s: Dictionary) -> void:
	if not s.has("local_combat"):
		s.local_combat = {"fighters": {}, "projectiles": [], "effects": []}

static func start_encounter(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	initialize(s)
	for fighter in s.local_combat.fighters.values():
		if fighter.side == "raider" and fighter.health > 0: return
	var player: Array = s.entities[str(s.player)].cell
	var spawned: Array[int] = []
	for offset in [[10, 0], [11, 2], [12, -2], [9, 3], [13, 0]]:
		if spawned.size() >= 2: break
		var cell: Array = [player[0] + offset[0], player[1] + offset[1]]
		if not World.walkable(s, cell) or World.inside_building(s, cell) != 0: continue
		var occupied: bool = false
		for entity in s.entities.values():
			if entity.get("kind", "") in ["resident", "player", "raider"] and entity.get("cell", []) == cell: occupied = true; break
		if occupied: continue
		var id := World.add_entity(sim, "raider", Names.generate(sim), cell, 0)
		Inventory.create(s, id, 10)
		s.local_combat.fighters[str(id)] = _fighter(id, "raider", "ranged" if spawned.is_empty() else "melee")
		spawned.append(id)
	if spawned.is_empty():
		sim.record("No clear ground nearby for an encounter.")
		return
	var defenders: int = 0
	for npc in Sheriff.defender_order(s):
		if defenders >= 3: break
		if npc.get("migration", {}).is_empty() and npc.health > 0 and s.entities.has(str(npc.id)):
			var cell: Array = s.entities[str(npc.id)].cell
			if absi(cell[0] - player[0]) + absi(cell[1] - player[1]) > 15: continue
			if npc.job != 0: Jobs.release(s, npc.job, "INTERRUPTED_FOR_DANGER")
			npc.goal = ""
			npc.path = []
			s.local_combat.fighters[str(npc.id)] = _fighter(npc.id, "defender", "ranged" if defenders == 0 else "melee")
			s.local_combat.fighters[str(npc.id)].health = npc.health
			defenders += 1
	sim.record("Road raiders approach; nearby residents defend the settlement.")

static func _fighter(id: int, side: String, weapon: String) -> Dictionary:
	return {"id": id, "side": side, "weapon": weapon, "health": 100, "target": 0,
		"next_attack": 0, "attack_tick": -1000, "hit_tick": -1000, "path": [], "path_target": [], "path_revision": -1, "retry": 0}

static func busy(s: Dictionary, id: int) -> bool:
	return s.get("local_combat", {}).get("fighters", {}).has(str(id))

static func update(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	if not s.has("local_combat"): return
	var combat: Dictionary = s.local_combat
	for projectile in combat.projectiles.duplicate():
		if s.tick < projectile.next_tick: continue
		projectile.next_tick = s.tick + 1
		projectile.index += 1
		if projectile.index >= projectile.cells.size():
			combat.projectiles.erase(projectile)
			continue
		var cell: Array = projectile.cells[projectile.index]
		if not World.walkable(s, cell):
			_effect(s, "impact", cell)
			combat.projectiles.erase(projectile)
			continue
		var hit: int = 0
		for candidate in combat.fighters.values():
			if candidate.id != projectile.owner and candidate.health > 0 and s.entities[str(candidate.id)].cell == cell:
				hit = candidate.id
				break
		if hit != 0:
			_damage(sim, hit, projectile.damage)
			combat.projectiles.erase(projectile)
		elif projectile.index == projectile.cells.size() - 1:
			_effect(s, "impact", cell)
			combat.projectiles.erase(projectile)
	while not combat.effects.is_empty() and combat.effects[0].tick + 12 < s.tick: combat.effects.pop_front()
	if s.tick % 2 != 0: return
	var living: Dictionary = {"raider": 0, "defender": 0}
	for fighter in combat.fighters.values():
		if fighter.health > 0 and s.entities.has(str(fighter.id)): living[fighter.side] += 1
	if living.raider == 0 or living.defender == 0:
		if living.raider == 0 and not combat.fighters.is_empty():
			for key in combat.fighters.keys():
				if combat.fighters[key].side == "defender": combat.fighters.erase(key)
		return
	for fighter in combat.fighters.values():
		if fighter.health <= 0 or not s.entities.has(str(fighter.id)) or s.tick < int(fighter.get("impact_until", 0)): continue
		var actor: Dictionary = s.entities[str(fighter.id)]
		var target: Dictionary = {}
		var distance: int = 99999
		for other in combat.fighters.values():
			if other.side == fighter.side or other.health <= 0 or not s.entities.has(str(other.id)): continue
			var p: Array = s.entities[str(other.id)].cell
			var d: int = absi(p[0] - actor.cell[0]) + absi(p[1] - actor.cell[1])
			if d < distance: target = other; distance = d
		if target.is_empty(): continue
		fighter.target = target.id
		var target_cell: Array = s.entities[str(target.id)].cell
		var line: Array = _line(actor.cell, target_cell)
		var clear: bool = true
		for i in range(1, line.size() - 1):
			if not World.walkable(s, line[i]): clear = false; break
		var attack_range: int = 7 if fighter.weapon == "ranged" else 1
		if distance <= attack_range and (fighter.weapon == "melee" or clear):
			if s.tick < fighter.next_attack: continue
			fighter.attack_tick = s.tick
			fighter.next_attack = s.tick + (25 if fighter.weapon == "ranged" else 18)
			if fighter.weapon == "ranged":
				combat.projectiles.append({"owner": fighter.id, "cells": line, "index": 0, "next_tick": s.tick + 1, "damage": 20})
				_effect(s, "muzzle", actor.cell)
			else: _damage(sim, target.id, 15)
		elif s.tick >= fighter.retry:
			if not fighter.path.is_empty() and fighter.path_target == target_cell and fighter.path_revision != s.world.nav_revision and Nav.still_clear(s, fighter.path):
				fighter.path_revision = s.world.nav_revision
			if fighter.path.is_empty() or fighter.path_target != target_cell or fighter.path_revision != s.world.nav_revision:
				fighter.path = []
				for offset in [[0, -1], [-1, 0], [1, 0], [0, 1]]:
					var goal: Array = [target_cell[0] + offset[0], target_cell[1] + offset[1]]
					if not World.walkable(s, goal): continue
					var route := Nav.request_path(s, actor.cell, goal)
					if route.ok and (fighter.path.is_empty() or route.path.size() < fighter.path.size()): fighter.path = route.path
				fighter.path_target = target_cell.duplicate()
				fighter.path_revision = s.world.nav_revision
				fighter.retry = s.tick + 10
			if not fighter.path.is_empty():
				var next: Array = fighter.path.pop_front()
				if World.walkable(s, next): actor.cell = next
		if s.residents.has(str(fighter.id)): s.residents[str(fighter.id)].status = "Defending against raiders"

static func _damage(sim: RefCounted, id: int, amount: int) -> void:
	var s: Dictionary = sim.state
	var fighter: Dictionary = s.local_combat.fighters[str(id)]
	fighter.health = maxi(0, fighter.health - amount)
	fighter.hit_tick = s.tick
	if s.residents.has(str(id)): s.residents[str(id)].health = fighter.health
	_effect(s, "hit", s.entities[str(id)].cell)
	if fighter.health == 0: sim.record(s.entities[str(id)].name + " is incapacitated.")

static func _effect(s: Dictionary, kind: String, cell: Array) -> void:
	s.local_combat.effects.append({"kind": kind, "cell": cell.duplicate(), "tick": s.tick})

static func _line(a: Array, b: Array) -> Array:
	var result: Array = []
	var x: int = a[0]; var y: int = a[1]
	var dx: int = absi(b[0] - x); var dy: int = absi(b[1] - y)
	var sx: int = 1 if x < b[0] else -1; var sy: int = 1 if y < b[1] else -1
	var error: int = dx - dy
	while true:
		result.append([x, y])
		if x == b[0] and y == b[1]: break
		var twice: int = 2 * error
		if twice > -dy: error -= dy; x += sx
		if twice < dx: error += dx; y += sy
	return result
