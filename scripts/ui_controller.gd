class_name UIController
extends Control

const _TimeSpeedSettings := preload("res://scripts/time_speed_settings.gd")
const _Die := preload("res://scripts/die_definition.gd")

@onready var status_label: Label = $Margin/VBox/TopRow/LeftColumn/StatusLabel
@onready var turn_label: Label = $Margin/VBox/TopRow/LeftColumn/TurnLabel
@onready var rolls_label: Label = $Margin/VBox/TopRow/LeftColumn/RollsLabel
@onready var tables_scroll: ScrollContainer = $Margin/VBox/TopRow/LeftColumn/TablesScroll
@onready var tables_grid: GridContainer = $Margin/VBox/TopRow/LeftColumn/TablesScroll/TablesGrid
@onready var score_board: RichTextLabel = $Margin/VBox/TopRow/ScoreBoardPanel/ScoreBoardMargin/ScoreBoard
@onready var menu_button: MenuButton = $Margin/VBox/MenuRow/MenuButton
@onready var growth_button: Button = $Margin/VBox/MenuRow/GrowthButton
@onready var throw_pulse_timer: Timer = $ThrowPulseTimer

var dice_stats_dialog: AcceptDialog
var growth_window: Window
var growth_coin_label: Label
var growth_node_panels: Dictionary = {}
var growth_tree_scroll: ScrollContainer
var growth_tree_stage: Control
var growth_tree_root: VBoxContainer
var growth_tree_link_layer: Control
var growth_tree_node_prereqs: Dictionary = {}
var growth_detail_richtext: RichTextLabel
var growth_node_detail_text: Dictionary = {}
var growth_hovered_node_id: String = ""
var time_speed_window: Window
var time_speed_slider: HSlider
var time_speed_value_label: Label
var time_speed: int = 1

var game_state := GameState.new()
var turn_manager := TurnManager.new(game_state)
var upgrade_buttons: Dictionary = {}
var table_panel_roots: Array[Control] = []
var table_die_buttons: Array = []
var table_info_labels: Array[Label] = []
var table_roll_buttons: Array[Button] = []
var table_settle_buttons: Array[Button] = []
var table_auto_buttons: Array[Button] = []
var table_dice_upgrade_buttons: Array[Button] = []
var table_expedition_buttons: Array[Button] = []
var table_expedition_timers: Array[Timer] = []
var table_throw_timers: Array[Timer] = []
var table_auto_timers: Array[Timer] = []
var table_is_throwing: Array[bool] = []
var table_throw_sources: Array[String] = []
var table_throw_visuals: Array = []
var table_queued_auto: Array[int] = []

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

const SAVE_PATH := "user://savegame.json"

const GROWTH_DETAIL_TABLE := "增加可同时使用的骰桌数量。每桌独立掷骰、锁骰与结算，多桌收益叠加为货币1。"
const GROWTH_DETAIL_AUTO_UNLOCK := "解锁后每张骰桌可单独开启自动：按当前自动间隔完成投掷与结算，仍播放投掷表现。"
const GROWTH_DETAIL_AUTO_SPEED := "缩短各桌自动掷骰的等待间隔（全桌同一档位）。逻辑间隔与最短投掷动画独立；过短时排队触发，避免重复结算。"
const GROWTH_DETAIL_PLACEHOLDER := "将鼠标移到左侧节点上查看说明。"
const THROW_ANIMATION_SEC: float = 0.5
const THROW_PULSE_SEC: float = 0.08
const DIE_TEXTURES := {
	1: preload("res://assets/dice/die_1.svg"),
	2: preload("res://assets/dice/die_2.svg"),
	3: preload("res://assets/dice/die_3.svg"),
	4: preload("res://assets/dice/die_4.svg"),
	5: preload("res://assets/dice/die_5.svg"),
	6: preload("res://assets/dice/die_6.svg")
}


func _ready() -> void:
	randomize()
	_TimeSpeedSettings.apply_engine_multiplier(time_speed)
	_init_dice_stats_dialog()
	_init_growth_window()
	_init_expedition_window()
	_init_time_speed_window()
	_init_throw_tracking_arrays()
	_create_per_table_timers()
	_build_table_panels()
	_bind_signals()
	_apply_tables_scroll_min_height()
	_apply_table_panel_density()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_tables_scroll_min_height()


func _apply_tables_scroll_min_height() -> void:
	if tables_scroll == null:
		return
	var h := get_viewport_rect().size.y
	tables_scroll.custom_minimum_size.y = clampf(h * 0.5, 260.0, 620.0)


func _apply_table_panel_density() -> void:
	var n := game_state.table_count
	var die := 48
	var sep_inner := 4
	var gh := 10
	var gv := 10
	var fs_info := 14
	var fs_btn := 13
	if n >= 7:
		die = 32
		sep_inner = 2
		gh = 6
		gv = 6
		fs_info = 12
		fs_btn = 10
	elif n >= 5:
		die = 40
		sep_inner = 3
		gh = 8
		gv = 8
		fs_info = 13
		fs_btn = 11
	tables_grid.add_theme_constant_override("h_separation", gh)
	tables_grid.add_theme_constant_override("v_separation", gv)
	for t in range(GameState.MAX_TABLE_COUNT):
		var inner := table_panel_roots[t].get_child(0) as VBoxContainer
		inner.add_theme_constant_override("separation", sep_inner)
		var row := inner.get_child(1) as HBoxContainer
		row.add_theme_constant_override("separation", maxi(2, sep_inner))
		var cbox := inner.get_child(2) as HBoxContainer
		cbox.add_theme_constant_override("separation", maxi(4, sep_inner + 2))
		for d in range(GameState.MAX_DICE_COUNT):
			(table_die_buttons[t][d] as Button).custom_minimum_size = Vector2(die, die)
		table_info_labels[t].add_theme_font_size_override("font_size", fs_info)
		for b in [table_roll_buttons[t], table_settle_buttons[t], table_auto_buttons[t]]:
			(b as Button).add_theme_font_size_override("font_size", fs_btn)
		(table_dice_upgrade_buttons[t] as Button).add_theme_font_size_override("font_size", maxi(9, fs_btn - 1))


func _init_throw_tracking_arrays() -> void:
	for _i in range(GameState.MAX_TABLE_COUNT):
		table_is_throwing.append(false)
		table_throw_sources.append("")
		table_throw_visuals.append([])
		table_queued_auto.append(0)


func _create_per_table_timers() -> void:
	for i in range(GameState.MAX_TABLE_COUNT):
		var tt := Timer.new()
		tt.one_shot = true
		tt.wait_time = THROW_ANIMATION_SEC
		var throw_idx := i
		tt.timeout.connect(func() -> void:
			_on_table_throw_timer_timeout(throw_idx)
		)
		add_child(tt)
		table_throw_timers.append(tt)
		var at := Timer.new()
		at.one_shot = false
		at.wait_time = game_state.get_auto_interval()
		var auto_idx := i
		at.timeout.connect(func() -> void:
			_on_table_auto_timer_timeout(auto_idx)
		)
		add_child(at)
		table_auto_timers.append(at)
		var et := Timer.new()
		et.one_shot = true
		var exp_idx := i
		et.timeout.connect(func() -> void:
			_on_table_expedition_timer_timeout(exp_idx)
		)
		add_child(et)
		table_expedition_timers.append(et)


func _init_dice_stats_dialog() -> void:
	dice_stats_dialog = AcceptDialog.new()
	dice_stats_dialog.title = "掷骰统计"
	dice_stats_dialog.ok_button_text = "关闭"
	dice_stats_dialog.dialog_autowrap = true
	dice_stats_dialog.min_size = Vector2i(440, 180)
	add_child(dice_stats_dialog)


func _init_growth_window() -> void:
	growth_node_panels.clear()
	growth_tree_node_prereqs.clear()
	growth_window = Window.new()
	growth_window.title = "成长与解锁 · 科技树"
	growth_window.size = Vector2i(700, 480)
	growth_window.min_size = Vector2i(560, 360)
	growth_window.transient = true
	growth_window.exclusive = true
	growth_window.unresizable = false
	growth_window.visible = false
	growth_window.close_requested.connect(func() -> void:
		growth_window.hide()
	)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	growth_window.add_child(margin)
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)
	growth_coin_label = Label.new()
	growth_coin_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(growth_coin_label)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	outer.add_child(body)
	var tree_panel := PanelContainer.new()
	tree_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_panel.size_flags_stretch_ratio = 7.0
	var tree_style := _growth_tree_node_stylebox()
	tree_style.bg_color = Color(0.08, 0.09, 0.11, 1.0)
	tree_panel.add_theme_stylebox_override("panel", tree_style)
	body.add_child(tree_panel)
	var tree_margin := MarginContainer.new()
	tree_margin.add_theme_constant_override("margin_left", 10)
	tree_margin.add_theme_constant_override("margin_top", 10)
	tree_margin.add_theme_constant_override("margin_right", 10)
	tree_margin.add_theme_constant_override("margin_bottom", 10)
	tree_panel.add_child(tree_margin)
	growth_tree_scroll = ScrollContainer.new()
	growth_tree_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	growth_tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	growth_tree_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tree_margin.add_child(growth_tree_scroll)
	growth_tree_stage = Control.new()
	growth_tree_stage.custom_minimum_size = Vector2(480, 260)
	growth_tree_stage.size = Vector2(480, 260)
	growth_tree_scroll.add_child(growth_tree_stage)
	growth_tree_link_layer = Control.new()
	growth_tree_link_layer.position = Vector2.ZERO
	growth_tree_link_layer.size = growth_tree_stage.size
	growth_tree_link_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	growth_tree_stage.add_child(growth_tree_link_layer)
	growth_tree_root = VBoxContainer.new()
	growth_tree_root.position = Vector2.ZERO
	growth_tree_root.add_theme_constant_override("separation", 6)
	growth_tree_stage.add_child(growth_tree_root)
	growth_tree_root.resized.connect(func() -> void:
		call_deferred("_update_growth_tree_canvas_size")
		call_deferred("_refresh_growth_tree_links")
	)
	var vbar := growth_tree_scroll.get_v_scroll_bar()
	if vbar != null:
		vbar.value_changed.connect(func(_v: float) -> void:
			call_deferred("_refresh_growth_tree_links")
		)
	var hbar := growth_tree_scroll.get_h_scroll_bar()
	if hbar != null:
		hbar.value_changed.connect(func(_v: float) -> void:
			call_deferred("_refresh_growth_tree_links")
		)
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_stretch_ratio = 3.0
	var detail_style := _growth_tree_node_stylebox()
	detail_style.bg_color = Color(0.09, 0.1, 0.12, 1.0)
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	body.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	detail_margin.add_theme_constant_override("margin_left", 10)
	detail_margin.add_theme_constant_override("margin_top", 8)
	detail_margin.add_theme_constant_override("margin_right", 10)
	detail_margin.add_theme_constant_override("margin_bottom", 10)
	detail_panel.add_child(detail_margin)
	var detail_col := VBoxContainer.new()
	detail_col.add_theme_constant_override("separation", 8)
	detail_margin.add_child(detail_col)
	var detail_title := Label.new()
	detail_title.text = "说明"
	detail_title.add_theme_font_size_override("font_size", 14)
	detail_col.add_child(detail_title)
	growth_detail_richtext = RichTextLabel.new()
	growth_detail_richtext.bbcode_enabled = false
	growth_detail_richtext.fit_content = false
	growth_detail_richtext.scroll_active = true
	growth_detail_richtext.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	growth_detail_richtext.size_flags_vertical = Control.SIZE_EXPAND_FILL
	growth_detail_richtext.custom_minimum_size = Vector2(240, 160)
	growth_detail_richtext.text = GROWTH_DETAIL_PLACEHOLDER
	detail_col.add_child(growth_detail_richtext)
	_build_growth_tree_nodes()
	growth_window.size_changed.connect(func() -> void:
		call_deferred("_refresh_growth_tree_links")
	)
	growth_window.size = Vector2i(760, 560)
	growth_window.min_size = Vector2i(620, 480)
	add_child(growth_window)


func _init_expedition_window() -> void:
	expedition_window = Window.new()
	expedition_window.title = "远征"
	expedition_window.size = Vector2i(520, 420)
	expedition_window.min_size = Vector2i(440, 360)
	expedition_window.transient = true
	expedition_window.exclusive = true
	expedition_window.visible = false
	expedition_window.close_requested.connect(func() -> void:
		if _is_expedition_flow_locked():
			status_label.text = "请先完成当前远征流程。"
			return
		expedition_window.hide()
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
	expedition_item_list = ItemList.new()
	expedition_item_list.custom_minimum_size = Vector2(0, 160)
	expedition_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	expedition_item_list.allow_reselect = true
	expedition_item_list.select_mode = ItemList.SELECT_MULTI
	col.add_child(expedition_item_list)
	expedition_start_button = Button.new()
	expedition_start_button.text = "开始远征"
	expedition_start_button.pressed.connect(_on_expedition_start_pressed)
	col.add_child(expedition_start_button)
	expedition_close_button = Button.new()
	expedition_close_button.text = "关闭"
	expedition_close_button.pressed.connect(func() -> void:
		if _is_expedition_flow_locked():
			status_label.text = "请先完成当前远征流程。"
			return
		expedition_window.hide()
	)
	col.add_child(expedition_close_button)
	add_child(expedition_window)


func _init_time_speed_window() -> void:
	time_speed_window = Window.new()
	time_speed_window.title = "时间倍速"
	time_speed_window.size = Vector2i(400, 160)
	time_speed_window.min_size = Vector2i(360, 140)
	time_speed_window.transient = true
	time_speed_window.exclusive = true
	time_speed_window.unresizable = true
	time_speed_window.visible = false
	time_speed_window.close_requested.connect(func() -> void:
		time_speed_window.hide()
	)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	time_speed_window.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "加快或减慢整局游戏时间（含投掷动画与自动计时）。与成长树中的升级无关。"
	vbox.add_child(hint)
	time_speed_value_label = Label.new()
	time_speed_value_label.text = "当前倍速: 1×"
	vbox.add_child(time_speed_value_label)
	time_speed_slider = HSlider.new()
	time_speed_slider.min_value = _TimeSpeedSettings.MIN_MULT
	time_speed_slider.max_value = _TimeSpeedSettings.MAX_MULT
	time_speed_slider.step = 1
	time_speed_slider.tick_count = _TimeSpeedSettings.MAX_MULT - _TimeSpeedSettings.MIN_MULT + 1
	time_speed_slider.ticks_on_borders = true
	time_speed_slider.value = time_speed
	time_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_speed_slider.value_changed.connect(_on_time_speed_slider_changed)
	vbox.add_child(time_speed_slider)
	add_child(time_speed_window)


func _on_time_speed_slider_changed(v: float) -> void:
	var m := _TimeSpeedSettings.clamp_mult(int(round(v)))
	time_speed_slider.set_value_no_signal(m)
	time_speed_value_label.text = "当前倍速: %d×" % m
	_TimeSpeedSettings.apply_engine_multiplier(m)
	if m == time_speed:
		return
	time_speed = m
	_save_game()


func _growth_tree_node_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.14, 1.0)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.32, 0.35, 0.4, 1.0)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	return sb


func _growth_tree_node_stylebox_compact() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.14, 1.0)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.3, 0.33, 0.38, 1.0)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(4)
	return sb


func _create_tech_tree_node(parent: Node, node_id: String, callback: Callable) -> Button:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.custom_minimum_size = Vector2(40, 40)
	panel.position = Vector2.ZERO
	panel.size = Vector2(40, 40)
	panel.add_theme_stylebox_override("panel", _growth_tree_node_stylebox_compact())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(_on_growth_node_hover.bind(node_id))
	parent.add_child(panel)
	growth_node_panels[node_id] = panel
	var button := Button.new()
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size = Vector2(36, 36)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", 10)
	button.pressed.connect(callback)
	button.mouse_entered.connect(_on_growth_node_hover.bind(node_id))
	button.tooltip_text = ""
	button.focus_mode = Control.FOCUS_NONE
	panel.add_child(button)
	return button


func _build_growth_tree_nodes() -> void:
	upgrade_buttons = {}
	growth_node_panels.clear()
	growth_tree_node_prereqs.clear()
	if growth_tree_root == null:
		return
	for child in growth_tree_root.get_children():
		child.queue_free()
	var defs: Array = _growth_tree_node_defs()
	var defs_by_id: Dictionary = {}
	var section_order: Array[String] = []
	var section_defs: Dictionary = {}
	for d in defs:
		if d is Dictionary and d.has("id"):
			var dd := d as Dictionary
			var node_id := String(dd.get("id", ""))
			var section := String(dd.get("section", ""))
			defs_by_id[node_id] = dd
			if not section_defs.has(section):
				section_defs[section] = []
				section_order.append(section)
			(section_defs[section] as Array).append(dd)
	var depth_cache: Dictionary = {}
	for section in section_order:
		var section_label := Label.new()
		section_label.text = section
		section_label.add_theme_font_size_override("font_size", 12)
		growth_tree_root.add_child(section_label)
		var section_box := VBoxContainer.new()
		section_box.add_theme_constant_override("separation", 18)
		growth_tree_root.add_child(section_box)
		var nodes_in_section: Array = section_defs.get(section, [])
		var section_node_ids: Array[String] = []
		var section_def_by_id: Dictionary = {}
		for node_variant in nodes_in_section:
			if not (node_variant is Dictionary):
				continue
			var node_def := node_variant as Dictionary
			var node_id := String(node_def.get("id", ""))
			if node_id == "":
				continue
			section_node_ids.append(node_id)
			section_def_by_id[node_id] = node_def
		var section_children := _build_growth_tree_section_children(section_node_ids, section_def_by_id)
		var section_x_slots := _build_growth_tree_section_x_slots(section_node_ids, section_children, section_def_by_id)
		var section_max_slot := 0
		for slot in section_x_slots.values():
			section_max_slot = maxi(section_max_slot, int(slot))
		var rows_by_depth: Dictionary = {}
		var max_depth := 0
		for node_variant in nodes_in_section:
			if not (node_variant is Dictionary):
				continue
			var node_def := node_variant as Dictionary
			var node_id := String(node_def.get("id", ""))
			if node_id == "":
				continue
			var reqs: Array = []
			var req_variant: Variant = node_def.get("requires", [])
			if req_variant is Array:
				reqs = (req_variant as Array).duplicate()
			growth_tree_node_prereqs[node_id] = reqs
			var depth := _resolve_growth_node_depth(node_id, defs_by_id, depth_cache, {})
			max_depth = maxi(max_depth, depth)
			if not rows_by_depth.has(depth):
				var row := _create_growth_tree_row_layer(section_max_slot + 64)
				rows_by_depth[depth] = row
			var target_row := rows_by_depth[depth] as Control
			var slot_x := int(section_x_slots.get(node_id, 0))
			target_row.add_child(_create_growth_tree_node_holder(node_id, slot_x, node_def))
		for depth_idx in range(max_depth + 1):
			if rows_by_depth.has(depth_idx):
				section_box.add_child(rows_by_depth[depth_idx] as Control)
	call_deferred("_update_growth_tree_canvas_size")
	call_deferred("_refresh_growth_tree_links")


func _create_growth_tree_row_layer(width_px: int) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(maxi(200, width_px), 58)
	row.size = row.custom_minimum_size
	return row


func _create_growth_tree_node_holder(node_id: String, slot_x: int, node_def: Dictionary) -> Control:
	var holder := Control.new()
	holder.position = Vector2(slot_x, 0)
	holder.custom_minimum_size = Vector2(40, 40)
	holder.size = holder.custom_minimum_size
	var callback_name := String(node_def.get("callback", ""))
	var callback := Callable()
	if callback_name != "":
		callback = Callable(self, callback_name)
	var btn := _create_tech_tree_node(holder, node_id, callback)
	btn.custom_minimum_size = Vector2(36, 36)
	upgrade_buttons[node_id] = btn
	return holder


func _build_growth_tree_section_children(section_node_ids: Array[String], section_def_by_id: Dictionary) -> Dictionary:
	var in_section := {}
	for node_id in section_node_ids:
		in_section[node_id] = true
	var children: Dictionary = {}
	for node_id in section_node_ids:
		children[node_id] = []
	for node_id in section_node_ids:
		var node_def := section_def_by_id.get(node_id, {}) as Dictionary
		var req_variant: Variant = node_def.get("requires", [])
		if req_variant is Array:
			for req in req_variant:
				var req_id := String(req)
				if in_section.has(req_id):
					(children[req_id] as Array).append(node_id)
	return children


func _build_growth_tree_section_x_slots(section_node_ids: Array[String], children: Dictionary, section_def_by_id: Dictionary) -> Dictionary:
	var x_cache: Dictionary = {}
	var leaf_state := {"next": 0.0}
	var indegree: Dictionary = {}
	for node_id in section_node_ids:
		indegree[node_id] = 0
	for node_id in section_node_ids:
		var node_def := section_def_by_id.get(node_id, {}) as Dictionary
		var req_variant: Variant = node_def.get("requires", [])
		if req_variant is Array:
			for req in req_variant:
				var req_id := String(req)
				if indegree.has(node_id) and indegree.has(req_id):
					indegree[node_id] = int(indegree[node_id]) + 1
	var roots: Array[String] = []
	for node_id in section_node_ids:
		if int(indegree.get(node_id, 0)) == 0:
			roots.append(node_id)
	roots.sort()
	for root_id in roots:
		_compute_growth_tree_x_slot(root_id, children, x_cache, leaf_state, {})
	var sorted_all := section_node_ids.duplicate()
	sorted_all.sort()
	for node_id in sorted_all:
		if not x_cache.has(node_id):
			_compute_growth_tree_x_slot(node_id, children, x_cache, leaf_state, {})
	var pixel_slots: Dictionary = {}
	var slot_step := 58.0
	for node_id in section_node_ids:
		var unit_x := float(x_cache.get(node_id, 0.0))
		pixel_slots[node_id] = int(round(unit_x * slot_step))
	return pixel_slots


func _compute_growth_tree_x_slot(node_id: String, children: Dictionary, x_cache: Dictionary, leaf_state: Dictionary, visiting: Dictionary) -> float:
	if x_cache.has(node_id):
		return float(x_cache[node_id])
	if visiting.has(node_id):
		return float(leaf_state.get("next", 0.0))
	visiting[node_id] = true
	var child_ids := children.get(node_id, []) as Array
	var x_value := 0.0
	if child_ids.is_empty():
		x_value = float(leaf_state.get("next", 0.0))
		leaf_state["next"] = x_value + 1.0
	else:
		var sorted_children: Array[String] = []
		for cid in child_ids:
			sorted_children.append(String(cid))
		sorted_children.sort()
		var sum := 0.0
		for child_id in sorted_children:
			sum += _compute_growth_tree_x_slot(child_id, children, x_cache, leaf_state, visiting)
		x_value = sum / float(sorted_children.size())
	x_cache[node_id] = x_value
	visiting.erase(node_id)
	return x_value


func _update_growth_tree_canvas_size() -> void:
	if growth_tree_stage == null or growth_tree_root == null or growth_tree_link_layer == null:
		return
	var min_size: Vector2 = growth_tree_root.get_combined_minimum_size()
	min_size.x = maxf(min_size.x + 120.0, 480.0)
	min_size.y = maxf(min_size.y + 24.0, 260.0)
	growth_tree_stage.custom_minimum_size = min_size
	growth_tree_stage.size = min_size
	growth_tree_link_layer.size = min_size


func _growth_tree_node_defs() -> Array:
	return [
		{
			"id": "table",
			"section": "基础成长",
			"requires": [],
			"callback": "_on_upgrade_table_pressed"
		},
		{
			"id": "auto_unlock",
			"section": "基础成长",
			"requires": [],
			"callback": "_on_upgrade_auto_unlock_pressed"
		},
		{
			"id": "auto_speed",
			"section": "基础成长",
			"requires": ["auto_unlock"],
			"callback": "_on_upgrade_auto_speed_pressed"
		},
		{
			"id": "expedition_unlock",
			"section": "远征科技（货币1）",
			"requires": [],
			"callback": "_on_tech_expedition_unlock_pressed"
		},
		{
			"id": "expedition_delete",
			"section": "远征科技（货币1）",
			"requires": ["expedition_unlock"],
			"callback": "_on_tech_delete_expedition_pressed"
		},
		{
			"id": "expedition_synth",
			"section": "远征科技（货币1）",
			"requires": ["expedition_delete"],
			"callback": "_on_tech_synth_expedition_pressed"
		},
		{
			"id": "dice_cap_tech",
			"section": "远征科技（货币1）",
			"requires": ["expedition_unlock"],
			"callback": "_on_tech_dice_cap_pressed"
		},
		{
			"id": "exp_acquire_n",
			"section": "远征科技（货币1）",
			"requires": ["expedition_unlock"],
			"callback": "_on_tech_acquire_n_pressed"
		},
		{
			"id": "exp_delete_n",
			"section": "远征科技（货币1）",
			"requires": ["expedition_delete"],
			"callback": "_on_tech_delete_n_pressed"
		},
		{
			"id": "exp_synth_n",
			"section": "远征科技（货币1）",
			"requires": ["expedition_synth"],
			"callback": "_on_tech_synth_n_pressed"
		},
		{
			"id": "exp_duration",
			"section": "远征科技（货币1）",
			"requires": ["expedition_unlock"],
			"callback": "_on_tech_exp_duration_pressed"
		}
	]


func _resolve_growth_node_depth(node_id: String, defs_by_id: Dictionary, cache: Dictionary, visiting: Dictionary) -> int:
	if cache.has(node_id):
		return int(cache[node_id])
	if visiting.has(node_id):
		return 0
	visiting[node_id] = true
	var depth := 0
	var d_variant: Variant = defs_by_id.get(node_id, {})
	if d_variant is Dictionary:
		var req_variant: Variant = (d_variant as Dictionary).get("requires", [])
		if req_variant is Array:
			for req in req_variant:
				var req_id := String(req)
				if defs_by_id.has(req_id):
					depth = maxi(depth, _resolve_growth_node_depth(req_id, defs_by_id, cache, visiting) + 1)
	cache[node_id] = depth
	visiting.erase(node_id)
	return depth


func _refresh_growth_tree_links() -> void:
	if growth_tree_link_layer == null:
		return
	for child in growth_tree_link_layer.get_children():
		child.queue_free()
	for to_node_id in growth_tree_node_prereqs.keys():
		var to_panel := growth_node_panels.get(to_node_id, null) as Control
		if to_panel == null:
			continue
		var reqs: Array = growth_tree_node_prereqs.get(to_node_id, [])
		for from_node in reqs:
			var from_node_id := String(from_node)
			var from_panel := growth_node_panels.get(from_node_id, null) as Control
			if from_panel == null:
				continue
			_draw_growth_link(from_panel, to_panel)


func _rect_edge_midpoints(rect: Rect2) -> Array[Vector2]:
	return [
		Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y),
		Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y * 0.5),
		Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y),
		Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5)
	]


func _draw_growth_link(from_panel: Control, to_panel: Control) -> void:
	var from_rect := from_panel.get_global_rect()
	var to_rect := to_panel.get_global_rect()
	var layer_origin: Vector2 = growth_tree_link_layer.global_position
	var start_global := Vector2(from_rect.position.x + from_rect.size.x * 0.5, from_rect.position.y + from_rect.size.y)
	var end_global := Vector2(to_rect.position.x + to_rect.size.x * 0.5, to_rect.position.y)
	var start: Vector2 = start_global - layer_origin
	var tip: Vector2 = end_global - layer_origin
	if start.distance_squared_to(tip) < 1.0:
		return
	var body := Line2D.new()
	body.default_color = Color(0.42, 0.72, 0.94, 0.92)
	body.width = 2.0
	body.joint_mode = Line2D.LINE_JOINT_ROUND
	body.begin_cap_mode = Line2D.LINE_CAP_ROUND
	body.end_cap_mode = Line2D.LINE_CAP_ROUND
	body.antialiased = true
	body.add_point(start)
	body.add_point(tip)
	growth_tree_link_layer.add_child(body)
	var dir := (tip - start).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var arrow_len := 8.0
	var arrow_half_width := 4.0
	var base := tip - dir * arrow_len
	var left_pt := base + normal * arrow_half_width
	var right_pt := base - normal * arrow_half_width
	var head_left := Line2D.new()
	head_left.default_color = Color(0.42, 0.72, 0.94, 0.92)
	head_left.width = 2.0
	head_left.joint_mode = Line2D.LINE_JOINT_ROUND
	head_left.begin_cap_mode = Line2D.LINE_CAP_ROUND
	head_left.end_cap_mode = Line2D.LINE_CAP_ROUND
	head_left.antialiased = true
	head_left.add_point(tip)
	head_left.add_point(left_pt)
	growth_tree_link_layer.add_child(head_left)
	var head_right := Line2D.new()
	head_right.default_color = Color(0.42, 0.72, 0.94, 0.92)
	head_right.width = 2.0
	head_right.joint_mode = Line2D.LINE_JOINT_ROUND
	head_right.begin_cap_mode = Line2D.LINE_CAP_ROUND
	head_right.end_cap_mode = Line2D.LINE_CAP_ROUND
	head_right.antialiased = true
	head_right.add_point(tip)
	head_right.add_point(right_pt)
	growth_tree_link_layer.add_child(head_right)


func _on_growth_node_hover(node_id: String) -> void:
	growth_hovered_node_id = node_id
	if growth_detail_richtext == null:
		return
	var body_text: Variant = growth_node_detail_text.get(node_id, "")
	growth_detail_richtext.text = str(body_text) if str(body_text).length() > 0 else GROWTH_DETAIL_PLACEHOLDER


func _bind_signals() -> void:
	var pop := menu_button.get_popup()
	pop.add_item("掷骰统计…", 0)
	pop.add_item("时间倍速…", 1)
	pop.id_pressed.connect(_on_game_menu_id_pressed)
	growth_button.pressed.connect(_on_growth_button_pressed)
	throw_pulse_timer.timeout.connect(_on_throw_pulse_timer_timeout)
	for t in range(GameState.MAX_TABLE_COUNT):
		for d in range(GameState.MAX_DICE_COUNT):
			var die_button := table_die_buttons[t][d] as Button
			var ti := t
			var di := d
			die_button.expand_icon = true
			die_button.toggled.connect(func(_pressed: bool) -> void:
				_on_dice_toggled(ti, di)
			)
		table_roll_buttons[t].pressed.connect(func() -> void:
			_on_roll_pressed(t)
		)
		table_settle_buttons[t].pressed.connect(func() -> void:
			_on_settle_pressed(t)
		)
		table_auto_buttons[t].pressed.connect(func() -> void:
			_on_table_auto_pressed(t)
		)
		table_dice_upgrade_buttons[t].pressed.connect(func() -> void:
			_on_upgrade_dice_on_table_pressed(t)
		)
		table_expedition_buttons[t].pressed.connect(func() -> void:
			_on_expedition_button_pressed(t)
		)


func _build_table_panels() -> void:
	for child in tables_grid.get_children():
		child.queue_free()
	table_panel_roots.clear()
	table_die_buttons.clear()
	table_info_labels.clear()
	table_roll_buttons.clear()
	table_settle_buttons.clear()
	table_auto_buttons.clear()
	table_dice_upgrade_buttons.clear()
	table_expedition_buttons.clear()
	tables_grid.columns = 2
	var die_size := Vector2(48, 48)
	for table_index in range(GameState.MAX_TABLE_COUNT):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		table_panel_roots.append(panel)
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 4)
		panel.add_child(inner)
		var info := Label.new()
		table_info_labels.append(info)
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
		table_die_buttons.append(buttons_for_table)
		var ctrl := HBoxContainer.new()
		ctrl.add_theme_constant_override("separation", 6)
		inner.add_child(ctrl)
		var rb := Button.new()
		rb.text = "掷骰"
		table_roll_buttons.append(rb)
		ctrl.add_child(rb)
		var sb := Button.new()
		sb.text = "结算"
		table_settle_buttons.append(sb)
		ctrl.add_child(sb)
		var ab := Button.new()
		ab.text = "自动:关"
		table_auto_buttons.append(ab)
		ctrl.add_child(ab)
		var ub := Button.new()
		ub.text = "本桌骰子+1"
		table_dice_upgrade_buttons.append(ub)
		inner.add_child(ub)
		var exb := Button.new()
		exb.text = "远征"
		table_expedition_buttons.append(exb)
		inner.add_child(exb)
		tables_grid.add_child(panel)


func _any_table_throwing() -> bool:
	for t in range(GameState.MAX_TABLE_COUNT):
		if table_is_throwing[t]:
			return true
	return false


func _start_new_game() -> void:
	turn_manager.start_new_game()
	for i in range(GameState.MAX_TABLE_COUNT):
		table_throw_timers[i].stop()
		table_auto_timers[i].stop()
		if i < table_expedition_timers.size():
			table_expedition_timers[i].stop()
		table_is_throwing[i] = false
		table_throw_sources[i] = ""
		table_throw_visuals[i] = []
		table_queued_auto[i] = 0
	throw_pulse_timer.stop()
	_apply_all_auto_timers()
	status_label.text = "新对局开始。"
	_save_game()
	_refresh_all()


func _refresh_all() -> void:
	_apply_tables_scroll_min_height()
	_apply_table_panel_density()
	_refresh_turn_labels()
	_refresh_table_infos()
	_refresh_dice()
	_refresh_growth_tree()
	_refresh_score_board()
	_update_all_table_buttons()


func _refresh_turn_labels() -> void:
	var sum_dice := 0
	for i in range(game_state.table_count):
		sum_dice += game_state.get_table_dice_count(i)
	turn_label.text = "骰桌:%d/%d · 骰子合计:%d（每桌独立操作与自动计时）" % [
		game_state.table_count, GameState.MAX_TABLE_COUNT, sum_dice
	]
	rolls_label.text = "各桌独立操作；骰桌区可上下滚动。"


func _refresh_table_infos() -> void:
	for t in range(GameState.MAX_TABLE_COUNT):
		if t >= game_state.table_count:
			continue
		var dc := game_state.get_table_dice_count(t)
		var ru := int(game_state.table_rolls_used[t])
		table_info_labels[t].text = "桌%d · 投%d/%d · 骰%d个" % [t + 1, ru, GameState.MAX_ROLLS_PER_TURN, dc]


func _refresh_dice() -> void:
	for table_index in range(table_panel_roots.size()):
		var root := table_panel_roots[table_index]
		root.visible = table_index < game_state.table_count
		if not root.visible:
			continue
		var dc := game_state.get_table_dice_count(table_index)
		for die_index in range(GameState.MAX_DICE_COUNT):
			var die_button := table_die_buttons[table_index][die_index] as Button
			var visible_for_count := die_index < dc
			die_button.visible = visible_for_count
			if not visible_for_count:
				continue
			var value: int = 1
			var held := false
			if table_is_throwing[table_index] and table_throw_visuals[table_index] is Array:
				var tv: Array = table_throw_visuals[table_index]
				if die_index < tv.size():
					value = clampi(int(tv[die_index]), DiceLogic.FACE_MIN, DiceLogic.FACE_MAX)
			else:
				var vals: Array = game_state.table_dice_values[table_index]
				if die_index < vals.size():
					value = clampi(int(vals[die_index]), DiceLogic.FACE_MIN, DiceLogic.FACE_MAX)
				var hrow: Array = game_state.table_holds[table_index]
				if die_index < hrow.size():
					held = bool(hrow[die_index])
			die_button.icon = DIE_TEXTURES.get(value, DIE_TEXTURES[1])
			die_button.text = ""
			var auto_on := game_state.is_table_auto_enabled(table_index)
			die_button.set_pressed_no_signal(not table_is_throwing[table_index] and held)
			if table_is_throwing[table_index]:
				die_button.modulate = Color(0.85, 0.9, 1.0)
			else:
				die_button.modulate = Color(1.0, 0.92, 0.6) if held else Color(1, 1, 1)
			var tip := "桌%d 骰%d 点%d %s" % [
				table_index + 1,
				die_index + 1,
				value,
				"已锁定" if held else "可点锁定"
			]
			if table_index < game_state.table_die_defs.size():
				var drow: Array = game_state.table_die_defs[table_index]
				if die_index < drow.size() and drow[die_index] is _Die:
					tip += "  " + (drow[die_index] as _Die).summary_label()
			die_button.tooltip_text = tip
			var ru := int(game_state.table_rolls_used[table_index])
			die_button.disabled = table_is_throwing[table_index] or auto_on or ru == 0


func _refresh_growth_tree() -> void:
	if growth_coin_label != null:
		growth_coin_label.text = "货币1: %d  ·  在科技树中消耗货币购买升级" % game_state.coin_1
	var table_cost := game_state.get_table_upgrade_cost()
	var auto_unlock_cost := game_state.get_auto_unlock_cost()
	var auto_speed_cost := game_state.get_auto_speed_upgrade_cost()

	var table_btn := upgrade_buttons.get("table") as Button
	table_btn.text = "桌满" if table_cost < 0 else "骰桌"
	table_btn.disabled = table_cost < 0 or game_state.coin_1 < table_cost

	var auto_unlock_btn := upgrade_buttons.get("auto_unlock") as Button
	if game_state.auto_unlocked:
		auto_unlock_btn.text = "自动开"
		auto_unlock_btn.disabled = true
	else:
		auto_unlock_btn.text = "自动"
		auto_unlock_btn.disabled = game_state.coin_1 < auto_unlock_cost

	var auto_speed_btn := upgrade_buttons.get("auto_speed") as Button
	auto_speed_btn.text = "速满" if auto_speed_cost < 0 else "间隔"
	auto_speed_btn.disabled = auto_speed_cost < 0 or game_state.coin_1 < auto_speed_cost

	var exu := upgrade_buttons.get("expedition_unlock") as Button
	if game_state.tech_expedition_portal_unlocked:
		exu.text = "入口开"
		exu.disabled = true
	else:
		exu.text = "入口"
		exu.disabled = game_state.coin_1 < GameState.TECH_COST_EXPEDITION_ENTRY

	var exd := upgrade_buttons.get("expedition_delete") as Button
	if game_state.tech_delete_expedition_unlocked:
		exd.text = "删骰开"
		exd.disabled = true
	else:
		exd.text = "删骰"
		exd.disabled = (not game_state.tech_expedition_portal_unlocked) or game_state.coin_1 < GameState.TECH_COST_DELETE_EXPEDITION

	var exs := upgrade_buttons.get("expedition_synth") as Button
	if game_state.tech_synth_expedition_unlocked:
		exs.text = "合成开"
		exs.disabled = true
	else:
		exs.text = "合成"
		exs.disabled = (not game_state.tech_delete_expedition_unlocked) or game_state.coin_1 < GameState.TECH_COST_SYNTH_EXPEDITION

	var dcap := upgrade_buttons.get("dice_cap_tech") as Button
	var dcc := game_state.get_dice_cap_tech_cost_for_next_level()
	if game_state.tech_dice_cap_level >= 2:
		dcap.text = "上限满"
		dcap.disabled = true
	elif game_state.tech_dice_cap_level == 1:
		dcap.text = "上限7"
		dcap.disabled = game_state.coin_1 < dcc
	else:
		dcap.text = "上限6"
		dcap.disabled = game_state.coin_1 < dcc

	var an := upgrade_buttons.get("exp_acquire_n") as Button
	var ac := game_state.get_acquire_n_upgrade_cost()
	an.text = "得N+1" if ac >= 0 else "得N满"
	an.disabled = ac < 0 or game_state.coin_1 < ac

	var dn := upgrade_buttons.get("exp_delete_n") as Button
	var del_n_cost := game_state.get_delete_n_upgrade_cost()
	dn.text = "删N+1" if del_n_cost >= 0 else "删N满"
	dn.disabled = del_n_cost < 0 or game_state.coin_1 < del_n_cost

	var sn := upgrade_buttons.get("exp_synth_n") as Button
	var sc := game_state.get_synth_n_upgrade_cost()
	sn.text = "合N+1" if sc >= 0 else "合N满"
	sn.disabled = sc < 0 or game_state.coin_1 < sc

	var du := upgrade_buttons.get("exp_duration") as Button
	var duc := game_state.get_duration_upgrade_cost()
	du.text = "耗时-" if duc >= 0 else "耗时满"
	du.disabled = duc < 0 or game_state.coin_1 < duc

	for t in range(GameState.MAX_TABLE_COUNT):
		var btn := table_dice_upgrade_buttons[t] as Button
		if t >= game_state.table_count:
			btn.visible = false
			continue
		btn.visible = true
		var cost := game_state.get_dice_upgrade_cost(t)
		btn.text = "桌%d 骰子+1  花费:%s" % [t + 1, "MAX" if cost < 0 else str(cost)]

	_refresh_growth_detail_cache()
	call_deferred("_refresh_growth_tree_links")


func _refresh_growth_detail_cache() -> void:
	var table_cost := game_state.get_table_upgrade_cost()
	var auto_unlock_cost := game_state.get_auto_unlock_cost()
	var auto_speed_cost := game_state.get_auto_speed_upgrade_cost()

	var tt_table := GROWTH_DETAIL_TABLE + "\n\n"
	tt_table += "当前：%d / %d 张骰桌。\n" % [game_state.table_count, GameState.MAX_TABLE_COUNT]
	if table_cost >= 0:
		tt_table += "下一档花费：%d 货币1。" % table_cost
	else:
		tt_table += "已达到骰桌上限，无法再购买。"
	growth_node_detail_text["table"] = tt_table

	var tt_unlock := GROWTH_DETAIL_AUTO_UNLOCK + "\n\n"
	if game_state.auto_unlocked:
		tt_unlock += "状态：已解锁。"
	else:
		tt_unlock += "状态：未解锁。\n购买花费：%d 货币1。" % auto_unlock_cost
	growth_node_detail_text["auto_unlock"] = tt_unlock

	var tt_speed := GROWTH_DETAIL_AUTO_SPEED + "\n\n"
	tt_speed += "当前等级：Lv.%d，逻辑间隔 %.2f 秒（各桌同档）。\n" % [
		game_state.auto_speed_level,
		game_state.get_auto_interval()
	]
	if auto_speed_cost >= 0:
		tt_speed += "下一档花费：%d 货币1。" % auto_speed_cost
	else:
		tt_speed += "已达到自动速度上限，无法再购买。"
	growth_node_detail_text["auto_speed"] = tt_speed

	var tt_exu := "解锁后每张骰桌可使用独立「远征」入口；默认可进行获得骰子远征。\n\n"
	if game_state.tech_expedition_portal_unlocked:
		tt_exu += "状态：已解锁。"
	else:
		tt_exu += "状态：未解锁。\n购买花费：%d 货币1。" % GameState.TECH_COST_EXPEDITION_ENTRY
	growth_node_detail_text["expedition_unlock"] = tt_exu

	var tt_exd := "解锁删骰远征：从本桌骰池移除一颗低价值骰子（至少保留1颗）。\n\n"
	if game_state.tech_delete_expedition_unlocked:
		tt_exd += "状态：已解锁。"
	else:
		tt_exd += "状态：未解锁。\n购买花费：%d 货币1。\n需先解锁远征入口。" % GameState.TECH_COST_DELETE_EXPEDITION
	growth_node_detail_text["expedition_delete"] = tt_exd

	var tt_exs := "解锁合成远征：选择两颗骰子合并成一颗更强骰子（骰数-1）。\n\n"
	if game_state.tech_synth_expedition_unlocked:
		tt_exs += "状态：已解锁。"
	else:
		tt_exs += "状态：未解锁。\n购买花费：%d 货币1。\n需先解锁删骰远征。" % GameState.TECH_COST_SYNTH_EXPEDITION
	growth_node_detail_text["expedition_synth"] = tt_exs

	var tt_cap := "同一科技节点两级：Lv1 解锁第6颗骰子，Lv2 解锁第7颗；Lv2 花费远高于 Lv1。\n\n"
	tt_cap += "当前等级：%d（单桌骰子上限 %d）。\n" % [game_state.tech_dice_cap_level, game_state.get_effective_max_dice_per_table()]
	var nxc := game_state.get_dice_cap_tech_cost_for_next_level()
	if nxc >= 0:
		tt_cap += "下一级花费：%d 货币1。" % nxc
	else:
		tt_cap += "已满级。"
	growth_node_detail_text["dice_cap_tech"] = tt_cap

	growth_node_detail_text["exp_acquire_n"] = (
		"提升「获得骰子」远征的候选数量（N选1）。\n\n当前N=%d，下一档花费：%s"
		% [game_state.get_expedition_acquire_choice_n(), str(game_state.get_acquire_n_upgrade_cost()) if game_state.get_acquire_n_upgrade_cost() >= 0 else "已满"]
	)
	growth_node_detail_text["exp_delete_n"] = (
		"提升「删骰」远征的候选数量（N选1）。\n\n当前N=%d，下一档花费：%s"
		% [game_state.get_expedition_delete_choice_n(), str(game_state.get_delete_n_upgrade_cost()) if game_state.get_delete_n_upgrade_cost() >= 0 else "已满"]
	)
	growth_node_detail_text["exp_synth_n"] = (
		"提升「合成」远征的候选池大小（N选2）。\n\n当前N=%d，下一档花费：%s"
		% [game_state.get_expedition_synth_pool_n(), str(game_state.get_synth_n_upgrade_cost()) if game_state.get_synth_n_upgrade_cost() >= 0 else "已满"]
	)
	growth_node_detail_text["exp_duration"] = (
		"缩短各桌远征等待时间（受时间倍速影响）。\n\n当前耗时 %.2f 秒，等级 %d，下一档花费：%s"
		% [
			game_state.get_expedition_duration_sec(),
			game_state.tech_expedition_duration_level,
			str(game_state.get_duration_upgrade_cost()) if game_state.get_duration_upgrade_cost() >= 0 else "已满"
		]
	)

	if growth_detail_richtext == null:
		return
	if growth_hovered_node_id != "" and growth_node_detail_text.has(growth_hovered_node_id):
		growth_detail_richtext.text = str(growth_node_detail_text[growth_hovered_node_id])


func _refresh_score_board() -> void:
	var lines: Array[String] = []
	lines.append("货币1: %d" % [game_state.coin_1])
	lines.append("总产出: %d" % [game_state.total_coin_earned])
	lines.append("当前预估收益/秒: %.1f" % [game_state.estimate_income_per_second()])
	lines.append("最近结算: %s  +%d" % [game_state.last_settlement_label, game_state.last_settlement_income])
	lines.append("基础点数:%d  判型倍率:%.2f  成长倍率:%.2f" % [
		game_state.last_settlement_base,
		game_state.last_settlement_multiplier,
		game_state.get_progress_multiplier()
	])
	lines.append("手动回合:%d  自动回合:%d" % [
		game_state.total_manual_turns,
		game_state.total_auto_turns
	])
	score_board.text = "\n".join(lines)


func _on_game_menu_id_pressed(id: int) -> void:
	if id == 0:
		dice_stats_dialog.dialog_text = game_state.dice_face_stats.format_dialog_text()
		dice_stats_dialog.popup_centered()
	elif id == 1:
		time_speed_slider.set_value_no_signal(time_speed)
		time_speed_value_label.text = "当前倍速: %d×" % time_speed
		time_speed_window.popup_centered()


func _on_growth_button_pressed() -> void:
	growth_hovered_node_id = ""
	if growth_detail_richtext != null:
		growth_detail_richtext.text = GROWTH_DETAIL_PLACEHOLDER
	_refresh_growth_tree()
	growth_window.popup_centered()
	call_deferred("_refresh_growth_tree_links")


func _update_all_table_buttons() -> void:
	var active_exp_table := _active_expedition_table_index()
	var any_exp_busy := active_exp_table >= 0
	for t in range(game_state.table_count):
		var throwing := table_is_throwing[t]
		table_roll_buttons[t].disabled = throwing or game_state.is_table_auto_enabled(t) or not game_state.can_manual_roll(t)
		table_settle_buttons[t].disabled = throwing or game_state.is_table_auto_enabled(t) or not game_state.can_settle_manual(t)
		var ab := table_auto_buttons[t]
		ab.disabled = not game_state.auto_unlocked
		ab.text = "自动:%s" % ["开" if game_state.is_table_auto_enabled(t) else "关"]
		var dice_cost := game_state.get_dice_upgrade_cost(t)
		table_dice_upgrade_buttons[t].disabled = dice_cost < 0 or game_state.coin_1 < dice_cost
		var exb2 := table_expedition_buttons[t] as Button
		var exp_busy := t < table_expedition_timers.size() and table_expedition_timers[t].time_left > 0.0
		var waiting_other := expedition_waiting_result_choice and expedition_table_index >= 0 and expedition_table_index != t
		var busy_other := any_exp_busy and active_exp_table != t
		exb2.disabled = not game_state.tech_expedition_portal_unlocked or exp_busy or waiting_other or busy_other
	for t in range(game_state.table_count, GameState.MAX_TABLE_COUNT):
		table_roll_buttons[t].disabled = true
		table_settle_buttons[t].disabled = true
		table_auto_buttons[t].disabled = true
		if t < table_expedition_buttons.size():
			(table_expedition_buttons[t] as Button).disabled = true


func _on_roll_pressed(table_index: int) -> void:
	if table_is_throwing[table_index]:
		status_label.text = "桌%d 投掷表现中。" % [table_index + 1]
		return
	var result := turn_manager.roll_manual_dice(table_index)
	if not result["ok"]:
		status_label.text = String(result["message"])
		_refresh_all()
		return
	status_label.text = "桌%d 手动投掷中…" % [table_index + 1]
	_start_throw_phase(table_index, "manual")


func _on_settle_pressed(table_index: int) -> void:
	if table_is_throwing[table_index]:
		status_label.text = "桌%d 投掷表现中，暂不可结算。" % [table_index + 1]
		return
	var result := turn_manager.settle_manual_turn(table_index)
	if not result["ok"]:
		status_label.text = String(result["message"])
	else:
		status_label.text = "桌%d 结算：%s  +%d" % [
			table_index + 1,
			String(result["pattern_label"]),
			int(result["income"])
		]
		_save_game()
	_refresh_all()


func start_session(_player_count: int) -> void:
	visible = true
	_start_new_game()


func start_new_session() -> void:
	visible = true
	_start_new_game()


func continue_session() -> bool:
	visible = true
	var loaded := _load_game()
	if not loaded:
		_start_new_game()
		status_label.text = "未找到有效存档，已开始新游戏。"
	return loaded


func has_continue_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _on_dice_toggled(table_index: int, die_index: int) -> void:
	if table_is_throwing[table_index] or game_state.is_table_auto_enabled(table_index):
		_refresh_dice()
		return
	if int(game_state.table_rolls_used[table_index]) == 0:
		_refresh_dice()
		return
	turn_manager.toggle_hold(table_index, die_index)
	_refresh_dice()


func _on_table_auto_pressed(table_index: int) -> void:
	if not game_state.auto_unlocked:
		status_label.text = "请先在「成长与解锁」按钮中解锁自动扔骰。"
		return
	var next := not game_state.is_table_auto_enabled(table_index)
	game_state.set_table_auto_enabled(table_index, next)
	status_label.text = "桌%d 自动:%s" % [table_index + 1, "开" if next else "关"]
	_apply_table_auto_timer(table_index)
	_save_game()
	_refresh_all()


func _on_table_auto_timer_timeout(table_index: int) -> void:
	if table_index >= game_state.table_count:
		return
	if not game_state.is_table_auto_enabled(table_index):
		return
	if table_is_throwing[table_index]:
		table_queued_auto[table_index] = mini(3, table_queued_auto[table_index] + 1)
		return
	var begin := turn_manager.begin_auto_throw_for_table(table_index)
	if not begin.get("ok", false):
		return
	status_label.text = "桌%d 自动投掷中…" % [table_index + 1]
	_start_throw_phase(table_index, "auto")


func _apply_table_auto_timer(table_index: int) -> void:
	if table_index >= table_auto_timers.size():
		return
	var tmr := table_auto_timers[table_index]
	tmr.stop()
	tmr.wait_time = game_state.get_auto_interval()
	if table_index < game_state.table_count and game_state.is_table_auto_enabled(table_index):
		if not table_is_throwing[table_index]:
			tmr.start()


func _apply_all_auto_timers() -> void:
	for i in range(GameState.MAX_TABLE_COUNT):
		_apply_table_auto_timer(i)


func _on_upgrade_dice_on_table_pressed(table_index: int) -> void:
	var result := game_state.upgrade_dice_on_table(table_index)
	if result["ok"]:
		if bool(result.get("takes_effect_next_turn", false)):
			status_label.text = "桌%d 骰子已升级；新骰子将从下一次投掷生效。" % [table_index + 1]
		else:
			status_label.text = "桌%d 骰子数=%d" % [table_index + 1, game_state.get_table_dice_count(table_index)]
	else:
		status_label.text = String(result["message"])
	if result["ok"]:
		_save_game()
	_refresh_all()


func _on_upgrade_table_pressed() -> void:
	if _any_table_throwing():
		return
	var previous_table_count := game_state.table_count
	var result := game_state.upgrade_table_count()
	status_label.text = "骰桌数量提升到 %d。" % [game_state.table_count] if result["ok"] else String(result["message"])
	if result["ok"]:
		if previous_table_count < game_state.table_count:
			_apply_table_auto_timer(previous_table_count)
		_save_game()
	_refresh_all()


func _on_upgrade_auto_unlock_pressed() -> void:
	if _any_table_throwing():
		return
	var result := game_state.unlock_auto()
	if result["ok"]:
		status_label.text = "已解锁自动扔骰（各桌默认开启，可单桌关闭）。"
		_apply_all_auto_timers()
		_save_game()
	else:
		status_label.text = String(result["message"])
	_refresh_all()


func _on_upgrade_auto_speed_pressed() -> void:
	if _any_table_throwing():
		return
	var result := game_state.upgrade_auto_speed()
	if result["ok"]:
		status_label.text = "自动速度提升到 Lv.%d。" % [game_state.auto_speed_level]
		_apply_all_auto_timers()
		_save_game()
	else:
		status_label.text = String(result["message"])
	_refresh_all()


func _on_tech_expedition_unlock_pressed() -> void:
	if _any_table_throwing():
		return
	var r := game_state.try_buy_expedition_portal()
	status_label.text = "已解锁各桌远征入口。" if r["ok"] else String(r["message"])
	if r["ok"]:
		_save_game()
	_refresh_all()


func _on_tech_delete_expedition_pressed() -> void:
	if _any_table_throwing():
		return
	var r := game_state.try_buy_delete_expedition()
	status_label.text = "已解锁删骰远征。" if r["ok"] else String(r["message"])
	if r["ok"]:
		_save_game()
	_refresh_all()


func _on_tech_synth_expedition_pressed() -> void:
	if _any_table_throwing():
		return
	var r := game_state.try_buy_synth_expedition()
	status_label.text = "已解锁合成远征。" if r["ok"] else String(r["message"])
	if r["ok"]:
		_save_game()
	_refresh_all()


func _on_tech_dice_cap_pressed() -> void:
	if _any_table_throwing():
		return
	var r := game_state.try_buy_dice_cap_level()
	status_label.text = "骰子上限科技已提升。" if r["ok"] else String(r["message"])
	if r["ok"]:
		_save_game()
	_refresh_all()


func _on_tech_acquire_n_pressed() -> void:
	if _any_table_throwing():
		return
	var r := game_state.try_upgrade_acquire_n()
	status_label.text = "得骰远征选项+1。" if r["ok"] else String(r["message"])
	if r["ok"]:
		_save_game()
	_refresh_all()


func _on_tech_delete_n_pressed() -> void:
	if _any_table_throwing():
		return
	var r := game_state.try_upgrade_delete_n()
	status_label.text = "删骰远征选项+1。" if r["ok"] else String(r["message"])
	if r["ok"]:
		_save_game()
	_refresh_all()


func _on_tech_synth_n_pressed() -> void:
	if _any_table_throwing():
		return
	var r := game_state.try_upgrade_synth_n()
	status_label.text = "合成远征候选池+1。" if r["ok"] else String(r["message"])
	if r["ok"]:
		_save_game()
	_refresh_all()


func _on_tech_exp_duration_pressed() -> void:
	if _any_table_throwing():
		return
	var r := game_state.try_upgrade_expedition_duration()
	status_label.text = "远征耗时已缩短。" if r["ok"] else String(r["message"])
	if r["ok"]:
		_save_game()
	_refresh_all()


func _on_expedition_button_pressed(table_index: int) -> void:
	if table_index >= game_state.table_count:
		return
	if not game_state.tech_expedition_portal_unlocked:
		status_label.text = "请先在成长树解锁远征入口。"
		return
	if expedition_waiting_result_choice and expedition_table_index != table_index:
		status_label.text = "请先完成当前远征的结果选择。"
		return
	var active_exp_table := _active_expedition_table_index()
	if active_exp_table >= 0 and active_exp_table != table_index:
		status_label.text = "已有其他骰桌远征进行中。"
		return
	if table_index < table_expedition_timers.size() and table_expedition_timers[table_index].time_left > 0.0:
		status_label.text = "该桌远征进行中。"
		return
	expedition_table_index = table_index
	expedition_income_before = game_state.estimate_income_per_second()
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
	expedition_type_option.disabled = _is_expedition_flow_locked()
	expedition_item_list.disabled = not expedition_waiting_result_choice
	expedition_start_button.text = "确认结果" if expedition_waiting_result_choice else "开始远征"
	expedition_start_button.disabled = false
	expedition_close_button.disabled = _is_expedition_flow_locked()
	expedition_window.popup_centered()


func _expedition_selected_type() -> int:
	if expedition_type_option.item_count <= 0:
		return -1
	var sel := expedition_type_option.selected
	if sel < 0:
		return -1
	return int(expedition_type_option.get_item_metadata(sel))


func _refresh_expedition_type_options() -> void:
	expedition_type_option.clear()
	if game_state.tech_expedition_portal_unlocked:
		expedition_type_option.add_item("获得骰子")
		expedition_type_option.set_item_metadata(expedition_type_option.item_count - 1, 0)
	if game_state.tech_delete_expedition_unlocked:
		expedition_type_option.add_item("删骰")
		expedition_type_option.set_item_metadata(expedition_type_option.item_count - 1, 1)
	if game_state.tech_synth_expedition_unlocked:
		expedition_type_option.add_item("合成")
		expedition_type_option.set_item_metadata(expedition_type_option.item_count - 1, 2)


func _on_expedition_type_selected(_idx: int) -> void:
	var ty := _expedition_selected_type()
	if ty == 2:
		expedition_item_list.select_mode = ItemList.SELECT_MULTI
	else:
		expedition_item_list.select_mode = ItemList.SELECT_SINGLE
	_repopulate_expedition_item_list()


func _repopulate_expedition_item_list() -> void:
	expedition_item_list.clear()
	expedition_acquire_candidates.clear()
	expedition_delete_indices.clear()
	expedition_synth_indices.clear()
	if not expedition_waiting_result_choice:
		expedition_item_list.add_item("远征结束后会出现可选结果。")
		expedition_item_list.set_item_disabled(0, true)
		return
	var ti := expedition_table_index
	if ti < 0 or ti >= game_state.table_count:
		return
	var ty := expedition_pending_kind
	if ty == 0:
		expedition_acquire_candidates = game_state.generate_acquire_candidates()
		var i := 0
		for d in expedition_acquire_candidates:
			if d is _Die:
				expedition_item_list.add_item("候选%d: %s" % [i + 1, (d as _Die).summary_label()])
				expedition_item_list.set_item_metadata(expedition_item_list.item_count - 1, i)
			i += 1
	elif ty == 1:
		expedition_delete_indices = game_state.get_random_delete_candidate_indices(ti)
		for j in range(expedition_delete_indices.size()):
			var di := expedition_delete_indices[j]
			var row: Array = game_state.table_die_defs[ti]
			var summ := ""
			if di < row.size() and row[di] is _Die:
				summ = (row[di] as _Die).summary_label()
			expedition_item_list.add_item("删除 骰位%d: %s" % [di + 1, summ])
			expedition_item_list.set_item_metadata(expedition_item_list.item_count - 1, di)
	elif ty == 2:
		expedition_synth_indices = game_state.get_random_synth_candidate_indices(ti)
		for j in range(expedition_synth_indices.size()):
			var di2 := expedition_synth_indices[j]
			var row2: Array = game_state.table_die_defs[ti]
			var summ2 := ""
			if di2 < row2.size() and row2[di2] is _Die:
				summ2 = (row2[di2] as _Die).summary_label()
			expedition_item_list.add_item("骰位%d: %s" % [di2 + 1, summ2])
			expedition_item_list.set_item_metadata(expedition_item_list.item_count - 1, di2)


func _on_expedition_start_pressed() -> void:
	var ti := expedition_table_index
	if ti < 0 or ti >= game_state.table_count:
		return
	if ti < table_expedition_timers.size() and table_expedition_timers[ti].time_left > 0.0:
		return
	if expedition_waiting_result_choice:
		_confirm_expedition_result()
		return
	var ty := _expedition_selected_type()
	_reset_expedition_pending_selection()
	if ty == 0:
		if game_state.get_table_dice_count(ti) >= game_state.get_effective_max_dice_per_table():
			status_label.text = "已达骰子上限，无法再通过远征获得骰子。"
			return
	elif ty == 1:
		if game_state.get_table_dice_count(ti) <= 1:
			status_label.text = "至少需要2颗骰子才能进行删骰远征。"
			return
	elif ty == 2:
		if game_state.get_table_dice_count(ti) < 2:
			status_label.text = "至少需要2颗骰子才能进行合成远征。"
			return
	else:
		status_label.text = "没有可用的远征类型。"
		return
	expedition_pending_kind = ty
	var dur := game_state.get_expedition_duration_sec() / maxf(0.05, float(Engine.time_scale))
	table_expedition_timers[ti].wait_time = dur
	table_expedition_timers[ti].start()
	expedition_waiting_result_choice = false
	expedition_type_option.disabled = true
	expedition_item_list.disabled = true
	expedition_item_list.clear()
	expedition_start_button.disabled = true
	expedition_start_button.text = "远征进行中..."
	expedition_close_button.disabled = true
	status_label.text = "桌%d 远征进行中（%.1fs）…" % [ti + 1, dur]
	expedition_hint_label.text = "桌%d 远征进行中，结束后请选择结果并确认。" % [ti + 1]
	_refresh_all()


func _on_table_expedition_timer_timeout(table_index: int) -> void:
	if table_index != expedition_table_index:
		return
	expedition_waiting_result_choice = true
	expedition_type_option.disabled = true
	expedition_item_list.disabled = false
	expedition_hint_label.text = "桌%d 远征已完成：请选择结果并点击「确认结果」。" % [table_index + 1]
	_repopulate_expedition_item_list()
	expedition_start_button.text = "确认结果"
	expedition_start_button.disabled = false
	expedition_close_button.disabled = true
	status_label.text = "桌%d 远征完成，等待选择结果。" % [table_index + 1]
	_refresh_all()


func _confirm_expedition_result() -> void:
	var ti := expedition_table_index
	if ti < 0 or ti >= game_state.table_count:
		return
	_reset_expedition_pending_selection()
	if expedition_pending_kind == 0:
		var sel := expedition_item_list.get_selected_items()
		if sel.size() != 1:
			status_label.text = "获得远征：请选择一个候选骰子。"
			return
		var ci := int(expedition_item_list.get_item_metadata(sel[0]))
		if ci < 0 or ci >= expedition_acquire_candidates.size():
			status_label.text = "选择无效。"
			return
		expedition_pending_acquire_idx = ci
	elif expedition_pending_kind == 1:
		var sel1 := expedition_item_list.get_selected_items()
		if sel1.size() != 1:
			status_label.text = "删骰远征：请选择一个删除目标。"
			return
		expedition_pending_delete_die_idx = int(expedition_item_list.get_item_metadata(sel1[0]))
	elif expedition_pending_kind == 2:
		var sel2 := expedition_item_list.get_selected_items()
		if sel2.size() != 2:
			status_label.text = "合成远征：请在列表中点选两颗骰子。"
			return
		var a := int(expedition_item_list.get_item_metadata(sel2[0]))
		var b := int(expedition_item_list.get_item_metadata(sel2[1]))
		expedition_pending_synth_lo = mini(a, b)
		expedition_pending_synth_hi = maxi(a, b)
	else:
		status_label.text = "远征状态异常。"
		return
	var msg := ""
	if expedition_pending_kind == 0:
		var die: _Die = expedition_acquire_candidates[expedition_pending_acquire_idx] as _Die
		var r := game_state.apply_expedition_acquire(ti, die)
		msg = "获得新骰子。" if r["ok"] else String(r["message"])
	elif expedition_pending_kind == 1:
		var r2 := game_state.apply_expedition_delete(ti, expedition_pending_delete_die_idx)
		msg = "已删除骰子。" if r2["ok"] else String(r2["message"])
	elif expedition_pending_kind == 2:
		var r3 := game_state.apply_expedition_synth(ti, expedition_pending_synth_lo, expedition_pending_synth_hi)
		msg = "合成完成。" if r3["ok"] else String(r3["message"])
	var after := game_state.estimate_income_per_second()
	expedition_income_label.text = "远征前估算收益/秒: %.1f  →  现在: %.1f" % [expedition_income_before, after]
	status_label.text = "桌%d %s" % [ti + 1, msg]
	expedition_waiting_result_choice = false
	expedition_pending_kind = -1
	_reset_expedition_pending_selection()
	expedition_type_option.disabled = false
	expedition_item_list.disabled = true
	expedition_start_button.text = "开始远征"
	expedition_start_button.disabled = false
	expedition_close_button.disabled = false
	expedition_hint_label.text = "桌%d：先选择远征类型并开始。远征结束后再选择结果并确认。" % [ti + 1]
	_save_game()
	_refresh_all()
	_repopulate_expedition_item_list()


func _save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入存档。")
		return
	var bundle := {
		"bundle": 1,
		"game": game_state.to_save_data(),
		"time_speed": time_speed
	}
	file.store_string(JSON.stringify(bundle))


func _load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	var game_dict: Dictionary = parsed
	if parsed.has("game") and parsed["game"] is Dictionary:
		game_dict = parsed["game"]
		time_speed = _TimeSpeedSettings.clamp_mult(int(parsed.get("time_speed", 1)))
	else:
		time_speed = 1
	var ok := game_state.load_from_save_data(game_dict)
	if not ok:
		return false
	_TimeSpeedSettings.apply_engine_multiplier(time_speed)
	for i in range(GameState.MAX_TABLE_COUNT):
		table_throw_timers[i].stop()
		table_auto_timers[i].stop()
		if i < table_expedition_timers.size():
			table_expedition_timers[i].stop()
		table_is_throwing[i] = false
		table_throw_sources[i] = ""
		table_throw_visuals[i] = []
		table_queued_auto[i] = 0
	throw_pulse_timer.stop()
	_apply_all_auto_timers()
	status_label.text = "已加载存档。"
	_refresh_all()
	return true


func _start_throw_phase(table_index: int, source: String) -> void:
	table_auto_timers[table_index].stop()
	table_is_throwing[table_index] = true
	table_throw_sources[table_index] = source
	_fill_throw_visuals_for_table(table_index)
	table_throw_timers[table_index].stop()
	table_throw_timers[table_index].wait_time = THROW_ANIMATION_SEC
	table_throw_timers[table_index].start()
	if throw_pulse_timer.is_stopped():
		throw_pulse_timer.wait_time = THROW_PULSE_SEC
		throw_pulse_timer.start()
	_refresh_all()


func _fill_throw_visuals_for_table(table_index: int) -> void:
	var dc := game_state.get_table_dice_count(table_index)
	var arr: Array[int] = []
	for i in range(dc):
		arr.append(randi_range(DiceLogic.FACE_MIN, DiceLogic.FACE_MAX))
	table_throw_visuals[table_index] = arr


func _on_throw_pulse_timer_timeout() -> void:
	if not _any_table_throwing():
		throw_pulse_timer.stop()
		return
	for t in range(game_state.table_count):
		if table_is_throwing[t]:
			_fill_throw_visuals_for_table(t)
	_refresh_dice()


func _on_table_throw_timer_timeout(table_index: int) -> void:
	if not table_is_throwing[table_index]:
		return
	table_is_throwing[table_index] = false
	table_throw_visuals[table_index] = []
	var src := table_throw_sources[table_index]
	table_throw_sources[table_index] = ""
	if src == "manual":
		status_label.text = "桌%d 掷骰完成，可锁骰或结算。" % [table_index + 1]
	elif src == "auto":
		var settle := turn_manager.finalize_auto_throw_for_table(table_index)
		if settle.get("ok", false):
			status_label.text = "桌%d 自动结算：%s  +%d" % [
				table_index + 1,
				String(settle["pattern_label"]),
				int(settle["income"])
			]
			_save_game()
	if not _any_table_throwing():
		throw_pulse_timer.stop()
	if table_queued_auto[table_index] > 0 and game_state.is_table_auto_enabled(table_index):
		var beginq := turn_manager.begin_auto_throw_for_table(table_index)
		if beginq.get("ok", false):
			table_queued_auto[table_index] -= 1
			_start_throw_phase(table_index, "auto")
			return
	_apply_table_auto_timer(table_index)
	_refresh_all()


func _active_expedition_table_index() -> int:
	for i in range(table_expedition_timers.size()):
		if table_expedition_timers[i].time_left > 0.0:
			return i
	return -1


func _is_expedition_flow_locked() -> bool:
	return expedition_waiting_result_choice or _active_expedition_table_index() >= 0


func _reset_expedition_pending_selection() -> void:
	expedition_pending_acquire_idx = -1
	expedition_pending_delete_die_idx = -1
	expedition_pending_synth_lo = -1
	expedition_pending_synth_hi = -1
