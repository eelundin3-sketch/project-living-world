extends SceneTree
## Gunshot wounds: blood, falling over, limping, crawling, and arms that stop working until healed.
const Sim = preload("res://sim/core/simulation.gd")
const Limbs = preload("res://sim/player/limbs.gd")
const Wounds = preload("res://sim/player/wounds.gd")
const Brawl = preload("res://sim/player/brawl.gd")
const BodyHealth = preload("res://sim/player/body_health.gd")
const Shotgun = preload("res://sim/player/shotgun.gd")
const Unarmed = preload("res://sim/player/unarmed.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)
func villager(s: Dictionary) -> Dictionary:
	for npc in s.residents.values():
		if npc.occupation != "Sheriff": return npc
	return {}
func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	s.tick = 14400 + 5400
	var npc: Dictionary = villager(s)
	var id: int = npc.id
	var cell: Array = s.entities[str(id)].cell
	# A body hit leaves blood and the person goes down.
	var blood_before: int = s.brawl.blood.size()
	Wounds.shoot(sim, id, cell, [1000, 0])
	check(s.brawl.blood.size() > blood_before, "A hit leaves a blood stain")
	var hit: Dictionary = Wounds.pick(sim)
	check(hit.area in ["leg", "arm", "torso", "head"], "A hit picks a body part")
	# Legs: one disabled is a limp, both is a crawl; they heal back.
	npc.knock = {}
	Limbs.wound_npc(s, id, "left_leg", 70)
	check(Limbs.disabled(s, id, "left_leg") and Limbs.mode(s, id) == "limp" and Limbs.step_ticks(s, id) == 4, "One badly damaged leg means a limp")
	Limbs.wound_npc(s, id, "right_leg", 70)
	check(Limbs.crawling(s, id) and Limbs.step_ticks(s, id) == 12, "Both legs badly damaged means crawling")
	# Healing: still disabled until below the recovery line.
	npc.wounds.left_leg = 45
	Limbs.refresh(s, id)
	check(Limbs.disabled(s, id, "left_leg"), "A leg stays disabled until it has healed enough")
	npc.wounds.left_leg = 20
	Limbs.refresh(s, id)
	check(not Limbs.disabled(s, id, "left_leg") and Limbs.mode(s, id) == "limp", "It works again once healed")
	# A crawler covers ground slowly.
	npc.wounds.right_leg = 80; npc.wounds.left_leg = 80; Limbs.refresh(s, id)
	npc.knock = {}; npc.goal = ""; npc.job = 0
	var start: Array = s.entities[str(id)].cell.duplicate()
	var far: Array = [start[0] + 30, start[1]]
	var Nav = load("res://sim/movement/navigation.gd")
	var route = Nav.request_path(s, start, far)
	npc.path = route.path if route.ok else []
	npc.goal = "eat"; npc.nav_revision = s.world.nav_revision
	for t in range(120): sim.step()
	var moved: int = absi(s.entities[str(id)].cell[0] - start[0]) + absi(s.entities[str(id)].cell[1] - start[1])
	check(moved <= 12, "A crawler moves slowly (%d cells in 12 seconds)" % moved)
	# The player: arms.
	var pc: Dictionary = s.player_control
	check(Limbs.arms_ok(s, s.player) == 2 and Limbs.can_aim(s, s.player), "Healthy arms can aim")
	for part in ["left_upper_arm"]: BodyHealth.injure(s, part, 60, "cut")
	BodyHealth.injure(s, "left_upper_arm", 20, "cut")
	Limbs.refresh(s, s.player)
	check(Limbs.disabled(s, s.player, "left_arm") and not Limbs.can_aim(s, s.player), "A badly damaged arm cannot hold the shotgun up")
	Inventory.produce(s, s.player, "shotgun", 1)
	sim.submit("shotgun_toggle"); sim.step()
	check(not s.shotgun.equipped and str(pc.notice).contains("arm"), "The shotgun cannot be readied with a useless arm: " + str(pc.notice))
	check(Unarmed.begin(s, "punch", [1000, 0]), "The other hand can still punch")
	pc.unarmed = {}; pc.unarmed_cooldown = 0
	BodyHealth.injure(s, "right_upper_arm", 60, "cut"); BodyHealth.injure(s, "right_upper_arm", 20, "cut"); Limbs.refresh(s, s.player)
	check(not Unarmed.begin(s, "punch", [1000, 0]), "With both arms useless there is no punching")
	# The arm heals: damage goes down, then the flag clears.
	for part in s.player_health.parts.values(): part.damage = 10; part.wound = "none"; part.bleeding = false
	Limbs.refresh(s, s.player)
	check(Limbs.arms_ok(s, s.player) == 2, "The arms work again after healing")
	# The player's legs: crawl speed.
	for part in s.player_health.parts.values(): part.damage = 0
	s.player_health.parts.left_thigh.damage = 80
	s.player_health.parts.right_shin.damage = 80
	Limbs.refresh(s, s.player)
	check(Limbs.crawling(s, s.player), "The player with both legs gone crawls")
	pc.knock = {}
	s.entities[str(s.player)].cell = [60, 60]; pc.next_move = 0
	sim.submit("move_player", {"direction": [1, 0], "run": true}); sim.step()
	var first: int = int(pc.next_move) - s.tick
	check(first >= 11, "A crawl step takes about 1.2 seconds (%d ticks)" % first)
	var copy := Sim.new(); copy.restore(sim.snapshot())
	check(copy.state_hash() == sim.state_hash(), "Wounds survive a reload")
	print("Wounds: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
