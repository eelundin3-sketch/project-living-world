extends SceneTree
## Clothing review: dressed, no shirt, no trousers, underwear only, and without the backpack,
## each from the front, the side and behind; then the inventory with the backpack square.
const Character = preload("res://view/actors/drawn_character.gd")
const Outfits = preload("res://sim/entities/outfits.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var holder := Node2D.new(); root.add_child(holder)
	var bg := ColorRect.new(); bg.color = Color("a8905f"); bg.size = Vector2(1280, 720); holder.add_child(bg)
	var full: Dictionary = Outfits.default_for(0, true)
	var looks := [["dressed", {}], ["no shirt", {"shirt": "", "vest": ""}], ["no trousers", {"pants": ""}], ["underwear", {"hat": "", "vest": "", "shirt": "", "pants": "", "boots": ""}], ["no backpack", {"pack": ""}]]
	for i in range(looks.size()):
		var outfit: Dictionary = full.duplicate()
		for k in looks[i][1]: outfit[k] = looks[i][1][k]
		var label := Label.new(); label.text = looks[i][0]; label.position = Vector2(60 + i * 245, 20); label.add_theme_color_override("font_color", Color("2a1d12")); holder.add_child(label)
		var r := 0
		for heading in [PI / 2.0, 0.0, -PI / 2.0]:
			var f := Character.new(); holder.add_child(f); f.setup(0, true, false); f.scale = Vector2.ONE * 1.9
			f.set_pose({"position": Vector2(110 + i * 245, 190 + r * 200), "heading": heading, "action": "idle", "outfit": outfit, "moving": false})
			r += 1
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/outfits.png")
	holder.queue_free()
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); main.set_process(false)
	main.player_panels.show_mode("inventory")
	main.simulation.step(); main.refresh_view()
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/inventory-grid.png")
	quit()
