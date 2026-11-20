extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Inventory = preload("res://sim/inventory/inventory_store.gd")
var failures: int = 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void:
	var sim := Sim.new(); sim.start_game(); var s: Dictionary = sim.state
	check(s.hotbar.slots == ["", "", "", ""] and s.hotbar.active == 0, "Hotbar starts with four empty slots and slot 1 selected")
	sim.submit("hotbar_use", {"slot": 0}); sim.step()
	check(s.player_control.notice.contains("empty"), "Empty slot explains how to assign")
	# Assign from the inventory, use, put away.
	sim.submit("hotbar_assign", {"slot": 1, "item": "food"}); sim.step()
	check(s.hotbar.slots[1] == "food", "Item assigned to slot 2")
	sim.submit("hotbar_assign", {"slot": 2, "item": "food"}); sim.step()
	check(s.hotbar.slots[2] == "food" and s.hotbar.slots[1] == "", "An item sits in one slot at a time")
	sim.submit("hotbar_use", {"slot": 2}); sim.step()
	check(s.hotbar.active == 2 and s.player_control.held_item == "food", "Using a slot takes the item in hand")
	check(s.hotbar.active == 0 or s.hotbar.active == 2, "One slot is always selected")
	sim.submit("hotbar_use", {"slot": 2}); sim.step()
	check(s.hotbar.active == 2 and s.player_control.held_item == "food", "Pressing the selected slot again keeps it selected and in hand")
	# The rifle (your main gun) in a slot raises and lowers it.
	sim.submit("hotbar_assign", {"slot": 0, "item": "rifle"}); sim.step()
	sim.submit("hotbar_use", {"slot": 0}); sim.step()
	check(s.shotgun.equipped and s.hotbar.active == 0 and s.shotgun.kind == "rifle", "The rifle slot raises the rifle")
	sim.submit("hotbar_use", {"slot": 2}); sim.step()
	check(not s.shotgun.equipped and s.hotbar.active == 2, "Selecting another slot lowers the rifle and moves the selection")
	sim.submit("hotbar_assign", {"slot": 3, "item": "banana"}); sim.step()
	check(s.hotbar.slots[3] == "", "Unknown items are refused")
	if failures == 0: print("Hotbar: PASS")
	quit(failures)
