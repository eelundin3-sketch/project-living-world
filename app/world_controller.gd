extends Node2D
const Simulation = preload("res://sim/core/simulation.gd")
const Clock = preload("res://sim/core/sim_clock.gd")
const Save = preload("res://sim/persistence/save_manager.gd")
const Settings = preload("res://app/input_settings.gd")
const CELL: float = 24.0
var simulation := Simulation.new()
var clock := Clock.new()
var follow_player: bool = true
var last_input_tick: int = -1
var last_draw_tick: int = -1
var tick_ms: float = 0.0
var selected_id: int = 0
var pending_binding: String = ""
var save_path: String = "user://living_world.save"

func _ready() -> void:
	Settings.setup()
	simulation.start_game(20)
	$WorldView.simulation = simulation
	$DebugHUD.action.connect(handle_action)
	$ObserverCamera.position = Vector2(64, 46) * CELL
	$ObserverCamera.set_process(false)
	selected_id = simulation.state.player
	refresh_view()

func _process(delta: float) -> void:
	var direction := Vector2(
		Input.get_action_strength("walk_right") - Input.get_action_strength("walk_left"),
		Input.get_action_strength("walk_down") - Input.get_action_strength("walk_up"))
	if follow_player:
		if direction != Vector2.ZERO and simulation.state.tick != last_input_tick and not clock.paused:
			var cell_direction: Array = [int(signf(direction.x)), 0] if direction.x != 0 else [0, int(signf(direction.y))]
			simulation.submit("move_player", {"direction": cell_direction})
			last_input_tick = simulation.state.tick
	else:
		$ObserverCamera.position += direction.limit_length() * 480 * delta / $ObserverCamera.zoom.x
	var started := Time.get_ticks_usec()
	var advanced: int = clock.advance(delta, simulation)
	if advanced > 0:
		tick_ms = float(Time.get_ticks_usec() - started) / 1000.0 / advanced
	if follow_player:
		var cell: Array = simulation.state.entities[str(simulation.state.player)].cell
		$ObserverCamera.position = Vector2(cell[0], cell[1]) * CELL
	if simulation.state.tick != last_draw_tick:
		refresh_view()
	if not follow_player:
		$WorldView.queue_redraw()

func refresh_view() -> void:
	last_draw_tick = simulation.state.tick
	$WorldView.selected_id = selected_id
	$WorldView.queue_redraw()
	$DebugHUD.refresh(simulation, clock, selected_id, tick_ms)

func handle_action(kind: String) -> void:
	if kind.begins_with("buy:") or kind.begins_with("sell:"):
		var town: int = 1 if simulation.state.entities[str(simulation.state.player)].cell[0] < 122 else 2
		simulation.submit("trade", {"town": town, "item": kind.split(":")[1], "buy": kind.begins_with("buy:"), "quantity": 1})
	elif kind.begins_with("bind:"):
		pending_binding = kind.split(":")[1]
		$DebugHUD.notice.text = "Press a movement key (Esc cancels)."
	match kind:
		"pause": clock.paused = not clock.paused
		"speed1": clock.speed = 1
		"speed2": clock.speed = 2
		"speed4": clock.speed = 4
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
				selected_id = simulation.state.player
				$DebugHUD.notice.text = "Recovered backup." if result.get("recovered_backup", false) else "Loaded world."
			else:
				$DebugHUD.notice.text = result.error
		"cancel":
			if simulation.state.residents.has(str(selected_id)):
				simulation.submit("cancel_job", {"id": simulation.state.residents[str(selected_id)].job})
	refresh_view()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not pending_binding.is_empty():
		if event.physical_keycode != KEY_ESCAPE:
			Settings.bind(pending_binding, event.physical_keycode)
			$DebugHUD.notice.text = pending_binding.replace("walk_", "Move ") + " bound to " + OS.get_keycode_string(event.physical_keycode)
		pending_binding = ""
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_id = $WorldView.pick(get_global_mouse_position())
		refresh_view()
	if event is InputEventMouseButton:
		$WorldView.queue_redraw()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: handle_action("pause")
			KEY_1: handle_action("speed1")
			KEY_2: handle_action("speed2")
			KEY_3: handle_action("speed4")
			KEY_F5: handle_action("save")
			KEY_F9: handle_action("load")
			KEY_TAB: handle_action("follow")
			KEY_F2: simulation.submit("spawn_test")
			KEY_F3: handle_action("observer")
