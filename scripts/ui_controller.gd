class_name UIController
extends Control

@onready var status_label: Label = $Margin/VBox/TopRow/LeftColumn/StatusLabel
@onready var turn_label: Label = $Margin/VBox/TopRow/LeftColumn/TurnLabel
@onready var rolls_label: Label = $Margin/VBox/TopRow/LeftColumn/RollsLabel
@onready var dice_box: HBoxContainer = $Margin/VBox/TopRow/LeftColumn/DiceBox
@onready var player_score_lists: HBoxContainer = $Margin/VBox/PlayerScoreLists
@onready var score_board: RichTextLabel = $Margin/VBox/TopRow/ScoreBoardPanel/ScoreBoardMargin/ScoreBoard
@onready var roll_button: Button = $Margin/VBox/TopRow/LeftColumn/Controls/RollButton
@onready var score_button: Button = $Margin/VBox/TopRow/LeftColumn/Controls/ScoreButton
@onready var auto_button: Button = $Margin/VBox/TopRow/LeftColumn/Controls/AutoButton
@onready var auto_timer: Timer = $AutoTimer

var game_state := GameState.new()
var turn_manager := TurnManager.new(game_state)
var upgrade_buttons: Dictionary = {}
const SAVE_PATH := "user://savegame.json"
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
	_bind_signals()


func _bind_signals() -> void:
	roll_button.pressed.connect(_on_roll_pressed)
	score_button.pressed.connect(_on_settle_pressed)
	auto_button.pressed.connect(_on_auto_pressed)
	auto_timer.timeout.connect(_on_auto_timer_timeout)
	for i in range(dice_box.get_child_count()):
		var die_button := dice_box.get_child(i) as Button
		var index := i
		die_button.expand_icon = true
		die_button.toggled.connect(func(_pressed: bool) -> void:
			_on_dice_toggled(index)
		)

	_build_upgrade_panel()


func _build_upgrade_panel() -> void:
	for child in player_score_lists.get_children():
		child.queue_free()

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_score_lists.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	var title := Label.new()
	title.text = "成长与解锁（货币1）"
	column.add_child(title)

	upgrade_buttons = {}
	upgrade_buttons["dice"] = _create_upgrade_button(column, _on_upgrade_dice_pressed)
	upgrade_buttons["table"] = _create_upgrade_button(column, _on_upgrade_table_pressed)
	upgrade_buttons["auto_unlock"] = _create_upgrade_button(column, _on_upgrade_auto_unlock_pressed)
	upgrade_buttons["auto_speed"] = _create_upgrade_button(column, _on_upgrade_auto_speed_pressed)


func _create_upgrade_button(parent: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _start_new_game() -> void:
	turn_manager.start_new_game()
	auto_timer.stop()
	_apply_auto_timer()
	status_label.text = "新对局开始。"
	roll_button.text = "手动掷骰"
	score_button.text = "结算本回合"
	_save_game()
	_refresh_all()


func _refresh_all() -> void:
	_refresh_turn_labels()
	_refresh_dice()
	_refresh_upgrade_panel()
	_refresh_score_board()
	_update_button_states()


func _refresh_turn_labels() -> void:
	turn_label.text = "骰子:%d/7  骰桌:%d/%d" % [
		game_state.dice_count, game_state.table_count, game_state.MAX_TABLE_COUNT
	]
	rolls_label.text = "掷骰次数: %d / %d" % [
		game_state.current_rolls_used, game_state.MAX_ROLLS_PER_TURN
	]


func _refresh_dice() -> void:
	for i in range(dice_box.get_child_count()):
		var die_button := dice_box.get_child(i) as Button
		var visible_for_count := i < game_state.dice_count
		die_button.visible = visible_for_count
		if not visible_for_count:
			continue
		var value := game_state.current_dice_values[i]
		die_button.icon = DIE_TEXTURES.get(value, DIE_TEXTURES[1])
		die_button.text = ""
		die_button.button_pressed = game_state.current_holds[i]
		die_button.modulate = Color(1.0, 0.92, 0.6) if game_state.current_holds[i] else Color(1, 1, 1)
		die_button.tooltip_text = "骰子%d（点数%d）%s" % [
			i + 1,
			value,
			"已锁定" if game_state.current_holds[i] else "可点击锁定"
		]
		die_button.disabled = game_state.current_rolls_used == 0


func _refresh_upgrade_panel() -> void:
	var dice_cost := game_state.get_dice_upgrade_cost()
	var table_cost := game_state.get_table_upgrade_cost()
	var auto_unlock_cost := game_state.get_auto_unlock_cost()
	var auto_speed_cost := game_state.get_auto_speed_upgrade_cost()

	var dice_btn := upgrade_buttons.get("dice") as Button
	dice_btn.text = "升级骰子数量（当前%d）  花费:%s" % [
		game_state.dice_count,
		"MAX" if dice_cost < 0 else str(dice_cost)
	]
	dice_btn.disabled = dice_cost < 0 or game_state.coin_1 < dice_cost

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
	auto_speed_btn.text = "自动速度 Lv.%d  花费:%s  间隔:%.2fs" % [
		game_state.auto_speed_level,
		"-" if auto_speed_cost < 0 else str(auto_speed_cost),
		game_state.get_auto_interval()
	]
	auto_speed_btn.disabled = auto_speed_cost < 0 or game_state.coin_1 < auto_speed_cost


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


func _update_button_states() -> void:
	roll_button.disabled = not game_state.can_manual_roll()
	score_button.disabled = not game_state.can_settle_manual()
	auto_button.disabled = not game_state.auto_unlocked
	auto_button.text = "自动:%s" % ["开启" if game_state.auto_enabled else "关闭"]


func _on_roll_pressed() -> void:
	var result := turn_manager.roll_manual_dice()
	if not result["ok"]:
		status_label.text = result["message"]
	else:
		status_label.text = "掷骰完成，可锁骰并继续重投，或直接结算。"
	_refresh_all()


func _on_settle_pressed() -> void:
	var result := turn_manager.settle_manual_turn()
	if not result["ok"]:
		status_label.text = result["message"]
	else:
		status_label.text = "手动结算：%s  收益+%d" % [
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


func _on_dice_toggled(index: int) -> void:
	if game_state.current_rolls_used == 0:
		_refresh_dice()
		return
	turn_manager.toggle_hold(index)
	_refresh_dice()


func _on_auto_pressed() -> void:
	if not game_state.auto_unlocked:
		status_label.text = "请先在成长面板解锁自动扔骰。"
		return
	game_state.auto_enabled = not game_state.auto_enabled
	if game_state.auto_enabled:
		status_label.text = "自动扔骰已开启。"
	else:
		status_label.text = "自动扔骰已关闭。"
	_apply_auto_timer()
	_save_game()
	_refresh_all()


func _on_auto_timer_timeout() -> void:
	var result := turn_manager.run_auto_tick()
	if result.get("ok", false):
		status_label.text = "自动结算 +%d（%d桌）" % [
			int(result["income"]),
			int(result["turns"])
		]
		_save_game()
	_refresh_all()


func _apply_auto_timer() -> void:
	auto_timer.wait_time = game_state.get_auto_interval()
	if game_state.auto_enabled:
		auto_timer.start()
	else:
		auto_timer.stop()


func _on_upgrade_dice_pressed() -> void:
	var result := game_state.upgrade_dice_count()
	status_label.text = "骰子数量提升到 %d。" % [game_state.dice_count] if result["ok"] else String(result["message"])
	if result["ok"]:
		_save_game()
	_refresh_all()


func _on_upgrade_table_pressed() -> void:
	var result := game_state.upgrade_table_count()
	status_label.text = "骰桌数量提升到 %d。" % [game_state.table_count] if result["ok"] else String(result["message"])
	if result["ok"]:
		_save_game()
	_refresh_all()


func _on_upgrade_auto_unlock_pressed() -> void:
	var result := game_state.unlock_auto()
	if result["ok"]:
		status_label.text = "已解锁自动扔骰。"
		_apply_auto_timer()
		_save_game()
	else:
		status_label.text = String(result["message"])
	_refresh_all()


func _on_upgrade_auto_speed_pressed() -> void:
	var result := game_state.upgrade_auto_speed()
	if result["ok"]:
		status_label.text = "自动速度提升到 Lv.%d。" % [game_state.auto_speed_level]
		_apply_auto_timer()
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
	auto_timer.stop()
	_apply_auto_timer()
	status_label.text = "已加载存档。"
	_refresh_all()
	return true
