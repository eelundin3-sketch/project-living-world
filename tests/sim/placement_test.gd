extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Placement = preload("res://sim/world/placement.gd")
const World = preload("res://sim/world/world_db.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	var lodge: Dictionary = s.entities[str(s.home)]
	var beds: Array = lodge.furniture.filter(func(f: Dictionary) -> bool: return f.kind == "bed")
	check(beds.size() == 4, "The common lodge has four beds: %d" % beds.size())
	for bed in beds:
		check(bed.has("rot") and bed.rot >= 0 and bed.rot <= 3, "Every bed has an orientation")
		var rect: Array = bed.rect
		var size := Placement.size_for("bed", bed.rot)
		check(rect[2] == size.x and rect[3] == size.y, "Bed footprint matches its orientation")
		# The head side of the bed sits against a wall.
		var touching := 0
		var head_cells: Array = []
		match bed.rot:
			0: for x in range(rect[0], rect[0] + rect[2]): head_cells.append([x, rect[1] - 1])
			1: for y in range(rect[1], rect[1] + rect[3]): head_cells.append([rect[0] + rect[2], y])
			2: for x in range(rect[0], rect[0] + rect[2]): head_cells.append([x, rect[1] + rect[3]])
			3: for y in range(rect[1], rect[1] + rect[3]): head_cells.append([rect[0] - 1, y])
		for cell in head_cells:
			if Placement.is_wall(s, lodge, cell[0], cell[1]): touching += 1
		check(touching == head_cells.size(), "Bed head is flush against a wall (rot %d, %d/%d)" % [bed.rot, touching, head_cells.size()])
	# Each bed is also placed along as much wall as possible: at least one long side touches.
	for bed in beds:
		check(Placement.wall_score(s, lodge, "bed", bed.rect, bed.rot) >= 12, "Bed also hugs a wall")
	# Furniture cannot overlap.
	var seen: Dictionary = {}
	for item in lodge.furniture:
		for key in Placement.cells_of(item.rect):
			check(not seen.has(key), "No overlapping furniture at " + key)
			seen[key] = true
	# All four orientations are legal for a bed in open floor and give the right footprint.
	var open_room := Sim.new(); open_room.start_game(); var o: Dictionary = open_room.state
	var home: Dictionary = o.entities[str(o.home)]
	for item in home.furniture.duplicate():
		if item.kind == "bed": Placement.vacate(o, item.rect); home.furniture.erase(item)
	var fp := World.building_rect(home)
	var spot: Array = []
	for y in range(fp.position.y + 2, fp.end.y - 4):
		for x in range(fp.position.x + 2, fp.end.x - 4):
			var ok := true
			for rot in range(4):
				if not Placement.can_place(o, home, "bed", Placement.rect_for("bed", [x, y], rot)): ok = false
			if ok and spot.is_empty(): spot = [x, y]
	check(not spot.is_empty(), "Found open floor for a bed")
	for rot in range(4):
		var rect: Array = Placement.rect_for("bed", spot, rot)
		check(Placement.can_place(o, home, "bed", rect), "Bed placeable facing %d" % rot)
		check(Placement.place(o, home, "bed", spot, rot), "Placed bed facing %d" % rot)
		var placed: Dictionary = home.furniture[home.furniture.size() - 1]
		check(placed.rot == rot, "Stored orientation %d" % rot)
		Placement.vacate(o, placed.rect); home.furniture.pop_back()
	# Rotating a bed turns it clockwise through all four orientations.
	check(Placement.place(o, home, "bed", spot, 3), "Placed bed for rotation test")
	var index: int = home.furniture.size() - 1
	var turns: Array = []
	for step in range(4):
		var turned := Placement.rotate_item(o, home, index)
		turns.append(turned)
	check(turns.has(0) and turns.has(1) and turns.has(2) and turns.has(3), "Rotating visits all four orientations: " + str(turns))
	# Player commands: place_furniture and rotate_furniture through the simulation.
	var player: Dictionary = o.entities[str(o.player)]
	player.cell = [spot[0], spot[1] + 2]
	open_room.submit("rotate_furniture", {"building": home.id, "index": index}); open_room.step()
	check(o.player_control.notice.begins_with("Turned the bed"), "Rotate command reports: " + o.player_control.notice)
	if failures == 0: print("Placement: PASS")
	quit(failures)
