extends Node

@onready var home_screen: Control = $HomeScreen
@onready var start_button: Button = $HomeScreen/Margin/Panel/VBox/StartButton
@onready var continue_button: Button = $HomeScreen/Margin/Panel/VBox/ContinueButton
@onready var game_board: UIController = $GameBoard


func _ready() -> void:
	if not _validate_nodes():
		return
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.disabled = not game_board.has_continue_save()


func _validate_nodes() -> bool:
	if not has_node("HomeScreen"):
		push_error("HomeScreen is missing from Main.")
		return false
	if not has_node("GameBoard"):
		push_error("GameBoard scene instance is missing from Main.")
		return false
	return true


func _on_start_pressed() -> void:
	home_screen.visible = false
	game_board.start_new_session()


func _on_continue_pressed() -> void:
	home_screen.visible = false
	var loaded := game_board.continue_session()
	if not loaded:
		# Fall back to a fresh start when save is missing or invalid.
		game_board.start_new_session()
