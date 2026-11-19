extends SceneTree
## The map screen: markers for the buildings that matter, labels clear of the bottom bar, a waypoint.
const MapOverlay = preload("res://view/ui/map_overlay.gd")
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main)
	await process_frame
	var s: Dictionary = main.simulation.state
	var list: Array = MapOverlay.markers(s)
	var by_town: Dictionary = {}
	for marker in list:
		if not by_town.has(marker.town): by_town[marker.town] = {}
		by_town[marker.town][marker.kind] = true
	for town in [1, 2, 3]:
		var kinds: Dictionary = by_town.get(town, {})
		check(kinds.has("office") and kinds.has("warehouse") and kinds.has("home_lodge") and kinds.has("farm") and kinds.has("well"), "Town %d shows its sheriff, storehouse, lodge, farm and well (%s)" % [town, str(kinds.keys())])
	check(by_town.get(2, {}).has("forge") and by_town.get(2, {}).has("ore"), "Reedbank shows its forge and ore")
	var legend: Array = MapOverlay.legend_kinds(list)
	check(legend.size() >= 8 and legend.has("office") and legend.has("bakery"), "The legend lists what is on the map (%d kinds)" % legend.size())
	# Labels stay on screen and clear of the bottom bar.
	var screen := Vector2(1280, 720)
	for wanted in [Vector2(640, 700), Vector2(-50, 300), Vector2(1400, 10), Vector2(640, 600)]:
		var rect: Rect2 = MapOverlay.clamp_label(wanted, Vector2(150, 30), screen)
		check(Rect2(Vector2.ZERO, screen).encloses(rect) and rect.end.y <= screen.y - MapOverlay.BOTTOM_MARGIN + 0.01, "A label wanted at %s is moved inside and above the hotbar (%s)" % [str(wanted), str(rect)])
	# Bearings.
	check(MapOverlay.bearing_text(Vector2.ZERO, Vector2(24 * 100, 0)) == "100 m E", "Bearing east: " + MapOverlay.bearing_text(Vector2.ZERO, Vector2(2400, 0)))
	check(MapOverlay.bearing_text(Vector2.ZERO, Vector2(0, -24 * 50)) == "50 m N", "Bearing north")
	# The drawn map in the running game: painted once on opening, the world hidden behind it,
	# nothing repainted while it stays open, a fresh picture when it opens again.
	main.set_process(false)
	main.menu_active = false
	var world = main.get_node("WorldView")
	main.toggle_map()
	check(main.map_mode and main.medieval_map.visible, "The map opens")
	check(not world.visible, "The world is not drawn behind the map")
	check(main.medieval_map.builds == 1, "The map picture is painted once on opening")
	for i in range(5):
		main._process(1.0 / 60.0)
		await process_frame
	check(main.medieval_map.builds == 1, "...and not again while it stays open")
	# Waypoints still work on the drawn map.
	main.map_overlay.set_waypoint(Vector2(5000, 800))
	check(main.map_overlay.waypoint == Vector2(5000, 800), "A waypoint can be set")
	main.map_overlay.clear_waypoint()
	check(main.map_overlay.waypoint == Vector2.INF, "...and cleared")
	# Screen and world positions agree.
	var spot := Vector2(3000, 1500)
	check(main.medieval_map.world_of(main.medieval_map.screen_of(spot)).distance_to(spot) < 0.5, "Map positions convert both ways")
	# Clicking a town's name offers to travel there; choosing it closes the map and sets off.
	main.medieval_map.queue_redraw()
	await process_frame
	await process_frame
	var reedbank_rect: Rect2 = Rect2()
	for entry in main.medieval_map.town_rects:
		if int(entry.town) == 2: reedbank_rect = entry.rect
	check(reedbank_rect.size.x > 0, "Town names are lettered on the map")
	check(main.medieval_map.town_at(reedbank_rect.get_center()) == 2, "A click on Reedbank's name finds Reedbank")
	main._open_travel_menu(2, reedbank_rect.get_center())
	check(main.context_menu.visible, "A menu offers to travel there")
	main._on_context_chosen(2, "travel_town")
	main.simulation.step()
	check(not main.map_mode and world.visible, "Choosing Travel here closes the map")
	check(int(s.player_control.get("travelling", 0)) == 2, "...and the player sets off for Reedbank")
	# Esc closes the map.
	main.toggle_map()
	var esc := InputEventKey.new(); esc.pressed = true; esc.keycode = KEY_ESCAPE; esc.physical_keycode = KEY_ESCAPE
	main._unhandled_input(esc)
	check(not main.map_mode, "Esc closes the map")
	check(main.medieval_map.builds == 2, "Reopening the map paints a fresh picture")
	print("Map overlay: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
