extends RefCounted
const DEFAULTS: Dictionary = {"walk_up": KEY_W, "walk_left": KEY_A, "walk_down": KEY_S, "walk_right": KEY_D}
const PATH: String = "user://controls.cfg"

static func setup() -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	for action in DEFAULTS:
		bind(action, int(config.get_value("keys", action, DEFAULTS[action])), false)

static func bind(action: String, key: int, persist: bool = true) -> void:
	if not DEFAULTS.has(action):
		return
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)
	if persist:
		var config := ConfigFile.new()
		config.load(PATH)
		config.set_value("keys", action, key)
		config.save(PATH)
