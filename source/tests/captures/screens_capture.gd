extends SceneTree
## Screenshots of the new screens: health window, knockout stage light, death screen, speech
## bubbles, the two-window loot screen, and a kick.
const Brawl = preload("res://sim/combat/brawl.gd")
const Speech = preload("res://sim/entities/speech.gd")
const Health = preload("res://sim/combat/body_health.gd")
const Looting = preload("res://sim/player/looting.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
func _initialize() -> void: call_deferred("run")
func shot(main: Node, name: String, frames: int = 5) -> void:
	printerr("STAGE ", name)
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
	s.tick = 14400 + 6200
	# 1. health window
	Health.injure(s, "left_forearm", 26, "cut")
	Health.injure(s, "head", 22, "bruise")
	Health.injure(s, "upper_torso", 18, "bruise")
	Health.injure(s, "right_shin", 14, "sprain")
	s.player_health.parts.right_shin.bandage = "dirty"
	main.player_panels.show_mode("health")
	main.player_panels.select_part("left_forearm")
	await shot(main, "health-minimal")
	main.player_panels.health_window.press_action("bandage")
	for t in range(14): sim.step()
	await shot(main, "health-minimal-bandaging")
	main.player_panels.show_mode("")
	for t in range(60): sim.step()
	s.player_health.treatment = {}
	# 2. speech bubbles in the square
	var talkers: Array = []
	for npc in s.residents.values():
		if npc.settlement == 1 and npc.id != s.player: talkers.append(npc)
	var store: Array = s.entities[str(s.settlements["1"].warehouse)].cell
	s.entities[str(s.player)].cell = [store[0] + 1, store[1] + 5]
	for i in range(talkers.size()):
		s.entities[str(talkers[i].id)].cell = [store[0] - 4 + i * 3, store[1] + 4 + (i % 2) * 3]
	Speech.say(sim, talkers[0].id, "angry_first")
	Speech.say(sim, talkers[1].id, "smalltalk")
	Speech.say(sim, talkers[2].id, "reply")
	Speech.say(sim, talkers[3].id, "greet_player")
	main.follow_player = true
	await shot(main, "speech-bubbles", 8)
	# 3. a kick on someone lying down
	var victim = talkers[0]
	var vcell: Array = s.entities[str(victim.id)].cell
	s.entities[str(s.player)].cell = [vcell[0] - 1, vcell[1]]
	Brawl.knockdown(s, victim, vcell, "ko", [1000, 0])
	for t in range(30): sim.step()
	sim.submit("player_strike", {"kind": "shove", "direction": [1000, 0]})
	for t in range(5): sim.step()
	await shot(main, "kick", 2)
	# 4. loot window with drag and drop
	for t in range(20): sim.step()
	Inventory.produce(s, victim.id, "food", 3)
	s.accounts[str(victim.id)] = 120
	Looting.open(s, victim.id)
	sim.step(); main.player_panels.refresh()
	await shot(main, "loot-grid", 4)
	main.player_panels.show_mode("")
	# 5. knocked out: black with a stage light on the body
	for t in range(40): sim.step()
	Brawl.knockdown(s, s.player_control, s.entities[str(s.player)].cell, "ko", [1000, 0])
	for t in range(40): sim.step()
	await shot(main, "knocked-out", 30)
	# 6. death screen
	for part in s.player_health.parts.values(): part.damage = 100
	for t in range(12): sim.step()
	await shot(main, "death-screen", 40)
	quit()
