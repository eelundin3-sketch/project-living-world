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
	# The overlay in the running game: map mode on, a waypoint set and cleared, and it draws without errors.
	main.set_process(false)
	main.toggle_map()
	check(main.map_mode, "The map opens")
	main.map_overlay.state = s; main.map_overlay.active = true; main.map_overlay.zoom = 0.2
	main.map_overlay.set_waypoint(Vector2(5000, 800))
	check(main.map_overlay.waypoint == Vector2(5000, 800), "A waypoint can be set")
	for i in range(2): await process_frame
	main.map_overlay.clear_waypoint()
	check(main.map_overlay.waypoint == Vector2.INF, "...and cleared")
	main.toggle_map()
	print("Map overlay: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
