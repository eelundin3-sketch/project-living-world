extends RefCounted
## Validated data-only mod surface; never evaluates external scripts.
static func read_recipe(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Recipe file not found"}
	var text := FileAccess.get_file_as_string(path)
	if text.length() > 65536:
		return {"ok": false, "error": "Recipe file too large"}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or not parsed.has_all(["id", "input", "input_quantity", "output", "output_quantity", "work_ticks"]):
		return {"ok": false, "error": "Recipe fields missing"}
	if not parsed.id is String or not parsed.id.begins_with("mod:recipe/"):
		return {"ok": false, "error": "Use a mod:recipe/ identifier"}
	if parsed.input not in ["log", "food", "plank"] or parsed.output not in ["log", "food", "plank"]:
		return {"ok": false, "error": "Unknown item"}
	for field in ["input_quantity", "output_quantity", "work_ticks"]:
		if not (parsed[field] is int or parsed[field] is float) or int(parsed[field]) != parsed[field] or parsed[field] < 1 or parsed[field] > 10000:
			return {"ok": false, "error": "Recipe quantities and work must be positive integers"}
		parsed[field] = int(parsed[field])
	if parsed.input_quantity > 10 or parsed.output_quantity > 100:
		return {"ok": false, "error": "Recipe exceeds prototype carrier/workshop capacity"}
	return {"ok": true, "error": "", "recipe": parsed}
