extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const World = preload("res://sim/world/world_db.gd")
const Nav = preload("res://sim/movement/navigation.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	var a := Sim.new(42)
	var b := Sim.new(42)
	World.seed_world(a)
	World.seed_world(b)
	check(a.state_hash() == b.state_hash(), "Seeded world identical")
	check(World.chunk_coord(-1, -65) == Vector2i(-1, -2), "Negative coordinates floor correctly")
	var path := Nav.request_path(a.state, [62, 49], [64, 46])
	check(path.ok and path.path.size() == 5, "Shortest local path")
	World.apply_mutation(a.state, [64, 46], true)
	check(not Nav.request_path(a.state, [62, 49], [64, 46]).ok, "Blocked endpoint rejected")
	var before := Inventory.totals(a.state)
	check(not Inventory.transfer(a.state, a.state.warehouse, a.state.player, "food", -1).ok, "Negative transfer rejected")
	check(Inventory.transfer(a.state, a.state.warehouse, a.state.player, "food", 5).ok, "Transfer succeeds")
	check(Inventory.totals(a.state) == before, "Transfer conserves items")
	check(not Inventory.transfer(a.state, a.state.warehouse, a.state.player, "food", 100).ok, "Capacity enforced")
	check(Inventory.reserve(a.state, a.state.player, "test", 25), "Capacity reservation")
	check(not Inventory.transfer(a.state, a.state.warehouse, a.state.player, "food", 10).ok, "Reservation excludes another transfer")
	print("World/inventory: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
