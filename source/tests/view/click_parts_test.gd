extends SceneTree
## Clicking inside a building picks the furniture or fixture under the pointer (bed, weapon rack),
## a chest as its own chest, and nothing at all on bare floor.
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void: call_deferred("run")
func centre(r: Array) -> Vector2:
	return (Vector2(r[0], r[1]) + Vector2(r[2] - 1, r[3] - 1) * 0.5) * 24.0
func run() -> void:
	var main = load("res://app/main.tscn").instantiate(); root.add_child(main)
	await process_frame
	main.set_process(false)
	var world = main.get_node("WorldView")
	var s: Dictionary = main.simulation.state
	var office: Dictionary = {}
	for e in s.entities.values():
		if e.kind == "office" and int(e.settlement) == 1: office = e; break
	var bed_index := -1
	for i in range(office.furniture.size()):
		if office.furniture[i].kind == "bed" and str(office.furniture[i].get("for", "")) == "prisoner": bed_index = i
	s.entities[str(s.player)].cell = [office.cell[0] + 40, office.cell[1] + 40]   # nobody near to pick instead
	check(world.pick(centre(office.furniture[bed_index].rect)) == office.id and world.last_pick_part == "furniture:%d" % bed_index, "Clicking the prisoner's bed picks the bed (%s)" % world.last_pick_part)
	check(world.pick(centre(office.fixtures[0].rect)) == office.id and world.last_pick_part == "fixture:0" and office.fixtures[0].kind == "weapon_rack", "Clicking the rack picks the rack")
	var chest_item: Dictionary = office.furniture.filter(func(f): return f.kind == "chest")[0]
	check(world.pick(centre(chest_item.rect)) == int(chest_item.chest_id), "Clicking a chest picks the chest itself")
	# Bare floor: a walkable cell inside the office with no furniture on it or below it.
	var World = load("res://sim/world/world_db.gd")
	var rect: Rect2i = World.building_rect(office)
	var floor_cell := Vector2i(-1, -1)
	for y in range(rect.position.y + 1, rect.end.y - 1):
		for x in range(rect.position.x + 1, rect.end.x - 1):
			if floor_cell.x < 0 and World.walkable(s, [x, y]) and World.walkable(s, [x, y + 1]): floor_cell = Vector2i(x, y)
	check(world.pick(Vector2(floor_cell) * 24.0) == 0, "Clicking bare floor picks nothing")
	print("Click parts: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
