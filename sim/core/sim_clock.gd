extends RefCounted
const TICKS_PER_SECOND: int = 10
const STEP_SECONDS: float = 0.1
var accumulator: float = 0.0
var paused: bool = false
var speed: int = 1

func advance(delta: float, simulation: RefCounted) -> int:
	if paused:
		return 0
	accumulator += maxf(delta, 0.0) * speed
	var count: int = 0
	# Preserve backlog instead of dropping authoritative ticks on a slow frame.
	while accumulator + 0.000000001 >= STEP_SECONDS and count < 200:
		simulation.step()
		accumulator -= STEP_SECONDS
		count += 1
	return count
