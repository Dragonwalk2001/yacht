class_name TechTreeNode
extends RefCounted

var id: String = ""
var section: String = ""
var requires: Array[String] = []
var callback: String = ""
var display_name: String = ""
var is_unlocked_fn: Callable


func _init(
	p_id: String = "",
	p_section: String = "",
	p_requires: Array[String] = [],
	p_callback: String = "",
	p_display_name: String = "",
	p_is_unlocked_fn: Callable = Callable()
) -> void:
	id = p_id
	section = p_section
	requires = p_requires.duplicate()
	callback = p_callback
	display_name = p_display_name
	is_unlocked_fn = p_is_unlocked_fn


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
