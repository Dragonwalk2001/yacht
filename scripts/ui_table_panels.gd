extends RefCounted

const _Die := preload("res://scripts/die_definition.gd")
const _DiceFacePreview := preload("res://scripts/dice_face_preview.gd")

var _host: Node

var pool_browser_window: Window
var pool_browser_table_index: int = -1
var pool_browser_list: ItemList
var pool_browser_preview: DiceFacePreview
var pool_browser_subtitle: Label
var _die_rarity_styles: Dictionary = {}


func _init(p_host: Node) -> void:
	_host = p_host


func init_pool_browser_window() -> void:
	pool_browser_window = Window.new()
	pool_browser_window.title = "骰池"
	pool_browser_window.size = Vector2i(560, 420)
	pool_browser_window.min_size = Vector2i(480, 360)
	pool_browser_window.transient = true
	pool_browser_window.exclusive = false
	pool_browser_window.visible = false
	pool_browser_window.close_requested.connect(func() -> void:
		pool_browser_window.hide()
	)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	pool_browser_window.add_child(margin)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	pool_browser_subtitle = Label.new()
	pool_browser_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(pool_browser_subtitle)
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	col.add_child(mid)
	var list_side := VBoxContainer.new()
	list_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(list_side)
	pool_browser_list = ItemList.new()
	pool_browser_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pool_browser_list.custom_minimum_size = Vector2(240, 220)
	pool_browser_list.item_selected.connect(_on_pool_browser_item_selected)
	list_side.add_child(pool_browser_list)
	var prev_side := VBoxContainer.new()
	prev_side.custom_minimum_size = Vector2(230, 0)
	var prev_lbl := Label.new()
	prev_lbl.text = "六面"
	prev_side.add_child(prev_lbl)
	pool_browser_preview = _DiceFacePreview.new()
	pool_browser_preview.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	prev_side.add_child(pool_browser_preview)
	mid.add_child(prev_side)
	_host.add_child(pool_browser_window)


func on_pool_view_pressed(table_index: int) -> void:
	var gs: GameState = _host.game_state
	if table_index < 0 or table_index >= gs.table_count:
		return
	pool_browser_table_index = table_index
	pool_browser_window.title = "桌%d 骰池" % [table_index + 1]
	var n := gs.get_table_dice_count(table_index)
	pool_browser_subtitle.text = "共%d颗；本回合随机上场%d颗（★）。点选槽位查看六面。" % [gs.get_table_die_pool_size(table_index), n]
	_refresh_pool_browser_list(false)
	pool_browser_window.popup_centered()


func _refresh_pool_browser_list(preserve_sel: bool) -> void:
	var gs: GameState = _host.game_state
	var ti := pool_browser_table_index
	if ti < 0 or ti >= gs.table_count:
		return
	var prev := 0
	if preserve_sel and pool_browser_list.get_selected_items().size() > 0:
		prev = int(pool_browser_list.get_selected_items()[0])
	var active := gs.get_active_pool_indices(ti)
	pool_browser_list.clear()
	for s in range(gs.get_table_die_pool_size(ti)):
		var d: Variant = gs.get_die_at_pool_slot(ti, s)
		var prefix := "★ " if active.has(s) else ""
		var summ := ""
		if d is _Die:
			summ = (d as _Die).summary_label()
		pool_browser_list.add_item("%s槽%d  %s" % [prefix, s + 1, summ])
	if pool_browser_list.item_count > 0:
		var pick := clampi(prev if preserve_sel else 0, 0, pool_browser_list.item_count - 1)
		pool_browser_list.select(pick)
		_on_pool_browser_item_selected(pick)


func _on_pool_browser_item_selected(index: int) -> void:
	if pool_browser_table_index < 0 or index < 0:
		return
	var gs: GameState = _host.game_state
	pool_browser_preview.apply_die(gs.get_die_at_pool_slot(pool_browser_table_index, index))


func refresh_pool_browser_if_visible() -> void:
	if pool_browser_window == null or not pool_browser_window.visible:
		return
	var gs: GameState = _host.game_state
	if pool_browser_table_index < 0 or pool_browser_table_index >= gs.table_count:
		return
	_refresh_pool_browser_list(true)


func build_table_panels() -> void:
	var tables_grid: GridContainer = _host.tables_grid
	for child in tables_grid.get_children():
		child.queue_free()
	_host.table_panel_roots.clear()
	_host.table_die_buttons.clear()
	_host.table_info_labels.clear()
	_host.table_roll_buttons.clear()
	_host.table_settle_buttons.clear()
	_host.table_auto_buttons.clear()
	_host.table_dice_upgrade_buttons.clear()
	_host.table_pool_buttons.clear()
	_host.table_expedition_buttons.clear()
	tables_grid.columns = 2
	var die_size := Vector2(48, 48)
	for table_index in range(GameState.MAX_TABLE_COUNT):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_host.table_panel_roots.append(panel)
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 4)
		panel.add_child(inner)
		var info := Label.new()
		_host.table_info_labels.append(info)
		inner.add_child(info)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		inner.add_child(row)
		var buttons_for_table: Array[Button] = []
		for _die_index in range(GameState.MAX_DICE_COUNT):
			var die_button := Button.new()
			die_button.custom_minimum_size = die_size
			die_button.text = ""
			die_button.expand_icon = true
			die_button.toggle_mode = true
			row.add_child(die_button)
			buttons_for_table.append(die_button)
		_host.table_die_buttons.append(buttons_for_table)
		var pool_row := HBoxContainer.new()
		var pvb := Button.new()
		pvb.text = "骰池（%d）" % GameState.TABLE_DICE_POOL_BASE
		var ti_pool := table_index
		pvb.pressed.connect(func() -> void:
			on_pool_view_pressed(ti_pool)
		)
		pool_row.add_child(pvb)
		_host.table_pool_buttons.append(pvb)
		inner.add_child(pool_row)
		var ctrl := HBoxContainer.new()
		ctrl.add_theme_constant_override("separation", 6)
		inner.add_child(ctrl)
		var rb := Button.new()
		rb.text = "掷骰"
		_host.table_roll_buttons.append(rb)
		ctrl.add_child(rb)
		var sb := Button.new()
		sb.text = "结算"
		_host.table_settle_buttons.append(sb)
		ctrl.add_child(sb)
		var ab := Button.new()
		ab.text = "自动:关"
		_host.table_auto_buttons.append(ab)
		ctrl.add_child(ab)
		var ub := Button.new()
		ub.text = "本桌骰子+1"
		_host.table_dice_upgrade_buttons.append(ub)
		inner.add_child(ub)
		var exb := Button.new()
		exb.text = "远征"
		_host.table_expedition_buttons.append(exb)
		inner.add_child(exb)
		tables_grid.add_child(panel)


func refresh_table_infos() -> void:
	var gs: GameState = _host.game_state
	for t in range(GameState.MAX_TABLE_COUNT):
		if t >= gs.table_count:
			continue
		var dc := gs.get_table_dice_count(t)
		var ru := int(gs.table_rolls_used[t])
		var psz := gs.get_table_die_pool_size(t)
		_host.table_info_labels[t].text = "桌%d · 投%d/%d · 上场%d · 池%d" % [t + 1, ru, GameState.MAX_ROLLS_PER_TURN, dc, psz]
		if t < _host.table_pool_buttons.size():
			var pb: Button = _host.table_pool_buttons[t] as Button
			if pb != null:
				pb.text = "骰池（%d）" % psz


func refresh_dice() -> void:
	var gs: GameState = _host.game_state
	var tex := DiceFacePreview.FACE_TEXTURES
	for table_index in range(_host.table_panel_roots.size()):
		var root: Control = _host.table_panel_roots[table_index] as Control
		root.visible = table_index < gs.table_count
		if not root.visible:
			continue
		var dc := gs.get_table_dice_count(table_index)
		var ap: Array[int] = gs.get_active_pool_indices(table_index)
		for die_index in range(GameState.MAX_DICE_COUNT):
			var die_button := _host.table_die_buttons[table_index][die_index] as Button
			var visible_for_count := die_index < dc
			die_button.visible = visible_for_count
			if not visible_for_count:
				continue
			var value: int = 1
			var held := false
			if _host.table_is_throwing[table_index] and _host.table_throw_visuals[table_index] is Array:
				var tv: Array = _host.table_throw_visuals[table_index]
				if die_index < tv.size():
					value = clampi(int(tv[die_index]), DiceLogic.FACE_MIN, DiceLogic.FACE_MAX)
			else:
				var vals: Array = gs.table_dice_values[table_index]
				if die_index < vals.size():
					value = clampi(int(vals[die_index]), DiceLogic.FACE_MIN, DiceLogic.FACE_MAX)
				var hrow: Array = gs.table_holds[table_index]
				if die_index < hrow.size():
					held = bool(hrow[die_index])
			die_button.icon = tex.get(value, tex[1])
			die_button.text = ""
			var rarity := 0
			if die_index < ap.size():
				var slot_idx := int(ap[die_index])
				var dslot: Variant = gs.get_die_at_pool_slot(table_index, slot_idx)
				if dslot is _Die:
					rarity = clampi(int((dslot as _Die).rarity), 0, 2)
			var rarity_style := _get_rarity_button_stylebox(rarity)
			for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
				die_button.add_theme_stylebox_override(style_name, rarity_style)
			var auto_on := gs.is_table_auto_enabled(table_index)
			die_button.set_pressed_no_signal(not _host.table_is_throwing[table_index] and held)
			if _host.table_is_throwing[table_index]:
				die_button.modulate = Color(0.85, 0.9, 1.0)
			else:
				die_button.modulate = Color(1.0, 0.92, 0.6) if held else Color(1, 1, 1)
			var tip := "桌%d 骰%d 点%d %s" % [
				table_index + 1,
				die_index + 1,
				value,
				"已锁定" if held else "可点锁定"
			]
			if die_index < ap.size():
				var ps := int(ap[die_index])
				var dslot: Variant = gs.get_die_at_pool_slot(table_index, ps)
				if dslot is _Die:
					tip += "  池位%d %s" % [ps + 1, (dslot as _Die).summary_label()]
			die_button.tooltip_text = tip
			var ru := int(gs.table_rolls_used[table_index])
			die_button.disabled = _host.table_is_throwing[table_index] or auto_on or ru == 0


func _get_rarity_button_stylebox(rarity: int) -> StyleBoxFlat:
	var key := clampi(rarity, 0, 2)
	if _die_rarity_styles.has(key):
		return _die_rarity_styles[key] as StyleBoxFlat
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.28)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	match key:
		1:
			sb.border_color = Color(0.45, 0.78, 0.92, 0.95)
		2:
			sb.border_color = Color(0.95, 0.72, 0.28, 0.98)
		_:
			sb.border_color = Color(0.28, 0.31, 0.36, 0.75)
	sb.set_content_margin_all(3)
	_die_rarity_styles[key] = sb
	return sb
