extends Node

@onready var home_screen: Control = $HomeScreen
@onready var player_count_box: SpinBox = $HomeScreen/Margin/Panel/VBox/PlayerCountRow/PlayerCount
@onready var start_button: Button = $HomeScreen/Margin/Panel/VBox/StartButton
@onready var game_board: UIController = $GameBoard


func _ready() -> void:
	if not _validate_nodes():
		return
	start_button.pressed.connect(_on_start_pressed)


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
	game_board.start_session(int(player_count_box.value))
