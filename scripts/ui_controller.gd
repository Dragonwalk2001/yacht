class_name UIController
extends Control

@onready var status_label: Label = $Margin/VBox/TopRow/LeftColumn/StatusLabel
@onready var turn_label: Label = $Margin/VBox/TopRow/LeftColumn/TurnLabel
@onready var rolls_label: Label = $Margin/VBox/TopRow/LeftColumn/RollsLabel
@onready var tables_scroll: ScrollContainer = $Margin/VBox/TopRow/LeftColumn/TablesScroll
@onready var tables_grid: GridContainer = $Margin/VBox/TopRow/LeftColumn/TablesScroll/TablesGrid
@onready var score_board: RichTextLabel = $Margin/VBox/TopRow/ScoreBoardPanel/ScoreBoardMargin/ScoreBoard
@onready var menu_button: MenuButton = $Margin/VBox/MenuRow/MenuButton
@onready var throw_pulse_timer: Timer = $ThrowPulseTimer

var dice_stats_dialog: AcceptDialog
var growth_window: Window
var growth_coin_label: Label

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
var table_throw_timers: Array[Timer] = []
var table_auto_timers: Array[Timer] = []
var table_is_throwing: Array[bool] = []
var table_throw_sources: Array[String] = []
var table_throw_visuals: Array = []
var table_queued_auto: Array[int] = []

const SAVE_PATH := "user://savegame.json"
const THROW_ANIMATION_SEC: float = 0.5
const THROW_PULSE_SEC: float = 0.08
const DIE_TEXTURES := {
	1: preload("res://assets/dice/die_1.svg"),
	2: preload("res://assets/dice/die_2.svg"),
	3: preload("res://assets/dice/die_3.svg"),
	4: preload("res://assets/dice/die_4.svg"),
	5: preload("res://assets/dice/die_5.svg"),
	6: preload("res://assets/dice/die_6.svg")
}


func _ready() -> void:
	randomize()
	_init_dice_stats_dialog()
	_init_growth_window()
	_init_throw_tracking_arrays()
	_create_per_table_timers()
	_build_table_panels()
	_bind_signals()
	_apply_tables_scroll_min_height()
	_apply_table_panel_density()


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
		var cbox := inner.get_child(2) as HBoxContainer
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


func _init_dice_stats_dialog() -> void:
	dice_stats_dialog = AcceptDialog.new()
	dice_stats_dialog.title = "掷骰统计"
	dice_stats_dialog.ok_button_text = "关闭"
	dice_stats_dialog.dialog_autowrap = true
	dice_stats_dialog.min_size = Vector2i(440, 180)
	add_child(dice_stats_dialog)


func _init_growth_window() -> void:
	growth_window = Window.new()
	growth_window.title = "成长与解锁 · 科技树"
	growth_window.size = Vector2i(540, 480)
	growth_window.min_size = Vector2i(420, 360)
	growth_window.transient = true
	growth_window.exclusive = true
	growth_window.unresizable = false
	growth_window.visible = false
	growth_window.close_requested.connect(func() -> void:
		growth_window.hide()
	)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	growth_window.add_child(margin)
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)
	growth_coin_label = Label.new()
	growth_coin_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(growth_coin_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var tree_root := VBoxContainer.new()
	tree_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_root.add_theme_constant_override("separation", 14)
	tree_root.custom_minimum_size.x = 420
	scroll.add_child(tree_root)
	var trunk := _growth_tree_panel("骰桌扩张", tree_root)
	upgrade_buttons = {}
	upgrade_buttons["table"] = _create_upgrade_button(trunk, _on_upgrade_table_pressed)
	_add_growth_tree_connector(tree_root, "↓")
	var auto_panel := _growth_tree_panel("自动化", tree_root)
	upgrade_buttons["auto_unlock"] = _create_upgrade_button(auto_panel, _on_upgrade_auto_unlock_pressed)
	upgrade_buttons["auto_speed"] = _create_upgrade_button(auto_panel, _on_upgrade_auto_speed_pressed)
	add_child(growth_window)


func _growth_tree_panel(subtitle: String, parent: VBoxContainer) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)
	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_font_size_override("font_size", 15)
	inner.add_child(sub)
	return inner


func _add_growth_tree_connector(parent: VBoxContainer, text: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var lab := Label.new()
	lab.text = text
	lab.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62))
	row.add_child(lab)
	parent.add_child(row)


func _bind_signals() -> void:
	var pop := menu_button.get_popup()
	pop.add_item("掷骰统计…", 0)
	pop.add_item("成长与解锁…", 1)
	pop.id_pressed.connect(_on_game_menu_id_pressed)
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


func _build_table_panels() -> void:
	for child in tables_grid.get_children():
		child.queue_free()
	table_panel_roots.clear()
	table_die_buttons.clear()
	table_info_labels.clear()
	table_roll_buttons.clear()
	table_settle_buttons.clear()
	table_auto_buttons.clear()
	table_dice_upgrade_buttons.clear()
	tables_grid.columns = 2
	var die_size := Vector2(48, 48)
	for table_index in range(GameState.MAX_TABLE_COUNT):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		table_panel_roots.append(panel)
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 4)
		panel.add_child(inner)
		var info := Label.new()
		table_info_labels.append(info)
		inner.add_child(info)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		inner.add_child(row)
		var buttons_for_table: Array[Button] = []
		for _die_index in range(GameState.MAX_DICE_COUNT):
			var die_button := Button.new()
			die_button.custom_minimum_size = die_size
			die_button.text = ""
			die_button.expand_icon = true
			die_button.toggle_mode = true
			row.add_child(die_button)
			buttons_for_table.append(die_button)
		table_die_buttons.append(buttons_for_table)
		var ctrl := HBoxContainer.new()
		ctrl.add_theme_constant_override("separation", 6)
		inner.add_child(ctrl)
		var rb := Button.new()
		rb.text = "掷骰"
		table_roll_buttons.append(rb)
		ctrl.add_child(rb)
		var sb := Button.new()
		sb.text = "结算"
		table_settle_buttons.append(sb)
		ctrl.add_child(sb)
		var ab := Button.new()
		ab.text = "自动:关"
		table_auto_buttons.append(ab)
		ctrl.add_child(ab)
		var ub := Button.new()
		ub.text = "本桌骰子+1"
		table_dice_upgrade_buttons.append(ub)
		inner.add_child(ub)
		tables_grid.add_child(panel)


func _create_upgrade_button(parent: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


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
	_refresh_table_infos()
	_refresh_dice()
	_refresh_growth_tree()
	_refresh_score_board()
	_update_all_table_buttons()


func _refresh_turn_labels() -> void:
	var sum_dice := 0
	for i in range(game_state.table_count):
		sum_dice += game_state.get_table_dice_count(i)
	turn_label.text = "骰桌:%d/%d · 骰子合计:%d（每桌独立操作与自动计时）" % [
		game_state.table_count, GameState.MAX_TABLE_COUNT, sum_dice
	]
	rolls_label.text = "各桌独立操作；骰桌区可上下滚动。"


func _refresh_table_infos() -> void:
	for t in range(GameState.MAX_TABLE_COUNT):
		if t >= game_state.table_count:
			continue
		var dc := game_state.get_table_dice_count(t)
		var ru := int(game_state.table_rolls_used[t])
		table_info_labels[t].text = "桌%d · 投%d/%d · 骰%d个" % [t + 1, ru, GameState.MAX_ROLLS_PER_TURN, dc]


func _refresh_dice() -> void:
	for table_index in range(table_panel_roots.size()):
		var root := table_panel_roots[table_index]
		root.visible = table_index < game_state.table_count
		if not root.visible:
			continue
		var dc := game_state.get_table_dice_count(table_index)
		for die_index in range(GameState.MAX_DICE_COUNT):
			var die_button := table_die_buttons[table_index][die_index] as Button
			var visible_for_count := die_index < dc
			die_button.visible = visible_for_count
			if not visible_for_count:
				continue
			var value: int = 1
			var held := false
			if table_is_throwing[table_index] and table_throw_visuals[table_index] is Array:
				var tv: Array = table_throw_visuals[table_index]
				if die_index < tv.size():
					value = clampi(int(tv[die_index]), DiceLogic.FACE_MIN, DiceLogic.FACE_MAX)
			else:
				var vals: Array = game_state.table_dice_values[table_index]
				if die_index < vals.size():
					value = clampi(int(vals[die_index]), DiceLogic.FACE_MIN, DiceLogic.FACE_MAX)
				var hrow: Array = game_state.table_holds[table_index]
				if die_index < hrow.size():
					held = bool(hrow[die_index])
			die_button.icon = DIE_TEXTURES.get(value, DIE_TEXTURES[1])
			die_button.text = ""
			var auto_on := game_state.is_table_auto_enabled(table_index)
			die_button.set_pressed_no_signal(not table_is_throwing[table_index] and held)
			if table_is_throwing[table_index]:
				die_button.modulate = Color(0.85, 0.9, 1.0)
			else:
				die_button.modulate = Color(1.0, 0.92, 0.6) if held else Color(1, 1, 1)
			die_button.tooltip_text = "桌%d 骰%d 点%d %s" % [
				table_index + 1,
				die_index + 1,
				value,
				"已锁定" if held else "可点锁定"
			]
			var ru := int(game_state.table_rolls_used[table_index])
			die_button.disabled = table_is_throwing[table_index] or auto_on or ru == 0


func _refresh_growth_tree() -> void:
	if growth_coin_label != null:
		growth_coin_label.text = "货币1: %d  ·  在科技树中消耗货币购买升级" % game_state.coin_1
	var table_cost := game_state.get_table_upgrade_cost()
	var auto_unlock_cost := game_state.get_auto_unlock_cost()
	var auto_speed_cost := game_state.get_auto_speed_upgrade_cost()

	var table_btn := upgrade_buttons.get("table") as Button
	table_btn.text = "升级骰桌数量（当前%d）  花费:%s" % [
		game_state.table_count,
		"MAX" if table_cost < 0 else str(table_cost)
	]
	table_btn.disabled = table_cost < 0 or game_state.coin_1 < table_cost

	var auto_unlock_btn := upgrade_buttons.get("auto_unlock") as Button
	if game_state.auto_unlocked:
		auto_unlock_btn.text = "自动扔骰：已解锁"
		auto_unlock_btn.disabled = true
	else:
		auto_unlock_btn.text = "解锁自动扔骰  花费:%d" % auto_unlock_cost
		auto_unlock_btn.disabled = game_state.coin_1 < auto_unlock_cost

	var auto_speed_btn := upgrade_buttons.get("auto_speed") as Button
	auto_speed_btn.text = "自动速度 Lv.%d  花费:%s  间隔:%.2fs（各桌同档）" % [
		game_state.auto_speed_level,
		"MAX" if auto_speed_cost < 0 else str(auto_speed_cost),
		game_state.get_auto_interval()
	]
	auto_speed_btn.disabled = auto_speed_cost < 0 or game_state.coin_1 < auto_speed_cost

	for t in range(GameState.MAX_TABLE_COUNT):
		var btn := table_dice_upgrade_buttons[t] as Button
		if t >= game_state.table_count:
			btn.visible = false
			continue
		btn.visible = true
		var cost := game_state.get_dice_upgrade_cost(t)
		btn.text = "桌%d 骰子+1  花费:%s" % [t + 1, "MAX" if cost < 0 else str(cost)]


func _refresh_score_board() -> void:
	var lines: Array[String] = []
	lines.append("货币1: %d" % [game_state.coin_1])
	lines.append("总产出: %d" % [game_state.total_coin_earned])
	lines.append("当前预估收益/秒: %.1f" % [game_state.estimate_income_per_second()])
	lines.append("最近结算: %s  +%d" % [game_state.last_settlement_label, game_state.last_settlement_income])
	lines.append("基础点数:%d  判型倍率:%.2f  成长倍率:%.2f" % [
		game_state.last_settlement_base,
		game_state.last_settlement_multiplier,
		game_state.get_progress_multiplier()
	])
	lines.append("手动回合:%d  自动回合:%d" % [
		game_state.total_manual_turns,
		game_state.total_auto_turns
	])
	score_board.text = "\n".join(lines)


func _on_game_menu_id_pressed(id: int) -> void:
	if id == 0:
		dice_stats_dialog.dialog_text = game_state.dice_face_stats.format_dialog_text()
		dice_stats_dialog.popup_centered()
	elif id == 1:
		_refresh_growth_tree()
		growth_window.popup_centered()


func _update_all_table_buttons() -> void:
	for t in range(game_state.table_count):
		var throwing := table_is_throwing[t]
		table_roll_buttons[t].disabled = throwing or game_state.is_table_auto_enabled(t) or not game_state.can_manual_roll(t)
		table_settle_buttons[t].disabled = throwing or game_state.is_table_auto_enabled(t) or not game_state.can_settle_manual(t)
		var ab := table_auto_buttons[t]
		ab.disabled = not game_state.auto_unlocked
		ab.text = "自动:%s" % ["开" if game_state.is_table_auto_enabled(t) else "关"]
		var dice_cost := game_state.get_dice_upgrade_cost(t)
		table_dice_upgrade_buttons[t].disabled = throwing or dice_cost < 0 or game_state.coin_1 < dice_cost
	for t in range(game_state.table_count, GameState.MAX_TABLE_COUNT):
		table_roll_buttons[t].disabled = true
		table_settle_buttons[t].disabled = true
		table_auto_buttons[t].disabled = true


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
		_refresh_dice()
		return
	if int(game_state.table_rolls_used[table_index]) == 0:
		_refresh_dice()
		return
	turn_manager.toggle_hold(table_index, die_index)
	_refresh_dice()


func _on_table_auto_pressed(table_index: int) -> void:
	if not game_state.auto_unlocked:
		status_label.text = "请先在菜单「成长与解锁」中解锁自动扔骰。"
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
	if table_is_throwing[table_index]:
		return
	var result := game_state.upgrade_dice_on_table(table_index)
	status_label.text = "桌%d 骰子数=%d" % [table_index + 1, game_state.get_table_dice_count(table_index)] if result["ok"] else String(result["message"])
	if result["ok"]:
		_save_game()
	_refresh_all()


func _on_upgrade_table_pressed() -> void:
	if _any_table_throwing():
		return
	var result := game_state.upgrade_table_count()
	status_label.text = "骰桌数量提升到 %d。" % [game_state.table_count] if result["ok"] else String(result["message"])
	if result["ok"]:
		_apply_all_auto_timers()
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


func _save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入存档。")
		return
	file.store_string(JSON.stringify(game_state.to_save_data()))


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
	var ok := game_state.load_from_save_data(parsed)
	if not ok:
		return false
	for i in range(GameState.MAX_TABLE_COUNT):
		table_throw_timers[i].stop()
		table_auto_timers[i].stop()
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
	for _i in range(dc):
		arr.append(randi_range(DiceLogic.FACE_MIN, DiceLogic.FACE_MAX))
	table_throw_visuals[table_index] = arr


func _on_throw_pulse_timer_timeout() -> void:
	if not _any_table_throwing():
		throw_pulse_timer.stop()
		return
	for t in range(game_state.table_count):
		if table_is_throwing[t]:
			_fill_throw_visuals_for_table(t)
	_refresh_dice()


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
