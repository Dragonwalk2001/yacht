class_name UIController
extends Control

@onready var status_label: Label = $Margin/VBox/TopRow/LeftColumn/StatusLabel
@onready var turn_label: Label = $Margin/VBox/TopRow/LeftColumn/TurnLabel
@onready var rolls_label: Label = $Margin/VBox/TopRow/LeftColumn/RollsLabel
@onready var dice_box: HBoxContainer = $Margin/VBox/TopRow/LeftColumn/DiceBox
@onready var player_score_lists: HBoxContainer = $Margin/VBox/PlayerScoreLists
@onready var score_board: RichTextLabel = $Margin/VBox/TopRow/ScoreBoardPanel/ScoreBoardMargin/ScoreBoard
@onready var player_count_box: SpinBox = $Margin/VBox/TopRow/LeftColumn/Controls/PlayerCount
@onready var roll_button: Button = $Margin/VBox/TopRow/LeftColumn/Controls/RollButton
@onready var score_button: Button = $Margin/VBox/TopRow/LeftColumn/Controls/ScoreButton
@onready var new_game_button: Button = $Margin/VBox/TopRow/LeftColumn/Controls/NewGameButton
@onready var result_popup: AcceptDialog = $ResultPopup
@onready var result_label: RichTextLabel = $ResultPopup/ResultText

var game_state := GameState.new()
var turn_manager := TurnManager.new(game_state)
var category_ids: Array[String] = []
var selected_category_id := ""
var selected_player_index := -1
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
	_build_categories()
	_start_new_game(2)


func _bind_signals() -> void:
	roll_button.pressed.connect(_on_roll_pressed)
	score_button.pressed.connect(_on_score_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	for i in range(dice_box.get_child_count()):
		var die_button := dice_box.get_child(i) as Button
		var index := i
		die_button.expand_icon = true
		die_button.toggled.connect(func(_pressed: bool) -> void:
			_on_dice_toggled(index)
		)


func _build_categories() -> void:
	category_ids.clear()
	for category in ScoringRules.ALL_CATEGORIES:
		category_ids.append(category)


func _start_new_game(player_count: int) -> void:
	turn_manager.start_new_game(player_count)
	selected_category_id = ""
	selected_player_index = -1
	status_label.text = "新对局开始。"
	_refresh_all()


func _refresh_all() -> void:
	_refresh_turn_labels()
	_refresh_dice()
	_refresh_player_score_lists()
	_refresh_score_board()
	_update_button_states()


func _refresh_turn_labels() -> void:
	if game_state.has_game_ended():
		turn_label.text = "对局结束"
		rolls_label.text = "掷骰次数: -"
		return
	var player := game_state.get_current_player()
	turn_label.text = "第 %d / %d 轮 - %s" % [
		game_state.current_round, game_state.TOTAL_ROUNDS, player["name"]
	]
	rolls_label.text = "掷骰次数: %d / %d" % [
		game_state.rolls_used, game_state.MAX_ROLLS_PER_TURN
	]


func _refresh_dice() -> void:
	for i in range(dice_box.get_child_count()):
		var die_button := dice_box.get_child(i) as Button
		var value := game_state.dice_values[i]
		die_button.icon = DIE_TEXTURES.get(value, DIE_TEXTURES[1])
		die_button.text = ""
		die_button.button_pressed = game_state.held_flags[i]
		die_button.modulate = Color(1.0, 0.92, 0.6) if game_state.held_flags[i] else Color(1, 1, 1)
		die_button.tooltip_text = "骰子%d（点数%d）%s" % [
			i + 1,
			value,
			"已锁定" if game_state.held_flags[i] else "可点击锁定"
		]
		die_button.disabled = game_state.rolls_used == 0 or game_state.has_game_ended()


func _refresh_player_score_lists() -> void:
	if selected_player_index != game_state.current_player_index:
		selected_category_id = ""
		selected_player_index = -1

	for child in player_score_lists.get_children():
		child.queue_free()

	for player_index in range(game_state.players.size()):
		var player := game_state.players[player_index]
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_score_lists.add_child(panel)

		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		panel.add_child(column)

		var total := game_state.get_total_score(player)
		var header := Label.new()
		var header_suffix := "（当前）" if player_index == game_state.current_player_index and not game_state.has_game_ended() else ""
		header.text = "%s%s  总分:%d" % [player["name"], header_suffix, total]
		column.add_child(header)

		for category in category_ids:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			column.add_child(row)

			var category_label := Label.new()
			category_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			category_label.text = ScoringRules.get_label(category)
			row.add_child(category_label)

			var score_button_item := Button.new()
			score_button_item.custom_minimum_size = Vector2(92, 0)
			row.add_child(score_button_item)

			var value = player["scores"][category]
			var preview := 0
			if game_state.rolls_used > 0:
				preview = ScoringRules.score_category(category, game_state.dice_values)

			if value != null:
				score_button_item.text = "已记:%d" % [int(value)]
				score_button_item.disabled = true
			else:
				score_button_item.text = "预估:%d" % [preview]
				score_button_item.disabled = player_index != game_state.current_player_index \
					or game_state.rolls_used == 0 \
					or game_state.has_game_ended()

			if player_index == selected_player_index and category == selected_category_id:
				score_button_item.text = "已选:%d" % [preview]
				score_button_item.modulate = Color(0.35, 0.9, 0.45)
			else:
				score_button_item.modulate = Color(1, 1, 1)

			score_button_item.pressed.connect(_on_category_pressed.bind(player_index, category))


func _refresh_score_board() -> void:
	var lines: Array[String] = ["计分板："]
	for player in game_state.players:
		var upper := game_state.get_upper_subtotal(player)
		var bonus := game_state.get_upper_bonus(player)
		var total := game_state.get_total_score(player)
		lines.append("%s  上半区:%d  奖励:%d  总分:%d" % [player["name"], upper, bonus, total])
	score_board.text = "\n".join(lines)


func _update_button_states() -> void:
	roll_button.disabled = not game_state.can_roll() or game_state.has_game_ended()
	score_button.disabled = game_state.rolls_used == 0 or game_state.has_game_ended()


func _on_roll_pressed() -> void:
	var result := turn_manager.roll_current_dice()
	if not result["ok"]:
		status_label.text = result["message"]
	else:
		status_label.text = "掷骰完成，可锁定骰子或落分。"
	_refresh_all()


func _on_score_pressed() -> void:
	if selected_category_id.is_empty() or selected_player_index != game_state.current_player_index:
		status_label.text = "请先选择一个类别。"
		return
	var result := turn_manager.score_category(selected_category_id)
	if not result["ok"]:
		status_label.text = result["message"]
		_refresh_all()
		return
	status_label.text = "已在 %s 落分：%d" % [ScoringRules.get_label(selected_category_id), result["score"]]
	selected_category_id = ""
	selected_player_index = -1
	if result["game_over"]:
		result_label.text = ResultLogic.build_result_text(game_state)
		result_popup.popup_centered_ratio(0.55)
	_refresh_all()


func _on_new_game_pressed() -> void:
	_start_new_game(int(player_count_box.value))


func _on_dice_toggled(index: int) -> void:
	if game_state.rolls_used == 0 or game_state.has_game_ended():
		_refresh_dice()
		return
	turn_manager.toggle_hold(index)
	_refresh_dice()


func _on_category_pressed(player_index: int, category: String) -> void:
	if player_index != game_state.current_player_index:
		return
	selected_player_index = player_index
	selected_category_id = category
	_refresh_player_score_lists()
