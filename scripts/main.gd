extends Node


func _ready() -> void:
	if not has_node("GameBoard"):
		push_error("GameBoard scene instance is missing from Main.")
