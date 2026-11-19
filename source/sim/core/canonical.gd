extends RefCounted
## Stable serialization for same-engine replay checks, independent of map insertion order.

static func encode(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var parts := PackedStringArray()
		for key in keys:
			parts.append(JSON.stringify(str(key)) + ":" + encode(value[key]))
		return "{" + ",".join(parts) + "}"
	if value is Array:
		var parts := PackedStringArray()
		for element in value:
			parts.append(encode(element))
		return "[" + ",".join(parts) + "]"
	return JSON.stringify(value)


static func hash_state(value: Dictionary) -> String:
	return encode(value).sha256_text()
