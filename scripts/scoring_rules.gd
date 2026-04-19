class_name ScoringRules
extends RefCounted

const PATTERN_NONE := "none"
const PATTERN_PAIR := "pair"
const PATTERN_TWO_PAIR := "two_pair"
const PATTERN_THREE_KIND := "three_kind"
const PATTERN_SMALL_STRAIGHT := "small_straight"
const PATTERN_LARGE_STRAIGHT := "large_straight"
const PATTERN_FULL_HOUSE := "full_house"
const PATTERN_FOUR_KIND := "four_kind"
const PATTERN_FIVE_KIND := "five_kind"
const PATTERN_SIX_KIND := "six_kind"
const PATTERN_SEVEN_KIND := "seven_kind"

const PATTERN_ORDER: Array[String] = [
	PATTERN_NONE,
	PATTERN_PAIR,
	PATTERN_TWO_PAIR,
	PATTERN_THREE_KIND,
	PATTERN_SMALL_STRAIGHT,
	PATTERN_LARGE_STRAIGHT,
	PATTERN_FULL_HOUSE,
	PATTERN_FOUR_KIND,
	PATTERN_FIVE_KIND,
	PATTERN_SIX_KIND,
	PATTERN_SEVEN_KIND
]

const PATTERN_MULTIPLIERS := {
	PATTERN_NONE: 1.00,
	PATTERN_PAIR: 1.25,
	PATTERN_TWO_PAIR: 1.50,
	PATTERN_THREE_KIND: 1.90,
	PATTERN_SMALL_STRAIGHT: 2.20,
	PATTERN_LARGE_STRAIGHT: 2.70,
	PATTERN_FULL_HOUSE: 3.10,
	PATTERN_FOUR_KIND: 3.90,
	PATTERN_FIVE_KIND: 5.20,
	PATTERN_SIX_KIND: 7.00,
	PATTERN_SEVEN_KIND: 9.00
}

const LABELS := {
	PATTERN_NONE: "散点",
	PATTERN_PAIR: "一对",
	PATTERN_TWO_PAIR: "两对",
	PATTERN_THREE_KIND: "三条",
	PATTERN_SMALL_STRAIGHT: "小顺",
	PATTERN_LARGE_STRAIGHT: "大顺",
	PATTERN_FULL_HOUSE: "葫芦",
	PATTERN_FOUR_KIND: "四条",
	PATTERN_FIVE_KIND: "五同",
	PATTERN_SIX_KIND: "六同",
	PATTERN_SEVEN_KIND: "七同"
}


static func evaluate_best_pattern(dice: Array[int]) -> Dictionary:
	if dice.is_empty():
		return {
			"id": PATTERN_NONE,
			"label": LABELS[PATTERN_NONE],
			"multiplier": PATTERN_MULTIPLIERS[PATTERN_NONE],
			"base_score": 0
		}

	var sorted_dice := dice.duplicate()
	sorted_dice.sort()
	var counts := _counts(dice)
	var count_values: Array[int] = []
	for value in counts.values():
		count_values.append(int(value))
	count_values.sort()
	count_values.reverse()
	var max_same := count_values[0]
	var pair_count := 0
	for value in count_values:
		if value >= 2:
			pair_count += 1

	var pattern_id := PATTERN_NONE
	if max_same >= 7:
		pattern_id = PATTERN_SEVEN_KIND
	elif max_same >= 6:
		pattern_id = PATTERN_SIX_KIND
	elif max_same >= 5:
		pattern_id = PATTERN_FIVE_KIND
	elif max_same >= 4:
		pattern_id = PATTERN_FOUR_KIND
	elif _is_full_house(count_values):
		pattern_id = PATTERN_FULL_HOUSE
	elif _is_large_straight(sorted_dice):
		pattern_id = PATTERN_LARGE_STRAIGHT
	elif _is_small_straight(sorted_dice):
		pattern_id = PATTERN_SMALL_STRAIGHT
	elif max_same >= 3:
		pattern_id = PATTERN_THREE_KIND
	elif pair_count >= 2:
		pattern_id = PATTERN_TWO_PAIR
	elif pair_count >= 1:
		pattern_id = PATTERN_PAIR

	return {
		"id": pattern_id,
		"label": LABELS[pattern_id],
		"multiplier": float(PATTERN_MULTIPLIERS[pattern_id]),
		"base_score": _sum_dice(dice)
	}


static func _is_small_straight(sorted_dice: Array[int]) -> bool:
	var unique_sorted := _unique_sorted(sorted_dice)
	if _contains_sequence(unique_sorted, [1, 2, 3, 4]) \
		or _contains_sequence(unique_sorted, [2, 3, 4, 5]) \
		or _contains_sequence(unique_sorted, [3, 4, 5, 6]):
		return true
	return false


static func _is_large_straight(sorted_dice: Array[int]) -> bool:
	var unique_sorted := _unique_sorted(sorted_dice)
	return unique_sorted == [1, 2, 3, 4, 5] or unique_sorted == [2, 3, 4, 5, 6]


static func _is_full_house(count_values: Array[int]) -> bool:
	if count_values.size() < 2:
		return false
	var has_three := false
	var has_pair := false
	for value in count_values:
		if value >= 3 and not has_three:
			has_three = true
		elif value >= 2:
			has_pair = true
	return has_three and has_pair


static func _sum_dice(dice: Array[int]) -> int:
	var total := 0
	for value in dice:
		total += value
	return total


static func _counts(dice: Array[int]) -> Dictionary:
	var result := {}
	for value in dice:
		result[value] = int(result.get(value, 0)) + 1
	return result


static func _unique_sorted(sorted_dice: Array[int]) -> Array[int]:
	var unique: Array[int] = []
	for value in sorted_dice:
		if unique.is_empty() or unique[-1] != value:
			unique.append(value)
	return unique


static func _contains_sequence(source: Array[int], sequence: Array[int]) -> bool:
	for value in sequence:
		if not source.has(value):
			return false
	return true
