class_name TurnManager
extends RefCounted

var game_state: GameState


func _init(state: GameState) -> void:
	game_state = state


func start_new_game() -> void:
	game_state.initialize()


func roll_manual_dice(table_index: int) -> Dictionary:
	return game_state.roll_manual(table_index)


func toggle_hold(table_index: int, die_index: int) -> void:
	game_state.toggle_hold(table_index, die_index)


func settle_manual_turn(table_index: int) -> Dictionary:
	return game_state.settle_manual_turn(table_index)


func begin_auto_throw_for_table(table_index: int) -> Dictionary:
	return game_state.begin_auto_throw_for_table(table_index)


func finalize_auto_throw_for_table(table_index: int) -> Dictionary:
	return game_state.finalize_auto_throw_for_table(table_index)
