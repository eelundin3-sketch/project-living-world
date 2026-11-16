extends RefCounted
## Seeded weather is simulation state; rendering only reads this record.
const BLOCK_TICKS: int = 3600
const TRANSITION_TICKS: int = 300

static func initialize(s: Dictionary) -> void:
	if not s.has("weather"):
		s.weather = {"kind": "clear", "previous": "clear", "since": s.tick, "wind": 25, "snow": 0}

static func update(sim: RefCounted) -> void:
	var s: Dictionary = sim.state
	if not s.has("weather"): initialize(s)
	if s.tick % BLOCK_TICKS == 0:
		var weather: Dictionary = s.weather
		weather.previous = weather.kind
		var season: int = (s.tick / (14400 * 7)) % 4
		var roll: int = sim.random_int("weather:kind", 0, 99)
		weather.kind = ("snow" if season == 3 else "rain") if roll < 35 else ("fog" if roll < 50 else "clear")
		weather.wind = sim.random_int("weather:wind", 15, 85)
		weather.since = s.tick
	if s.tick % 100 == 0:
		var w: Dictionary = s.weather
		if w.kind == "snow": w.snow = mini(100, w.snow + 1)
		elif w.snow > 0 and (s.tick / (14400 * 7)) % 4 != 3: w.snow = maxi(0, w.snow - 1)
