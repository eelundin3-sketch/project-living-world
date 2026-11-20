extends RefCounted
## One record for the player's own longer-lived numbers that later features add (skills, look,
## debts, hired help, places met, tips seen...). Kept apart from `player_control`, which is the
## moment-to-moment input state, so each feature only adds a key here. Created on first use, so
## saves from before it existed load unchanged.

static func of(s: Dictionary) -> Dictionary:
	if not s.has("player_status"): s.player_status = {}
	return s.player_status

## A sub-record, created with `default` the first time it is asked for.
static func part(s: Dictionary, key: String, default: Variant) -> Variant:
	var status: Dictionary = of(s)
	if not status.has(key): status[key] = default
	return status[key]
