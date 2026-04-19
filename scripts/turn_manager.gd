class_name TurnManager
extends RefCounted

var game_state: GameState


func _init(state: GameState) -> void:
	game_state = state


func start_new_game() -> void:
	game_state.initialize()


func roll_manual_dice() -> Dictionary:
	return game_state.roll_manual()


func toggle_hold(index: int) -> void:
	game_state.toggle_hold(index)


func settle_manual_turn() -> Dictionary:
	return game_state.settle_manual_turn()


func run_auto_tick() -> Dictionary:
	return game_state.run_auto_tick()


func begin_auto_throw_cycle() -> Dictionary:
	return game_state.begin_auto_throw_cycle()


func finalize_auto_throw_cycle() -> Dictionary:
	return game_state.finalize_auto_throw_cycle()
