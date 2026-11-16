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
const Moodles = preload("res://view/ui/moodles.gd")
const BottomBar = preload("res://view/ui/bottom_bar.gd")
const PerfOverlay = preload("res://view/ui/perf_overlay.gd")
const ContextMenu = preload("res://view/ui/context_menu.gd")
const ContextActions = preload("res://sim/player/context_actions.gd")
const MainMenu = preload("res://view/ui/main_menu.gd")
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
var last_selected_id: int = -1
var map_mode: bool = false
var map_return_zoom: Vector2 = Vector2(2, 2)
var map_return_follow: bool = true
var pending_binding: String = ""
var last_left_press: int = -10000
var last_left_position: Vector2 = Vector2.ZERO
var save_path: String = "user://living_world.save"
var aiming: bool = false
var pointer_held: bool = false
var action_pointer: Control
var moodles: Control
var bottom_bar: Control
var perf: Control
var context_menu: Control
var menu: CanvasLayer
var menu_active: bool = false
var menu_time: float = 0.0
var intro_tween: Tween
var last_right_press: int = -10000
var last_right_position: Vector2 = Vector2.ZERO

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
	var moodle_layer := CanvasLayer.new()
	moodle_layer.layer = 5
	add_child(moodle_layer)
	moodles = Moodles.new()
	moodles.simulation = simulation
	moodle_layer.add_child(moodles)
	var bar_layer := CanvasLayer.new()
	bar_layer.layer = 6
	add_child(bar_layer)
	bottom_bar = BottomBar.new()
	bottom_bar.simulation = simulation
	bottom_bar.clock = clock
	bottom_bar.action.connect(handle_action)
	bottom_bar.slot_pressed.connect(func(index: int) -> void: simulation.submit("hotbar_use", {"slot": index}))
	bar_layer.add_child(bottom_bar)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 12
	add_child(menu_layer)
	context_menu = ContextMenu.new()
	context_menu.chosen.connect(_on_context_chosen)
	menu_layer.add_child(context_menu)
	var perf_layer := CanvasLayer.new()
	perf_layer.layer = 8
	add_child(perf_layer)
	perf = PerfOverlay.new()
	perf.main = self
	perf_layer.add_child(perf)
	$WorldView.simulation = simulation
	world_audio = Audio.new()
	add_child(world_audio)
	$DebugHUD.sound_button.text = "Sound on" if world_audio.enabled else "Sound off"
	$DebugHUD.action.connect(handle_action)
	$ObserverCamera.position = Vector2(64, 46) * CELL
	$ObserverCamera.set_process(false)
	selected_id = simulation.state.player
	refresh_view()
	call_deferred("_maybe_open_menu")

## The title screen appears only when the game is launched normally (tests add this scene by hand).
func _maybe_open_menu() -> void:
	if get_tree().current_scene != self: return
	menu_active = true
	menu = MainMenu.new()
	add_child(menu)
	menu.start_requested.connect(_start_from_menu)
	menu.quit_requested.connect(func() -> void: get_tree().quit())
	_set_hud_visible(false)
	follow_player = false
	$ObserverCamera.zoom = Vector2.ONE * 0.6
	$ObserverCamera.position = _menu_camera(0.0)

var hud_was_visible: Dictionary = {}
func _set_hud_visible(shown: bool) -> void:
	for node in [moodles, bottom_bar, perf]:
		if node != null:
			if not shown: hud_was_visible[node.get_instance_id()] = node.visible
			node.visible = bool(hud_was_visible.get(node.get_instance_id(), true)) if shown else false
			if shown and node.visible:
				node.modulate.a = 0.0
				create_tween().tween_property(node, "modulate:a", 1.0, 0.6)
	$DebugHUD.visible = shown
	if not shown: player_panels.show_mode("")

## A slow drift over the countryside around the first town.
func _menu_camera(t: float) -> Vector2:
	return Vector2(66, 54) * CELL + Vector2(sin(t * 0.045) * 1150.0, sin(t * 0.031 + 1.0) * 560.0)

## Start: fly down to the player and zoom in; control is handed over once the camera has landed.
func _start_from_menu() -> void:
	var player_key := str(simulation.state.player)
	var cell: Array = simulation.state.entities[player_key].cell
	var landing: Vector2 = $WorldView.motion.actors.get(player_key, {}).get("position", Vector2(cell[0], cell[1]) * CELL)
	intro_tween = create_tween()
	intro_tween.tween_property($ObserverCamera, "position", landing, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	intro_tween.parallel().tween_property($ObserverCamera, "zoom", Vector2.ONE * 0.9, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	intro_tween.tween_property($ObserverCamera, "zoom", Vector2.ONE * 2.0, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	intro_tween.tween_callback(_finish_intro)

func _finish_intro() -> void:
	menu_active = false
	follow_player = true
	intro_tween = null
	if menu != null: menu.queue_free()
	menu = null
	_set_hud_visible(true)

func _process(delta: float) -> void:
	if perf != null: perf.sample(delta)
	if menu_active and intro_tween == null:
		menu_time += delta
		$ObserverCamera.position = _menu_camera(menu_time)
	var direction := Vector2(
		Input.get_action_strength("walk_right") - Input.get_action_strength("walk_left"),
		Input.get_action_strength("walk_down") - Input.get_action_strength("walk_up"))
	if player_panels.visible or menu_active: direction=Vector2.ZERO
	if follow_player:
		# Commands execute on the next tick. Queue at the end of the preceding
		# tick so the two-tick walking cadence has no extra idle tick.
		if direction != Vector2.ZERO and simulation.state.tick >= last_input_tick and simulation.state.tick + 1 >= simulation.state.player_control.next_move and not clock.paused:
			var sprint: bool=Input.is_key_pressed(KEY_SHIFT)
			# W+A, W+D, S+A and S+D combine both axes into one diagonal step.
			var cell_direction: Array = [int(signf(direction.x)), int(signf(direction.y))]
			simulation.submit("move_player", {"direction": cell_direction,"run":sprint})
			last_input_tick = simulation.state.tick+1
	else:
		$ObserverCamera.position += direction.limit_length() * 480 * delta / $ObserverCamera.zoom.x
	# Holding Shift while a route is being followed (double-click, or walking up to a target) runs it.
	var route_active: bool = not simulation.state.get("player_path", []).is_empty()
	if route_active and Input.is_key_pressed(KEY_SHIFT) != bool(simulation.state.player_control.get("travel_run", false)):
		simulation.submit("travel_run", {"run": Input.is_key_pressed(KEY_SHIFT)})
	var started := Time.get_ticks_usec()
	var advanced: int = clock.advance(delta, simulation)
	if advanced > 0:
		tick_ms = float(Time.get_ticks_usec() - started) / 1000.0 / advanced
	var shotgun_equipped: bool = simulation.state.get("shotgun", {}).get("equipped", false)
	$WorldView.motion.player_aiming = (aiming or (pointer_held and not shotgun_equipped)) and not player_panels.visible and not map_mode
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
	# The static background repaints on a timer and when the selection changes, not every tick.
	if $WorldView.background != null and selected_id != last_selected_id:
		last_selected_id = selected_id
		$WorldView.background.queue_redraw()
	$DebugHUD.refresh(simulation, clock, selected_id, tick_ms)
	player_panels.refresh()
	if moodles != null: moodles.refresh()
	if bottom_bar != null:
		bottom_bar.blocked = player_panels.visible
		bottom_bar.refresh()
	if not map_mode: $DebugHUD.notice.text = PlayerActions.prompt(simulation.state, selected_id)

func handle_action(kind: String) -> void:
	if kind.begins_with("buy:") or kind.begins_with("sell:"):
		var town: int = nearest_town()
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
		"map": toggle_map()
		"pause": clock.paused = not clock.paused
		"slower": clock.speed = BottomBar.SPEEDS[maxi(0, BottomBar.SPEEDS.find(clock.speed) - 1)]
		"faster": clock.speed = BottomBar.SPEEDS[mini(BottomBar.SPEEDS.size() - 1, BottomBar.SPEEDS.find(clock.speed) + 1)]
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
	if menu_active: return
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
	if menu_active: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			# Two quick right-clicks on the same spot: walk there by the shortest route.
			var now := Time.get_ticks_msec()
			if not simulation.state.get("shotgun", {}).get("equipped", false) and now - last_right_press < 380 and event.position.distance_to(last_right_position) < 30.0 and not player_panels.visible and not map_mode and follow_player:
				var spot := get_global_mouse_position()
				simulation.submit("walk_to", {"cell": [roundi(spot.x / CELL), roundi(spot.y / CELL)]})
				context_menu.close()
				aiming = false
				last_right_press = -10000
				return
			last_right_press = now
			last_right_position = event.position
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
		if aiming and not player_panels.visible and not clock.paused and not map_mode:
			if simulation.state.get("shotgun", {}).get("equipped", false): _submit_shot()
			else: _submit_strike("punch")
		elif not player_panels.visible:
			selected_id = $WorldView.pick(get_global_mouse_position())
			refresh_view()
			var now_left := Time.get_ticks_msec()
			if selected_id == 0 and now_left - last_left_press < 380 and event.position.distance_to(last_left_position) < 30.0 and not map_mode and follow_player:
				# Two quick left-clicks on open ground: walk there by the shortest route (Shift runs).
				var spot_left := get_global_mouse_position()
				simulation.submit("walk_to", {"cell": [roundi(spot_left.x / CELL), roundi(spot_left.y / CELL)]})
				context_menu.close()
				last_left_press = -10000
			else:
				last_left_press = now_left
				last_left_position = event.position
				_open_context_menu(selected_id, event.position)
	if event is InputEventMouseButton:
		$WorldView.queue_redraw()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_I: handle_action("inventory")
			KEY_H: handle_action("health")
			KEY_E: simulation.submit("eat")
			KEY_M: toggle_map()
			KEY_C: simulation.submit("context_action", {"target": simulation.state.player, "action": "wardrobe"})
			KEY_X: simulation.submit("crouch_toggle")
			KEY_T: simulation.submit("rotate_furniture")
			KEY_G: simulation.submit("rearrange_furniture")
			KEY_R: simulation.submit("shotgun_reload")
			KEY_Q: simulation.submit("drink")
			KEY_F: handle_action("interact")
			KEY_ESCAPE: player_panels.show_mode("")
			KEY_SPACE:
				if not player_panels.visible and not clock.paused: _submit_strike("shove")
			KEY_P: handle_action("pause")
			KEY_1: simulation.submit("hotbar_use", {"slot": 0})
			KEY_2: simulation.submit("hotbar_use", {"slot": 1})
			KEY_3: simulation.submit("hotbar_use", {"slot": 2})
			KEY_4: simulation.submit("hotbar_use", {"slot": 3})
			KEY_COMMA: handle_action("slower")
			KEY_PERIOD: handle_action("faster")
			KEY_F5: handle_action("save")
			KEY_F9: handle_action("load")
			KEY_TAB: handle_action("follow")
			KEY_F3: handle_action("observer")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		aiming = false
		pointer_held = false

## Map view: leaves the character and frames every settlement. Move with WASD, zoom with
## the wheel; press M again to return to the character at the previous zoom.
## The settlement whose storehouse is closest to the player (for trading at its stalls).
func nearest_town() -> int:
	var cell: Array = simulation.state.entities[str(simulation.state.player)].cell
	var best: int = 1
	var best_distance: float = INF
	for town in simulation.state.get("settlements", {}).values():
		var store: Array = simulation.state.entities[str(town.warehouse)].cell
		var distance: float = Vector2(store[0] - cell[0], store[1] - cell[1]).length()
		if distance < best_distance:
			best_distance = distance
			best = int(town.id)
	return best

## Clicking a person or thing opens a menu of what can be done to it; F stays the quick way.
func _open_context_menu(id: int, at: Vector2) -> void:
	if id == 0 or map_mode:
		context_menu.close()
		return
	var s: Dictionary = simulation.state
	var options: Array = ContextActions.options(s, id)
	if options.is_empty():
		context_menu.close()
		return
	var entity: Dictionary = s.entities[str(id)]
	context_menu.open(id, entity.name, ContextActions.subtitle(s, id), options, at)
	pointer_held = false

func _on_context_chosen(target: int, action: String) -> void:
	if action in ["inventory", "health"]:
		handle_action(action)
		return
	simulation.submit("context_action", {"target": target, "action": action})

func toggle_map() -> void:
	var camera: Camera2D = $ObserverCamera
	map_mode = not map_mode
	context_menu.close()
	if map_mode:
		map_return_zoom = camera.zoom
		map_return_follow = follow_player
		follow_player = false
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for town in simulation.state.get("settlements", {}).values():
			var store: Array = simulation.state.entities[str(town.warehouse)].cell
			low = Vector2(minf(low.x, store[0]), minf(low.y, store[1]))
			high = Vector2(maxf(high.x, store[0]), maxf(high.y, store[1]))
		if low.x == INF:
			low = Vector2(40, 30); high = Vector2(90, 70)
		# Frame every settlement with a generous margin so the roads and forest around them show.
		var span := (high - low + Vector2(120, 70)) * CELL
		var fit: float = minf(get_viewport().get_visible_rect().size.x / span.x, get_viewport().get_visible_rect().size.y / span.y)
		camera.position = (low + high) * 0.5 * CELL
		camera.zoom = Vector2.ONE * clampf(fit, camera.MIN_ZOOM, camera.MAX_ZOOM)
		$DebugHUD.notice.text = "Map: WASD to move, wheel to zoom, M to return."
	else:
		follow_player = map_return_follow
		camera.zoom = map_return_zoom
	refresh_view()

func _submit_shot() -> void:
	var actor: Dictionary = $WorldView.motion.actors.get(str(simulation.state.player), {})
	var cell: Array = simulation.state.entities[str(simulation.state.player)].cell
	var origin: Vector2 = actor.get("position", Vector2(cell[0], cell[1]) * CELL)
	var direction: Vector2 = get_global_mouse_position() - origin
	if direction.length_squared() < 16.0: direction = Vector2.from_angle(float(actor.get("heading", PI / 2.0)))
	direction = direction.normalized()
	simulation.submit("shotgun_fire", {"direction": [roundi(direction.x * 1000.0), roundi(direction.y * 1000.0)]})

func _submit_strike(kind: String) -> void:
	var actor: Dictionary = $WorldView.motion.actors.get(str(simulation.state.player), {})
	var cell: Array = simulation.state.entities[str(simulation.state.player)].cell
	var origin: Vector2 = actor.get("position", Vector2(cell[0], cell[1]) * CELL)
	var direction: Vector2 = get_global_mouse_position() - origin if aiming or pointer_held else Vector2.from_angle(float(actor.get("heading", PI / 2.0)))
	if direction.length_squared() < 16.0: direction = Vector2.from_angle(float(actor.get("heading", PI / 2.0)))
	direction = direction.normalized()
	simulation.submit("player_strike", {"kind": kind, "direction": [roundi(direction.x * 1000.0), roundi(direction.y * 1000.0)]})
