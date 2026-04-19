class_name GameState
extends RefCounted

const MAX_ROLLS_PER_TURN: int = 3
const MIN_DICE_COUNT: int = 1
const MAX_DICE_COUNT: int = 7
const MIN_TABLE_COUNT: int = 1
const MAX_TABLE_COUNT: int = 8
const BASE_AUTO_INTERVAL: float = 2.2
const MIN_AUTO_INTERVAL: float = 0.45
const AUTO_INTERVAL_STEP: float = 0.2

var coin_1: int = 0
var total_coin_earned: int = 0
var current_rolls_used: int = 0
var current_dice_values: Array[int] = []
var current_holds: Array[bool] = []
var table_count: int = MIN_TABLE_COUNT
var dice_count: int = MIN_DICE_COUNT
var auto_unlocked: bool = false
var auto_enabled: bool = false
var auto_speed_level: int = 0
var total_manual_turns: int = 0
var total_auto_turns: int = 0
var last_settlement_label: String = "未结算"
var last_settlement_income: int = 0
var last_settlement_base: int = 0
var last_settlement_multiplier: float = 1.0
var recent_income_window: Array[Dictionary] = []

func initialize() -> void:
	coin_1 = 0
	total_coin_earned = 0
	current_rolls_used = 0
	dice_count = MIN_DICE_COUNT
	table_count = MIN_TABLE_COUNT
	auto_unlocked = false
	auto_enabled = false
	auto_speed_level = 0
	total_manual_turns = 0
	total_auto_turns = 0
	last_settlement_label = "未结算"
	last_settlement_income = 0
	last_settlement_base = 0
	last_settlement_multiplier = 1.0
	recent_income_window.clear()
	_reset_manual_turn()


func _reset_manual_turn() -> void:
	current_rolls_used = 0
	current_dice_values = DiceLogic.create_default_dice(dice_count)
	current_holds = DiceLogic.create_default_holds(dice_count)


func can_manual_roll() -> bool:
	return current_rolls_used < MAX_ROLLS_PER_TURN


func can_settle_manual() -> bool:
	return current_rolls_used > 0


func toggle_hold(index: int) -> void:
	if current_rolls_used <= 0:
		return
	current_holds = DiceLogic.toggle_hold(current_holds, index)


func roll_manual() -> Dictionary:
	if not can_manual_roll():
		return {"ok": false, "message": "本回合重投次数已用完，请先结算。"}
	current_dice_values = DiceLogic.roll_dice(current_dice_values, current_holds)
	current_rolls_used += 1
	return {"ok": true}


func settle_manual_turn() -> Dictionary:
	if not can_settle_manual():
		return {"ok": false, "message": "请至少掷骰一次后再结算。"}
	var snapshot := _evaluate_income_for_dice(current_dice_values)
	var income := int(snapshot["income"])
	var total_income := income
	for _table_index in range(table_count - 1):
		total_income += _simulate_background_table_income()
	_add_coin(total_income)
	total_manual_turns += 1
	last_settlement_label = String(snapshot["label"])
	last_settlement_base = int(snapshot["base"])
	last_settlement_multiplier = float(snapshot["multiplier"])
	last_settlement_income = total_income
	_record_income_event(total_income)
	_reset_manual_turn()
	return {
		"ok": true,
		"income": total_income,
		"pattern_label": last_settlement_label
	}


func run_auto_tick() -> Dictionary:
	if not auto_unlocked or not auto_enabled:
		return {"ok": false}
	var turns_done := 0
	var total_income := 0
	for _table_index in range(table_count):
		total_income += _simulate_auto_table_income()
		turns_done += 1
	_add_coin(total_income)
	total_auto_turns += turns_done
	last_settlement_label = "自动结算"
	last_settlement_base = 0
	last_settlement_multiplier = get_progress_multiplier()
	last_settlement_income = total_income
	_record_income_event(total_income)
	return {
		"ok": true,
		"income": total_income,
		"turns": turns_done
	}


func get_dice_upgrade_cost() -> int:
	if dice_count >= MAX_DICE_COUNT:
		return -1
	return int(35 * pow(1.75, dice_count - MIN_DICE_COUNT))


func can_upgrade_dice() -> bool:
	var cost := get_dice_upgrade_cost()
	return cost > 0 and coin_1 >= cost


func upgrade_dice_count() -> Dictionary:
	var cost := get_dice_upgrade_cost()
	if cost <= 0:
		return {"ok": false, "message": "骰子数量已达上限。"}
	if coin_1 < cost:
		return {"ok": false, "message": "货币1不足。"}
	coin_1 -= cost
	dice_count += 1
	_reset_manual_turn()
	return {"ok": true}


func get_table_upgrade_cost() -> int:
	if table_count >= MAX_TABLE_COUNT:
		return -1
	return int(80 * pow(1.95, table_count - MIN_TABLE_COUNT))


func can_upgrade_table() -> bool:
	var cost := get_table_upgrade_cost()
	return cost > 0 and coin_1 >= cost


func upgrade_table_count() -> Dictionary:
	var cost := get_table_upgrade_cost()
	if cost <= 0:
		return {"ok": false, "message": "骰桌数量已达上限。"}
	if coin_1 < cost:
		return {"ok": false, "message": "货币1不足。"}
	coin_1 -= cost
	table_count += 1
	return {"ok": true}


func get_auto_unlock_cost() -> int:
	return 220


func can_unlock_auto() -> bool:
	return (not auto_unlocked) and coin_1 >= get_auto_unlock_cost()


func unlock_auto() -> Dictionary:
	if auto_unlocked:
		return {"ok": false, "message": "自动扔骰已解锁。"}
	var cost := get_auto_unlock_cost()
	if coin_1 < cost:
		return {"ok": false, "message": "货币1不足。"}
	coin_1 -= cost
	auto_unlocked = true
	auto_enabled = true
	return {"ok": true}


func get_auto_speed_upgrade_cost() -> int:
	if not auto_unlocked:
		return -1
	return int(120 * pow(1.8, auto_speed_level))


func can_upgrade_auto_speed() -> bool:
	var cost := get_auto_speed_upgrade_cost()
	return cost > 0 and coin_1 >= cost


func upgrade_auto_speed() -> Dictionary:
	var cost := get_auto_speed_upgrade_cost()
	if cost <= 0:
		return {"ok": false, "message": "自动系统尚未解锁。"}
	if coin_1 < cost:
		return {"ok": false, "message": "货币1不足。"}
	coin_1 -= cost
	auto_speed_level += 1
	return {"ok": true}


func get_auto_interval() -> float:
	if not auto_unlocked:
		return BASE_AUTO_INTERVAL
	return maxf(MIN_AUTO_INTERVAL, BASE_AUTO_INTERVAL - AUTO_INTERVAL_STEP * float(auto_speed_level))


func get_progress_multiplier() -> float:
	var dice_factor := 1.0 + (float(dice_count - MIN_DICE_COUNT) * 0.16)
	var table_factor := 1.0 + (float(table_count - MIN_TABLE_COUNT) * 0.10)
	return dice_factor * table_factor


func estimate_income_per_second() -> float:
	if recent_income_window.size() < 2:
		return 0.0
	var now_msec := Time.get_ticks_msec()
	var total_income := 0.0
	for row in recent_income_window:
		total_income += float(row["income"])
	var oldest_msec := int(recent_income_window[0]["tick"])
	var delta_sec := maxf(0.1, float(now_msec - oldest_msec) / 1000.0)
	return total_income / delta_sec


func _simulate_auto_table_income() -> int:
	var dice := DiceLogic.roll_fresh_dice(dice_count)
	# Auto keeps strong dice on rerolls to emulate simple strategy.
	for _i in range(MAX_ROLLS_PER_TURN - 1):
		var holds: Array[bool] = []
		for value in dice:
			holds.append(value >= 5)
		dice = DiceLogic.roll_dice(dice, holds)
	var snapshot := _evaluate_income_for_dice(dice)
	return int(snapshot["income"])


func _simulate_background_table_income() -> int:
	var dice := DiceLogic.roll_fresh_dice(dice_count)
	var snapshot := _evaluate_income_for_dice(dice)
	return int(snapshot["income"])


func _evaluate_income_for_dice(dice: Array[int]) -> Dictionary:
	var eval := ScoringRules.evaluate_best_pattern(dice)
	var base_score := int(eval["base_score"])
	var pattern_multiplier := float(eval["multiplier"])
	var progress_multiplier := get_progress_multiplier()
	var income := int(round(float(base_score) * pattern_multiplier * progress_multiplier))
	return {
		"label": String(eval["label"]),
		"base": base_score,
		"multiplier": pattern_multiplier,
		"income": maxi(1, income)
	}


func _add_coin(amount: int) -> void:
	var safe_amount := maxi(0, amount)
	coin_1 += safe_amount
	total_coin_earned += safe_amount


func _record_income_event(amount: int) -> void:
	recent_income_window.append({
		"income": amount,
		"tick": Time.get_ticks_msec()
	})
	while recent_income_window.size() > 12:
		recent_income_window.remove_at(0)


func to_save_data() -> Dictionary:
	return {
		"coin_1": coin_1,
		"total_coin_earned": total_coin_earned,
		"current_rolls_used": current_rolls_used,
		"current_dice_values": current_dice_values.duplicate(),
		"current_holds": current_holds.duplicate(),
		"table_count": table_count,
		"dice_count": dice_count,
		"auto_unlocked": auto_unlocked,
		"auto_enabled": auto_enabled,
		"auto_speed_level": auto_speed_level,
		"total_manual_turns": total_manual_turns,
		"total_auto_turns": total_auto_turns,
		"last_settlement_label": last_settlement_label,
		"last_settlement_income": last_settlement_income,
		"last_settlement_base": last_settlement_base,
		"last_settlement_multiplier": last_settlement_multiplier,
		"recent_income_window": recent_income_window.duplicate(true)
	}


func load_from_save_data(data: Dictionary) -> bool:
	if data.is_empty():
		return false

	coin_1 = maxi(0, int(data.get("coin_1", 0)))
	total_coin_earned = maxi(coin_1, int(data.get("total_coin_earned", coin_1)))
	current_rolls_used = clampi(int(data.get("current_rolls_used", 0)), 0, MAX_ROLLS_PER_TURN)
	dice_count = clampi(int(data.get("dice_count", MIN_DICE_COUNT)), MIN_DICE_COUNT, MAX_DICE_COUNT)
	table_count = clampi(int(data.get("table_count", MIN_TABLE_COUNT)), MIN_TABLE_COUNT, MAX_TABLE_COUNT)
	auto_unlocked = bool(data.get("auto_unlocked", false))
	auto_enabled = bool(data.get("auto_enabled", false)) and auto_unlocked
	auto_speed_level = maxi(0, int(data.get("auto_speed_level", 0)))
	total_manual_turns = maxi(0, int(data.get("total_manual_turns", 0)))
	total_auto_turns = maxi(0, int(data.get("total_auto_turns", 0)))
	last_settlement_label = String(data.get("last_settlement_label", "未结算"))
	last_settlement_income = maxi(0, int(data.get("last_settlement_income", 0)))
	last_settlement_base = maxi(0, int(data.get("last_settlement_base", 0)))
	last_settlement_multiplier = maxf(1.0, float(data.get("last_settlement_multiplier", 1.0)))

	current_dice_values = []
	var saved_dice: Array = data.get("current_dice_values", [])
	for value in saved_dice:
		current_dice_values.append(clampi(int(value), DiceLogic.FACE_MIN, DiceLogic.FACE_MAX))

	current_holds = []
	var saved_holds: Array = data.get("current_holds", [])
	for value in saved_holds:
		current_holds.append(bool(value))

	if current_dice_values.size() != dice_count:
		current_dice_values = DiceLogic.create_default_dice(dice_count)
	if current_holds.size() != dice_count:
		current_holds = DiceLogic.create_default_holds(dice_count)

	recent_income_window = []
	var saved_window: Array = data.get("recent_income_window", [])
	for row in saved_window:
		if row is Dictionary and row.has("income") and row.has("tick"):
			recent_income_window.append({
				"income": maxi(0, int(row["income"])),
				"tick": int(row["tick"])
			})
	if recent_income_window.size() > 12:
		recent_income_window = recent_income_window.slice(recent_income_window.size() - 12, recent_income_window.size())

	return true
