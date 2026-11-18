extends SceneTree
const Outfits = preload("res://sim/entities/outfits.gd")
const Character = preload("res://view/actors/drawn_character.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	# 1. outfits sheet: fully dressed, then losing one piece at a time
	root.size = Vector2i(1280, 720)
	var holder := Node2D.new(); root.add_child(holder)
	var bg := ColorRect.new(); bg.color = Color("a8905f"); bg.size = Vector2(1280, 720); holder.add_child(bg)
	var steps := [["dressed", {}], ["no hat", {"hat": ""}], ["no vest", {"vest": ""}], ["no shirt", {"vest": "", "shirt": ""}], ["no trousers", {"pants": ""}], ["barefoot", {"boots": ""}], ["underclothes only", {"hat": "", "vest": "", "shirt": "", "pants": "", "boots": ""}]]
	for i in range(steps.size()):
		var outfit: Dictionary = Outfits.default_for(7 + i * 3 if i > 0 else 7).duplicate()
		outfit = Outfits.default_for(7)
		for k in steps[i][1]: outfit[k] = steps[i][1][k]
		for heading in [PI / 2.0, 0.0]:
			var figure := Character.new(); holder.add_child(figure); figure.setup(7, false, false)
			figure.scale = Vector2.ONE * 2.2
			figure.set_pose({"position": Vector2(95 + i * 175 + (0 if heading > 1 else 0), 150 if heading > 1 else 400), "heading": heading, "action": "idle", "outfit": outfit})
		var label := Label.new(); label.text = steps[i][0]; label.position = Vector2(60 + i * 175, 160 if true else 0); label.add_theme_color_override("font_color", Color("2a1d12")); holder.add_child(label)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/outfits.png")
	holder.queue_free()
	# 2. the loot window on a knocked-out villager, and on a chest
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); main.set_process(false)
	var sim = main.simulation; var s: Dictionary = sim.state
	for t in range(200): sim.step()
	var Brawl = load("res://sim/combat/brawl.gd"); var Looting = load("res://sim/player/looting.gd")
	var npc: Dictionary = s.residents.values()[1]
	var cell: Array = s.entities[str(npc.id)].cell.duplicate()
	s.entities[str(s.player)].cell = [cell[0] + 1, cell[1]]
	Brawl.knockdown(s, npc, cell, "ko", [1000, 0])
	Looting.open(s, npc.id)
	sim.step(); main.refresh_view()
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/loot-window-person.png")
	main.player_panels.show_mode("")
	var chest: Dictionary = {}
	for e in s.entities.values():
		if e.kind == "chest" and e.settlement == 1: chest = e; break
	var r: Array = chest.rock_rect
	s.entities[str(s.player)].cell = [r[0] - 1, r[1]]
	Looting.open(s, chest.id)
	sim.step(); main.refresh_view()
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/loot-window-chest.png")
	quit()
