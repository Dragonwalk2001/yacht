class_name ScoringRules
extends RefCounted

const UPPER_CATEGORIES: Array[String] = [
	"ones", "twos", "threes", "fours", "fives", "sixes"
]

const LOWER_CATEGORIES: Array[String] = [
	"four_of_a_kind", "full_house", "small_straight",
	"large_straight", "yacht", "chance"
]

const ALL_CATEGORIES: Array[String] = UPPER_CATEGORIES + LOWER_CATEGORIES

const UPPER_BONUS_THRESHOLD: int = 63
const UPPER_BONUS_SCORE: int = 35

const LABELS := {
	"ones": "一点",
	"twos": "二点",
	"threes": "三点",
	"fours": "四点",
	"fives": "五点",
	"sixes": "六点",
	"four_of_a_kind": "四条",
	"full_house": "葫芦",
	"small_straight": "小顺",
	"large_straight": "大顺",
	"yacht": "快艇",
	"chance": "机会"
}


static func get_label(category: String) -> String:
	return LABELS.get(category, category)


static func score_category(category: String, dice: Array[int]) -> int:
	var sorted_dice := dice.duplicate()
	sorted_dice.sort()
	match category:
		"ones":
			return _score_upper(dice, 1)
		"twos":
			return _score_upper(dice, 2)
		"threes":
			return _score_upper(dice, 3)
		"fours":
			return _score_upper(dice, 4)
		"fives":
			return _score_upper(dice, 5)
		"sixes":
			return _score_upper(dice, 6)
		"four_of_a_kind":
			return _score_four_of_a_kind(dice)
		"full_house":
			return _score_full_house(dice)
		"small_straight":
			return _score_small_straight(sorted_dice)
		"large_straight":
			return _score_large_straight(sorted_dice)
		"yacht":
			return _score_yacht(dice)
		"chance":
			return _sum_dice(dice)
		_:
			return 0


static func _score_upper(dice: Array[int], face: int) -> int:
	var total := 0
	for value in dice:
		if value == face:
			total += face
	return total


static func _score_four_of_a_kind(dice: Array[int]) -> int:
	for count in _counts(dice).values():
		if count >= 4:
			return _sum_dice(dice)
	return 0


static func _score_full_house(dice: Array[int]) -> int:
	var values := _counts(dice).values()
	values.sort()
	if values.size() == 2 and values[0] == 2 and values[1] == 3:
		return 25
	return 0


static func _score_small_straight(sorted_dice: Array[int]) -> int:
	var unique_sorted := _unique_sorted(sorted_dice)
	if _contains_sequence(unique_sorted, [1, 2, 3, 4]) \
		or _contains_sequence(unique_sorted, [2, 3, 4, 5]) \
		or _contains_sequence(unique_sorted, [3, 4, 5, 6]):
		return 30
	return 0


static func _score_large_straight(sorted_dice: Array[int]) -> int:
	var unique_sorted := _unique_sorted(sorted_dice)
	if unique_sorted == [1, 2, 3, 4, 5] or unique_sorted == [2, 3, 4, 5, 6]:
		return 40
	return 0


static func _score_yacht(dice: Array[int]) -> int:
	for count in _counts(dice).values():
		if count == 5:
			return 50
	return 0


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
