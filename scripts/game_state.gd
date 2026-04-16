class_name GameState
extends RefCounted

const TOTAL_ROUNDS: int = 12
const MAX_ROLLS_PER_TURN: int = 3

var player_count: int = 2
var players: Array[Dictionary] = []
var current_player_index: int = 0
var current_round: int = 1
var rolls_used: int = 0
var dice_values: Array[int] = []
var held_flags: Array[bool] = []


func initialize(new_player_count: int) -> void:
	player_count = clampi(new_player_count, 1, 4)
	players.clear()
	for index in range(player_count):
		var scores := {}
		for category in ScoringRules.ALL_CATEGORIES:
			scores[category] = null
		players.append({
			"name": "玩家%d" % [index + 1],
			"scores": scores
		})
	current_player_index = 0
	current_round = 1
	reset_turn()


func reset_turn() -> void:
	rolls_used = 0
	dice_values = DiceLogic.create_default_dice()
	held_flags = DiceLogic.create_default_holds()


func can_roll() -> bool:
	return rolls_used < MAX_ROLLS_PER_TURN


func has_game_ended() -> bool:
	return current_round > TOTAL_ROUNDS


func get_current_player() -> Dictionary:
	return players[current_player_index]


func is_category_used(category: String) -> bool:
	return get_current_player()["scores"][category] != null


func set_score(category: String, score: int) -> void:
	players[current_player_index]["scores"][category] = score


func advance_turn() -> void:
	current_player_index += 1
	if current_player_index >= player_count:
		current_player_index = 0
		current_round += 1
	if not has_game_ended():
		reset_turn()


func get_upper_subtotal(player: Dictionary) -> int:
	var subtotal := 0
	for category in ScoringRules.UPPER_CATEGORIES:
		var value = player["scores"][category]
		if value != null:
			subtotal += int(value)
	return subtotal


func get_upper_bonus(player: Dictionary) -> int:
	if get_upper_subtotal(player) >= ScoringRules.UPPER_BONUS_THRESHOLD:
		return ScoringRules.UPPER_BONUS_SCORE
	return 0


func get_total_score(player: Dictionary) -> int:
	var total := 0
	for category in ScoringRules.ALL_CATEGORIES:
		var value = player["scores"][category]
		if value != null:
			total += int(value)
	return total + get_upper_bonus(player)
