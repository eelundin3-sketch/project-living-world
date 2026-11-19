extends SceneTree
const Sim = preload("res://sim/core/simulation.gd")
const Weather = preload("res://sim/world/weather.gd")
var failures: int = 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	var first := Sim.new(237)
	first.start_village(2)
	var second := Sim.new(237)
	second.restore(first.snapshot())
	for block in range(12):
		first.state.tick = (block + 1) * Weather.BLOCK_TICKS
		second.state.tick = first.state.tick
		Weather.update(first)
		Weather.update(second)
		check(first.state.weather == second.state.weather and first.state.rng == second.state.rng, "Weather follows the same seeded stream after reload")
		check(first.state.weather.kind in ["clear", "rain", "snow", "fog"], "Weather kind is valid")
	first.state.weather.kind = "snow"
	first.state.weather.snow = 0
	first.state.tick += 100
	Weather.update(first)
	check(first.state.weather.snow == 1, "Snow accumulates in simulated time")
	first.state.weather.kind = "clear"
	first.state.tick = 100
	Weather.update(first)
	check(first.state.weather.snow == 0, "Snow melts in a warmer season")
	print("Weather: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
