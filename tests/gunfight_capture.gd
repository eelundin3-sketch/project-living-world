extends SceneTree
## A gunfight in Alder Hollow: recoil, villagers behind cover, sheriffs hiding and peeking.
const Sheriff = preload("res://sim/settlement/sheriff.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
func _initialize() -> void: call_deferred("run")
func shot(main: Node, name: String, frames: int = 8) -> void:
	main.refresh_view()
	for i in range(frames):
		main.get_node("WorldView").animate(0.05, false, 1)
		main._process(0.05)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/%s.png" % name)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); main.set_process(false)
	var sim = main.simulation; var s: Dictionary = sim.state
	s.tick = 14400 + 5400
	for npc in s.residents.values(): npc.sleeping = {}; npc.goal = ""; npc.path = []; npc.hunger = 0; npc.thirst = 0; npc.fatigue = 0
	var store: Array = s.entities[str(s.settlements["1"].warehouse)].cell
	s.entities[str(s.player)].cell = [store[0] - 2, store[1] + 10]
	Inventory.produce(s, s.player, "shotgun", 1); Inventory.produce(s, s.player, "shell", 20)
	s.shotgun.equipped = true; s.shotgun.loaded = 5
	var ids: Array = Sheriff.roster(s, 1)
	for i in range(ids.size()): s.entities[str(ids[i])].cell = [store[0] - 14 + i * 5, store[1] + 6]
	var folk := 0
	for npc in s.residents.values():
		if npc.settlement == 1 and npc.occupation != "Sheriff" and folk < 4:
			s.entities[str(npc.id)].cell = [store[0] + 4 + folk * 4, store[1] + 7]; folk += 1
	main.follow_player = true
	main.get_node("ObserverCamera").zoom = Vector2.ONE * 1.5
	sim.submit("shotgun_fire", {"direction": [1000, 0]}); sim.step()
	for t in range(3): sim.step()
	await shot(main, "gunfight-first-shot", 3)
	for t in range(80):
		if t % 38 == 0: s.shotgun.last_shot = -1000; s.shotgun.loaded = 3; sim.submit("shotgun_fire", {"direction": [1000, 0]})
		sim.step()
	await shot(main, "gunfight-cover", 6)
	# Wounds: shot legs and an arm.
	var Limbs = load("res://sim/player/limbs.gd")
	var victim: Dictionary = {}
	for npc in s.residents.values():
		if npc.settlement == 1 and npc.occupation != "Sheriff": victim = npc; break
	victim.fear = {}; victim.knock = {}
	Limbs.wound_npc(s, victim.id, "left_leg", 80); Limbs.wound_npc(s, victim.id, "right_leg", 80); Limbs.wound_npc(s, victim.id, "left_arm", 80)
	s.entities[str(victim.id)].cell = [store[0] - 2, store[1] + 7]
	var Brawl = load("res://sim/player/brawl.gd")
	Brawl.add_blood(s, [store[0] - 2, store[1] + 7], [1, 0], 2); Brawl.add_blood(s, [store[0] - 3, store[1] + 7], [1, 0], 2); Brawl.add_blood(s, [store[0] - 4, store[1] + 8], [1, 0], 1)
	victim.path = []
	await shot(main, "wounds-crawling", 6)
	quit()
