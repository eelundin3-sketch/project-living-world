extends Node2D
const World = preload("res://sim/world/world_db.gd")
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer2D] = []
var enabled: bool = true
var cooldowns: Dictionary = {}
var elapsed: float = 0.0

func _ready() -> void:
	for name in ["step_grass", "step_wood", "chop", "saw", "pickup", "drop", "build", "harvest", "fall", "punch", "shove", "thud", "shot", "door"]:
		sounds[name] = load("res://content/audio/" + name + ".wav")
	for index in range(12):
		var voice := AudioStreamPlayer2D.new()
		voice.max_distance = 650
		voice.attenuation = 1.6
		add_child(voice)
		voices.append(voice)
	var config := ConfigFile.new()
	if config.load("user://audio.cfg") == OK:
		enabled = config.get_value("audio", "enabled", true)
	# No ambient loop: the old wind bed repeated a short stretch over and over and grated.

func toggle() -> void:
	enabled = not enabled
	if not enabled:
		for voice in voices: voice.stop()
	var config := ConfigFile.new()
	config.set_value("audio", "enabled", enabled)
	config.save("user://audio.cfg")

func present(cues: Array[Dictionary], s: Dictionary, listener: Vector2, paused: bool, delta: float) -> void:
	elapsed += delta
	for voice in voices:
		voice.stream_paused = paused or not enabled
	if paused or not enabled or DisplayServer.get_name() == "headless":
		return
	var ordered := cues.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.position.distance_squared_to(listener) < b.position.distance_squared_to(listener))
	var emitted: int = 0
	for cue in ordered:
		if emitted >= 4 or cue.position.distance_to(listener) > 580:
			continue
		var kind: String = cue.kind
		# Nearby villagers produce many overlapping hard transients. Keep the
		# player's own footsteps and only occasional close ambient footsteps.
		if kind == "step" and int(cue.get("actor", 0)) != int(s.player):
			if cue.position.distance_to(listener) > 110 or elapsed - float(cooldowns.get("ambient_step", -10)) < 0.8:
				continue
			cooldowns["ambient_step"] = elapsed
		var key := "%s:%d:%d" % [kind, int(cue.position.x / 96), int(cue.position.y / 96)]
		if elapsed - float(cooldowns.get(key, -10)) < (0.14 if kind == "step" else 0.09):
			continue
		if kind == "step":
			kind = "step_wood" if World.inside_building(s, [roundi(cue.position.x / 24), roundi(cue.position.y / 24)]) != 0 else "step_grass"
		if not sounds.has(kind):
			continue
		for voice in voices:
			if not voice.playing:
				voice.stream = sounds[kind]
				voice.position = cue.position
				voice.volume_db = (-29 if int(cue.get("actor", 0)) == int(s.player) else -38) if kind.begins_with("step") else {"punch": -10.0, "shove": -14.0, "thud": -12.0, "shot": -4.0, "door": -22.0}.get(kind, -19.0)
				voice.pitch_scale = (0.9 if kind == "thud" else 0.96) + float(absi(int(cue.position.x + cue.position.y)) % 9) * 0.01
				voice.play()
				cooldowns[key] = elapsed
				emitted += 1
				break
	if cooldowns.size() > 256:
		for key in cooldowns.keys():
			if elapsed - cooldowns[key] > 3:
				cooldowns.erase(key)

func _exit_tree() -> void:
	for voice in voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	sounds.clear()

func stop_effects() -> void:
	for voice in voices:
		voice.stop()
	cooldowns.clear()
