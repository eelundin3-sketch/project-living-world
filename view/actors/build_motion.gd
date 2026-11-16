extends RefCounted
## One build tile, as a sequence: lift the board into place, three hammer blows (wind-up,
## strike, rebound) with the other hand steadying the nail, then lower the tools and check it.
static func build_cycle(phase: float) -> Dictionary:
	var carry: float = 1.0 - smoothstep(0.0, 0.22, phase)
	var raise := 0.0
	var hit := 0.0
	if phase >= 0.22 and phase < 0.88:
		var frac: float = fposmod((phase - 0.22) / 0.66 * 3.0, 1.0)
		if frac < 0.52: raise = smoothstep(0.0, 0.52, frac)
		elif frac < 0.64: raise = 1.0 - smoothstep(0.52, 0.64, frac)
		else: raise = 0.16 * (1.0 - smoothstep(0.64, 1.0, frac))
		hit = smoothstep(0.52, 0.64, frac) * (1.0 - smoothstep(0.64, 0.82, frac))
	return {"carry": carry, "raise": raise, "hit": hit, "check": smoothstep(0.88, 0.95, phase)}

## Hammer blows completed by this point of the tile; used to time the sound.
static func build_strikes(phase: float) -> int:
	var count := 0
	for k in range(3):
		if phase >= 0.22 + 0.66 * (float(k) + 0.64) / 3.0: count += 1
	return count

