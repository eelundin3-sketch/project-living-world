extends SceneTree
## Cover and peeking: corner detection, leaning out past a corner, exposure, and shots from a corner.
const Sim = preload("res://sim/core/simulation.gd")
const Cover = preload("res://sim/combat/cover.gd")
const World = preload("res://sim/world/world_db.gd")
var failures: int = 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	s.world.bounds = [-1000, -1000, 2000, 2000]
	# A small test wall in open ground: a vertical wall x=700, y 690..699.
	for y in range(690, 700): s.world.building_walls["700,%d" % y] = 0
	check(Cover.blocker(s, [700, 695]) and not Cover.blocker(s, [702, 695]), "A wall blocks, open ground does not")
	check(Cover.is_cover(s, [701, 695]) and not Cover.is_cover(s, [705, 695]), "Beside a wall is cover; open ground is not")
	check(Cover.peek_cell(s, [701, 695], Vector2(0, 1)).is_empty(), "Mid-wall has no corner to look past")
	# Standing at the south end of the wall, the corner is one step south.
	var corner: Array = Cover.peek_cell(s, [701, 699], Vector2(0, 1))
	check(corner == [701, 700], "At the end of the wall the corner cell is one step past it: " + str(corner))
	check(Cover.peek_cell(s, [701, 699], Vector2(0, -1)).is_empty(), "Looking back along the wall there is no corner")
	# A tree is cover too.
	var tree: Dictionary = {}
	for entity in s.entities.values():
		if entity.kind == "tree": tree = entity; break
	check(Cover.tree_at(s, tree.cell), "A standing tree is a blocker")
	# Lines of sight.
	check(not Cover.line_clear(s, [699, 695], [702, 695]), "A wall breaks the line of sight")
	check(Cover.line_clear(s, [701, 700], [701, 705]) and Cover.line_clear(s, [699, 701], [704, 704]), "Open ground does not")
	check(Cover.first_block(s, [705, 695], [695, 695]) == [700, 695], "The first solid cell along a line is found")
	# High and low: a wall stops a shot whoever is behind it; a low thing (a chest, a bed) only
	# shields someone crouched right behind it, and covers only the crouched.
	s.world.fixture_cells["710,695"] = 0
	check(Cover.height(s, [700, 695]) == Cover.HIGH and Cover.height(s, [710, 695]) == Cover.LOW, "Walls are high, a chest-sized thing is low")
	check(not Cover.is_cover(s, [711, 695], false) and Cover.is_cover(s, [711, 695], true), "Behind something low is cover only when crouched")
	check(Cover.is_cover(s, [701, 695], false), "Beside a wall is cover even standing")
	check(Cover.line_clear(s, [705, 695], [711, 695]), "A shot goes over something low at someone standing behind it")
	check(not Cover.line_clear(s, [705, 695], [711, 695], false, true), "...but not at someone crouched right behind it")
	check(Cover.line_clear(s, [705, 695], [713, 695], false, true), "Crouching two cells back from it is no cover")
	check(not Cover.line_clear(s, [699, 695], [702, 695], false, false), "A wall stops shots at anyone")
	s.world.fixture_cells.erase("710,695")
	# The player takes cover, then leans out while the right button is held.
	var pc: Dictionary = s.player_control
	s.entities[str(s.player)].cell = [701, 699]
	pc.next_move = 0; s.player_path = []
	for t in range(6): sim.step()
	check(not pc.has("cover"), "Just standing at a wall is not taking cover (not sneaking, not in a fight)")
	pc.crouching = true
	for t in range(3): sim.step()
	check(pc.has("cover") and not pc.has("peek"), "Crouched still at the wall is cover")
	check(not Cover.player_exposed(s), "In cover the player is not exposed")
	sim.submit("peek", {"on": true, "toward": [0, 1000]}); sim.step(); sim.step()
	check(pc.has("peek") and pc.peek.to == [701, 700], "Holding peek leans out to the corner")
	check(s.entities[str(s.player)].cell == [701, 699], "Leaning out does not move the player's cell")
	check(Cover.player_exposed(s) and Cover.eye_cell(s) == [701, 700], "Leaning out exposes the player and moves the eyes")
	sim.submit("peek", {"on": false}); sim.step(); sim.step()
	check(not pc.has("peek") and not Cover.player_exposed(s), "Releasing returns to cover")
	# No corner towards the mouse: nothing happens.
	sim.submit("peek", {"on": true, "toward": [0, -1000]}); sim.step(); sim.step()
	check(not pc.has("peek"), "No corner that way, no peek")
	sim.submit("peek", {"on": false}); sim.step()
	# Moving leaves cover.
	s.entities[str(s.player)].cell = [705, 699]; pc.next_move = s.tick + 5
	sim.step()
	check(not pc.has("cover"), "Walking away leaves cover")
	# A shot from the corner leaves from the corner cell.
	var Inventory = load("res://sim/inventory/inventory_store.gd")
	Inventory.produce(s, s.player, "shotgun", 1); Inventory.produce(s, s.player, "shell", 5)
	s.shotgun.equipped = true; s.shotgun.loaded = 3; s.shotgun.last_shot = -1000
	s.entities[str(s.player)].cell = [701, 699]; pc.next_move = 0
	for t in range(6): sim.step()
	sim.submit("peek", {"on": true, "toward": [0, 1000]}); sim.step(); sim.step()
	sim.submit("shotgun_fire", {"direction": [0, 1000]}); sim.step()
	var first: Dictionary = s.shotgun.pellets[0] if not s.shotgun.pellets.is_empty() else {}
	check(not first.is_empty() and float(first.y) >= 699.9, "A shot fired while leaning out starts at the corner (y=%s)" % str(first.get("y")))
	var copy := Sim.new(); copy.restore(sim.snapshot())
	check(copy.state_hash() == sim.state_hash(), "Cover and peek state survive a reload")
	print("Cover: %s" % ("PASS" if failures == 0 else "FAIL")); quit(failures)
