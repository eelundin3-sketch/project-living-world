extends RefCounted
## Park–Miller streams use only bounded 64-bit integer operations.
const MODULUS: int = 2147483647

static func next_int(streams: Dictionary, world_seed: int, stream: String, low: int, high: int) -> int:
	assert(high >= low)
	if not streams.has(stream):
		streams[stream] = (abs(world_seed) + (stream.sha256_text().substr(0, 8).hex_to_int() % (MODULUS - 1))) % (MODULUS - 1) + 1
	var value: int = (int(streams[stream]) * 48271) % MODULUS
	streams[stream] = value
	return low + value % (high - low + 1)
