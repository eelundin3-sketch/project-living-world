extends SceneTree
## Arrest animations (hands up, sheriff aiming, cuffing, cuffed, escort) and in-game shots of a
## standoff, an escort and the jail cell.
const Character = preload("res://view/actors/drawn_character.gd")
const Outfits = preload("res://sim/entities/outfits.gd")
const Law = preload("res://sim/law/law.gd")
func _initialize() -> void: call_deferred("run")
func put(holder: Node, at: Vector2, pose: Dictionary, player: bool) -> void:
	var f := Character.new(); holder.add_child(f); f.setup(0 if player else 5, player, false); f.scale = Vector2.ONE * 1.25
	pose.position = at
	if not pose.has("moving"): pose.moving = false
	if not player: pose.outfit = Outfits.SHERIFF
	f.set_pose(pose)
func shot(main: Node, name: String, frames: int = 6) -> void:
	main.refresh_view()
	for i in range(frames):
		main.get_node("WorldView").animate(0.05, false, 1)
		main._process(0.05)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/%s.png" % name)
func run() -> void:
	root.size = Vector2i(1280, 860)
	var holder := Node2D.new(); root.add_child(holder)
	var bg := ColorRect.new(); bg.color = Color("a8905f"); bg.size = Vector2(1280, 860); holder.add_child(bg)
	var rows := [
		["hands up", true, "surrender", [PI / 2.0, PI / 4.0, 0.0]],
		["cuffed", true, "cuffed", [PI / 2.0, 0.0, -PI / 2.0]],
		["sheriff aims", false, "aim", [PI / 2.0, PI / 4.0, 0.0]],
		["cuffing", false, "cuff", [PI / 2.0, 0.0, PI]],
		["escort", false, "escort", [PI / 2.0, 0.0, -PI / 2.0]],
		["search", false, "search", [PI / 2.0, 0.0, -PI / 2.0]]]
	for r in range(rows.size()):
		var label := Label.new(); label.text = rows[r][0]; label.position = Vector2(10, 40 + r * 116); label.add_theme_color_override("font_color", Color("2a1d12")); holder.add_child(label)
		for i in range(3):
			var pose := {"heading": rows[r][3][i], "action": rows[r][2], "phase": 0.4, "age": 0.3 * i}
			if rows[r][2] in ["cuffed", "escort"] and i == 1: pose.moving = true; pose.gait_phase = 0.3; pose.move_direction = Vector2.from_angle(rows[r][3][i])
			put(holder, Vector2(220 + i * 330, 115 + r * 116), pose, rows[r][1])
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/animation-arrest.png")
	holder.queue_free()
	root.size = Vector2i(1280, 720)
	# In game
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); main.set_process(false)
	var sim = main.simulation; var s: Dictionary = sim.state
	s.tick = 14400 + 5400
	for npc in s.residents.values():
		npc.sleeping = {}; npc.goal = ""; npc.path = []
	var sheriff: Dictionary = Law.sheriffs(s, 1)[0]
	var store: Array = s.entities[str(s.settlements["1"].warehouse)].cell
	s.entities[str(sheriff.id)].cell = [store[0] - 3, store[1] + 6]
	s.entities[str(s.player)].cell = [store[0] + 40, store[1] + 6]
	Law.crime(s, 1, "theft", 0)
	s.entities[str(s.player)].cell = [store[0] + 3, store[1] + 6]
	for t in range(4): sim.step()
	await shot(main, "arrest-standoff", 10)
	sim.submit("surrender")
	for t in range(3): sim.step()
	await shot(main, "arrest-surrender", 6)
	for t in range(80):
		sim.step()
		if str(sheriff.get("arrest", {}).get("phase", "")) == "escort": break
	for t in range(30): sim.step()
	await shot(main, "arrest-escort", 6)
	var office: Dictionary = Law.office_of(s, 1)
	var cam = main.get_node("ObserverCamera")
	for t in range(2000):
		sim.step()
		if str(sheriff.get("arrest", {}).get("phase", "")) == "book": break
	cam.zoom = Vector2.ONE * 1.6
	for t in range(10): sim.step()
	await shot(main, "booking-search", 6)
	for t in range(20): sim.step()
	await shot(main, "booking-property", 6)
	for t in range(80):
		sim.step()
		if bool(s.player_control.get("booking", {}).get("dressed", false)): break
	await shot(main, "booking-flash", 1)
	for t in range(2000):
		sim.step()
		if Law.jailed(s): break
	for t in range(10): sim.step()
	await shot(main, "jail-cell", 8)
	s.player_control.jail.until = s.tick + 2
	for t in range(4000):
		sim.step()
		if bool(office.get("cell_open", false)): break
	for t in range(40): sim.step()
	await shot(main, "release-unlock", 6)
	for t in range(4000):
		sim.step()
		if str(sheriff.get("arrest", {}).get("phase", "")) == "return": break
	for t in range(10): sim.step()
	await shot(main, "release-desk", 6)
	for t in range(80): sim.step()
	await shot(main, "release-free", 6)
	quit()
