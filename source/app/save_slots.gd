extends RefCounted
## Where saves live and which one is newest. The quick save (F5) keeps its old file name; two
## autosaves take turns each morning so a bad write never costs the only copy. Next to every save
## sits a small ".info" file (day, time, town, when it was written) so the title screen can offer
## "Continue" without reading and verifying a whole world.
const Save = preload("res://sim/persistence/save_manager.gd")
const QUICK := "project_solo.save"
const AUTOS := ["autosave_a.save", "autosave_b.save"]
const AUTOSAVE_MINUTE := 360          # 06:00
const DAY_TICKS := 14400

static func paths(dir: String = "user://") -> Array:
	var result: Array = [dir.path_join(QUICK)]
	for name in AUTOS: result.append(dir.path_join(name))
	return result

static func _town_name(s: Dictionary) -> String:
	if not s.has("settlements") or not s.has("player"): return ""
	var cell: Array = s.entities[str(s.player)].cell
	var best := ""
	var best_distance := 1 << 30
	var keys: Array = s.settlements.keys()
	keys.sort()
	for key in keys:
		var town: Dictionary = s.settlements[key]
		var store: Array = s.entities.get(str(town.get("warehouse", 0)), {}).get("cell", [])
		if store.is_empty(): continue
		var distance: int = absi(store[0] - cell[0]) + absi(store[1] - cell[1])
		if distance < best_distance: best_distance = distance; best = str(town.get("name", ""))
	return best

static func info_for(s: Dictionary, kind: String) -> Dictionary:
	var tick: int = int(s.get("tick", 0))
	return {"day": tick / DAY_TICKS + 1, "minute": (tick / 10) % 1440, "town": _town_name(s), "kind": kind,
		"saved": Time.get_unix_time_from_system()}

## Saves the world to `path` and writes its info file, all at once. Returns the save result.
static func save(sim: RefCounted, path: String, kind: String) -> Dictionary:
	return write(sim.snapshot(), info_for(sim.state, kind), path)

## The slow part of a save (checksum, write, verify: about a third of a second for the real world),
## on a private snapshot, so it can run on a background thread. Copying the world first is the
## only part that must happen on the main thread (about 12 ms).
static func write(data: Dictionary, save_info: Dictionary, path: String) -> Dictionary:
	var result: Dictionary = Save.save_snapshot(data, path)
	if result.ok:
		var file := FileAccess.open(path + ".info", FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(save_info))
			file.close()
	return result

static func info(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var text := FileAccess.get_file_as_string(path + ".info")
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if parsed is Dictionary: return parsed
	# A save from before info files existed: still offered, dated by the file itself.
	return {"day": 0, "minute": -1, "town": "", "kind": "save", "saved": float(FileAccess.get_modified_time(path))}

## The most recently written save in `dir` (and any `extra` save files), as {"path", "info"}, or {} when there is none.
static func newest(dir: String = "user://", extra: Array = []) -> Dictionary:
	var best: Dictionary = {}
	for path in paths(dir) + extra:
		var data := info(path)
		if data.is_empty(): continue
		if best.is_empty() or float(data.saved) > float(best.info.saved): best = {"path": path, "info": data}
	return best

## The autosave file to write next: a missing one first, otherwise the older of the two.
static func next_autosave(dir: String = "user://") -> String:
	var a: String = dir.path_join(AUTOS[0])
	var b: String = dir.path_join(AUTOS[1])
	var info_a := info(a)
	var info_b := info(b)
	if info_a.is_empty(): return a
	if info_b.is_empty(): return b
	return a if float(info_a.saved) <= float(info_b.saved) else b

## True on the first frame of a new morning (06:00 or later) that hasn't been autosaved yet.
static func autosave_due(s: Dictionary, last_day: int) -> bool:
	var tick: int = int(s.get("tick", 0))
	var day: int = tick / DAY_TICKS
	var minute: int = (tick / 10) % 1440
	return day != last_day and minute >= AUTOSAVE_MINUTE and minute < AUTOSAVE_MINUTE + 120

## "Day 3 · 07:40 · Reedbank".
static func describe(data: Dictionary) -> String:
	var parts: Array = []
	if int(data.get("day", 0)) > 0: parts.append("Day %d" % int(data.day))
	var minute: int = int(data.get("minute", -1))
	if minute >= 0: parts.append("%02d:%02d" % [minute / 60, minute % 60])
	if not str(data.get("town", "")).is_empty(): parts.append(str(data.town))
	return " · ".join(parts) if not parts.is_empty() else "Saved game"
