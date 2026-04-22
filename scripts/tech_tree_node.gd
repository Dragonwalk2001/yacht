class_name TechTreeNode
extends RefCounted

var id: String = ""
var section: String = ""
var requires: Array[String] = []
var callback: String = ""
var display_name: String = ""
var is_unlocked_fn: Callable
var current_level_fn: Callable
var max_level_fn: Callable


func _init(
	p_id: String = "",
	p_section: String = "",
	p_requires: Array[String] = [],
	p_callback: String = "",
	p_display_name: String = "",
	p_is_unlocked_fn: Callable = Callable(),
	p_current_level_fn: Callable = Callable(),
	p_max_level_fn: Callable = Callable()
) -> void:
	id = p_id
	section = p_section
	requires = p_requires.duplicate()
	callback = p_callback
	display_name = p_display_name
	is_unlocked_fn = p_is_unlocked_fn
	current_level_fn = p_current_level_fn
	max_level_fn = p_max_level_fn


func to_growth_def() -> Dictionary:
	return {
		"id": id,
		"section": section,
		"requires": requires.duplicate(),
		"callback": callback
	}


func is_unlocked() -> bool:
	if is_unlocked_fn.is_valid():
		return bool(is_unlocked_fn.call())
	return false


func get_current_level() -> int:
	if current_level_fn.is_valid():
		return maxi(0, int(current_level_fn.call()))
	return 0


func get_max_level() -> int:
	if max_level_fn.is_valid():
		return maxi(1, int(max_level_fn.call()))
	return 1


func get_level_progress_text() -> String:
	var current := get_current_level()
	var max_level := get_max_level()
	current = mini(current, max_level)
	return "%d/%d" % [current, max_level]
