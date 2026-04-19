class_name GameState
extends RefCounted

const DiceFaceStatsT := preload("res://scripts/dice_face_stats.gd")

const MAX_ROLLS_PER_TURN: int = 3
const MIN_DICE_COUNT: int = 1
const MAX_DICE_COUNT: int = 7
const MIN_TABLE_COUNT: int = 1
const MAX_TABLE_COUNT: int = 8
const BASE_AUTO_INTERVAL: float = 3.0
const MIN_AUTO_INTERVAL: float = 1.0
const AUTO_INTERVAL_STEP: float = 0.2
const MAX_AUTO_SPEED_LEVEL: int = 10
const AUTO_SPEED_BASE_COST: int = 100

var coin_1: int = 0
var total_coin_earned: int = 0
var table_count: int = MIN_TABLE_COUNT
var auto_unlocked: bool = false
var auto_speed_level: int = 0
var total_manual_turns: int = 0
var total_auto_turns: int = 0
var last_settlement_label: String = "未结算"
var last_settlement_income: int = 0
var last_settlement_base: int = 0
var last_settlement_multiplier: float = 1.0
var recent_income_window: Array[Dictionary] = []
var dice_face_stats = DiceFaceStatsT.new()

var table_dice_counts: Array = []
var table_rolls_used: Array = []
var table_dice_values: Array = []
var table_holds: Array = []
var per_table_auto_enabled: Array = []
var table_auto_staging: Array = []


func initialize() -> void:
	coin_1 = 0
	total_coin_earned = 0
	table_count = MIN_TABLE_COUNT
	auto_unlocked = false
	auto_speed_level = 0
	total_manual_turns = 0
	total_auto_turns = 0
	last_settlement_label = "未结算"
	last_settlement_income = 0
	last_settlement_base = 0
	last_settlement_multiplier = 1.0
	recent_income_window.clear()
	dice_face_stats.reset()
	_reset_all_tables()


func _reset_all_tables() -> void:
	table_dice_counts.clear()
	table_rolls_used.clear()
	table_dice_values.clear()
	table_holds.clear()
	per_table_auto_enabled.clear()
	table_auto_staging.clear()
	for _i in range(table_count):
		table_dice_counts.append(MIN_DICE_COUNT)
		table_rolls_used.append(0)
		table_dice_values.append(DiceLogic.create_default_dice(MIN_DICE_COUNT))
		table_holds.append(DiceLogic.create_default_holds(MIN_DICE_COUNT))
		per_table_auto_enabled.append(false)
		table_auto_staging.append([])


func _ensure_table_index(table_index: int) -> bool:
	return table_index >= 0 and table_index < table_count


func get_table_dice_count(table_index: int) -> int:
	if not _ensure_table_index(table_index):
		return MIN_DICE_COUNT
	return int(table_dice_counts[table_index])


func can_manual_roll(table_index: int) -> bool:
	if not _ensure_table_index(table_index):
		return false
	if auto_unlocked and bool(per_table_auto_enabled[table_index]):
		return false
	return int(table_rolls_used[table_index]) < MAX_ROLLS_PER_TURN


func can_settle_manual(table_index: int) -> bool:
	if not _ensure_table_index(table_index):
		return false
	if auto_unlocked and bool(per_table_auto_enabled[table_index]):
		return false
	return int(table_rolls_used[table_index]) > 0


func toggle_hold(table_index: int, die_index: int) -> void:
	if not _ensure_table_index(table_index):
		return
	if int(table_rolls_used[table_index]) <= 0:
		return
	if auto_unlocked and bool(per_table_auto_enabled[table_index]):
		return
	var holds: Array = table_holds[table_index]
	table_holds[table_index] = DiceLogic.toggle_hold(holds, die_index)


func roll_manual(table_index: int) -> Dictionary:
	if not can_manual_roll(table_index):
		if auto_unlocked and bool(per_table_auto_enabled[table_index]):
			return {"ok": false, "message": "该桌已开启自动，请先关闭本桌自动。"}
		return {"ok": false, "message": "本回合重投次数已用完，请先结算。"}
	var values: Array = table_dice_values[table_index]
	var holds: Array = table_holds[table_index]
	var next_values := DiceLogic.roll_dice(values, holds)
	dice_face_stats.record_rerolled_only(holds, next_values)
	table_dice_values[table_index] = next_values
	table_rolls_used[table_index] = int(table_rolls_used[table_index]) + 1
	return {"ok": true}


func settle_manual_turn(table_index: int) -> Dictionary:
	if not can_settle_manual(table_index):
		return {"ok": false, "message": "请至少掷骰一次后再结算。"}
	var dice := _clone_dice_row(table_dice_values[table_index], get_table_dice_count(table_index))
	var snapshot := _evaluate_income_for_dice(dice)
	var income := int(snapshot["income"])
	_add_coin(income)
	total_manual_turns += 1
	last_settlement_label = String(snapshot["label"])
	last_settlement_base = int(snapshot["base"])
	last_settlement_multiplier = float(snapshot["multiplier"])
	last_settlement_income = income
	_record_income_event(income)
	_reset_table_turn(table_index)
	return {
		"ok": true,
		"income": income,
		"pattern_label": last_settlement_label,
		"table_index": table_index
	}


func begin_auto_throw_for_table(table_index: int) -> Dictionary:
	if not _ensure_table_index(table_index):
		return {"ok": false, "message": "无效骰桌。"}
	if not auto_unlocked or not bool(per_table_auto_enabled[table_index]):
		return {"ok": false, "message": "该桌自动未开启。"}
	var staging: Array = table_auto_staging[table_index]
	if staging.size() > 0:
		return {"ok": false, "message": "该桌已有待完成的自动投掷。"}
	var dice := _build_auto_cycle_dice_for_table(table_index)
	table_auto_staging[table_index] = dice
	return {"ok": true}


func finalize_auto_throw_for_table(table_index: int) -> Dictionary:
	if not _ensure_table_index(table_index):
		return {"ok": false, "message": "无效骰桌。"}
	var staging: Array = table_auto_staging[table_index]
	if staging.is_empty():
		return {"ok": false, "message": "没有待结算的自动投掷。"}
	var dice := _clone_dice_row(staging, get_table_dice_count(table_index))
	var snapshot := _evaluate_income_for_dice(dice)
	var income := int(snapshot["income"])
	table_dice_values[table_index] = dice.duplicate()
	table_auto_staging[table_index] = []
	table_rolls_used[table_index] = 0
	table_holds[table_index] = DiceLogic.create_default_holds(get_table_dice_count(table_index))
	_add_coin(income)
	total_auto_turns += 1
	last_settlement_label = "%s(自动桌%d)" % [String(snapshot["label"]), table_index + 1]
	last_settlement_base = int(snapshot["base"])
	last_settlement_multiplier = float(snapshot["multiplier"])
	last_settlement_income = income
	_record_income_event(income)
	return {
		"ok": true,
		"income": income,
		"pattern_label": last_settlement_label,
		"table_index": table_index
	}


func get_dice_upgrade_cost(table_index: int) -> int:
	if not _ensure_table_index(table_index):
		return -1
	var dc := get_table_dice_count(table_index)
	if dc >= MAX_DICE_COUNT:
		return -1
	return int(35 * pow(1.75, dc - MIN_DICE_COUNT))


func can_upgrade_dice_on_table(table_index: int) -> bool:
	var cost := get_dice_upgrade_cost(table_index)
	return cost > 0 and coin_1 >= cost


func upgrade_dice_on_table(table_index: int) -> Dictionary:
	var cost := get_dice_upgrade_cost(table_index)
	if not _ensure_table_index(table_index):
		return {"ok": false, "message": "无效骰桌。"}
	if cost <= 0:
		return {"ok": false, "message": "该桌骰子数量已达上限。"}
	if coin_1 < cost:
		return {"ok": false, "message": "货币1不足。"}
	coin_1 -= cost
	table_dice_counts[table_index] = int(table_dice_counts[table_index]) + 1
	_reset_table_turn(table_index)
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
	table_dice_counts.append(MIN_DICE_COUNT)
	table_rolls_used.append(0)
	table_dice_values.append(DiceLogic.create_default_dice(MIN_DICE_COUNT))
	table_holds.append(DiceLogic.create_default_holds(MIN_DICE_COUNT))
	per_table_auto_enabled.append(auto_unlocked)
	table_auto_staging.append([])
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
	for i in range(table_count):
		per_table_auto_enabled[i] = true
	return {"ok": true}


func get_auto_speed_upgrade_cost() -> int:
	if not auto_unlocked:
		return -1
	if auto_speed_level >= MAX_AUTO_SPEED_LEVEL:
		return -1
	return AUTO_SPEED_BASE_COST * int(pow(2.0, auto_speed_level))


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


func set_table_auto_enabled(table_index: int, enabled: bool) -> void:
	if not _ensure_table_index(table_index):
		return
	if not auto_unlocked:
		return
	per_table_auto_enabled[table_index] = enabled


func is_table_auto_enabled(table_index: int) -> bool:
	if not _ensure_table_index(table_index):
		return false
	return auto_unlocked and bool(per_table_auto_enabled[table_index])


func get_progress_multiplier() -> float:
	var sum_extra := 0
	for i in range(table_count):
		sum_extra += int(table_dice_counts[i]) - MIN_DICE_COUNT
	var avg_extra := float(sum_extra) / float(maxi(1, table_count))
	var dice_factor := 1.0 + avg_extra * 0.16
	var table_factor := 1.0 + float(table_count - MIN_TABLE_COUNT) * 0.10
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


func _reset_table_turn(table_index: int) -> void:
	if not _ensure_table_index(table_index):
		return
	var dc := get_table_dice_count(table_index)
	table_rolls_used[table_index] = 0
	table_dice_values[table_index] = DiceLogic.create_default_dice(dc)
	table_holds[table_index] = DiceLogic.create_default_holds(dc)
	table_auto_staging[table_index] = []


func _build_auto_cycle_dice_for_table(table_index: int) -> Array[int]:
	var dc := get_table_dice_count(table_index)
	var dice := DiceLogic.roll_fresh_dice(dc)
	dice_face_stats.record_all_faces(dice)
	for _i in range(MAX_ROLLS_PER_TURN - 1):
		var holds: Array[bool] = []
		for value in dice:
			holds.append(value >= 5)
		dice = DiceLogic.roll_dice(dice, holds)
		dice_face_stats.record_rerolled_only(holds, dice)
	return dice


func _clone_dice_row(source: Variant, expected_count: int) -> Array[int]:
	var out: Array[int] = []
	if source is Array:
		for v in source:
			out.append(clampi(int(v), DiceLogic.FACE_MIN, DiceLogic.FACE_MAX))
	if out.size() != expected_count:
		return DiceLogic.create_default_dice(expected_count)
	return out


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
		"version": 2,
		"coin_1": coin_1,
		"total_coin_earned": total_coin_earned,
		"table_count": table_count,
		"auto_unlocked": auto_unlocked,
		"auto_speed_level": auto_speed_level,
		"total_manual_turns": total_manual_turns,
		"total_auto_turns": total_auto_turns,
		"last_settlement_label": last_settlement_label,
		"last_settlement_income": last_settlement_income,
		"last_settlement_base": last_settlement_base,
		"last_settlement_multiplier": last_settlement_multiplier,
		"recent_income_window": recent_income_window.duplicate(true),
		"table_dice_counts": _int_array_to_save(table_dice_counts),
		"table_rolls_used": _int_array_to_save(table_rolls_used),
		"table_dice_values": _nested_dice_to_save(table_dice_values),
		"table_holds": _nested_holds_to_save(table_holds),
		"per_table_auto_enabled": _bool_array_to_save(per_table_auto_enabled),
		"table_auto_staging": _nested_dice_to_save(table_auto_staging)
	}


func load_from_save_data(data: Dictionary) -> bool:
	if data.is_empty():
		return false

	coin_1 = maxi(0, int(data.get("coin_1", 0)))
	total_coin_earned = maxi(coin_1, int(data.get("total_coin_earned", coin_1)))
	table_count = clampi(int(data.get("table_count", MIN_TABLE_COUNT)), MIN_TABLE_COUNT, MAX_TABLE_COUNT)
	auto_unlocked = bool(data.get("auto_unlocked", false))
	auto_speed_level = maxi(0, int(data.get("auto_speed_level", 0)))
	total_manual_turns = maxi(0, int(data.get("total_manual_turns", 0)))
	total_auto_turns = maxi(0, int(data.get("total_auto_turns", 0)))
	last_settlement_label = String(data.get("last_settlement_label", "未结算"))
	last_settlement_income = maxi(0, int(data.get("last_settlement_income", 0)))
	last_settlement_base = maxi(0, int(data.get("last_settlement_base", 0)))
	last_settlement_multiplier = maxf(1.0, float(data.get("last_settlement_multiplier", 1.0)))

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

	var ver := int(data.get("version", 1))
	if ver >= 2:
		_load_v2_tables(data)
	else:
		_migrate_v1_to_v2(data)

	return true


func _load_v2_tables(data: Dictionary) -> void:
	table_dice_counts = _read_int_array(data.get("table_dice_counts", []), MIN_DICE_COUNT, MAX_DICE_COUNT, MIN_DICE_COUNT)
	table_rolls_used = _read_int_array(data.get("table_rolls_used", []), 0, MAX_ROLLS_PER_TURN, 0)
	_normalize_table_arrays()
	table_dice_values = _read_nested_dice(data.get("table_dice_values", []))
	table_holds = _read_nested_holds(data.get("table_holds", []))
	per_table_auto_enabled = _read_bool_array(data.get("per_table_auto_enabled", []))
	table_auto_staging = _read_nested_dice_allow_empty(data.get("table_auto_staging", []))
	_clamp_all_table_rows()


func _migrate_v1_to_v2(data: Dictionary) -> void:
	var legacy_dice := clampi(int(data.get("dice_count", MIN_DICE_COUNT)), MIN_DICE_COUNT, MAX_DICE_COUNT)
	var legacy_rolls := clampi(int(data.get("current_rolls_used", 0)), 0, MAX_ROLLS_PER_TURN)
	var legacy_auto := bool(data.get("auto_enabled", false)) and auto_unlocked
	var saved_dice: Array = data.get("current_dice_values", [])
	var row0: Array[int] = []
	for v in saved_dice:
		row0.append(clampi(int(v), DiceLogic.FACE_MIN, DiceLogic.FACE_MAX))
	if row0.size() != legacy_dice:
		row0 = DiceLogic.create_default_dice(legacy_dice)
	var saved_holds: Array = data.get("current_holds", [])
	var holds0: Array[bool] = []
	for v in saved_holds:
		holds0.append(bool(v))
	if holds0.size() != legacy_dice:
		holds0 = DiceLogic.create_default_holds(legacy_dice)
	table_dice_counts.clear()
	table_rolls_used.clear()
	table_dice_values.clear()
	table_holds.clear()
	per_table_auto_enabled.clear()
	table_auto_staging.clear()
	for i in range(table_count):
		table_dice_counts.append(legacy_dice)
		table_rolls_used.append(legacy_rolls if i == 0 else 0)
		per_table_auto_enabled.append(legacy_auto)
		table_auto_staging.append([])
		if i == 0:
			table_dice_values.append(row0)
			table_holds.append(holds0)
		else:
			table_dice_values.append(DiceLogic.create_default_dice(legacy_dice))
			table_holds.append(DiceLogic.create_default_holds(legacy_dice))
	_clamp_all_table_rows()


func _normalize_table_arrays() -> void:
	while table_dice_counts.size() < table_count:
		table_dice_counts.append(MIN_DICE_COUNT)
	while table_dice_counts.size() > table_count:
		table_dice_counts.pop_back()
	while table_rolls_used.size() < table_count:
		table_rolls_used.append(0)
	while table_rolls_used.size() > table_count:
		table_rolls_used.pop_back()
	while per_table_auto_enabled.size() < table_count:
		per_table_auto_enabled.append(false)
	while per_table_auto_enabled.size() > table_count:
		per_table_auto_enabled.pop_back()
	while table_auto_staging.size() < table_count:
		table_auto_staging.append([])
	while table_auto_staging.size() > table_count:
		table_auto_staging.pop_back()


func _clamp_all_table_rows() -> void:
	_normalize_table_arrays()
	for i in range(table_count):
		var dc := clampi(int(table_dice_counts[i]), MIN_DICE_COUNT, MAX_DICE_COUNT)
		table_dice_counts[i] = dc
		table_rolls_used[i] = clampi(int(table_rolls_used[i]), 0, MAX_ROLLS_PER_TURN)
		table_dice_values[i] = _clone_dice_row(table_dice_values[i], dc)
		table_holds[i] = _normalize_holds_row(table_holds[i], dc)
		var st: Array = table_auto_staging[i]
		if st.size() > 0:
			if st.size() != dc:
				table_auto_staging[i] = []
			else:
				table_auto_staging[i] = _clone_dice_row(st, dc)


func _normalize_holds_row(holds: Variant, count: int) -> Array[bool]:
	var out: Array[bool] = []
	if holds is Array:
		for v in holds:
			out.append(bool(v))
	while out.size() < count:
		out.append(false)
	if out.size() > count:
		out = out.slice(0, count)
	return out


func _int_array_to_save(arr: Array) -> Array:
	var out: Array = []
	for v in arr:
		out.append(int(v))
	return out


func _bool_array_to_save(arr: Array) -> Array:
	var out: Array = []
	for v in arr:
		out.append(bool(v))
	return out


func _nested_dice_to_save(arr: Array) -> Array:
	var out: Array = []
	for row in arr:
		var inner: Array = []
		if row is Array:
			for v in row:
				inner.append(clampi(int(v), DiceLogic.FACE_MIN, DiceLogic.FACE_MAX))
		out.append(inner)
	return out


func _nested_holds_to_save(arr: Array) -> Array:
	var out: Array = []
	for row in arr:
		var inner: Array = []
		if row is Array:
			for v in row:
				inner.append(bool(v))
		out.append(inner)
	return out


func _read_int_array(raw: Variant, lo: int, hi: int, fill: int) -> Array:
	var out: Array = []
	if raw is Array:
		for v in raw:
			out.append(clampi(int(v), lo, hi))
	while out.size() < table_count:
		out.append(fill)
	if out.size() > table_count:
		out = out.slice(0, table_count)
	return out


func _read_bool_array(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for v in raw:
			out.append(bool(v))
	while out.size() < table_count:
		out.append(false)
	if out.size() > table_count:
		out = out.slice(0, table_count)
	return out


func _read_nested_dice(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for row in raw:
			var inner: Array[int] = []
			if row is Array:
				for v in row:
					inner.append(clampi(int(v), DiceLogic.FACE_MIN, DiceLogic.FACE_MAX))
			out.append(inner)
	while out.size() < table_count:
		out.append([])
	if out.size() > table_count:
		return out.slice(0, table_count)
	return out


func _read_nested_holds(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for row in raw:
			var inner: Array[bool] = []
			if row is Array:
				for v in row:
					inner.append(bool(v))
			out.append(inner)
	while out.size() < table_count:
		out.append([])
	if out.size() > table_count:
		return out.slice(0, table_count)
	return out


func _read_nested_dice_allow_empty(raw: Variant) -> Array:
	var out: Array = _read_nested_dice(raw)
	for i in range(out.size()):
		var row: Array = out[i]
		if row.size() == 0:
			continue
		var dc := get_table_dice_count(i)
		out[i] = _clone_dice_row(row, dc)
	return out
