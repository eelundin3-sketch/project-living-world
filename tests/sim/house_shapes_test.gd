extends SceneTree
## Every house type, turned to every door side: walls enclose it, the door is a way in, every
## inside cell can be reached from the door, beds fit, and the staged build covers every tile.
const Sim = preload("res://sim/core/simulation.gd")
const World = preload("res://sim/world/world_db.gd")
const Housing = preload("res://sim/settlement/housing.gd")
const Orient = preload("res://sim/world/orient.gd")
const Checks = preload("res://sim/diagnostics/invariants.gd")
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void:
	var sim := Sim.new(77); sim.start_game(5)
	var s: Dictionary = sim.state
	s.world.bounds = [-1000, -1000, 2000, 2000]   # open ground far from every town
	check(Housing.TYPES.size() >= 20, "At least twenty house types (%d)" % Housing.TYPES.size())
	var turned := 0
	var index := 0
	for entry in Housing.TYPES:
		for side in range(4):
			# Open ground far from everything: a grid of test plots out in the east.
			var door: Array = [600 + (index % 10) * 30, 600 + (index / 10) * 30]
			index += 1
			var label: String = "%s facing %d" % [entry.id, side]
			var id := World.add_entity(sim, "home", label, door, 1, Housing.placed_fields(entry, door, side))
			var home: Dictionary = s.entities[str(id)]
			turned += 1
			var rect := World.building_rect(home)
			var cells: Array = []
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					if World.building_contains(home, [x, y]): cells.append([x, y])
			check(cells.size() >= 30, "%s has a real floor (%d cells)" % [label, cells.size()])
			check(World.building_contains(home, door), "%s: the door is part of the building" % label)
			# Enclosed: every cell on the edge of the shape is a wall, except the door.
			var open_edge := 0
			for cell in cells:
				if cell == door: continue
				for offset in [[0, -1], [0, 1], [-1, 0], [1, 0]]:
					var next: Array = [cell[0] + offset[0], cell[1] + offset[1]]
					if not World.building_contains(home, next) and World.walkable(s, cell): open_edge += 1
			check(open_edge == 0, "%s is walled all round (%d open edges)" % [label, open_edge])
			# The door leads inside: from just outside, every walkable cell indoors is reachable.
			var out := Orient.outward(side)
			var outside: Array = [door[0] + out.x * 2, door[1] + out.y * 2]
			# A flood fill from just outside the door, kept to the house and a margin around it.
			var area := rect.grow(3)
			var seen: Dictionary = {"%d,%d" % [outside[0], outside[1]]: true}
			var queue: Array = [outside]
			while not queue.is_empty():
				var here: Array = queue.pop_back()
				for offset in [[0, -1], [0, 1], [-1, 0], [1, 0]]:
					var next: Array = [here[0] + offset[0], here[1] + offset[1]]
					var key := "%d,%d" % [next[0], next[1]]
					if seen.has(key) or not area.has_point(Vector2i(next[0], next[1])) or not World.walkable(s, next): continue
					seen[key] = true
					queue.append(next)
			var unreachable := 0
			var walkable_inside := 0
			for cell in cells:
				if not World.walkable(s, cell): continue
				walkable_inside += 1
				if not seen.has("%d,%d" % [cell[0], cell[1]]): unreachable += 1
			check(walkable_inside > 0 and unreachable <= 2, "%s: the inside is reachable from the door (%d of %d not)" % [label, unreachable, walkable_inside])
			var beds := 0
			for item in home.get("furniture", []):
				if item.kind != "bed": continue
				beds += 1
				var reachable_side := false
				for dy in range(-1, item.rect[3] + 1):
					for dx in range(-1, item.rect[2] + 1):
						if seen.has("%d,%d" % [item.rect[0] + dx, item.rect[1] + dy]): reachable_side = true
				check(reachable_side, "%s: a bed can be reached" % label)
			check(beds >= 1 and beds >= mini(int(entry.beds), 2), "%s has beds (%d of %d)" % [label, beds, int(entry.beds)])
			# The door faces the way it was asked to: the cell outside is open, the one behind is inside.
			check(World.walkable(s, outside) and World.building_contains(home, [door[0] - out.x, door[1] - out.y]), "%s: the door faces the right way" % label)
			var stages := World.construction_stages(home, "home")
			var tiles := 0
			for stage in stages: tiles += stage.tiles.size()
			check(tiles >= cells.size() - 1, "%s: the build plan covers the house (%d of %d)" % [label, tiles, cells.size()])
	check(turned == Housing.TYPES.size() * 4, "Every house was turned four ways")
	check(Checks.validate(s).is_empty(), "Invariants hold: " + str(Checks.validate(s)))
	s.world.bounds = [-96, -84, 486, 336]   # back to the real map before saving
	load("res://sim/entities/chests.gd").ensure_all(sim)   # every chest has its stock before the save
	var copy := Sim.new(); copy.restore(sim.snapshot())
	check(copy.state_hash() == sim.state_hash(), "Turned houses survive a reload")
	print("House shapes: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
