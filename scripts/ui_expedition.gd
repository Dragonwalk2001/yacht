extends RefCounted

const _Die := preload("res://scripts/die_definition.gd")
const _DiceFacePreview := preload("res://scripts/dice_face_preview.gd")
const _ExpeditionGate := preload("res://scripts/expedition_gate.gd")

var _host: Node

var expedition_window: Window
var expedition_table_index: int = -1
var expedition_type_option: OptionButton
var expedition_item_list: ItemList
var expedition_hint_label: Label
var expedition_income_label: Label
var expedition_start_button: Button
var expedition_close_button: Button
var expedition_income_before: float = 0.0
var expedition_acquire_candidates: Array = []
var expedition_delete_indices: Array[int] = []
var expedition_synth_indices: Array[int] = []
var expedition_pending_kind: int = -1
var expedition_waiting_result_choice: bool = false
var expedition_pending_acquire_idx: int = -1
var expedition_pending_delete_die_idx: int = -1
var expedition_pending_synth_lo: int = -1
var expedition_pending_synth_hi: int = -1
var expedition_face_preview: DiceFacePreview
var table_pending_kind: Array[int] = []
var table_waiting_result: Array[bool] = []
var table_acquire_candidates: Array = []
var table_delete_indices: Array = []
var table_synth_indices: Array = []
var expedition_synth_selected_slots: Array[int] = []
var _synth_repainting: bool = false


func _init(p_host: Node) -> void:
	_host = p_host


func init_expedition_window() -> void:
	expedition_window = Window.new()
	expedition_window.title = "远征"
	expedition_window.size = Vector2i(640, 440)
	expedition_window.min_size = Vector2i(520, 380)
	expedition_window.transient = true
	expedition_window.exclusive = true
	expedition_window.visible = false
	expedition_window.close_requested.connect(func() -> void:
		expedition_window.hide()
		_host._refresh_all()
	)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	expedition_window.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(col)
	expedition_hint_label = Label.new()
	expedition_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(expedition_hint_label)
	expedition_income_label = Label.new()
	expedition_income_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(expedition_income_label)
	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 8)
	col.add_child(type_row)
	var type_lbl := Label.new()
	type_lbl.text = "类型"
	type_row.add_child(type_lbl)
	expedition_type_option = OptionButton.new()
	expedition_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expedition_type_option.item_selected.connect(_on_expedition_type_selected)
	type_row.add_child(expedition_type_option)
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	col.add_child(mid)
	var list_side := VBoxContainer.new()
	list_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(list_side)
	expedition_item_list = ItemList.new()
	expedition_item_list.custom_minimum_size = Vector2(0, 160)
	expedition_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	expedition_item_list.allow_reselect = true
	expedition_item_list.select_mode = ItemList.SELECT_MULTI
	expedition_item_list.item_selected.connect(_on_expedition_item_list_selected)
	list_side.add_child(expedition_item_list)
	var prev_side := VBoxContainer.new()
	prev_side.custom_minimum_size = Vector2(210, 0)
	var prev_title := Label.new()
	prev_title.text = "六面（稀有度着色）"
	prev_side.add_child(prev_title)
	expedition_face_preview = _DiceFacePreview.new()
	expedition_face_preview.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	prev_side.add_child(expedition_face_preview)
	mid.add_child(prev_side)
	expedition_start_button = Button.new()
	expedition_start_button.text = "开始远征"
	expedition_start_button.pressed.connect(_on_expedition_start_pressed)
	col.add_child(expedition_start_button)
	expedition_close_button = Button.new()
	expedition_close_button.text = "关闭"
	expedition_close_button.pressed.connect(func() -> void:
		expedition_window.hide()
		_host._refresh_all()
	)
	col.add_child(expedition_close_button)
	_host.add_child(expedition_window)


func active_expedition_table_index() -> int:
	return _ExpeditionGate.active_expedition_table_index(_host.table_expedition_timers)


func _is_expedition_flow_locked() -> bool:
	return false


func _reset_expedition_pending_selection() -> void:
	expedition_pending_acquire_idx = -1
	expedition_pending_delete_die_idx = -1
	expedition_pending_synth_lo = -1
	expedition_pending_synth_hi = -1


func _ensure_expedition_rows() -> void:
	var tc: int = int(_host.game_state.table_count)
	while table_pending_kind.size() < tc:
		table_pending_kind.append(-1)
		table_waiting_result.append(false)
		table_acquire_candidates.append([])
		table_delete_indices.append([])
		table_synth_indices.append([])
	while table_pending_kind.size() > tc:
		table_pending_kind.pop_back()
		table_waiting_result.pop_back()
		table_acquire_candidates.pop_back()
		table_delete_indices.pop_back()
		table_synth_indices.pop_back()


func _clear_table_expedition_state(table_index: int) -> void:
	if table_index < 0 or table_index >= table_pending_kind.size():
		return
	table_pending_kind[table_index] = -1
	table_waiting_result[table_index] = false
	table_acquire_candidates[table_index] = []
	table_delete_indices[table_index] = []
	table_synth_indices[table_index] = []


func _sync_window_state_flags() -> void:
	var ti := expedition_table_index
	if ti < 0 or ti >= table_pending_kind.size():
		expedition_pending_kind = -1
		expedition_waiting_result_choice = false
		return
	expedition_pending_kind = table_pending_kind[ti]
	expedition_waiting_result_choice = bool(table_waiting_result[ti])


func is_table_waiting_result(table_index: int) -> bool:
	_ensure_expedition_rows()
	if table_index < 0 or table_index >= table_waiting_result.size():
		return false
	return bool(table_waiting_result[table_index])


func on_expedition_button_pressed(table_index: int) -> void:
	var gs: GameState = _host.game_state
	_ensure_expedition_rows()
	if table_index >= gs.table_count:
		return
	if not gs.tech_expedition_portal_unlocked:
		_host.status_label.text = "请先在成长树解锁远征入口。"
		return
	expedition_table_index = table_index
	_sync_window_state_flags()
	expedition_income_before = gs.estimate_income_per_second()
	expedition_income_label.text = "远征前估算收益/秒: %.1f" % expedition_income_before
	expedition_hint_label.text = "桌%d：先选择远征类型并开始。远征结束后再选择结果并确认。" % [table_index + 1]
	_refresh_expedition_type_options()
	if expedition_pending_kind >= 0 and expedition_waiting_result_choice:
		for i in range(expedition_type_option.item_count):
			if int(expedition_type_option.get_item_metadata(i)) == expedition_pending_kind:
				expedition_type_option.select(i)
				break
	elif expedition_type_option.item_count > 0:
		expedition_type_option.select(0)
	_on_expedition_type_selected(expedition_type_option.selected)
	var running: bool = table_index < _host.table_expedition_timers.size() and _host.table_expedition_timers[table_index].time_left > 0.0
	if running:
		expedition_type_option.disabled = true
		_set_expedition_item_list_interactive(false)
		expedition_item_list.clear()
		expedition_start_button.text = "远征进行中..."
		expedition_start_button.disabled = true
		expedition_hint_label.text = "桌%d 远征进行中，结束后可确认结果。" % [table_index + 1]
	elif expedition_waiting_result_choice:
		expedition_type_option.disabled = true
		_set_expedition_item_list_interactive(true)
		expedition_start_button.text = "确认结果"
		expedition_start_button.disabled = false
		expedition_hint_label.text = "桌%d 远征已完成：请选择结果并点击「确认结果」。" % [table_index + 1]
	else:
		expedition_type_option.disabled = false
		_set_expedition_item_list_interactive(false)
		expedition_start_button.text = "开始远征"
		expedition_start_button.disabled = false
	expedition_close_button.disabled = false
	expedition_window.popup_centered()
	_update_expedition_face_preview()


func _expedition_selected_type() -> int:
	if expedition_type_option.item_count <= 0:
		return -1
	var sel := expedition_type_option.selected
	if sel < 0:
		return -1
	return int(expedition_type_option.get_item_metadata(sel))


func _refresh_expedition_type_options() -> void:
	var gs: GameState = _host.game_state
	expedition_type_option.clear()
	if gs.tech_expedition_portal_unlocked:
		expedition_type_option.add_item("获得骰子")
		expedition_type_option.set_item_metadata(expedition_type_option.item_count - 1, 0)
	if gs.tech_delete_expedition_unlocked:
		expedition_type_option.add_item("删骰")
		expedition_type_option.set_item_metadata(expedition_type_option.item_count - 1, 1)
	if gs.tech_synth_expedition_unlocked:
		expedition_type_option.add_item("合成")
		expedition_type_option.set_item_metadata(expedition_type_option.item_count - 1, 2)


func _on_expedition_type_selected(_idx: int) -> void:
	expedition_item_list.select_mode = ItemList.SELECT_SINGLE
	expedition_item_list.allow_reselect = true
	_repopulate_expedition_item_list()


func _repopulate_expedition_item_list() -> void:
	var gs: GameState = _host.game_state
	expedition_item_list.clear()
	expedition_acquire_candidates.clear()
	expedition_delete_indices.clear()
	expedition_synth_indices.clear()
	expedition_synth_selected_slots.clear()
	var ti := expedition_table_index
	if ti < 0 or ti >= gs.table_count:
		return
	_ensure_expedition_rows()
	var table_waiting: bool = bool(table_waiting_result[ti])
	var ty := int(table_pending_kind[ti])
	if not table_waiting:
		expedition_item_list.add_item("远征结束后会出现可选结果。")
		expedition_item_list.set_item_disabled(0, true)
		return
	if ty == 0:
		expedition_acquire_candidates = (table_acquire_candidates[ti] as Array).duplicate()
		var i := 0
		for d in expedition_acquire_candidates:
			if d is _Die:
				expedition_item_list.add_item("候选%d: %s" % [i + 1, (d as _Die).summary_label()])
				expedition_item_list.set_item_metadata(expedition_item_list.item_count - 1, i)
			i += 1
	elif ty == 1:
		expedition_delete_indices = (table_delete_indices[ti] as Array).duplicate()
		for j in range(expedition_delete_indices.size()):
			var di := expedition_delete_indices[j]
			var summ := ""
			var ddel: Variant = gs.get_die_at_pool_slot(ti, di)
			if ddel is _Die:
				summ = (ddel as _Die).summary_label()
			expedition_item_list.add_item("删除 池位%d: %s" % [di + 1, summ])
			expedition_item_list.set_item_metadata(expedition_item_list.item_count - 1, di)
	elif ty == 2:
		expedition_synth_indices = (table_synth_indices[ti] as Array).duplicate()
		for j in range(expedition_synth_indices.size()):
			var di2 := expedition_synth_indices[j]
			var summ2 := ""
			var d2: Variant = gs.get_die_at_pool_slot(ti, di2)
			if d2 is _Die:
				summ2 = (d2 as _Die).summary_label()
			expedition_item_list.add_item("□ 池位%d: %s" % [di2 + 1, summ2])
			expedition_item_list.set_item_metadata(expedition_item_list.item_count - 1, di2)
		_refresh_synth_item_marks()
	if expedition_item_list.item_count > 0:
		expedition_item_list.select(0)
	_update_expedition_face_preview()


func _on_expedition_item_list_selected(_index: int) -> void:
	if _synth_repainting:
		return
	if expedition_waiting_result_choice and expedition_pending_kind == 2:
		_handle_synth_item_click(_index)
		return
	_update_expedition_face_preview()


func _refresh_synth_item_marks() -> void:
	_synth_repainting = true
	for i in range(expedition_item_list.item_count):
		var slot := int(expedition_item_list.get_item_metadata(i))
		var mark := "■" if expedition_synth_selected_slots.has(slot) else "□"
		var raw := expedition_item_list.get_item_text(i)
		var pos := raw.find(" ")
		var tail := raw.substr(pos + 1) if pos >= 0 else raw
		expedition_item_list.set_item_text(i, "%s %s" % [mark, tail])
	expedition_item_list.deselect_all()
	_synth_repainting = false


func _handle_synth_item_click(item_index: int) -> void:
	if item_index < 0 or item_index >= expedition_item_list.item_count:
		return
	var slot := int(expedition_item_list.get_item_metadata(item_index))
	var pos := expedition_synth_selected_slots.find(slot)
	if pos >= 0:
		expedition_synth_selected_slots.remove_at(pos)
	else:
		if expedition_synth_selected_slots.size() >= 2:
			expedition_synth_selected_slots.remove_at(0)
		expedition_synth_selected_slots.append(slot)
	_refresh_synth_item_marks()
	_update_expedition_face_preview()


func _update_expedition_face_preview() -> void:
	if expedition_face_preview == null:
		return
	if not expedition_waiting_result_choice:
		expedition_face_preview.apply_die(null)
		return
	var ty := expedition_pending_kind
	var gs: GameState = _host.game_state
	if ty == 0:
		var sel := expedition_item_list.get_selected_items()
		if sel.is_empty():
			expedition_face_preview.apply_die(null)
			return
		var ci := int(expedition_item_list.get_item_metadata(sel[0]))
		if ci >= 0 and ci < expedition_acquire_candidates.size():
			expedition_face_preview.apply_die(expedition_acquire_candidates[ci])
		else:
			expedition_face_preview.apply_die(null)
	elif ty == 1 or ty == 2:
		if ty == 2 and expedition_synth_selected_slots.size() > 0:
			var last_slot := expedition_synth_selected_slots[expedition_synth_selected_slots.size() - 1]
			expedition_face_preview.apply_die(gs.get_die_at_pool_slot(expedition_table_index, last_slot))
			return
		var sel2 := expedition_item_list.get_selected_items()
		if sel2.is_empty():
			expedition_face_preview.apply_die(null)
			return
		var pool_i := int(expedition_item_list.get_item_metadata(sel2[0]))
		expedition_face_preview.apply_die(gs.get_die_at_pool_slot(expedition_table_index, pool_i))
	else:
		expedition_face_preview.apply_die(null)


func _set_expedition_item_list_interactive(on: bool) -> void:
	expedition_item_list.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	expedition_item_list.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE


func _on_expedition_start_pressed() -> void:
	var gs: GameState = _host.game_state
	var ti := expedition_table_index
	_ensure_expedition_rows()
	_sync_window_state_flags()
	if ti < 0 or ti >= gs.table_count:
		return
	if ti < _host.table_expedition_timers.size() and _host.table_expedition_timers[ti].time_left > 0.0:
		return
	if expedition_waiting_result_choice:
		_confirm_expedition_result()
		return
	var ty := _expedition_selected_type()
	_reset_expedition_pending_selection()
	if ty == 1:
		if gs.get_pool_filled_count(ti) <= gs.get_table_dice_count(ti):
			_host.status_label.text = "删骰远征需要骰池有多余骰子（不影响上场骰位）。"
			return
	elif ty == 2:
		if not gs.can_start_synth_expedition(ti):
			_host.status_label.text = "合成远征需要该桌骰池至少达到上限+1。"
			return
	elif ty != 0:
		_host.status_label.text = "没有可用的远征类型。"
		return
	table_pending_kind[ti] = ty
	table_waiting_result[ti] = false
	table_acquire_candidates[ti] = []
	table_delete_indices[ti] = []
	table_synth_indices[ti] = []
	_sync_window_state_flags()
	var dur := gs.get_expedition_duration_sec() / maxf(0.05, float(Engine.time_scale))
	_host.table_expedition_timers[ti].wait_time = dur
	_host.table_expedition_timers[ti].start()
	expedition_type_option.disabled = true
	_set_expedition_item_list_interactive(false)
	expedition_item_list.clear()
	expedition_start_button.disabled = true
	expedition_start_button.text = "远征进行中..."
	expedition_close_button.disabled = false
	_host.status_label.text = "桌%d 远征进行中（%.1fs）…" % [ti + 1, dur]
	expedition_hint_label.text = "桌%d 远征进行中，结束后请选择结果并确认。" % [ti + 1]
	_host._refresh_all()


func on_table_expedition_timer_timeout(table_index: int) -> void:
	_ensure_expedition_rows()
	if table_index < 0 or table_index >= table_pending_kind.size():
		return
	var ty := int(table_pending_kind[table_index])
	if ty < 0:
		return
	table_waiting_result[table_index] = true
	var gs: GameState = _host.game_state
	if ty == 0:
		table_acquire_candidates[table_index] = gs.generate_acquire_candidates()
	elif ty == 1:
		table_delete_indices[table_index] = gs.get_random_delete_candidate_indices(table_index)
	elif ty == 2:
		table_synth_indices[table_index] = gs.get_random_synth_candidate_indices(table_index)
	_host._save_game()
	_host.status_label.text = "桌%d 远征完成，等待选择结果。" % [table_index + 1]
	if expedition_window.visible and expedition_table_index == table_index:
		_sync_window_state_flags()
		expedition_type_option.disabled = true
		_set_expedition_item_list_interactive(true)
		expedition_hint_label.text = "桌%d 远征已完成：请选择结果并点击「确认结果」。" % [table_index + 1]
		_repopulate_expedition_item_list()
		expedition_start_button.text = "确认结果"
		expedition_start_button.disabled = false
		expedition_close_button.disabled = false
	_host._refresh_all()


func _confirm_expedition_result() -> void:
	var gs: GameState = _host.game_state
	var ti := expedition_table_index
	_ensure_expedition_rows()
	_sync_window_state_flags()
	if ti < 0 or ti >= gs.table_count:
		return
	if not expedition_waiting_result_choice:
		_host.status_label.text = "该桌当前没有待确认的远征结果。"
		return
	var has_any := true
	if expedition_pending_kind == 0:
		has_any = table_acquire_candidates[ti] is Array and (table_acquire_candidates[ti] as Array).size() > 0
	elif expedition_pending_kind == 1:
		has_any = table_delete_indices[ti] is Array and (table_delete_indices[ti] as Array).size() > 0
	elif expedition_pending_kind == 2:
		has_any = table_synth_indices[ti] is Array and (table_synth_indices[ti] as Array).size() > 0
	if not has_any:
		_clear_table_expedition_state(ti)
		_sync_window_state_flags()
		expedition_type_option.disabled = false
		_set_expedition_item_list_interactive(false)
		expedition_start_button.text = "开始远征"
		expedition_start_button.disabled = false
		expedition_close_button.disabled = false
		expedition_hint_label.text = "桌%d：该次远征结果为空，已自动取消。" % [ti + 1]
		_host.status_label.text = "桌%d 远征结果为空，已取消。" % [ti + 1]
		_host._refresh_all()
		return
	_reset_expedition_pending_selection()
	if expedition_pending_kind == 0:
		var sel := expedition_item_list.get_selected_items()
		if sel.size() != 1:
			_host.status_label.text = "获得远征：请选择一个候选骰子。"
			return
		var ci := int(expedition_item_list.get_item_metadata(sel[0]))
		if ci < 0 or ci >= expedition_acquire_candidates.size():
			_host.status_label.text = "选择无效。"
			return
		expedition_pending_acquire_idx = ci
	elif expedition_pending_kind == 1:
		var sel1 := expedition_item_list.get_selected_items()
		if sel1.size() != 1:
			_host.status_label.text = "删骰远征：请选择一个删除目标。"
			return
		expedition_pending_delete_die_idx = int(expedition_item_list.get_item_metadata(sel1[0]))
	elif expedition_pending_kind == 2:
		if expedition_synth_selected_slots.size() != 2:
			_host.status_label.text = "合成远征：请依次点选两颗骰子。"
			return
		var a := int(expedition_synth_selected_slots[0])
		var b := int(expedition_synth_selected_slots[1])
		expedition_pending_synth_lo = mini(a, b)
		expedition_pending_synth_hi = maxi(a, b)
	else:
		_host.status_label.text = "远征状态异常。"
		return
	var msg := ""
	var ok := false
	if expedition_pending_kind == 0:
		var die: _Die = expedition_acquire_candidates[expedition_pending_acquire_idx] as _Die
		var r := gs.apply_expedition_acquire(ti, die)
		ok = bool(r["ok"])
		msg = "获得新骰子。" if ok else String(r["message"])
	elif expedition_pending_kind == 1:
		var r2 := gs.apply_expedition_delete(ti, expedition_pending_delete_die_idx)
		ok = bool(r2["ok"])
		msg = "已删除骰子。" if ok else String(r2["message"])
	elif expedition_pending_kind == 2:
		if not gs.can_start_synth_expedition(ti):
			_host.status_label.text = "合成远征需要该桌骰池至少达到上限+1。"
			return
		var r3 := gs.apply_expedition_synth(ti, expedition_pending_synth_lo, expedition_pending_synth_hi)
		ok = bool(r3["ok"])
		msg = "合成完成。" if ok else String(r3["message"])
	if not ok:
		_host.status_label.text = "桌%d %s" % [ti + 1, msg]
		return
	var after := gs.estimate_income_per_second()
	expedition_income_label.text = "远征前估算收益/秒: %.1f  →  现在: %.1f" % [expedition_income_before, after]
	_host.status_label.text = "桌%d %s" % [ti + 1, msg]
	_clear_table_expedition_state(ti)
	_sync_window_state_flags()
	_reset_expedition_pending_selection()
	expedition_type_option.disabled = false
	_set_expedition_item_list_interactive(false)
	expedition_start_button.text = "开始远征"
	expedition_start_button.disabled = false
	expedition_close_button.disabled = false
	expedition_hint_label.text = "桌%d：先选择远征类型并开始。远征结束后再选择结果并确认。" % [ti + 1]
	_host._save_game()
	_host._refresh_all()
	_repopulate_expedition_item_list()
