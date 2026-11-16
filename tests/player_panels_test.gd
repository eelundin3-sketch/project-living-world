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
	check(main.player_panels.mode=="health" and main.player_panels.rows.size()==17,"H opens every body part")
	main.player_panels.select_part("left_forearm")
	check(main.player_panels.selected_part=="left_forearm","Body part selection works")
	var panels = main.player_panels
	check(not panels.rows["right_hand"].visible and panels.empty_wounds.visible, "Healthy areas stay out of the default injury list")
	main.simulation.submit("debug_injury", {"part": "right_hand", "damage": 28, "kind": "cut"})
	main.simulation.step()
	panels.refresh()
	check(panels.rows["right_hand"].visible and not panels.empty_wounds.visible, "New wounds appear in the injury list")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	panels.rows["right_hand"].gui_input.emit(click)
	check(panels.treatment_menu.visible and panels.treatment_part == "right_hand", "Right-click opens treatment for the clicked wound")
	check(not panels.treatment_menu.is_item_disabled(0) and panels.treatment_menu.is_item_disabled(2), "Treatment menu respects available actions")
	panels.treatment_menu.id_pressed.emit(0)
	panels.treatment_menu.hide()
	main.simulation.step()
	check(main.simulation.state.player_health.treatment.part == "right_hand", "Menu submits treatment for the right body part")
	for tick in range(35): main.simulation.step()
	panels.refresh()
	check(panels.wound_labels["right_hand"].text == "Bandaged", "Completed treatment updates the injury row")
	panels.healthy_toggle.button_pressed = true
	check(panels.rows["left_foot"].visible, "Healthy areas can be shown for inspection")
	press(main,KEY_ESCAPE)
	check(not main.player_panels.visible,"Esc closes panel")
	main.simulation.submit("hold_item",{"item":"food"}); main.simulation.step(); main.refresh_view()
	press(main,KEY_F); main.simulation.step(); main.refresh_view()
	check(main.simulation.state.player_control.held_quantity==0,"F submits contextual interaction")
	main.queue_free(); await process_frame
	print("Player panels: %s" % ("PASS" if failures==0 else "FAIL")); quit(0 if failures==0 else 1)
