extends Node2D
const World = preload("res://sim/world/world_db.gd")
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer2D] = []
var wind: AudioStreamPlayer
var enabled: bool = true
var cooldowns: Dictionary = {}
var elapsed: float = 0.0

func _ready() -> void:
	for name in ["step_grass", "step_wood", "chop", "saw", "pickup", "drop", "build", "harvest", "fall", "wind"]:
		sounds[name] = load("res://content/audio/" + name + ".wav")
	for index in range(12):
		var voice := AudioStreamPlayer2D.new()
		voice.max_distance = 650
		voice.attenuation = 1.6
		add_child(voice)
		voices.append(voice)
	wind = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = sounds.wind.duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	wind.stream = stream
	wind.volume_db = -23
	add_child(wind)
	var config := ConfigFile.new()
	if config.load("user://audio.cfg") == OK:
		enabled = config.get_value("audio", "enabled", true)
	if enabled and DisplayServer.get_name() != "headless": wind.play()

func toggle() -> void:
	enabled = not enabled
	if enabled and DisplayServer.get_name() != "headless":
		wind.play()
	else:
		wind.stop()
		for voice in voices: voice.stop()
	var config := ConfigFile.new()
	config.set_value("audio", "enabled", enabled)
	config.save("user://audio.cfg")

func present(cues: Array[Dictionary], s: Dictionary, listener: Vector2, paused: bool, delta: float) -> void:
	elapsed += delta
	wind.stream_paused = paused or not enabled
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
				voice.volume_db = (-29 if int(cue.get("actor", 0)) == int(s.player) else -38) if kind.begins_with("step") else -19
				voice.pitch_scale = 0.96 + float(absi(int(cue.position.x + cue.position.y)) % 9) * 0.01
				voice.play()
				cooldowns[key] = elapsed
				emitted += 1
				break
	if cooldowns.size() > 256:
		for key in cooldowns.keys():
			if elapsed - cooldowns[key] > 3:
				cooldowns.erase(key)

func _exit_tree() -> void:
	if is_instance_valid(wind):
		wind.stop()
		wind.stream = null
	for voice in voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	sounds.clear()

func stop_effects() -> void:
	for voice in voices:
		voice.stop()
	cooldowns.clear()
