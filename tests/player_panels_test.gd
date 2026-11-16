extends SceneTree
var failures: int=0
func check(value: bool,label: String) -> void:
	if not value: failures+=1; printerr("FAIL: "+label)
func press(main: Node,key: int) -> void:
	var event:=InputEventKey.new(); event.physical_keycode=key; event.keycode=key; event.pressed=true
	main._unhandled_input(event)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var main=load("res://app/main.tscn").instantiate(); root.add_child(main); await process_frame; main.set_process(false)
	press(main,KEY_I)
	check(main.player_panels.mode=="inventory" and main.player_panels.visible,"I opens inventory")
	var cell: Array=main.simulation.state.entities[str(main.simulation.state.player)].cell.duplicate()
	Input.action_press("walk_right"); main._process(0.1); Input.action_release("walk_right")
	check(main.simulation.state.entities[str(main.simulation.state.player)].cell==cell,"Modal inventory prevents accidental movement")
	press(main,KEY_H)
	var panels = main.player_panels
	var window = panels.health_window
	check(panels.mode=="health" and window.visible and not panels.panel.visible,"H opens the health window")
	main.player_panels.select_part("left_forearm")
	check(window.selected_part=="left_forearm","Body part selection works")
	panels.refresh()
	check(not window.cards.has("right_hand") and window.listed.is_empty(), "Healthy areas stay out of the default injury list")
	main.simulation.submit("debug_injury", {"part": "right_hand", "damage": 28, "kind": "cut"})
	main.simulation.step()
	panels.refresh()
	check(window.cards.has("right_hand"), "New wounds appear in the injury list")
	window.select_part("right_hand")
	check(window.action_problem("bandage").is_empty() and not window.action_problem("remove").is_empty(), "Treatment buttons respect available actions")
	var bandages: int = main.simulation.state.inventories[str(main.simulation.state.player)].items.get("bandage", 0)
	main.simulation.state.inventories[str(main.simulation.state.player)].items["bandage"] = 0
	check(not window.action_problem("bandage").is_empty(), "Bandaging needs a bandage in the inventory")
	main.simulation.state.inventories[str(main.simulation.state.player)].items["bandage"] = bandages
	check(window.press_action("bandage"), "The bandage button submits a treatment")
	main.simulation.step()
	check(main.simulation.state.player_health.treatment.part == "right_hand", "The treatment is for the selected body part")
	panels.refresh()
	check(window.diagram.treat_part == "right_hand", "The figure in the window acts out the bandaging")
	for tick in range(40): main.simulation.step()
	panels.refresh()
	check(window.status_text("right_hand").contains("Bandaged"), "Completed treatment updates the injury card")
	check(window.diagram.treat_part == "", "The figure goes back to standing afterwards")
	window.show_all = true
	panels.refresh()
	check(window.listed.has("left_foot"), "Healthy areas can be shown for inspection")
	var Brawl = load("res://sim/player/brawl.gd")
	Brawl.knockdown(main.simulation.state, main.simulation.state.player_control, main.simulation.state.entities[str(main.simulation.state.player)].cell, "ko", [1000, 0])
	main.simulation.state.player_health.parts.right_hand.bandage = "dirty"
	check(not window.action_problem("bandage").is_empty(), "No treatment while unconscious")
	main.simulation.submit("treat_body", {"part": "right_hand", "action": "bandage"}); main.simulation.step()
	check(main.simulation.state.player_health.treatment.is_empty(), "The simulation refuses treatment while unconscious")
	main.simulation.state.player_control.knock = {}
	press(main,KEY_ESCAPE)
	check(not main.player_panels.visible,"Esc closes panel")
	main.simulation.submit("hold_item",{"item":"food"}); main.simulation.step(); main.refresh_view()
	press(main,KEY_F); main.simulation.step(); main.refresh_view()
	check(main.simulation.state.player_control.held_quantity==0,"F submits contextual interaction")
	main.queue_free(); await process_frame
	print("Player panels: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
