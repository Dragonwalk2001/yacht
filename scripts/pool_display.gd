extends RefCounted

const _DieT := preload("res://scripts/die_definition.gd")


static func refresh_table_slots(slot_labels: Array, game_state: GameState, table_index: int) -> void:
	var active: Array[int] = game_state.get_active_pool_indices(table_index)
	var psz := game_state.get_table_die_pool_size(table_index)
	for s in range(mini(slot_labels.size(), psz)):
		var sl: Label = slot_labels[s] as Label
		var pan := sl.get_parent() as PanelContainer
		var d: Variant = game_state.get_die_at_pool_slot(table_index, s)
		if d is _DieT:
			sl.text = "%d\n%s" % [s + 1, (d as _DieT).summary_label()]
		else:
			sl.text = "·"
		var on_field := active.has(s)
		pan.modulate = Color(1.0, 0.94, 0.62) if on_field and (d is _DieT) else Color(1, 1, 1)
