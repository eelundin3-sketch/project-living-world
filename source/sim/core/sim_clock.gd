extends RefCounted
## Turns rendered frame time into whole simulation ticks. The tick count is the authority, so
## how wall-clock time maps onto ticks never changes the outcome, only how fast the world runs.
const TICKS_PER_SECOND: int = 10
const STEP_SECONDS: float = 0.1
## Simulation work per rendered frame is capped, so one slow tick cannot snowball into a run of
## slow frames (each catching up more ticks than the last).
const FRAME_BUDGET_USEC: int = 10000
## At most this much unplayed time is carried into the next frame (scaled by the speed).
const MAX_BACKLOG_SECONDS: float = 0.25
var accumulator: float = 0.0
var paused: bool = false
var speed: int = 1
var budget_usec: int = FRAME_BUDGET_USEC
var worst_step_usec: int = 0   # the slowest single tick in the last advance(), for the perf tab

func advance(delta: float, simulation: RefCounted) -> int:
	if paused:
		return 0
	accumulator += maxf(delta, 0.0) * speed
	var count: int = 0
	var started := Time.get_ticks_usec()
	worst_step_usec = 0
	while accumulator + 0.000000001 >= STEP_SECONDS:
		var before := Time.get_ticks_usec()
		simulation.step()
		accumulator -= STEP_SECONDS
		count += 1
		worst_step_usec = maxi(worst_step_usec, Time.get_ticks_usec() - before)
		if Time.get_ticks_usec() - started >= budget_usec: break
	# Drop wall-clock time the frame could not afford; the world simply runs a moment slower.
	accumulator = minf(accumulator, maxf(STEP_SECONDS, MAX_BACKLOG_SECONDS * speed))
	return count
