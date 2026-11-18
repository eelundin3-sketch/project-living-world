extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Combat = preload("res://sim/combat/local_combat.gd")
const World = preload("res://sim/world/world_db.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
const Save = preload("res://sim/persistence/save_manager.gd")
const Motion = preload("res://view/actors/animation_director.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void:
	var sim := Sim.new(400)
	sim.start_game()
	sim.submit("demo_encounter")
	sim.step()
	var s: Dictionary = sim.state
	var combat: Dictionary = s.local_combat
	check(combat.fighters.size() >= 3, "Encounter creates raiders and defenders")
	var saw_attack := false
	var saw_projectile := false
	var saw_damage := false
	var saw_animation := false
	for tick in range(500):
		sim.step()
		for shot in combat.projectiles:
			saw_projectile = true
			check(World.walkable(s, shot.cells[shot.index]), "Projectile never remains in a blocked cell")
		for fighter in combat.fighters.values():
			if fighter.attack_tick > 0: saw_attack = true
			if fighter.health < 100: saw_damage = true
			var action: String = Motion.action_for(s, s.entities[str(fighter.id)]).action
			if action in ["shoot", "melee", "hit", "down"]: saw_animation = true
			if s.entities.has(str(fighter.id)): check(World.walkable(s, s.entities[str(fighter.id)].cell), "Fighters do not enter walls")
		if tick == 60:
			var path := OS.get_temp_dir().path_join("lw-combat-test.save")
			check(Save.save_state(sim, path).ok, "Encounter can be saved")
			var restored := Sim.new()
			check(Save.load_into(restored, path).ok and restored.state_hash() == sim.state_hash(), "Encounter resumes from the same simulation state")
	check(saw_attack and saw_projectile and saw_damage and saw_animation, "Attacks drive projectiles, damage and combat poses")
	check(Checks.validate(s).is_empty(), "Encounter preserves material and job invariants")
	var wall_cell: Array = [5, 5]
	World.apply_mutation(s, wall_cell, true)
	combat.projectiles.append({"owner": 0, "cells": [[4, 5], wall_cell, [6, 5]], "index": 0, "next_tick": s.tick + 1, "damage": 20})
	s.tick += 1
	Combat.update(sim)
	check(combat.projectiles.is_empty() and combat.effects[-1].kind == "impact" and combat.effects[-1].cell == wall_cell, "Wall stops a projectile and produces impact feedback")
	print("Local combat: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
