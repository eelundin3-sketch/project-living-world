extends Node2D
const Simulation = preload("res://sim/core/simulation.gd")
const Clock = preload("res://sim/core/sim_clock.gd")
const Save = preload("res://sim/persistence/save_manager.gd")
const Settings = preload("res://app/input_settings.gd")
const PlayerPanels = preload("res://view/ui/player_panels.gd")
const Health = preload("res://sim/player/body_health.gd")
const PlayerActions = preload("res://sim/player/player_actions.gd")
const Audio = preload("res://view/audio/world_audio.gd")
const ActionPointer = preload("res://view/ui/action_pointer.gd")
const CELL: float = 24.0
var player_panels: CanvasLayer
var world_audio: Node2D
var simulation := Simulation.new()
var clock := Clock.new()
var follow_player: bool = true
var last_input_tick: int = -1
var last_draw_tick: int = -1
var tick_ms: float = 0.0
var selected_id: int = 0
var pending_binding: String = ""
var save_path: String = "user://living_world.save"
var aiming: bool = false
var pointer_held: bool = false
var action_pointer: Control

func _ready() -> void:
	Settings.setup()
	simulation.start_game()
	player_panels=PlayerPanels.new()
	player_panels.simulation=simulation
	add_child(player_panels)
	var pointer_layer := CanvasLayer.new()
	pointer_layer.layer = 20
	add_child(pointer_layer)
	action_pointer = ActionPointer.new()
	pointer_layer.add_child(action_pointer)
	$WorldView.simulation = simulation
	world_audio = Audio.new()
	add_child(world_audio)
	$DebugHUD.sound_button.text = "Sound on" if world_audio.enabled else "Sound off"
	$DebugHUD.action.connect(handle_action)
	$ObserverCamera.position = Vector2(64, 46) * CELL
	$ObserverCamera.set_process(false)
	selected_id = simulation.state.player
	refresh_view()

func _process(delta: float) -> void:
	var direction := Vector2(
		Input.get_action_strength("walk_right") - Input.get_action_strength("walk_left"),
		Input.get_action_strength("walk_down") - Input.get_action_strength("walk_up"))
	if player_panels.visible: direction=Vector2.ZERO
	if follow_player:
		# Commands execute on the next tick. Queue at the end of the preceding
		# tick so the two-tick walking cadence has no extra idle tick.
		if direction != Vector2.ZERO and simulation.state.tick >= last_input_tick and simulation.state.tick + 1 >= simulation.state.player_control.next_move and not clock.paused:
			var sprint: bool=Input.is_key_pressed(KEY_SHIFT)
			var cell_direction: Array = [int(signf(direction.x)), 0] if direction.x != 0 else [0, int(signf(direction.y))]
			simulation.submit("move_player", {"direction": cell_direction,"run":sprint})
			last_input_tick = simulation.state.tick+1
	else:
		$ObserverCamera.position += direction.limit_length() * 480 * delta / $ObserverCamera.zoom.x
	var started := Time.get_ticks_usec()
	var advanced: int = clock.advance(delta, simulation)
	if advanced > 0:
		tick_ms = float(Time.get_ticks_usec() - started) / 1000.0 / advanced
	$WorldView.motion.player_aiming = (aiming or pointer_held) and not player_panels.visible
	$WorldView.motion.player_ready = pointer_held and not player_panels.visible
	$WorldView.motion.player_aim_position = get_global_mouse_position()
	action_pointer.active = pointer_held and not player_panels.visible
	action_pointer.queue_redraw()
	$WorldView.animate(delta, clock.paused, clock.speed)
	if follow_player:
		var cell: Array = simulation.state.entities[str(simulation.state.player)].cell
		$ObserverCamera.position = $WorldView.motion.actors.get(str(simulation.state.player), {}).get("position", Vector2(cell[0], cell[1]) * CELL)
	world_audio.present($WorldView.motion.cues, simulation.state, $ObserverCamera.position, clock.paused, delta)
	if simulation.state.tick != last_draw_tick:
		refresh_view()
	if not follow_player:
		$WorldView.queue_redraw()

func refresh_view() -> void:
	last_draw_tick = simulation.state.tick
	$WorldView.selected_id = selected_id
	$WorldView.queue_redraw()
	if $WorldView.background != null:
		$WorldView.background.queue_redraw()
	$DebugHUD.refresh(simulation, clock, selected_id, tick_ms)
	player_panels.refresh()
	$DebugHUD.notice.text = PlayerActions.prompt(simulation.state, selected_id)

func handle_action(kind: String) -> void:
	if kind.begins_with("buy:") or kind.begins_with("sell:"):
		var town: int = 1 if simulation.state.entities[str(simulation.state.player)].cell[0] < 122 else 2
		simulation.submit("trade", {"town": town, "item": kind.split(":")[1], "buy": kind.begins_with("buy:"), "quantity": 1})
	elif kind.begins_with("bind:"):
		pending_binding = kind.split(":")[1]
		$DebugHUD.notice.text = "Press a movement key (Esc cancels)."
	match kind:
		"inventory":
			simulation.submit("stop_travel")
			player_panels.toggle("inventory")
		"health":
			simulation.submit("stop_travel")
			player_panels.toggle("health")
		"interact":
			if player_panels.visible: player_panels.show_mode("")
			else: simulation.submit("interact",{"target":selected_id})
		"injury_demo": simulation.submit("debug_injury",{"part":"right_forearm","damage":24,"kind":"cut"})
		"encounter_demo": simulation.submit("demo_encounter")
		"sound":
			world_audio.toggle()
			$DebugHUD.sound_button.text = "Sound on" if world_audio.enabled else "Sound off"
		"motion":
			$WorldView.motion.reduced_motion = not $WorldView.motion.reduced_motion
			$DebugHUD.motion_button.text = "Motion: low" if $WorldView.motion.reduced_motion else "Motion: full"
		"pause": clock.paused = not clock.paused
		"speed1": clock.speed = 1
		"speed2": clock.speed = 2
		"speed3": clock.speed = 3
		"details": $DebugHUD.toggle_details()
		"follow": follow_player = not follow_player
		"travel":
			var town: int = 2 if simulation.state.entities[str(simulation.state.player)].cell[0] < 122 else 1
			simulation.submit("travel", {"town": town})
			follow_player = true
		"road": simulation.submit("route_block", {"blocked": not simulation.state.routes["1"].blocked})
		"risk": simulation.submit("risk", {"value": 0 if simulation.state.routes["1"].risk > 0 else 70})
		"treaty": simulation.submit("treaty", {"open": not simulation.state.treaty.open_trade})
		"mod": simulation.submit("load_recipe", {"path": "user://recipe.json"})
		"large_text": $DebugHUD.toggle_large_text()
		"observer": $DebugHUD.toggle_observer()
		"cancel_batch":
			if simulation.state.workshops.has(str(selected_id)):
				simulation.submit("cancel_production", {"id": selected_id})
		"save":
			var result := Save.save_state(simulation, save_path)
			$DebugHUD.notice.text = "Saved world." if result.ok else result.error
		"load":
			var result := Save.load_into(simulation, save_path)
			if result.ok:
				clock.accumulator = 0
				$WorldView.snap_visuals()
				world_audio.stop_effects()
				selected_id = simulation.state.player
				$DebugHUD.notice.text = "Recovered backup." if result.get("recovered_backup", false) else "Loaded world."
			else:
				$DebugHUD.notice.text = result.error
		"cancel":
			if simulation.state.residents.has(str(selected_id)):
				simulation.submit("cancel_job", {"id": simulation.state.residents[str(selected_id)].job})
	refresh_view()

func _input(event: InputEvent) -> void:
	# Handle zoom before modal UI panels can consume trackpad/mouse scroll events.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		aiming = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		pointer_held = false
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and player_panels.scrolls_health_list_at(event.position):
			return
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: $ObserverCamera.adjust_zoom(1.15); get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: $ObserverCamera.adjust_zoom(1.0/1.15); get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		$ObserverCamera.adjust_zoom(event.factor); get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		aiming = event.pressed
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F8:
		$DebugHUD.toggle_details()
		return
	if event is InputEventKey and event.pressed and not event.echo and not pending_binding.is_empty():
		if event.physical_keycode != KEY_ESCAPE:
			Settings.bind(pending_binding, event.physical_keycode)
			$DebugHUD.notice.text = pending_binding.replace("walk_", "Move ") + " bound to " + OS.get_keycode_string(event.physical_keycode)
		pending_binding = ""
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pointer_held = true
		if aiming and not player_panels.visible and not clock.paused:
			_submit_strike("punch")
		elif not player_panels.visible:
			selected_id = $WorldView.pick(get_global_mouse_position())
			refresh_view()
	if event is InputEventMouseButton:
		$WorldView.queue_redraw()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_I: handle_action("inventory")
			KEY_H: handle_action("health")
			KEY_F: handle_action("interact")
			KEY_ESCAPE: player_panels.show_mode("")
			KEY_SPACE:
				if not player_panels.visible and not clock.paused: _submit_strike("shove")
			KEY_P: handle_action("pause")
			KEY_1: handle_action("speed1")
			KEY_2: handle_action("speed2")
			KEY_3: handle_action("speed3")
			KEY_F5: handle_action("save")
			KEY_F9: handle_action("load")
			KEY_TAB: handle_action("follow")
			KEY_F2: simulation.submit("spawn_test")
			KEY_F3: handle_action("observer")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		aiming = false
		pointer_held = false

func _submit_strike(kind: String) -> void:
	var actor: Dictionary = $WorldView.motion.actors.get(str(simulation.state.player), {})
	var cell: Array = simulation.state.entities[str(simulation.state.player)].cell
	var origin: Vector2 = actor.get("position", Vector2(cell[0], cell[1]) * CELL)
	var direction: Vector2 = get_global_mouse_position() - origin if aiming or pointer_held else Vector2.from_angle(float(actor.get("heading", PI / 2.0)))
	if direction.length_squared() < 16.0: direction = Vector2.from_angle(float(actor.get("heading", PI / 2.0)))
	direction = direction.normalized()
	simulation.submit("player_strike", {"kind": kind, "direction": [roundi(direction.x * 1000.0), roundi(direction.y * 1000.0)]})
