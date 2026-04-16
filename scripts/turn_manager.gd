class_name TurnManager
extends RefCounted

var game_state: GameState


func _init(state: GameState) -> void:
	game_state = state


func start_new_game(player_count: int) -> void:
	game_state.initialize(player_count)


func roll_current_dice() -> Dictionary:
	if not game_state.can_roll():
		return {"ok": false, "message": "本回合掷骰次数已用完。"}

	game_state.dice_values = DiceLogic.roll_dice(game_state.dice_values, game_state.held_flags)
	game_state.rolls_used += 1
	return {"ok": true}


func toggle_hold(index: int) -> void:
	game_state.held_flags = DiceLogic.toggle_hold(game_state.held_flags, index)


func score_category(category: String) -> Dictionary:
	if game_state.rolls_used == 0:
		return {"ok": false, "message": "请先掷骰再落分。"}
	if game_state.is_category_used(category):
		return {"ok": false, "message": "该类别已使用。"}

	var score := ScoringRules.score_category(category, game_state.dice_values)
	game_state.set_score(category, score)
	game_state.advance_turn()
	return {
		"ok": true,
		"score": score,
		"game_over": game_state.has_game_ended()
	}
