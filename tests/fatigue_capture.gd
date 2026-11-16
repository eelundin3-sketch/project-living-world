extends SceneTree
## Review sheets: the one-piece fall and get-up, the winded breathing, and the labouring run; plus the new inventory grid.
const Character = preload("res://view/actors/drawn_character.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var holder := Node2D.new(); root.add_child(holder)
	var bg := ColorRect.new(); bg.color = Color("a8905f"); bg.size = Vector2(1280, 720); holder.add_child(bg)
	var rows := [
		["fall (back)", "fall", [0.0, 0.15, 0.3, 0.45, 0.6, 0.8, 0.95], {"fall_style": "back"}],
		["fall (front)", "fall", [0.0, 0.15, 0.3, 0.45, 0.6, 0.8, 0.95], {"fall_style": "front"}],
		["get up", "getup", [0.0, 0.15, 0.3, 0.45, 0.6, 0.8, 0.95], {"fall_style": "back"}],
		["winded (side)", "idle", [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6], {"breath": 1.0, "heading": 0.0}],
		["winded", "idle", [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6], {"breath": 1.0}],
		["tired run", "run", [0.0, 0.14, 0.28, 0.42, 0.56, 0.7, 0.84], {"fatigue": 1.0, "run_blend": 1.0, "moving": true}]]
	for r in range(rows.size()):
		var title := Label.new(); title.text = rows[r][0]; title.position = Vector2(6, 20 + r * 118); title.add_theme_color_override("font_color", Color("2a1d12")); holder.add_child(title)
		for i in range(7):
			var figure := Character.new(); holder.add_child(figure); figure.setup(0, true, false)
			figure.scale = Vector2.ONE * 1.25
			var pose := {"position": Vector2(130 + i * 160, 105 + r * 118), "heading": 0.0 if rows[r][1] == "run" else PI / 2.0, "action": rows[r][1], "phase": rows[r][2][i], "moving": false, "fall_side": 1, "age": float(rows[r][2][i]) * 6.0, "gait_phase": rows[r][2][i]}
			for k in rows[r][3]: pose[k] = rows[r][3][k]
			figure.set_pose(pose)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/animation-fatigue.png")
	holder.queue_free()
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main); main.set_process(false)
	var sim = main.simulation; var s: Dictionary = sim.state
	for t in range(20): sim.step()
	var Inventory = load("res://sim/inventory/inventory_store.gd")
	Inventory.produce(s, s.player, "hat:2", 1); Inventory.produce(s, s.player, "shirt:1", 1); Inventory.produce(s, s.player, "log", 4); Inventory.produce(s, s.player, "food", 3)
	main.player_panels.show_mode("inventory")
	main.player_panels.inventory_window.grid.hover = "item:hat:2"
	sim.step(); main.refresh_view()
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/inventory-grid.png")
	quit()
