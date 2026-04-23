class_name GameState
extends RefCounted

const DiceFaceStatsT := preload("res://scripts/dice_face_stats.gd")
const _Die := preload("res://scripts/die_definition.gd")

const SAVE_DATA_VERSION_V2: int = 2
const SAVE_DATA_VERSION_V3: int = 3
const SAVE_DATA_VERSION_V4: int = 4
const SAVE_DATA_VERSION_V5: int = 5
const SAVE_DATA_VERSION_V6: int = 6
const SAVE_DATA_VERSION_V7: int = 7

const TABLE_DICE_POOL_BASE: int = 20

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
const PATTERN_UPGRADE_PER_LEVEL: float = 0.25

const BASE_DICE_CAP_BEFORE_TECH: int = 5
const TECH_COST_EXPEDITION_ENTRY: int = 180
const TECH_COST_DELETE_EXPEDITION: int = 320
const TECH_COST_SYNTH_EXPEDITION: int = 650
const TECH_COST_DICE_CAP_LEVEL_1: int = 450
const TECH_COST_DICE_CAP_LEVEL_2: int = 5000
const TECH_COST_ACQUIRE_N_BASE: int = 220
const TECH_COST_DELETE_N_BASE: int = 220
const TECH_COST_SYNTH_N_BASE: int = 260
const TECH_COST_DURATION_BASE: int = 280
const EXPEDITION_BASE_N: int = 3
const EXPEDITION_MAX_N: int = 8
const EXPEDITION_SYNTH_BASE_N: int = 4
const EXPEDITION_SYNTH_MAX_N: int = 10
const EXPEDITION_BASE_DURATION_SEC: float = 10.0
const EXPEDITION_MIN_DURATION_SEC: float = 2.0
const EXPEDITION_DURATION_STEP_SEC: float = 1.1
const EXPEDITION_MAX_DURATION_LEVEL: int = 6

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
var last_settlement_snapshot: Dictionary = {}
var recent_income_window: Array[Dictionary] = []
var dice_face_stats = DiceFaceStatsT.new()
var manual_mult_level: int = 0
var table_mult_level: int = 0
var global_mult_level: int = 0
var pattern_levels: Dictionary = {}

var tech_expedition_portal_unlocked: bool = false
var tech_delete_expedition_unlocked: bool = false
var tech_synth_expedition_unlocked: bool = false
var tech_dice_cap_level: int = 0
var tech_expedition_acquire_n_level: int = 0
var tech_expedition_delete_n_level: int = 0
var tech_expedition_synth_n_level: int = 0
var tech_expedition_duration_level: int = 0

var table_die_pool: Array = []
var table_active_pool_indices: Array = []

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
	last_settlement_snapshot = {}
	recent_income_window.clear()
	dice_face_stats.reset()
	_ensure_pattern_levels_defaults()
	tech_expedition_portal_unlocked = false
	tech_delete_expedition_unlocked = false
	tech_synth_expedition_unlocked = false
	tech_dice_cap_level = 0
	tech_expedition_acquire_n_level = 0
	tech_expedition_delete_n_level = 0
	tech_expedition_synth_n_level = 0
	tech_expedition_duration_level = 0
	_reset_all_tables()


func _reset_all_tables() -> void:
	table_dice_counts.clear()
	table_rolls_used.clear()
	table_dice_values.clear()
	table_holds.clear()
	per_table_auto_enabled.clear()
	table_auto_staging.clear()
	table_die_pool.clear()
	table_active_pool_indices.clear()
	for _i in range(table_count):
		table_dice_counts.append(MIN_DICE_COUNT)
		table_rolls_used.append(0)
		table_dice_values.append(DiceLogic.create_default_dice(MIN_DICE_COUNT))
		table_holds.append(DiceLogic.create_default_holds(MIN_DICE_COUNT))
		per_table_auto_enabled.append(false)
		table_auto_staging.append([])
		table_die_pool.append(_create_full_standard_pool())
		table_active_pool_indices.append([])
	for i in range(table_count):
		_resample_active_pool_indices(i)
		var dc0 := get_table_dice_count(i)
		var defs0 := _get_die_defs_row_no_resample(i)
		table_dice_values[i] = DiceLogic.roll_fresh_dice_with_definitions(defs0)
		table_holds[i] = DiceLogic.create_default_holds(dc0)


func _create_empty_die_pool() -> Array:
	var row: Array = []
	row.resize(TABLE_DICE_POOL_BASE)
	for i in range(TABLE_DICE_POOL_BASE):
		row[i] = null
	return row


func _create_full_standard_pool() -> Array:
	var row: Array = []
	for _j in range(TABLE_DICE_POOL_BASE):
		row.append(_Die.create_standard())
	return row


func _ensure_pool_all_dice(table_index: int) -> void:
	if not _ensure_table_index(table_index):
		return
	var pool: Array = table_die_pool[table_index]
	for s in range(pool.size()):
		if pool[s] == null or not (pool[s] is _Die):
			pool[s] = _Die.create_standard()
	if pool.is_empty():
		pool.append(_Die.create_standard())


func get_table_die_pool_size(table_index: int) -> int:
	if not _ensure_table_index(table_index):
		return 0
	return table_die_pool[table_index].size()


func get_effective_max_dice_per_table() -> int:
	return clampi(BASE_DICE_CAP_BEFORE_TECH + tech_dice_cap_level, MIN_DICE_COUNT, MAX_DICE_COUNT)


func get_pool_filled_indices(table_index: int) -> Array[int]:
	var out: Array[int] = []
	if not _ensure_table_index(table_index):
		return out
	var pool: Array = table_die_pool[table_index]
	for i in range(pool.size()):
		if pool[i] is _Die:
			out.append(i)
	return out


func get_pool_filled_count(table_index: int) -> int:
	return get_pool_filled_indices(table_index).size()


func get_die_at_pool_slot(table_index: int, pool_slot: int) -> Variant:
	if not _ensure_table_index(table_index):
		return null
	var pool: Array = table_die_pool[table_index]
	if pool_slot < 0 or pool_slot >= pool.size():
		return null
	return pool[pool_slot]


func get_active_pool_indices(table_index: int) -> Array[int]:
	if not _ensure_table_index(table_index):
		return [] as Array[int]
	var raw: Array = table_active_pool_indices[table_index]
	var out: Array[int] = []
	for v in raw:
		out.append(int(v))
	return out


func _get_die_defs_row(table_index: int) -> Array:
	if not _ensure_table_index(table_index):
		return []
	_ensure_active_pool_indices(table_index)
	var pool: Array = table_die_pool[table_index]
	var idxs: Array = table_active_pool_indices[table_index]
	var out: Array = []
	for slot_v in idxs:
		var slot := int(slot_v)
		if slot >= 0 and slot < pool.size() and pool[slot] is _Die:
			out.append(pool[slot])
		else:
			out.append(_Die.create_standard())
	return out


func _get_die_defs_row_no_resample(table_index: int) -> Array:
	if not _ensure_table_index(table_index):
		return []
	var pool: Array = table_die_pool[table_index]
	var idxs: Array = table_active_pool_indices[table_index]
	var out: Array = []
	for slot_v in idxs:
		var slot := int(slot_v)
		if slot >= 0 and slot < pool.size() and pool[slot] is _Die:
			out.append(pool[slot])
		else:
			out.append(_Die.create_standard())
	return out


func _ensure_active_pool_indices(table_index: int) -> void:
	if not _ensure_table_index(table_index):
		return
	while table_active_pool_indices.size() < table_count:
		table_active_pool_indices.append([])
	while table_active_pool_indices.size() > table_count:
		table_active_pool_indices.pop_back()
	var dc := get_table_dice_count(table_index)
	var filled := get_pool_filled_indices(table_index)
	var need_resample := false
	var idxs: Array = table_active_pool_indices[table_index]
	if idxs.size() != dc:
		need_resample = true
	else:
		var pool: Array = table_die_pool[table_index]
		for slot_v in idxs:
			var s := int(slot_v)
			if s < 0 or s >= pool.size() or not (pool[s] is _Die):
				need_resample = true
				break
	if need_resample:
		_resample_active_pool_indices(table_index)
	elif dc > filled.size():
		_resample_active_pool_indices(table_index)


func _resample_active_pool_indices(table_index: int) -> void:
	var filled := get_pool_filled_indices(table_index)
	var pool_copy: Array[int] = filled.duplicate()
	pool_copy.shuffle()
	var dc := get_table_dice_count(table_index)
	var n := mini(dc, pool_copy.size())
	n = maxi(MIN_DICE_COUNT, n)
	n = mini(n, pool_copy.size())
	var active: Array = []
	for j in range(n):
		active.append(pool_copy[j])
	table_active_pool_indices[table_index] = active


func get_expedition_acquire_choice_n() -> int:
	return clampi(EXPEDITION_BASE_N + tech_expedition_acquire_n_level, EXPEDITION_BASE_N, EXPEDITION_MAX_N)


func get_expedition_delete_choice_n() -> int:
	return clampi(EXPEDITION_BASE_N + tech_expedition_delete_n_level, EXPEDITION_BASE_N, EXPEDITION_MAX_N)


func get_expedition_synth_pool_n() -> int:
	return clampi(EXPEDITION_SYNTH_BASE_N + tech_expedition_synth_n_level, EXPEDITION_SYNTH_BASE_N, EXPEDITION_SYNTH_MAX_N)


func get_synth_expedition_required_dice_count() -> int:
	return get_effective_max_dice_per_table() + 1


func can_start_synth_expedition(table_index: int) -> bool:
	if not _ensure_table_index(table_index):
		return false
	return get_pool_filled_count(table_index) >= get_synth_expedition_required_dice_count()


func get_expedition_duration_sec() -> float:
	var lv := clampi(tech_expedition_duration_level, 0, EXPEDITION_MAX_DURATION_LEVEL)
	var t := EXPEDITION_BASE_DURATION_SEC - float(lv) * EXPEDITION_DURATION_STEP_SEC
	return maxf(EXPEDITION_MIN_DURATION_SEC, t)


func get_acquire_n_upgrade_cost() -> int:
	if tech_expedition_acquire_n_level >= EXPEDITION_MAX_N - EXPEDITION_BASE_N:
		return -1
	return int(float(TECH_COST_ACQUIRE_N_BASE) * pow(1.78, float(tech_expedition_acquire_n_level)))


func get_delete_n_upgrade_cost() -> int:
	if tech_expedition_delete_n_level >= EXPEDITION_MAX_N - EXPEDITION_BASE_N:
		return -1
	return int(float(TECH_COST_DELETE_N_BASE) * pow(1.78, float(tech_expedition_delete_n_level)))


func get_synth_n_upgrade_cost() -> int:
	if tech_expedition_synth_n_level >= EXPEDITION_SYNTH_MAX_N - EXPEDITION_SYNTH_BASE_N:
		return -1
	return int(float(TECH_COST_SYNTH_N_BASE) * pow(1.78, float(tech_expedition_synth_n_level)))


func get_duration_upgrade_cost() -> int:
	if tech_expedition_duration_level >= EXPEDITION_MAX_DURATION_LEVEL:
		return -1
	return int(float(TECH_COST_DURATION_BASE) * pow(1.65, float(tech_expedition_duration_level)))


func get_dice_cap_tech_cost_for_next_level() -> int:
	if tech_dice_cap_level >= 2:
		return -1
	if tech_dice_cap_level == 0:
		return TECH_COST_DICE_CAP_LEVEL_1
	return TECH_COST_DICE_CAP_LEVEL_2


func try_buy_expedition_portal() -> Dictionary:
	if tech_expedition_portal_unlocked:
		return {"ok": false, "message": "远征入口已解锁。"}
	if coin_1 < TECH_COST_EXPEDITION_ENTRY:
		return {"ok": false, "message": "货币1不足。"}
	coin_1 -= TECH_COST_EXPEDITION_ENTRY
	tech_expedition_portal_unlocked = true
	return {"ok": true}


func try_buy_delete_expedition() -> Dictionary:
	if not tech_expedition_portal_unlocked:
		return {"ok": false, "message": "请先解锁远征入口。"}
	if tech_delete_expedition_unlocked:
		return {"ok": false, "message": "删骰远征已解锁。"}
	if coin_1 < TECH_COST_DELETE_EXPEDITION:
		return {"ok": false, "message": "货币1不足。"}
	coin_1 -= TECH_COST_DELETE_EXPEDITION
	tech_delete_expedition_unlocked = true
	return {"ok": true}


func try_buy_synth_expedition() -> Dictionary:
	if not tech_delete_expedition_unlocked:
		return {"ok": false, "message": "请先解锁删骰远征。"}
	if tech_synth_expedition_unlocked:
		return {"ok": false, "message": "合成远征已解锁。"}
	if coin_1 < TECH_COST_SYNTH_EXPEDITION:
		return {"ok": false, "message": "货币1不足。"}
	coin_1 -= TECH_COST_SYNTH_EXPEDITION
	tech_synth_expedition_unlocked = true
	return {"ok": true}


func try_buy_dice_cap_level() -> Dictionary:
	var cost := get_dice_cap_tech_cost_for_next_level()
	if cost < 0:
		return {"ok": false, "message": "骰子上限科技已满。"}
	if coin_1 < cost:
		return {"ok": false, "message": "货币1不足。"}
	coin_1 -= cost
	tech_dice_cap_level = mini(2, tech_dice_cap_level + 1)
	return {"ok": true}


func try_upgrade_acquire_n() -> Dictionary:
	var cost := get_acquire_n_upgrade_cost()
	if cost < 0:
		return {"ok": false, "message": "得骰选项数已满。"}
	if coin_1 < cost:
		return {"ok": false, "message": "货币1不足。"}
	coin_1 -= cost
	tech_expedition_acquire_n_level += 1
	return {"ok": true}


func try_upgrade_delete_n() -> Dictionary:
	var cost := get_delete_n_upgrade_cost()
	if cost < 0:
		return {"ok": false, "message": "删骰选项数已满。"}
	if coin_1 < cost:
		return {"ok": false, "message": "货币1不足。"}
	coin_1 -= cost
	tech_expedition_delete_n_level += 1
	return {"ok": true}


func try_upgrade_synth_n() -> Dictionary:
	var cost := get_synth_n_upgrade_cost()
	if cost < 0:
		return {"ok": false, "message": "合成候选池已满。"}
	if coin_1 < cost:
		return {"ok": false, "message": "货币1不足。"}
	coin_1 -= cost
	tech_expedition_synth_n_level += 1
	return {"ok": true}


func try_upgrade_expedition_duration() -> Dictionary:
	var cost := get_duration_upgrade_cost()
	if cost < 0:
		return {"ok": false, "message": "远征耗时升级已满。"}
	if coin_1 < cost:
		return {"ok": false, "message": "货币1不足。"}
	coin_1 -= cost
	tech_expedition_duration_level += 1
	return {"ok": true}


func generate_acquire_candidates() -> Array:
	var n := get_expedition_acquire_choice_n()
	var out: Array = []
	for _i in range(n):
		out.append(_Die.create_random_biased())
	return out


func get_random_delete_candidate_indices(table_index: int) -> Array[int]:
	var filled := get_pool_filled_indices(table_index)
	if filled.is_empty():
		return []
	if filled.size() <= get_table_dice_count(table_index):
		return []
	var n := mini(get_expedition_delete_choice_n(), filled.size())
	var pool: Array[int] = filled.duplicate()
	pool.shuffle()
	var out: Array[int] = []
	for j in range(n):
		out.append(pool[j])
	out.sort()
	return out


func get_random_synth_candidate_indices(table_index: int) -> Array[int]:
	if get_table_dice_count(table_index) < 2:
		return []
	var filled := get_pool_filled_indices(table_index)
	if filled.size() < 2:
		return []
	var want := mini(get_expedition_synth_pool_n(), filled.size())
	var pool: Array[int] = filled.duplicate()
	pool.shuffle()
	var out: Array[int] = []
	for j in range(want):
		out.append(pool[j])
	out.sort()
	return out


func apply_expedition_acquire(table_index: int, die: _Die) -> Dictionary:
	if not _ensure_table_index(table_index):
		return {"ok": false, "message": "无效骰桌。"}
	if not tech_expedition_portal_unlocked:
		return {"ok": false, "message": "远征未解锁。"}
	coin_1 = maxi(0, coin_1)
	var pool: Array = table_die_pool[table_index]
	pool.append(die.duplicate_die())
	var n0 := int(table_dice_counts[table_index])
	if n0 < get_effective_max_dice_per_table():
		table_dice_counts[table_index] = n0 + 1
	_clamp_all_table_rows()
	_resample_active_pool_indices(table_index)
	return {"ok": true}


func apply_expedition_delete(table_index: int, pool_slot: int) -> Dictionary:
	if not _ensure_table_index(table_index):
		return {"ok": false, "message": "无效骰桌。"}
	if not tech_delete_expedition_unlocked:
		return {"ok": false, "message": "删骰远征未解锁。"}
	if get_pool_filled_count(table_index) <= get_table_dice_count(table_index):
		return {"ok": false, "message": "骰池数量不足，不能影响当前上场骰子。"}
	var pool: Array = table_die_pool[table_index]
	if pool_slot < 0 or pool_slot >= pool.size():
		return {"ok": false, "message": "无效的删除目标。"}
	if not (pool[pool_slot] is _Die):
		return {"ok": false, "message": "无效的删除目标。"}
	pool.remove_at(pool_slot)
	var st: Array = table_auto_staging[table_index]
	if st.size() > 0:
		table_auto_staging[table_index] = []
	_clamp_all_table_rows()
	_resample_active_pool_indices(table_index)
	return {"ok": true}


func apply_expedition_synth(table_index: int, pool_slot_a: int, pool_slot_b: int) -> Dictionary:
	if not _ensure_table_index(table_index):
		return {"ok": false, "message": "无效骰桌。"}
	if not tech_synth_expedition_unlocked:
		return {"ok": false, "message": "合成远征未解锁。"}
	if not can_start_synth_expedition(table_index):
		return {"ok": false, "message": "合成远征需要该桌骰池至少达到上限+1。"}
	if get_table_dice_count(table_index) < 2:
		return {"ok": false, "message": "至少需要2颗上场骰子才能合成。"}
	if pool_slot_a == pool_slot_b:
		return {"ok": false, "message": "请选择两颗不同的骰子。"}
	var pool: Array = table_die_pool[table_index]
	if pool_slot_a < 0 or pool_slot_a >= pool.size() or pool_slot_b < 0 or pool_slot_b >= pool.size():
		return {"ok": false, "message": "无效的下标。"}
	if not (pool[pool_slot_a] is _Die) or not (pool[pool_slot_b] is _Die):
		return {"ok": false, "message": "无效的下标。"}
	var da: _Die = pool[pool_slot_a] as _Die
	var db: _Die = pool[pool_slot_b] as _Die
	var merged := _Die.merge(da, db)
	var hi := maxi(pool_slot_a, pool_slot_b)
	var lo := mini(pool_slot_a, pool_slot_b)
	pool[lo] = merged
	pool.remove_at(hi)
	table_dice_counts[table_index] = int(table_dice_counts[table_index]) - 1
	table_auto_staging[table_index] = []
	_clamp_all_table_rows()
	_resample_active_pool_indices(table_index)
	return {"ok": true}


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
	var defs := _get_die_defs_row_no_resample(table_index)
	var next_values := DiceLogic.roll_dice_with_definitions(values, holds, defs)
	dice_face_stats.record_rerolled_only(holds, next_values)
	table_dice_values[table_index] = next_values
	table_rolls_used[table_index] = int(table_rolls_used[table_index]) + 1
	return {"ok": true}


func settle_manual_turn(table_index: int) -> Dictionary:
	if not can_settle_manual(table_index):
		return {"ok": false, "message": "请至少掷骰一次后再结算。"}
	var dice := _clone_dice_row(table_dice_values[table_index], get_table_dice_count(table_index))
	var snapshot := evaluate_income_snapshot(dice, table_index, "manual")
	var income := int(snapshot["final_income"])
	_add_coin(income)
	total_manual_turns += 1
	last_settlement_label = String(snapshot["label"])
	last_settlement_base = int(snapshot["base_score"])
	last_settlement_multiplier = float(snapshot["pattern_multiplier"])
	last_settlement_income = income
	last_settlement_snapshot = snapshot.duplicate(true)
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
	var snapshot := evaluate_income_snapshot(dice, table_index, "auto")
	var income := int(snapshot["final_income"])
	table_dice_values[table_index] = dice.duplicate()
	table_auto_staging[table_index] = []
	table_rolls_used[table_index] = 0
	table_holds[table_index] = DiceLogic.create_default_holds(get_table_dice_count(table_index))
	_add_coin(income)
	total_auto_turns += 1
	last_settlement_label = "%s(自动桌%d)" % [String(snapshot["label"]), table_index + 1]
	last_settlement_base = int(snapshot["base_score"])
	last_settlement_multiplier = float(snapshot["pattern_multiplier"])
	last_settlement_income = income
	last_settlement_snapshot = snapshot.duplicate(true)
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
	var n := get_table_dice_count(table_index)
	if n >= get_effective_max_dice_per_table():
		return -1
	if get_pool_filled_count(table_index) < n + 1:
		return -1
	return int(35 * pow(1.75, n - MIN_DICE_COUNT))


func can_upgrade_dice_on_table(table_index: int) -> bool:
	var cost := get_dice_upgrade_cost(table_index)
	return cost > 0 and coin_1 >= cost


func upgrade_dice_on_table(table_index: int) -> Dictionary:
	var cost := get_dice_upgrade_cost(table_index)
	if not _ensure_table_index(table_index):
		return {"ok": false, "message": "无效骰桌。"}
	if cost <= 0:
		if get_table_dice_count(table_index) >= get_effective_max_dice_per_table():
			return {"ok": false, "message": "该桌上场骰子数已达上限。"}
		return {"ok": false, "message": "骰池骰子不足，无法增加上场数。"}
	if coin_1 < cost:
		return {"ok": false, "message": "货币1不足。"}
	coin_1 -= cost
	table_dice_counts[table_index] = int(table_dice_counts[table_index]) + 1
	var in_active_turn := int(table_rolls_used[table_index]) > 0
	var auto_staging: Array = table_auto_staging[table_index]
	var has_pending_auto := auto_staging.size() > 0
	_clamp_all_table_rows()
	if not in_active_turn and not has_pending_auto:
		_resample_active_pool_indices(table_index)
		var dc := get_table_dice_count(table_index)
		var defs := _get_die_defs_row_no_resample(table_index)
		table_dice_values[table_index] = DiceLogic.roll_fresh_dice_with_definitions(defs)
		table_holds[table_index] = DiceLogic.create_default_holds(dc)
	return {
		"ok": true,
		"takes_effect_next_turn": in_active_turn or has_pending_auto
	}


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
	table_die_pool.append(_create_full_standard_pool())
	table_active_pool_indices.append([])
	var ti_new := table_count - 1
	_resample_active_pool_indices(ti_new)
	var dcn := get_table_dice_count(ti_new)
	table_dice_values[ti_new] = DiceLogic.roll_fresh_dice_with_definitions(_get_die_defs_row_no_resample(ti_new))
	table_holds[ti_new] = DiceLogic.create_default_holds(dcn)
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
	return get_growth_multiplier_total(-1, "legacy")


func get_growth_multiplier_total(table_index: int, settle_mode: String) -> float:
	var zones := get_growth_zones(table_index, settle_mode, [], [])
	return float(zones["growth_multiplier_total"])


func get_growth_zones(table_index: int, settle_mode: String, used_indices: Array[int], die_defs: Array) -> Dictionary:
	var manual_zone := 1.0 + 0.25 * float(maxi(0, manual_mult_level))
	if settle_mode == "auto":
		manual_zone = 1.0
	var effective_table_level := maxi(0, table_count - MIN_TABLE_COUNT) + maxi(0, table_mult_level)
	var table_zone := 1.0 + 0.10 * float(effective_table_level)
	var global_zone := 1.0 + 0.25 * float(maxi(0, global_mult_level))
	var rarity_zone := _compute_rarity_zone(used_indices, die_defs)
	return {
		"manual_zone": manual_zone,
		"table_zone": table_zone,
		"global_zone": global_zone,
		"rarity_zone": rarity_zone,
		"growth_multiplier_total": manual_zone * table_zone * global_zone * rarity_zone
	}


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
	_resample_active_pool_indices(table_index)
	var dc := get_table_dice_count(table_index)
	table_rolls_used[table_index] = 0
	var defs := _get_die_defs_row(table_index)
	table_dice_values[table_index] = DiceLogic.roll_fresh_dice_with_definitions(defs)
	table_holds[table_index] = DiceLogic.create_default_holds(dc)
	table_auto_staging[table_index] = []


func _build_auto_cycle_dice_for_table(table_index: int) -> Array[int]:
	_resample_active_pool_indices(table_index)
	var defs := _get_die_defs_row_no_resample(table_index)
	var dice := DiceLogic.roll_fresh_dice_with_definitions(defs)
	dice_face_stats.record_all_faces(dice)
	for _i in range(MAX_ROLLS_PER_TURN - 1):
		var holds: Array[bool] = []
		for value in dice:
			holds.append(value >= 5)
		dice = DiceLogic.roll_dice_with_definitions(dice, holds, defs)
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


func evaluate_income_snapshot(dice: Array[int], table_index: int, settle_mode: String) -> Dictionary:
	_ensure_pattern_levels_defaults()
	var eval := ScoringRules.evaluate_best_pattern(dice)
	var pattern_id := String(eval["id"])
	var base_score := int(eval["base_score"])
	var pattern_multiplier_base := float(eval["multiplier"])
	var pattern_level := int(pattern_levels.get(pattern_id, 0))
	var pattern_multiplier_upgrade := 1.0 + PATTERN_UPGRADE_PER_LEVEL * float(maxi(0, pattern_level))
	var pattern_multiplier := pattern_multiplier_base * pattern_multiplier_upgrade
	var used_indices: Array[int] = []
	for idx in eval.get("used_indices", []):
		used_indices.append(int(idx))
	if used_indices.is_empty():
		for i in range(dice.size()):
			used_indices.append(i)
	var die_defs := _get_die_defs_for_snapshot(table_index, dice.size())
	var zones := get_growth_zones(table_index, settle_mode, used_indices, die_defs)
	var growth_multiplier_total := float(zones["growth_multiplier_total"])
	var income_raw := float(base_score) * pattern_multiplier * growth_multiplier_total
	var final_income := maxi(1, int(round(income_raw)))
	return {
		"settle_mode": settle_mode,
		"base_score": base_score,
		"pattern_id": pattern_id,
		"label": String(eval["label"]),
		"pattern_multiplier_base": pattern_multiplier_base,
		"pattern_multiplier_upgrade": pattern_multiplier_upgrade,
		"pattern_multiplier": pattern_multiplier,
		"manual_zone": float(zones["manual_zone"]),
		"table_zone": float(zones["table_zone"]),
		"global_zone": float(zones["global_zone"]),
		"rarity_zone": float(zones["rarity_zone"]),
		"growth_multiplier_total": growth_multiplier_total,
		"used_indices": used_indices,
		"income_raw": income_raw,
		"final_income": final_income,
		"base": base_score,
		"multiplier": pattern_multiplier,
		"income": final_income
	}


func _get_die_defs_for_snapshot(table_index: int, expected_count: int) -> Array:
	if _ensure_table_index(table_index):
		return _get_die_defs_row_no_resample(table_index)
	var fallback: Array = []
	for _i in range(expected_count):
		fallback.append(_Die.create_standard())
	return fallback


func _compute_rarity_zone(used_indices: Array[int], die_defs: Array) -> float:
	var zone := 1.0
	for idx in used_indices:
		var i := int(idx)
		if i < 0 or i >= die_defs.size():
			continue
		var d: Variant = die_defs[i]
		if d is _Die:
			zone *= _rarity_weight(int((d as _Die).rarity))
	return maxf(1.0, zone)


func _rarity_weight(rarity: int) -> float:
	var r := maxi(0, rarity)
	if r <= 0:
		return 1.0
	return 1.5 * pow(2.0, float(r - 1))


func _ensure_pattern_levels_defaults() -> void:
	for pattern_id in ScoringRules.get_pattern_order():
		if not pattern_levels.has(pattern_id):
			pattern_levels[pattern_id] = 0


func _add_coin(amount: int) -> void:
	var safe_amount := maxi(0, amount)
	coin_1 += safe_amount
	total_coin_earned += safe_amount


func grant_coin_for_admin(amount: int) -> Dictionary:
	if amount <= 0:
		return {"ok": false, "message": "金额需大于0。"}
	_add_coin(amount)
	return {"ok": true, "granted": amount}


func _record_income_event(amount: int) -> void:
	recent_income_window.append({
		"income": amount,
		"tick": Time.get_ticks_msec()
	})
	while recent_income_window.size() > 12:
		recent_income_window.remove_at(0)


func to_save_data() -> Dictionary:
	return {
		"version": SAVE_DATA_VERSION_V7,
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
		"last_settlement_snapshot": last_settlement_snapshot.duplicate(true),
		"recent_income_window": recent_income_window.duplicate(true),
		"manual_mult_level": manual_mult_level,
		"table_mult_level": table_mult_level,
		"global_mult_level": global_mult_level,
		"pattern_levels": pattern_levels.duplicate(true),
		"table_dice_counts": _int_array_to_save(table_dice_counts),
		"table_rolls_used": _int_array_to_save(table_rolls_used),
		"table_dice_values": _nested_dice_to_save(table_dice_values),
		"table_holds": _nested_holds_to_save(table_holds),
		"per_table_auto_enabled": _bool_array_to_save(per_table_auto_enabled),
		"table_auto_staging": _nested_dice_to_save(table_auto_staging),
		"tech_expedition_portal_unlocked": tech_expedition_portal_unlocked,
		"tech_delete_expedition_unlocked": tech_delete_expedition_unlocked,
		"tech_synth_expedition_unlocked": tech_synth_expedition_unlocked,
		"tech_dice_cap_level": tech_dice_cap_level,
		"tech_expedition_acquire_n_level": tech_expedition_acquire_n_level,
		"tech_expedition_delete_n_level": tech_expedition_delete_n_level,
		"tech_expedition_synth_n_level": tech_expedition_synth_n_level,
		"tech_expedition_duration_level": tech_expedition_duration_level,
		"table_die_pool": _die_pool_to_save(),
		"table_active_pool_indices": _active_indices_to_save()
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
	last_settlement_snapshot = {}
	var snapshot_raw: Variant = data.get("last_settlement_snapshot", {})
	if snapshot_raw is Dictionary:
		last_settlement_snapshot = (snapshot_raw as Dictionary).duplicate(true)
	manual_mult_level = maxi(0, int(data.get("manual_mult_level", 0)))
	table_mult_level = maxi(0, int(data.get("table_mult_level", 0)))
	global_mult_level = maxi(0, int(data.get("global_mult_level", 0)))
	pattern_levels = {}
	var pattern_raw: Variant = data.get("pattern_levels", {})
	if pattern_raw is Dictionary:
		for k in (pattern_raw as Dictionary).keys():
			pattern_levels[String(k)] = maxi(0, int((pattern_raw as Dictionary)[k]))
	_ensure_pattern_levels_defaults()

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

	if ver >= SAVE_DATA_VERSION_V3:
		tech_expedition_portal_unlocked = bool(data.get("tech_expedition_portal_unlocked", false))
		tech_delete_expedition_unlocked = bool(data.get("tech_delete_expedition_unlocked", false))
		tech_synth_expedition_unlocked = bool(data.get("tech_synth_expedition_unlocked", false))
		tech_dice_cap_level = clampi(int(data.get("tech_dice_cap_level", 0)), 0, 2)
		tech_expedition_acquire_n_level = maxi(0, int(data.get("tech_expedition_acquire_n_level", 0)))
		tech_expedition_delete_n_level = maxi(0, int(data.get("tech_expedition_delete_n_level", 0)))
		tech_expedition_synth_n_level = maxi(0, int(data.get("tech_expedition_synth_n_level", 0)))
		tech_expedition_duration_level = clampi(int(data.get("tech_expedition_duration_level", 0)), 0, EXPEDITION_MAX_DURATION_LEVEL)
		if ver >= SAVE_DATA_VERSION_V4:
			_load_v4_pool_payload(data)
		else:
			_migrate_v3_table_die_defs_to_pool(data.get("table_die_defs", []))
	else:
		tech_expedition_portal_unlocked = false
		tech_delete_expedition_unlocked = false
		tech_synth_expedition_unlocked = false
		tech_expedition_acquire_n_level = 0
		tech_expedition_delete_n_level = 0
		tech_expedition_synth_n_level = 0
		tech_expedition_duration_level = 0
		_infer_tech_dice_cap_from_loaded_counts()
		_migrate_v3_table_die_defs_to_pool([])

	_clamp_all_table_rows()

	return true


func _load_v2_tables(data: Dictionary) -> void:
	table_dice_counts = _read_int_array(data.get("table_dice_counts", []), MIN_DICE_COUNT, MAX_DICE_COUNT, MIN_DICE_COUNT)
	table_rolls_used = _read_int_array(data.get("table_rolls_used", []), 0, MAX_ROLLS_PER_TURN, 0)
	_normalize_table_arrays()
	table_dice_values = _read_nested_dice(data.get("table_dice_values", []))
	table_holds = _read_nested_holds(data.get("table_holds", []))
	per_table_auto_enabled = _read_bool_array(data.get("per_table_auto_enabled", []))
	table_auto_staging = _read_nested_dice_allow_empty(data.get("table_auto_staging", []))


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
	table_die_pool.clear()
	table_active_pool_indices.clear()
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
		table_die_pool.append(_create_full_standard_pool())
		table_active_pool_indices.append([])


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
	while table_die_pool.size() < table_count:
		table_die_pool.append(_create_full_standard_pool())
		table_active_pool_indices.append([])
	while table_die_pool.size() > table_count:
		table_die_pool.pop_back()
		table_active_pool_indices.pop_back()


func _infer_tech_dice_cap_from_loaded_counts() -> void:
	var mx := MIN_DICE_COUNT
	for i in range(mini(table_dice_counts.size(), table_count)):
		mx = maxi(mx, int(table_dice_counts[i]))
	if mx >= 7:
		tech_dice_cap_level = 2
	elif mx >= 6:
		tech_dice_cap_level = 1
	else:
		tech_dice_cap_level = 0


func _migrate_v3_table_die_defs_to_pool(raw: Variant) -> void:
	table_die_pool.clear()
	table_active_pool_indices.clear()
	if not (raw is Array) or (raw as Array).is_empty():
		for _i in range(table_count):
			table_die_pool.append(_create_full_standard_pool())
			table_active_pool_indices.append([])
		return
	var outer: Array = raw
	for i in range(table_count):
		var p := _create_empty_die_pool()
		if i < outer.size() and outer[i] is Array:
			var s := 0
			for cell in outer[i]:
				if cell is Dictionary and s < TABLE_DICE_POOL_BASE:
					p[s] = _Die.from_dict(cell)
					s += 1
		for _t in range(TABLE_DICE_POOL_BASE):
			if p[_t] == null or not (p[_t] is _Die):
				p[_t] = _Die.create_standard()
		table_die_pool.append(p)
	for i in range(table_count):
		var act: Array = []
		var dc := clampi(int(table_dice_counts[i]), MIN_DICE_COUNT, MAX_DICE_COUNT)
		var filled := get_pool_filled_indices(i)
		for j in range(mini(dc, filled.size())):
			act.append(filled[j])
		if act.is_empty() and filled.size() > 0:
			act.append(filled[0])
		table_active_pool_indices.append(act)


func get_pool_filled_indices_from_array(pool: Array) -> Array[int]:
	var out: Array[int] = []
	for i in range(pool.size()):
		if pool[i] is _Die:
			out.append(i)
	return out


func _load_v4_pool_payload(data: Dictionary) -> void:
	table_die_pool.clear()
	table_active_pool_indices.clear()
	var pools_raw: Variant = data.get("table_die_pool", [])
	var act_raw: Variant = data.get("table_active_pool_indices", [])
	for i in range(table_count):
		var p: Array = []
		if pools_raw is Array and i < pools_raw.size() and pools_raw[i] is Array:
			var cells: Array = pools_raw[i]
			for s in range(cells.size()):
				var c: Variant = cells[s]
				if c is Dictionary:
					p.append(_Die.from_dict(c))
				else:
					p.append(null)
		while p.size() < TABLE_DICE_POOL_BASE:
			p.append(null)
		for _t in range(p.size()):
			if p[_t] == null or not (p[_t] is _Die):
				p[_t] = _Die.create_standard()
		table_die_pool.append(p)
		var act: Array = []
		var mx := maxi(0, p.size() - 1)
		if act_raw is Array and i < act_raw.size() and act_raw[i] is Array:
			for v in act_raw[i]:
				act.append(clampi(int(v), 0, mx))
		table_active_pool_indices.append(act)


func _die_pool_to_save() -> Array:
	var out: Array = []
	for i in range(table_count):
		var inner: Array = []
		var row: Array = table_die_pool[i] if i < table_die_pool.size() else _create_empty_die_pool()
		for s in range(row.size()):
			var c: Variant = row[s]
			if c is _Die:
				inner.append((c as _Die).to_dict())
			else:
				inner.append(null)
		out.append(inner)
	return out


func _active_indices_to_save() -> Array:
	var out: Array = []
	for i in range(table_count):
		var inner: Array = []
		if i < table_active_pool_indices.size():
			for v in table_active_pool_indices[i]:
				inner.append(int(v))
		out.append(inner)
	return out


func _clamp_all_table_rows() -> void:
	_normalize_table_arrays()
	for i in range(table_count):
		_ensure_pool_all_dice(i)
		var filled := get_pool_filled_count(i)
		var em := get_effective_max_dice_per_table()
		var dc := clampi(int(table_dice_counts[i]), MIN_DICE_COUNT, em)
		dc = mini(dc, filled)
		dc = maxi(MIN_DICE_COUNT, dc)
		table_dice_counts[i] = dc
		table_rolls_used[i] = clampi(int(table_rolls_used[i]), 0, MAX_ROLLS_PER_TURN)
		_ensure_active_pool_indices(i)
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
