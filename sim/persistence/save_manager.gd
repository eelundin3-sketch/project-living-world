extends RefCounted
const Canonical = preload("res://sim/core/canonical.gd")
const Invariants = preload("res://sim/diagnostics/invariants.gd")
const FORMAT_VERSION: int = 2

static func save_state(sim: RefCounted, path: String) -> Dictionary:
	var data: Dictionary = sim.snapshot()
	var envelope := {"format": FORMAT_VERSION, "engine": Engine.get_version_info().string,
		"hash": Canonical.hash_state(data), "state": data}
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Cannot write save: %s" % FileAccess.get_open_error()}
	file.store_var(envelope, false)
	file.flush()
	file.close()
	var verified := read_state(temporary)
	if not verified.ok:
		return verified
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			return {"ok": false, "error": "Backup failed"}
	var error := DirAccess.rename_absolute(temporary, path)
	return {"ok": error == OK, "error": "" if error == OK else "Atomic replace failed"}

static func read_state(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Save not found"}
	if file.get_length() > 67108864:
		file.close()
		return {"ok": false, "error": "Save exceeds 64 MB limit"}
	var value: Variant = file.get_var(false)
	file.close()
	if not value is Dictionary or not value.has_all(["format", "hash", "state", "engine"]):
		return {"ok": false, "error": "Invalid save envelope"}
	if value.format not in [1, FORMAT_VERSION] or not value.state is Dictionary:
		return {"ok": false, "error": "Unsupported save format"}
	if Canonical.hash_state(value.state) != value.hash:
		return {"ok": false, "error": "Save checksum mismatch"}
	if not value.state.has_all(["tick", "seed", "next_id", "entities", "commands", "events", "rng"]):
		return {"ok": false, "error": "Missing core state"}
	var schema_error := validate_schema(value.state)
	if not schema_error.is_empty():
		return {"ok": false, "error": schema_error}
	if value.format == 1:
		value.state.format_version = 2
		value.state["ticks_per_minute"] = value.state.get("ticks_per_minute", 10)
	if value.engine != Engine.get_version_info().string:
		return {"ok": false, "error": "Save requires engine " + str(value.engine)}
	var errors := Invariants.validate(value.state)
	if not errors.is_empty():
		return {"ok": false, "error": "; ".join(errors)}
	return {"ok": true, "error": "", "state": value.state}

static func load_into(sim: RefCounted, path: String) -> Dictionary:
	var result := read_state(path)
	if not result.ok and FileAccess.file_exists(path + ".bak"):
		result = read_state(path + ".bak")
		result["recovered_backup"] = result.ok
	if result.ok:
		sim.restore(result.state)
	return result

static func validate_schema(s: Dictionary) -> String:
	for field in ["tick", "seed", "next_id"]:
		if not s[field] is int or (field != "seed" and s[field] < 0):
			return "Invalid core integer: " + field
	for field in ["entities", "rng"]:
		if not s[field] is Dictionary:
			return "Invalid map: " + field
	for field in ["commands", "events"]:
		if not s[field] is Array:
			return "Invalid queue: " + field
		for entry in s[field]:
			if not entry is Dictionary or not entry.has_all(["id", "due", "kind", "payload"]):
				return "Malformed queue entry"
			if not entry.id is int or not entry.due is int or not entry.kind is String or not entry.payload is Dictionary:
				return "Invalid queue entry types"
	for entity in s.entities.values():
		if not entity is Dictionary or not entity.get("id") is int:
			return "Invalid entity identity"
		if entity.has("cell"):
			if not entity.cell is Array or entity.cell.size() != 2 or not entity.cell[0] is int or not entity.cell[1] is int:
				return "Invalid integer cell"
	if s.has("inventories"):
		if not s.inventories is Dictionary or not s.get("accounting") is Dictionary:
			return "Invalid inventory store"
		for field in ["initial", "created", "consumed"]:
			if not s.accounting.get(field) is Dictionary:
				return "Invalid material accounting"
		for inventory in s.inventories.values():
			if not inventory is Dictionary or not inventory.has_all(["capacity", "items", "reserved"]):
				return "Invalid inventory record"
			if not inventory.capacity is int or inventory.capacity < 0 or not inventory.items is Dictionary or not inventory.reserved is Dictionary:
				return "Invalid inventory fields"
			for quantity in inventory.items.values() + inventory.reserved.values():
				if not quantity is int or quantity < 0:
					return "Invalid item quantity"
	if s.has("residents"):
		if not s.residents is Dictionary or not s.get("jobs") is Dictionary:
			return "Invalid resident/job store"
		for npc in s.residents.values():
			if not npc is Dictionary or not npc.has_all(["id", "hunger", "fatigue", "job", "path", "goal", "fidelity"]):
				return "Invalid resident record"
			for field in ["id", "hunger", "fatigue", "job"]:
				if not npc[field] is int:
					return "Invalid resident numeric field"
			if not npc.path is Array or not npc.goal is String:
				return "Invalid resident action"
		for job in s.jobs.values():
			if not job is Dictionary or not job.has_all(["id", "target", "destination", "owner", "lease_until"]):
				return "Invalid job record"
			for field in ["id", "target", "destination", "owner", "lease_until"]:
				if not job[field] is int:
					return "Invalid job numeric field"
	return ""
