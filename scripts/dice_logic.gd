class_name DiceLogic
extends RefCounted

const DICE_COUNT: int = 5


static func create_default_dice() -> Array[int]:
	return [1, 1, 1, 1, 1]


static func create_default_holds() -> Array[bool]:
	return [false, false, false, false, false]


static func roll_dice(values: Array[int], holds: Array[bool]) -> Array[int]:
	var next_values := values.duplicate()
	for index in range(DICE_COUNT):
		if index >= next_values.size():
			next_values.append(1)
		if index >= holds.size() or not holds[index]:
			next_values[index] = randi_range(1, 6)
	return next_values


static func toggle_hold(holds: Array[bool], index: int) -> Array[bool]:
	var next_holds := holds.duplicate()
	if index >= 0 and index < next_holds.size():
		next_holds[index] = not next_holds[index]
	return next_holds
