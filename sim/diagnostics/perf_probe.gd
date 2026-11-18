extends RefCounted
## Time spent per system, for the performance tab and the benchmarks. It is never part of the
## game state and never changes what the simulation does: it only reads the clock.
## Usage inside a step: begin(), then mark("name") after each system.
static var totals: Dictionary = {}    # name -> microseconds since the last take()
static var worst: Dictionary = {}     # name -> worst single measurement since the last take()
static var counters: Dictionary = {}  # name -> count since the last take()
static var _last: int = 0

static func begin() -> void:
	_last = Time.get_ticks_usec()

static func mark(name: String) -> void:
	var now := Time.get_ticks_usec()
	add(name, now - _last)
	_last = now

static func add(name: String, usec: int) -> void:
	totals[name] = int(totals.get(name, 0)) + usec
	if usec > int(worst.get(name, 0)): worst[name] = usec

static func count(name: String, amount: int = 1) -> void:
	counters[name] = int(counters.get(name, 0)) + amount

## Returns everything gathered since the last call and starts again.
static func take() -> Dictionary:
	var result := {"totals": totals, "worst": worst, "counters": counters}
	totals = {}
	worst = {}
	counters = {}
	return result
