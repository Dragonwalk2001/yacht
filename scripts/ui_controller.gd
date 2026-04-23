class_name UIController
extends Control

const _TimeSpeedSettings := preload("res://scripts/time_speed_settings.gd")
const _UIDialogs := preload("res://scripts/ui_dialogs.gd")
const _UIGrowthTree := preload("res://scripts/ui_growth_tree.gd")
const _UIExpedition := preload("res://scripts/ui_expedition.gd")
const _UITablePanels := preload("res://scripts/ui_table_panels.gd")

@onready var status_label: Label = $Margin/VBox/TopRow/LeftColumn/StatusLabel
@onready var turn_label: Label = $Margin/VBox/TopRow/LeftColumn/TurnLabel
@onready var rolls_label: Label = $Margin/VBox/TopRow/LeftColumn/RollsLabel
@onready var tables_scroll: ScrollContainer = $Margin/VBox/TopRow/LeftColumn/TablesScroll
@onready var tables_grid: GridContainer = $Margin/VBox/TopRow/LeftColumn/TablesScroll/TablesGrid
@onready var score_board: RichTextLabel = $Margin/VBox/TopRow/ScoreBoardPanel/ScoreBoardMargin/ScoreBoard
@onready var menu_button: MenuButton = $Margin/VBox/MenuRow/MenuButton
@onready var growth_button: Button = $Margin/VBox/MenuRow/GrowthButton
@onready var throw_pulse_timer: Timer = $ThrowPulseTimer

var _dialogs: _UIDialogs
var _growth: _UIGrowthTree
var _expedition: _UIExpedition
var _tables: _UITablePanels

var game_state := GameState.new()
var turn_manager := TurnManager.new(game_state)
var upgrade_buttons: Dictionary = {}
var table_panel_roots: Array[Control] = []
var table_die_buttons: Array = []
var table_info_labels: Array[Label] = []
var table_roll_buttons: Array[Button] = []
var table_settle_buttons: Array[Button] = []
var table_auto_buttons: Array[Button] = []
var table_dice_upgrade_buttons: Array[Button] = []
var table_pool_buttons: Array[Button] = []
var table_expedition_buttons: Array[Button] = []
var table_expedition_timers: Array[Timer] = []
var table_throw_timers: Array[Timer] = []
var table_auto_timers: Array[Timer] = []
var table_is_throwing: Array[bool] = []
var table_throw_sources: Array[String] = []
var table_throw_visuals: Array = []
var table_queued_auto: Array[int] = []

const SAVE_PATH := "user://savegame.json"

const THROW_ANIMATION_SEC: float = 0.5
const THROW_PULSE_SEC: float = 0.08


func _ready() -> void:
	randomize()
	_dialogs = _UIDialogs.new(self)
	_growth = _UIGrowthTree.new(self)
	_expedition = _UIExpedition.new(self)
	_tables = _UITablePanels.new(self)
	_TimeSpeedSettings.apply_engine_multiplier(_dialogs.time_speed)
	_dialogs.init_dice_stats_dialog()
	_dialogs.init_admin_grant_window()
	_growth.init_growth_window()
	_expedition.init_expedition_window()
	_tables.init_pool_browser_window()
	_dialogs.init_time_speed_window()
	_init_throw_tracking_arrays()
	_create_per_table_timers()
	_tables.build_table_panels()
	_bind_signals()
	_apply_tables_scroll_min_height()
	_apply_table_panel_density()


func _growth_deferred_update_canvas() -> void:
	_growth.update_growth_tree_canvas_size()


func _growth_deferred_refresh_links() -> void:
	_growth.refresh_growth_tree_links()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_tables_scroll_min_height()


func _apply_tables_scroll_min_height() -> void:
	if tables_scroll == null:
		return
	var h := get_viewport_rect().size.y
	tables_scroll.custom_minimum_size.y = clampf(h * 0.5, 260.0, 620.0)


func _apply_table_panel_density() -> void:
	var n := game_state.table_count
	var die := 48
	var sep_inner := 4
	var gh := 10
	var gv := 10
	var fs_info := 14
	var fs_btn := 13
	if n >= 7:
		die = 32
		sep_inner = 2
		gh = 6
		gv = 6
		fs_info = 12
		fs_btn = 10
	elif n >= 5:
		die = 40
		sep_inner = 3
		gh = 8
		gv = 8
		fs_info = 13
		fs_btn = 11
	tables_grid.add_theme_constant_override("h_separation", gh)
	tables_grid.add_theme_constant_override("v_separation", gv)
	for t in range(GameState.MAX_TABLE_COUNT):
		var inner := table_panel_roots[t].get_child(0) as VBoxContainer
		inner.add_theme_constant_override("separation", sep_inner)
		var row := inner.get_child(1) as HBoxContainer
		row.add_theme_constant_override("separation", maxi(2, sep_inner))
		var cbox := inner.get_child(3) as HBoxContainer
		cbox.add_theme_constant_override("separation", maxi(4, sep_inner + 2))
		for d in range(GameState.MAX_DICE_COUNT):
			(table_die_buttons[t][d] as Button).custom_minimum_size = Vector2(die, die)
		table_info_labels[t].add_theme_font_size_override("font_size", fs_info)
		for b in [table_roll_buttons[t], table_settle_buttons[t], table_auto_buttons[t]]:
			(b as Button).add_theme_font_size_override("font_size", fs_btn)
		(table_dice_upgrade_buttons[t] as Button).add_theme_font_size_override("font_size", maxi(9, fs_btn - 1))


func _init_throw_tracking_arrays() -> void:
	for _i in range(GameState.MAX_TABLE_COUNT):
		table_is_throwing.append(false)
		table_throw_sources.append("")
		table_throw_visuals.append([])
		table_queued_auto.append(0)


func _create_per_table_timers() -> void:
	for i in range(GameState.MAX_TABLE_COUNT):
		var tt := Timer.new()
		tt.one_shot = true
		tt.wait_time = THROW_ANIMATION_SEC
		var throw_idx := i
		tt.timeout.connect(func() -> void:
			_on_table_throw_timer_timeout(throw_idx)
		)
		add_child(tt)
		table_throw_timers.append(tt)
		var at := Timer.new()
		at.one_shot = false
		at.wait_time = game_state.get_auto_interval()
		var auto_idx := i
		at.timeout.connect(func() -> void:
			_on_table_auto_timer_timeout(auto_idx)
		)
		add_child(at)
		table_auto_timers.append(at)
		var et := Timer.new()
		et.one_shot = true
		var exp_idx := i
		et.timeout.connect(func() -> void:
			_expedition.on_table_expedition_timer_timeout(exp_idx)
		)
		add_child(et)
		table_expedition_timers.append(et)


func _bind_signals() -> void:
	var pop := menu_button.get_popup()
	pop.add_item("掷骰统计…", 0)
	pop.add_item("时间倍速…", 1)
	pop.add_item("管理员手动加钱…", 2)
	pop.id_pressed.connect(func(id: int) -> void:
		_dialogs.on_menu_id_pressed(id, game_state, status_label)
	)
	growth_button.pressed.connect(func() -> void:
		_growth.on_growth_button_pressed()
	)
	throw_pulse_timer.timeout.connect(_on_throw_pulse_timer_timeout)
	for t in range(GameState.MAX_TABLE_COUNT):
		for d in range(GameState.MAX_DICE_COUNT):
			var die_button := table_die_buttons[t][d] as Button
			var ti := t
			var di := d
			die_button.expand_icon = true
			die_button.toggled.connect(func(_pressed: bool) -> void:
				_on_dice_toggled(ti, di)
			)
		table_roll_buttons[t].pressed.connect(func() -> void:
			_on_roll_pressed(t)
		)
		table_settle_buttons[t].pressed.connect(func() -> void:
			_on_settle_pressed(t)
		)
		table_auto_buttons[t].pressed.connect(func() -> void:
			_on_table_auto_pressed(t)
		)
		table_dice_upgrade_buttons[t].pressed.connect(func() -> void:
			_on_upgrade_dice_on_table_pressed(t)
		)
		table_expedition_buttons[t].pressed.connect(func() -> void:
			_expedition.on_expedition_button_pressed(t)
		)


func _any_table_throwing() -> bool:
	for t in range(GameState.MAX_TABLE_COUNT):
		if table_is_throwing[t]:
			return true
	return false


func _start_new_game() -> void:
	turn_manager.start_new_game()
	for i in range(GameState.MAX_TABLE_COUNT):
		table_throw_timers[i].stop()
		table_auto_timers[i].stop()
		if i < table_expedition_timers.size():
			table_expedition_timers[i].stop()
		table_is_throwing[i] = false
		table_throw_sources[i] = ""
		table_throw_visuals[i] = []
		table_queued_auto[i] = 0
	throw_pulse_timer.stop()
	_apply_all_auto_timers()
	status_label.text = "新对局开始。"
	_save_game()
	_refresh_all()


func _refresh_all() -> void:
	_apply_tables_scroll_min_height()
	_apply_table_panel_density()
	_refresh_turn_labels()
	_tables.refresh_table_infos()
	_tables.refresh_dice()
	_growth.refresh_growth_tree(game_state, upgrade_buttons, table_dice_upgrade_buttons)
	_refresh_score_board()
	_update_all_table_buttons()
	_tables.refresh_pool_browser_if_visible()


func _refresh_turn_labels() -> void:
	turn_label.text = "骰桌:%d/%d · 开局池%d颗/桌可扩张（每桌独立操作与自动计时）" % [
		game_state.table_count, GameState.MAX_TABLE_COUNT, GameState.TABLE_DICE_POOL_BASE
	]
	rolls_label.text = "各桌独立操作；骰桌区可上下滚动。"


func _refresh_score_board() -> void:
	var lines: Array[String] = []
	var snap: Dictionary = game_state.last_settlement_snapshot
	var pattern_base := float(snap.get("pattern_multiplier_base", game_state.last_settlement_multiplier))
	var pattern_upg := float(snap.get("pattern_multiplier_upgrade", 1.0))
	var manual_zone := float(snap.get("manual_zone", 1.0))
	var table_zone := float(snap.get("table_zone", 1.0))
	var global_zone := float(snap.get("global_zone", 1.0))
	var rarity_zone := float(snap.get("rarity_zone", 1.0))
	var growth_total := float(snap.get("growth_multiplier_total", game_state.get_progress_multiplier()))
	lines.append("货币1: %d" % [game_state.coin_1])
	lines.append("总产出: %d" % [game_state.total_coin_earned])
	lines.append("当前预估收益/秒: %.1f" % [game_state.estimate_income_per_second()])
	lines.append("最近结算: %s  +%d" % [game_state.last_settlement_label, game_state.last_settlement_income])
	lines.append("基础点数:%d  判型:%.2f×%.2f=%.2f" % [
		game_state.last_settlement_base,
		pattern_base,
		pattern_upg,
		pattern_base * pattern_upg
	])
	lines.append("成长乘区 手动:%.2f 桌面:%.2f 全局:%.2f 稀有:%.2f 合计:%.2f" % [
		manual_zone,
		table_zone,
		global_zone,
		rarity_zone,
		growth_total
	])
	lines.append("手动回合:%d  自动回合:%d" % [
		game_state.total_manual_turns,
		game_state.total_auto_turns
	])
	score_board.text = "\n".join(lines)


func _update_all_table_buttons() -> void:
	var active_exp_table := _expedition.active_expedition_table_index()
	var any_exp_busy := active_exp_table >= 0
	for t in range(game_state.table_count):
		var throwing := table_is_throwing[t]
		table_roll_buttons[t].disabled = throwing or game_state.is_table_auto_enabled(t) or not game_state.can_manual_roll(t)
		table_settle_buttons[t].disabled = throwing or game_state.is_table_auto_enabled(t) or not game_state.can_settle_manual(t)
		var ab := table_auto_buttons[t]
		ab.disabled = not game_state.auto_unlocked
		ab.text = "自动:%s" % ["开" if game_state.is_table_auto_enabled(t) else "关"]
		var dice_cost := game_state.get_dice_upgrade_cost(t)
		table_dice_upgrade_buttons[t].disabled = dice_cost < 0 or game_state.coin_1 < dice_cost
		var exb2 := table_expedition_buttons[t] as Button
		var exp_busy := t < table_expedition_timers.size() and table_expedition_timers[t].time_left > 0.0
		var waiting_other := _expedition.expedition_waiting_result_choice and _expedition.expedition_table_index >= 0 and _expedition.expedition_table_index != t
		var busy_other := any_exp_busy and active_exp_table != t
		exb2.disabled = not game_state.tech_expedition_portal_unlocked or exp_busy or waiting_other or busy_other
	for t in range(game_state.table_count, GameState.MAX_TABLE_COUNT):
		table_roll_buttons[t].disabled = true
		table_settle_buttons[t].disabled = true
		table_auto_buttons[t].disabled = true
		if t < table_expedition_buttons.size():
			(table_expedition_buttons[t] as Button).disabled = true


func _on_roll_pressed(table_index: int) -> void:
	if table_is_throwing[table_index]:
		status_label.text = "桌%d 投掷表现中。" % [table_index + 1]
		return
	var result := turn_manager.roll_manual_dice(table_index)
	if not result["ok"]:
		status_label.text = String(result["message"])
		_refresh_all()
		return
	status_label.text = "桌%d 手动投掷中…" % [table_index + 1]
	_start_throw_phase(table_index, "manual")


func _on_settle_pressed(table_index: int) -> void:
	if table_is_throwing[table_index]:
		status_label.text = "桌%d 投掷表现中，暂不可结算。" % [table_index + 1]
		return
	var result := turn_manager.settle_manual_turn(table_index)
	if not result["ok"]:
		status_label.text = String(result["message"])
	else:
		status_label.text = "桌%d 结算：%s  +%d" % [
			table_index + 1,
			String(result["pattern_label"]),
			int(result["income"])
		]
		_save_game()
	_refresh_all()


func start_session(_player_count: int) -> void:
	visible = true
	_start_new_game()


func start_new_session() -> void:
	visible = true
	_start_new_game()


func continue_session() -> bool:
	visible = true
	var loaded := _load_game()
	if not loaded:
		_start_new_game()
		status_label.text = "未找到有效存档，已开始新游戏。"
	return loaded


func has_continue_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _on_dice_toggled(table_index: int, die_index: int) -> void:
	if table_is_throwing[table_index] or game_state.is_table_auto_enabled(table_index):
		_tables.refresh_dice()
		return
	if int(game_state.table_rolls_used[table_index]) == 0:
		_tables.refresh_dice()
		return
	turn_manager.toggle_hold(table_index, die_index)
	_tables.refresh_dice()


func _on_table_auto_pressed(table_index: int) -> void:
	if not game_state.auto_unlocked:
		status_label.text = "请先在「成长与解锁」按钮中解锁自动扔骰。"
		return
	var next := not game_state.is_table_auto_enabled(table_index)
	game_state.set_table_auto_enabled(table_index, next)
	status_label.text = "桌%d 自动:%s" % [table_index + 1, "开" if next else "关"]
	_apply_table_auto_timer(table_index)
	_save_game()
	_refresh_all()


func _on_table_auto_timer_timeout(table_index: int) -> void:
	if table_index >= game_state.table_count:
		return
	if not game_state.is_table_auto_enabled(table_index):
		return
	if table_is_throwing[table_index]:
		table_queued_auto[table_index] = mini(3, table_queued_auto[table_index] + 1)
		return
	var begin := turn_manager.begin_auto_throw_for_table(table_index)
	if not begin.get("ok", false):
		return
	status_label.text = "桌%d 自动投掷中…" % [table_index + 1]
	_start_throw_phase(table_index, "auto")


func _apply_table_auto_timer(table_index: int) -> void:
	if table_index >= table_auto_timers.size():
		return
	var tmr := table_auto_timers[table_index]
	tmr.stop()
	tmr.wait_time = game_state.get_auto_interval()
	if table_index < game_state.table_count and game_state.is_table_auto_enabled(table_index):
		if not table_is_throwing[table_index]:
			tmr.start()


func _apply_all_auto_timers() -> void:
	for i in range(GameState.MAX_TABLE_COUNT):
		_apply_table_auto_timer(i)


func _on_upgrade_dice_on_table_pressed(table_index: int) -> void:
	var result := game_state.upgrade_dice_on_table(table_index)
	if result["ok"]:
		if bool(result.get("takes_effect_next_turn", false)):
			status_label.text = "桌%d 骰子已升级；新骰子将从下一次投掷生效。" % [table_index + 1]
		else:
			status_label.text = "桌%d 上场骰子=%d" % [table_index + 1, game_state.get_table_dice_count(table_index)]
	else:
		status_label.text = String(result["message"])
	if result["ok"]:
		_save_game()
	_refresh_all()


func _on_upgrade_table_pressed() -> void:
	if _any_table_throwing():
		return
	var previous_table_count := game_state.table_count
	var result := game_state.upgrade_table_count()
	status_label.text = "骰桌数量提升到 %d。" % [game_state.table_count] if result["ok"] else String(result["message"])
	if result["ok"]:
		if previous_table_count < game_state.table_count:
			_apply_table_auto_timer(previous_table_count)
		_save_game()
	_refresh_all()


func _on_upgrade_auto_unlock_pressed() -> void:
	if _any_table_throwing():
		return
	var result := game_state.unlock_auto()
	if result["ok"]:
		status_label.text = "已解锁自动扔骰（各桌默认开启，可单桌关闭）。"
		_apply_all_auto_timers()
		_save_game()
	else:
		status_label.text = String(result["message"])
	_refresh_all()


func _on_upgrade_auto_speed_pressed() -> void:
	if _any_table_throwing():
		return
	var result := game_state.upgrade_auto_speed()
	if result["ok"]:
		status_label.text = "自动速度提升到 Lv.%d。" % [game_state.auto_speed_level]
		_apply_all_auto_timers()
		_save_game()
	else:
		status_label.text = String(result["message"])
	_refresh_all()


func _on_tech_expedition_unlock_pressed() -> void:
	if _any_table_throwing():
		return
	var r := game_state.try_buy_expedition_portal()
	status_label.text = "已解锁各桌远征入口。" if r["ok"] else String(r["message"])
	if r["ok"]:
		_save_game()
	_refresh_all()


func _on_tech_delete_expedition_pressed() -> void:
	if _any_table_throwing():
		return
	var r := game_state.try_buy_delete_expedition()
	status_label.text = "已解锁删骰远征。" if r["ok"] else String(r["message"])
	if r["ok"]:
		_save_game()
	_refresh_all()


func _on_tech_synth_expedition_pressed() -> void:
	if _any_table_throwing():
		return
	var r := game_state.try_buy_synth_expedition()
	status_label.text = "已解锁合成远征。" if r["ok"] else String(r["message"])
	if r["ok"]:
		_save_game()
	_refresh_all()


func _on_tech_dice_cap_pressed() -> void:
	if _any_table_throwing():
		return
	var r := game_state.try_buy_dice_cap_level()
	status_label.text = "骰子上限科技已提升。" if r["ok"] else String(r["message"])
	if r["ok"]:
		_save_game()
	_refresh_all()


func _on_tech_acquire_n_pressed() -> void:
	if _any_table_throwing():
		return
	var r := game_state.try_upgrade_acquire_n()
	status_label.text = "得骰远征选项+1。" if r["ok"] else String(r["message"])
	if r["ok"]:
		_save_game()
	_refresh_all()


func _on_tech_delete_n_pressed() -> void:
	if _any_table_throwing():
		return
	var r := game_state.try_upgrade_delete_n()
	status_label.text = "删骰远征选项+1。" if r["ok"] else String(r["message"])
	if r["ok"]:
		_save_game()
	_refresh_all()


func _on_tech_synth_n_pressed() -> void:
	if _any_table_throwing():
		return
	var r := game_state.try_upgrade_synth_n()
	status_label.text = "合成远征候选池+1。" if r["ok"] else String(r["message"])
	if r["ok"]:
		_save_game()
	_refresh_all()


func _on_tech_exp_duration_pressed() -> void:
	if _any_table_throwing():
		return
	var r := game_state.try_upgrade_expedition_duration()
	status_label.text = "远征耗时已缩短。" if r["ok"] else String(r["message"])
	if r["ok"]:
		_save_game()
	_refresh_all()


func _save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入存档。")
		return
	var bundle := {
		"bundle": 1,
		"game": game_state.to_save_data(),
		"time_speed": _dialogs.time_speed
	}
	file.store_string(JSON.stringify(bundle))


func _load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	var game_dict: Dictionary = parsed
	if parsed.has("game") and parsed["game"] is Dictionary:
		game_dict = parsed["game"]
		_dialogs.time_speed = _TimeSpeedSettings.clamp_mult(int(parsed.get("time_speed", 1)))
	else:
		_dialogs.time_speed = 1
	var ok := game_state.load_from_save_data(game_dict)
	if not ok:
		return false
	_TimeSpeedSettings.apply_engine_multiplier(_dialogs.time_speed)
	if _dialogs.time_speed_slider != null:
		_dialogs.time_speed_slider.set_value_no_signal(_dialogs.time_speed)
	if _dialogs.time_speed_value_label != null:
		_dialogs.time_speed_value_label.text = "当前倍速: %d×" % _dialogs.time_speed
	for i in range(GameState.MAX_TABLE_COUNT):
		table_throw_timers[i].stop()
		table_auto_timers[i].stop()
		if i < table_expedition_timers.size():
			table_expedition_timers[i].stop()
		table_is_throwing[i] = false
		table_throw_sources[i] = ""
		table_throw_visuals[i] = []
		table_queued_auto[i] = 0
	throw_pulse_timer.stop()
	_apply_all_auto_timers()
	status_label.text = "已加载存档。"
	_refresh_all()
	return true


func _start_throw_phase(table_index: int, source: String) -> void:
	table_auto_timers[table_index].stop()
	table_is_throwing[table_index] = true
	table_throw_sources[table_index] = source
	_fill_throw_visuals_for_table(table_index)
	table_throw_timers[table_index].stop()
	table_throw_timers[table_index].wait_time = THROW_ANIMATION_SEC
	table_throw_timers[table_index].start()
	if throw_pulse_timer.is_stopped():
		throw_pulse_timer.wait_time = THROW_PULSE_SEC
		throw_pulse_timer.start()
	_refresh_all()


func _fill_throw_visuals_for_table(table_index: int) -> void:
	var dc := game_state.get_table_dice_count(table_index)
	var arr: Array[int] = []
	for i in range(dc):
		arr.append(randi_range(DiceLogic.FACE_MIN, DiceLogic.FACE_MAX))
	table_throw_visuals[table_index] = arr


func _on_throw_pulse_timer_timeout() -> void:
	if not _any_table_throwing():
		throw_pulse_timer.stop()
		return
	for t in range(game_state.table_count):
		if table_is_throwing[t]:
			_fill_throw_visuals_for_table(t)
	_tables.refresh_dice()


func _on_table_throw_timer_timeout(table_index: int) -> void:
	if not table_is_throwing[table_index]:
		return
	table_is_throwing[table_index] = false
	table_throw_visuals[table_index] = []
	var src := table_throw_sources[table_index]
	table_throw_sources[table_index] = ""
	if src == "manual":
		status_label.text = "桌%d 掷骰完成，可锁骰或结算。" % [table_index + 1]
	elif src == "auto":
		var settle := turn_manager.finalize_auto_throw_for_table(table_index)
		if settle.get("ok", false):
			status_label.text = "桌%d 自动结算：%s  +%d" % [
				table_index + 1,
				String(settle["pattern_label"]),
				int(settle["income"])
			]
			_save_game()
	if not _any_table_throwing():
		throw_pulse_timer.stop()
	if table_queued_auto[table_index] > 0 and game_state.is_table_auto_enabled(table_index):
		var beginq := turn_manager.begin_auto_throw_for_table(table_index)
		if beginq.get("ok", false):
			table_queued_auto[table_index] -= 1
			_start_throw_phase(table_index, "auto")
			return
	_apply_table_auto_timer(table_index)
	_refresh_all()
