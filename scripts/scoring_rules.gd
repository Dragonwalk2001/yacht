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
const PATTERN_FULL_STRAIGHT := "full_straight"
const PATTERN_FULLEST_HOUSE := "fullest_house"
const PATTERN_SIX_KIND := "six_kind"
const PATTERN_SEVEN_KIND := "seven_kind"

const PATTERN_ORDER: Array[String] = [
	PATTERN_SEVEN_KIND,
	PATTERN_SIX_KIND,
	PATTERN_FULLEST_HOUSE,
	PATTERN_FULL_STRAIGHT,
	PATTERN_FIVE_KIND,
	PATTERN_FOUR_KIND,
	PATTERN_FULL_HOUSE,
	PATTERN_LARGE_STRAIGHT,
	PATTERN_SMALL_STRAIGHT,
	PATTERN_THREE_KIND,
	PATTERN_TWO_PAIR,
	PATTERN_PAIR,
	PATTERN_NONE
]

const PATTERN_MULTIPLIERS := {
	PATTERN_NONE: 1.00,
	PATTERN_PAIR: 1.50,
	PATTERN_TWO_PAIR: 2.00,
	PATTERN_THREE_KIND: 3.00,
	PATTERN_SMALL_STRAIGHT: 4.00,
	PATTERN_LARGE_STRAIGHT: 5.00,
	PATTERN_FULL_HOUSE: 6.00,
	PATTERN_FOUR_KIND: 10.00,
	PATTERN_FIVE_KIND: 20.00,
	PATTERN_FULL_STRAIGHT: 30.00,
	PATTERN_FULLEST_HOUSE: 50.00,
	PATTERN_SIX_KIND: 100.00,
	PATTERN_SEVEN_KIND: 200.00
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
	PATTERN_FULL_STRAIGHT: "满顺",
	PATTERN_FULLEST_HOUSE: "四带三",
	PATTERN_SIX_KIND: "六同",
	PATTERN_SEVEN_KIND: "七同"
}


static func evaluate_best_pattern(dice: Array[int]) -> Dictionary:
	if dice.is_empty():
		return {
			"id": PATTERN_NONE,
			"label": LABELS[PATTERN_NONE],
			"multiplier": PATTERN_MULTIPLIERS[PATTERN_NONE],
			"base_score": 0,
			"used_indices": []
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

	var pattern_id := _pick_pattern_id(sorted_dice, count_values, max_same, pair_count)
	var used_indices := _pick_used_indices(dice, sorted_dice, counts, pattern_id)
	return {
		"id": pattern_id,
		"label": LABELS[pattern_id],
		"multiplier": float(PATTERN_MULTIPLIERS[pattern_id]),
		"base_score": _sum_dice(dice),
		"used_indices": used_indices
	}


static func get_pattern_order() -> Array[String]:
	return PATTERN_ORDER.duplicate()


static func _pick_pattern_id(sorted_dice: Array[int], count_values: Array[int], max_same: int, pair_count: int) -> String:
	if max_same >= 7:
		return PATTERN_SEVEN_KIND
	if max_same >= 6:
		return PATTERN_SIX_KIND
	if _is_fullest_house(count_values):
		return PATTERN_FULLEST_HOUSE
	if _is_full_straight(sorted_dice):
		return PATTERN_FULL_STRAIGHT
	if max_same >= 5:
		return PATTERN_FIVE_KIND
	if max_same >= 4:
		return PATTERN_FOUR_KIND
	if _is_full_house(count_values):
		return PATTERN_FULL_HOUSE
	if _is_large_straight(sorted_dice):
		return PATTERN_LARGE_STRAIGHT
	if _is_small_straight(sorted_dice):
		return PATTERN_SMALL_STRAIGHT
	if max_same >= 3:
		return PATTERN_THREE_KIND
	if pair_count >= 2:
		return PATTERN_TWO_PAIR
	if pair_count >= 1:
		return PATTERN_PAIR
	return PATTERN_NONE


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


static func _is_full_straight(sorted_dice: Array[int]) -> bool:
	var unique_sorted := _unique_sorted(sorted_dice)
	return unique_sorted == [1, 2, 3, 4, 5, 6]


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


static func _is_fullest_house(count_values: Array[int]) -> bool:
	if count_values.size() < 2:
		return false
	var has_four := false
	var has_three := false
	for value in count_values:
		if value >= 4 and not has_four:
			has_four = true
			continue
		if value >= 3:
			has_three = true
	return has_four and has_three


static func _pick_used_indices(dice: Array[int], sorted_dice: Array[int], counts: Dictionary, pattern_id: String) -> Array[int]:
	match pattern_id:
		PATTERN_PAIR:
			return _indices_for_top_groups(dice, counts, [2])
		PATTERN_TWO_PAIR:
			return _indices_for_top_groups(dice, counts, [2, 2])
		PATTERN_THREE_KIND:
			return _indices_for_top_groups(dice, counts, [3])
		PATTERN_FOUR_KIND:
			return _indices_for_top_groups(dice, counts, [4])
		PATTERN_FIVE_KIND:
			return _indices_for_top_groups(dice, counts, [5])
		PATTERN_SIX_KIND:
			return _indices_for_top_groups(dice, counts, [6])
		PATTERN_SEVEN_KIND:
			return _indices_for_top_groups(dice, counts, [7])
		PATTERN_FULL_HOUSE:
			return _indices_for_top_groups(dice, counts, [3, 2])
		PATTERN_FULLEST_HOUSE:
			return _indices_for_top_groups(dice, counts, [4, 3])
		PATTERN_SMALL_STRAIGHT:
			return _indices_for_straight(dice, sorted_dice, 4)
		PATTERN_LARGE_STRAIGHT:
			return _indices_for_straight(dice, sorted_dice, 5)
		PATTERN_FULL_STRAIGHT:
			return _indices_for_exact_values(dice, [1, 2, 3, 4, 5, 6])
		_:
			var all_indices: Array[int] = []
			for i in range(dice.size()):
				all_indices.append(i)
			return all_indices


static func _indices_for_top_groups(dice: Array[int], counts: Dictionary, groups: Array[int]) -> Array[int]:
	var chosen_values: Array[int] = []
	var used_values := {}
	for need in groups:
		var best_value := -1
		var best_count := -1
		for value in counts.keys():
			if used_values.has(value):
				continue
			var c := int(counts[value])
			if c < int(need):
				continue
			if c > best_count or (c == best_count and int(value) > best_value):
				best_count = c
				best_value = int(value)
		if best_value >= 0:
			chosen_values.append(best_value)
			used_values[best_value] = true
	var value_targets := {}
	for idx in range(groups.size()):
		if idx < chosen_values.size():
			value_targets[chosen_values[idx]] = int(groups[idx])
	var out: Array[int] = []
	for i in range(dice.size()):
		var value := dice[i]
		if not value_targets.has(value):
			continue
		if int(value_targets[value]) <= 0:
			continue
		out.append(i)
		value_targets[value] = int(value_targets[value]) - 1
	out.sort()
	return out


static func _indices_for_straight(dice: Array[int], sorted_dice: Array[int], length: int) -> Array[int]:
	var unique_sorted := _unique_sorted(sorted_dice)
	var targets: Array[int] = []
	if length == 4:
		if _contains_sequence(unique_sorted, [1, 2, 3, 4]):
			targets = [1, 2, 3, 4]
		elif _contains_sequence(unique_sorted, [2, 3, 4, 5]):
			targets = [2, 3, 4, 5]
		elif _contains_sequence(unique_sorted, [3, 4, 5, 6]):
			targets = [3, 4, 5, 6]
	elif length == 5:
		if unique_sorted == [1, 2, 3, 4, 5]:
			targets = [1, 2, 3, 4, 5]
		elif unique_sorted == [2, 3, 4, 5, 6]:
			targets = [2, 3, 4, 5, 6]
	if targets.is_empty():
		return []
	return _indices_for_exact_values(dice, targets)


static func _indices_for_exact_values(dice: Array[int], targets: Array[int]) -> Array[int]:
	var need := {}
	for value in targets:
		need[value] = int(need.get(value, 0)) + 1
	var out: Array[int] = []
	for i in range(dice.size()):
		var value := dice[i]
		if not need.has(value):
			continue
		if int(need[value]) <= 0:
			continue
		out.append(i)
		need[value] = int(need[value]) - 1
	out.sort()
	return out


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
