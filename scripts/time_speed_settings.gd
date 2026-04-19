extends RefCounted

const MIN_MULT: int = 1
const MAX_MULT: int = 10


static func clamp_mult(value: int) -> int:
	return clampi(value, MIN_MULT, MAX_MULT)


static func apply_engine_multiplier(mult: int) -> void:
	Engine.time_scale = float(clamp_mult(mult))
