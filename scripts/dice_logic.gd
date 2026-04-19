class_name DiceLogic
extends RefCounted

const FACE_MIN: int = 1
const FACE_MAX: int = 6


static func create_default_dice(count: int) -> Array[int]:
	var safe_count := maxi(1, count)
	var result: Array[int] = []
	for _i in range(safe_count):
		result.append(1)
	return result


static func create_default_holds(count: int) -> Array[bool]:
	var safe_count := maxi(1, count)
	var result: Array[bool] = []
	for _i in range(safe_count):
		result.append(false)
	return result


static func roll_dice(values: Array[int], holds: Array[bool]) -> Array[int]:
	var next_values := values.duplicate()
	for index in range(next_values.size()):
		if index >= next_values.size():
			next_values.append(1)
		if index >= holds.size() or not holds[index]:
			next_values[index] = randi_range(FACE_MIN, FACE_MAX)
	return next_values


static func toggle_hold(holds: Array[bool], index: int) -> Array[bool]:
	var next_holds := holds.duplicate()
	if index >= 0 and index < next_holds.size():
		next_holds[index] = not next_holds[index]
	return next_holds


static func roll_fresh_dice(count: int) -> Array[int]:
	var values := create_default_dice(count)
	for index in range(values.size()):
		values[index] = randi_range(FACE_MIN, FACE_MAX)
	return values
