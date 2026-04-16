class_name UIController
extends Control

@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var turn_label: Label = $Margin/VBox/TurnLabel
@onready var rolls_label: Label = $Margin/VBox/RollsLabel
@onready var dice_box: HBoxContainer = $Margin/VBox/DiceBox
@onready var category_list: ItemList = $Margin/VBox/CategoryList
@onready var score_board: RichTextLabel = $Margin/VBox/ScoreBoard
@onready var player_count_box: SpinBox = $Margin/VBox/Controls/PlayerCount
@onready var roll_button: Button = $Margin/VBox/Controls/RollButton
@onready var score_button: Button = $Margin/VBox/Controls/ScoreButton
@onready var new_game_button: Button = $Margin/VBox/Controls/NewGameButton
@onready var result_popup: AcceptDialog = $ResultPopup
@onready var result_label: RichTextLabel = $ResultPopup/ResultText

var game_state := GameState.new()
var turn_manager := TurnManager.new(game_state)
var category_ids: Array[String] = []


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
		die_button.toggled.connect(func(_pressed: bool) -> void:
			_on_dice_toggled(index)
		)


func _build_categories() -> void:
	category_list.clear()
	category_ids.clear()
	for category in ScoringRules.ALL_CATEGORIES:
		category_ids.append(category)
		category_list.add_item(ScoringRules.get_label(category))


func _start_new_game(player_count: int) -> void:
	turn_manager.start_new_game(player_count)
	status_label.text = "新对局开始。"
	_refresh_all()


func _refresh_all() -> void:
	_refresh_turn_labels()
	_refresh_dice()
	_refresh_category_list()
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
		die_button.text = "骰%d: %d" % [i + 1, game_state.dice_values[i]]
		die_button.button_pressed = game_state.held_flags[i]
		die_button.disabled = game_state.rolls_used == 0 or game_state.has_game_ended()


func _refresh_category_list() -> void:
	category_list.deselect_all()
	var best_index := -1
	var best_preview := -1
	if game_state.rolls_used > 0 and not game_state.has_game_ended():
		for i in range(category_ids.size()):
			var candidate := category_ids[i]
			if game_state.is_category_used(candidate):
				continue
			var candidate_score := ScoringRules.score_category(candidate, game_state.dice_values)
			if candidate_score > best_preview:
				best_preview = candidate_score
				best_index = i

	for i in range(category_ids.size()):
		var category := category_ids[i]
		var is_used := game_state.is_category_used(category)
		var preview := 0
		if game_state.rolls_used > 0:
			preview = ScoringRules.score_category(category, game_state.dice_values)
		var text := "%s  预估:%d" % [ScoringRules.get_label(category), preview]
		if is_used:
			text = "%s  已用:%d" % [
				ScoringRules.get_label(category),
				int(game_state.get_current_player()["scores"][category])
			]
		category_list.set_item_text(i, text)
		category_list.set_item_disabled(i, is_used or game_state.has_game_ended())
		if is_used:
			category_list.set_item_custom_fg_color(i, Color(0.55, 0.55, 0.55))
		elif i == best_index:
			category_list.set_item_custom_fg_color(i, Color(0.35, 0.9, 0.45))
		else:
			category_list.set_item_custom_fg_color(i, Color(1, 1, 1))


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
	var selected := category_list.get_selected_items()
	if selected.is_empty():
		status_label.text = "请先选择一个类别。"
		return
	var category := category_ids[selected[0]]
	var result := turn_manager.score_category(category)
	if not result["ok"]:
		status_label.text = result["message"]
		_refresh_all()
		return
	status_label.text = "已在 %s 落分：%d" % [ScoringRules.get_label(category), result["score"]]
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
