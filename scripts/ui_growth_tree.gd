extends RefCounted

const _GrowthTreeStyle := preload("res://scripts/growth_tree_style.gd")

var _host: Node

var growth_window: Window
var growth_coin_label: Label
var growth_node_panels: Dictionary = {}
var growth_tree_scroll: ScrollContainer
var growth_tree_stage: Control
var growth_tree_root: VBoxContainer
var growth_tree_link_layer: Control
var growth_tree_node_prereqs: Dictionary = {}
var growth_nodes_by_id: Dictionary = {}
var growth_node_order: Array[String] = []
var growth_detail_richtext: RichTextLabel
var growth_node_detail_text: Dictionary = {}
var growth_hovered_node_id: String = ""

const GROWTH_DETAIL_TABLE := "增加可同时使用的骰桌数量。"
const GROWTH_DETAIL_AUTO_UNLOCK := "解锁后可为每张骰桌单独开关自动投掷。"
const GROWTH_DETAIL_AUTO_SPEED := "缩短自动投掷间隔（全桌共享等级）。"
const GROWTH_DETAIL_PLACEHOLDER := "将鼠标移到左侧节点上查看说明。"
const GROWTH_NODE_LABELS := {
	"table": "骰桌扩容",
	"auto_unlock": "自动投掷",
	"auto_speed": "自动间隔",
	"expedition_unlock": "远征入口",
	"expedition_delete": "删骰远征",
	"expedition_synth": "合成远征",
	"dice_cap_tech": "骰子上限",
	"exp_acquire_n": "得骰候选",
	"exp_delete_n": "删骰候选",
	"exp_synth_n": "合成候选",
	"exp_duration": "远征耗时"
}


func _init(p_host: Node) -> void:
	_host = p_host


func init_growth_window() -> void:
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
	var tree_style := _GrowthTreeStyle.node_stylebox()
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
		_host.call_deferred("_growth_deferred_update_canvas")
		_host.call_deferred("_growth_deferred_refresh_links")
	)
	var vbar := growth_tree_scroll.get_v_scroll_bar()
	if vbar != null:
		vbar.value_changed.connect(func(_v: float) -> void:
			_host.call_deferred("_growth_deferred_refresh_links")
		)
	var hbar := growth_tree_scroll.get_h_scroll_bar()
	if hbar != null:
		hbar.value_changed.connect(func(_v: float) -> void:
			_host.call_deferred("_growth_deferred_refresh_links")
		)
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_stretch_ratio = 3.0
	var detail_style := _GrowthTreeStyle.node_stylebox()
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
		_host.call_deferred("_growth_deferred_refresh_links")
	)
	growth_window.size = Vector2i(760, 560)
	growth_window.min_size = Vector2i(620, 480)
	_host.add_child(growth_window)


func on_growth_button_pressed() -> void:
	growth_hovered_node_id = ""
	if growth_detail_richtext != null:
		growth_detail_richtext.text = GROWTH_DETAIL_PLACEHOLDER
	refresh_growth_tree(_host.game_state, _host.upgrade_buttons, _host.table_dice_upgrade_buttons)
	growth_window.popup_centered()
	_host.call_deferred("_growth_deferred_refresh_links")


func update_growth_tree_canvas_size() -> void:
	if growth_tree_stage == null or growth_tree_root == null or growth_tree_link_layer == null:
		return
	var min_size: Vector2 = growth_tree_root.get_combined_minimum_size()
	min_size.x = maxf(min_size.x + 120.0, 480.0)
	min_size.y = maxf(min_size.y + 24.0, 260.0)
	growth_tree_stage.custom_minimum_size = min_size
	growth_tree_stage.size = min_size
	growth_tree_link_layer.size = min_size


func refresh_growth_tree_links() -> void:
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


func refresh_growth_tree(game_state: GameState, upgrade_buttons: Dictionary, table_dice_upgrade_buttons: Array) -> void:
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
	if _get_growth_locked_prereq_text("auto_speed") != "":
		auto_speed_btn.text = "需前置"
	elif auto_speed_cost < 0:
		auto_speed_btn.text = "速满"
	else:
		auto_speed_btn.text = "间隔"
	auto_speed_btn.disabled = auto_speed_cost < 0 or game_state.coin_1 < auto_speed_cost

	var exu := upgrade_buttons.get("expedition_unlock") as Button
	if game_state.tech_expedition_portal_unlocked:
		exu.text = "入口开"
		exu.disabled = true
	else:
		exu.text = "入口"
		exu.disabled = game_state.coin_1 < GameState.TECH_COST_EXPEDITION_ENTRY

	var exd := upgrade_buttons.get("expedition_delete") as Button
	if not _is_growth_node_prereq_met("expedition_delete"):
		exd.text = "需前置"
		exd.disabled = true
	elif game_state.tech_delete_expedition_unlocked:
		exd.text = "删骰开"
		exd.disabled = true
	else:
		exd.text = "删骰"
		exd.disabled = game_state.coin_1 < GameState.TECH_COST_DELETE_EXPEDITION

	var exs := upgrade_buttons.get("expedition_synth") as Button
	if not _is_growth_node_prereq_met("expedition_synth"):
		exs.text = "需前置"
		exs.disabled = true
	elif game_state.tech_synth_expedition_unlocked:
		exs.text = "合成开"
		exs.disabled = true
	else:
		exs.text = "合成"
		exs.disabled = game_state.coin_1 < GameState.TECH_COST_SYNTH_EXPEDITION

	var dcap := upgrade_buttons.get("dice_cap_tech") as Button
	var dcc := game_state.get_dice_cap_tech_cost_for_next_level()
	if not _is_growth_node_prereq_met("dice_cap_tech"):
		dcap.text = "需前置"
		dcap.disabled = true
	elif game_state.tech_dice_cap_level >= 2:
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
	if not _is_growth_node_prereq_met("exp_acquire_n"):
		an.text = "需前置"
		an.disabled = true
	else:
		an.text = "得N+1" if ac >= 0 else "得N满"
		an.disabled = ac < 0 or game_state.coin_1 < ac

	var dn := upgrade_buttons.get("exp_delete_n") as Button
	var del_n_cost := game_state.get_delete_n_upgrade_cost()
	if not _is_growth_node_prereq_met("exp_delete_n"):
		dn.text = "需前置"
		dn.disabled = true
	else:
		dn.text = "删N+1" if del_n_cost >= 0 else "删N满"
		dn.disabled = del_n_cost < 0 or game_state.coin_1 < del_n_cost

	var sn := upgrade_buttons.get("exp_synth_n") as Button
	var sc := game_state.get_synth_n_upgrade_cost()
	if not _is_growth_node_prereq_met("exp_synth_n"):
		sn.text = "需前置"
		sn.disabled = true
	else:
		sn.text = "合N+1" if sc >= 0 else "合N满"
		sn.disabled = sc < 0 or game_state.coin_1 < sc

	var du := upgrade_buttons.get("exp_duration") as Button
	var duc := game_state.get_duration_upgrade_cost()
	if not _is_growth_node_prereq_met("exp_duration"):
		du.text = "需前置"
		du.disabled = true
	else:
		du.text = "耗时-" if duc >= 0 else "耗时满"
		du.disabled = duc < 0 or game_state.coin_1 < duc

	_refresh_growth_node_button_progress_text()

	for t in range(GameState.MAX_TABLE_COUNT):
		var btn := table_dice_upgrade_buttons[t] as Button
		if t >= game_state.table_count:
			btn.visible = false
			continue
		btn.visible = true
		var cost := game_state.get_dice_upgrade_cost(t)
		btn.text = "桌%d 骰子+1  花费:%s" % [t + 1, "MAX" if cost < 0 else str(cost)]

	_refresh_growth_detail_cache(game_state)
	_host.call_deferred("_growth_deferred_refresh_links")


func _refresh_growth_detail_cache(game_state: GameState) -> void:
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
	var auto_speed_prereq := _get_growth_locked_prereq_text("auto_speed")
	if auto_speed_prereq != "":
		tt_speed += auto_speed_prereq
	elif auto_speed_cost >= 0:
		tt_speed += "下一档花费：%d 货币1。" % auto_speed_cost
	else:
		tt_speed += "已达到自动速度上限，无法再购买。"
	growth_node_detail_text["auto_speed"] = tt_speed

	var tt_exu := "解锁各桌远征入口，并开放获得骰子远征。\n\n"
	if game_state.tech_expedition_portal_unlocked:
		tt_exu += "状态：已解锁。"
	else:
		tt_exu += "状态：未解锁。\n购买花费：%d 货币1。" % GameState.TECH_COST_EXPEDITION_ENTRY
	growth_node_detail_text["expedition_unlock"] = tt_exu

	var tt_exd := "解锁删骰远征：移除本桌1颗骰子（至少保留1颗）。\n\n"
	var exd_prereq := _get_growth_locked_prereq_text("expedition_delete")
	if game_state.tech_delete_expedition_unlocked:
		tt_exd += "状态：已解锁。"
	else:
		tt_exd += "状态：未解锁。\n购买花费：%d 货币1。" % GameState.TECH_COST_DELETE_EXPEDITION
		if exd_prereq != "":
			tt_exd += "\n" + exd_prereq
	growth_node_detail_text["expedition_delete"] = tt_exd

	var tt_exs := "解锁合成远征：两颗骰子合成为一颗（骰数-1）。\n\n"
	var exs_prereq := _get_growth_locked_prereq_text("expedition_synth")
	if game_state.tech_synth_expedition_unlocked:
		tt_exs += "状态：已解锁。"
	else:
		tt_exs += "状态：未解锁。\n购买花费：%d 货币1。" % GameState.TECH_COST_SYNTH_EXPEDITION
		if exs_prereq != "":
			tt_exs += "\n" + exs_prereq
	growth_node_detail_text["expedition_synth"] = tt_exs

	var tt_cap := "两级升级：Lv1 解锁单桌第6颗上场骰子，Lv2 解锁第7颗。\n\n"
	tt_cap += "当前等级：%d（单桌上场骰子数上限 %d）。\n" % [game_state.tech_dice_cap_level, game_state.get_effective_max_dice_per_table()]
	var nxc := game_state.get_dice_cap_tech_cost_for_next_level()
	var cap_prereq := _get_growth_locked_prereq_text("dice_cap_tech")
	if cap_prereq != "":
		tt_cap += cap_prereq
	elif nxc >= 0:
		tt_cap += "下一级花费：%d 货币1。" % nxc
	else:
		tt_cap += "已满级。"
	growth_node_detail_text["dice_cap_tech"] = tt_cap

	var ac_cost_txt := str(game_state.get_acquire_n_upgrade_cost()) if game_state.get_acquire_n_upgrade_cost() >= 0 else "已满"
	var ac_prereq := _get_growth_locked_prereq_text("exp_acquire_n")
	var ac_detail := "提升获得骰子远征候选数（N选1）。\n\n当前N=%d，下一档花费：%s" % [game_state.get_expedition_acquire_choice_n(), ac_cost_txt]
	if ac_prereq != "":
		ac_detail += "\n" + ac_prereq
	growth_node_detail_text["exp_acquire_n"] = ac_detail

	var dn_cost_txt := str(game_state.get_delete_n_upgrade_cost()) if game_state.get_delete_n_upgrade_cost() >= 0 else "已满"
	var dn_prereq := _get_growth_locked_prereq_text("exp_delete_n")
	var dn_detail := "提升删骰远征候选数（N选1）。\n\n当前N=%d，下一档花费：%s" % [game_state.get_expedition_delete_choice_n(), dn_cost_txt]
	if dn_prereq != "":
		dn_detail += "\n" + dn_prereq
	growth_node_detail_text["exp_delete_n"] = dn_detail

	var sn_cost_txt := str(game_state.get_synth_n_upgrade_cost()) if game_state.get_synth_n_upgrade_cost() >= 0 else "已满"
	var sn_prereq := _get_growth_locked_prereq_text("exp_synth_n")
	var sn_detail := "提升合成远征候选池（N选2）。\n\n当前N=%d，下一档花费：%s" % [game_state.get_expedition_synth_pool_n(), sn_cost_txt]
	if sn_prereq != "":
		sn_detail += "\n" + sn_prereq
	growth_node_detail_text["exp_synth_n"] = sn_detail

	var du_cost_txt := str(game_state.get_duration_upgrade_cost()) if game_state.get_duration_upgrade_cost() >= 0 else "已满"
	var du_prereq := _get_growth_locked_prereq_text("exp_duration")
	var du_detail := "缩短远征耗时。\n\n当前耗时 %.2f 秒，等级 %d，下一档花费：%s" % [
		game_state.get_expedition_duration_sec(),
		game_state.tech_expedition_duration_level,
		du_cost_txt
	]
	if du_prereq != "":
		du_detail += "\n" + du_prereq
	growth_node_detail_text["exp_duration"] = du_detail

	if growth_detail_richtext == null:
		return
	if growth_hovered_node_id != "" and growth_node_detail_text.has(growth_hovered_node_id):
		growth_detail_richtext.text = str(growth_node_detail_text[growth_hovered_node_id])


func _get_growth_locked_prereq_text(node_id: String) -> String:
	_ensure_growth_nodes_registered()
	var reqs: Array = growth_tree_node_prereqs.get(node_id, [])
	for req in reqs:
		var req_id := String(req)
		if req_id == "":
			continue
		if not _is_growth_node_unlocked(req_id):
			return "需先解锁%s。" % _get_growth_node_display_name(req_id)
	return ""


func _is_growth_node_unlocked(node_id: String) -> bool:
	_ensure_growth_nodes_registered()
	if not growth_nodes_by_id.has(node_id):
		return false
	var node: TechTreeNode = growth_nodes_by_id.get(node_id, null) as TechTreeNode
	return node != null and node.is_unlocked()


func _get_growth_node_display_name(node_id: String) -> String:
	_ensure_growth_nodes_registered()
	if not growth_nodes_by_id.has(node_id):
		return "前置节点"
	var node: TechTreeNode = growth_nodes_by_id.get(node_id, null) as TechTreeNode
	if node != null:
		var label := String(node.display_name)
		if label != "":
			return label
	return "前置节点"


func _is_growth_node_prereq_met(node_id: String) -> bool:
	return _get_growth_locked_prereq_text(node_id) == ""


func _growth_node_unlocked_table() -> bool:
	return _host.game_state.table_count >= GameState.MAX_TABLE_COUNT


func _growth_node_unlocked_auto_unlock() -> bool:
	return _host.game_state.auto_unlocked


func _growth_node_unlocked_auto_speed() -> bool:
	return _host.game_state.auto_speed_level >= GameState.MAX_AUTO_SPEED_LEVEL


func _growth_node_unlocked_expedition_unlock() -> bool:
	return _host.game_state.tech_expedition_portal_unlocked


func _growth_node_unlocked_expedition_delete() -> bool:
	return _host.game_state.tech_delete_expedition_unlocked


func _growth_node_unlocked_expedition_synth() -> bool:
	return _host.game_state.tech_synth_expedition_unlocked


func _growth_node_unlocked_dice_cap() -> bool:
	return _host.game_state.tech_dice_cap_level >= 2


func _growth_node_unlocked_exp_acquire_n() -> bool:
	return _host.game_state.get_acquire_n_upgrade_cost() < 0


func _growth_node_unlocked_exp_delete_n() -> bool:
	return _host.game_state.get_delete_n_upgrade_cost() < 0


func _growth_node_unlocked_exp_synth_n() -> bool:
	return _host.game_state.get_synth_n_upgrade_cost() < 0


func _growth_node_unlocked_exp_duration() -> bool:
	return _host.game_state.get_duration_upgrade_cost() < 0


func _growth_node_level_table() -> int:
	return _host.game_state.table_count


func _growth_node_max_table() -> int:
	return GameState.MAX_TABLE_COUNT


func _growth_node_level_auto_unlock() -> int:
	return 1 if _host.game_state.auto_unlocked else 0


func _growth_node_level_auto_speed() -> int:
	return _host.game_state.auto_speed_level


func _growth_node_max_auto_speed() -> int:
	return GameState.MAX_AUTO_SPEED_LEVEL


func _growth_node_level_expedition_unlock() -> int:
	return 1 if _host.game_state.tech_expedition_portal_unlocked else 0


func _growth_node_level_expedition_delete() -> int:
	return 1 if _host.game_state.tech_delete_expedition_unlocked else 0


func _growth_node_level_expedition_synth() -> int:
	return 1 if _host.game_state.tech_synth_expedition_unlocked else 0


func _growth_node_level_dice_cap() -> int:
	return _host.game_state.tech_dice_cap_level


func _growth_node_max_dice_cap() -> int:
	return 2


func _growth_node_level_exp_acquire_n() -> int:
	return _host.game_state.tech_expedition_acquire_n_level


func _growth_node_max_exp_acquire_n() -> int:
	return GameState.EXPEDITION_MAX_N - GameState.EXPEDITION_BASE_N


func _growth_node_level_exp_delete_n() -> int:
	return _host.game_state.tech_expedition_delete_n_level


func _growth_node_max_exp_delete_n() -> int:
	return GameState.EXPEDITION_MAX_N - GameState.EXPEDITION_BASE_N


func _growth_node_level_exp_synth_n() -> int:
	return _host.game_state.tech_expedition_synth_n_level


func _growth_node_max_exp_synth_n() -> int:
	return GameState.EXPEDITION_SYNTH_MAX_N - GameState.EXPEDITION_SYNTH_BASE_N


func _growth_node_level_exp_duration() -> int:
	return _host.game_state.tech_expedition_duration_level


func _growth_node_max_exp_duration() -> int:
	return GameState.EXPEDITION_MAX_DURATION_LEVEL


func _refresh_growth_node_button_progress_text() -> void:
	_ensure_growth_nodes_registered()
	for node_id in growth_node_order:
		var btn := _host.upgrade_buttons.get(node_id, null) as Button
		if btn == null:
			continue
		var node: TechTreeNode = growth_nodes_by_id.get(node_id, null) as TechTreeNode
		if node == null:
			continue
		var label := String(GROWTH_NODE_LABELS.get(node_id, node.display_name))
		var progress := node.get_level_progress_text()
		btn.text = "%s\n%s" % [label, progress]
		btn.tooltip_text = "%s %s" % [label, progress]


func _create_tech_tree_node(parent: Node, node_id: String, callback: Callable) -> Button:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.custom_minimum_size = Vector2(74, 56)
	panel.position = Vector2.ZERO
	panel.size = Vector2(74, 56)
	panel.add_theme_stylebox_override("panel", _GrowthTreeStyle.node_stylebox_compact())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(_on_growth_node_hover.bind(node_id))
	parent.add_child(panel)
	growth_node_panels[node_id] = panel
	var button := Button.new()
	button.clip_text = false
	button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	button.custom_minimum_size = Vector2(70, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", 10)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.pressed.connect(callback)
	button.mouse_entered.connect(_on_growth_node_hover.bind(node_id))
	button.tooltip_text = ""
	button.focus_mode = Control.FOCUS_NONE
	panel.add_child(button)
	return button


func _build_growth_tree_nodes() -> void:
	_host.upgrade_buttons = {}
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
	_host.call_deferred("_growth_deferred_update_canvas")
	_host.call_deferred("_growth_deferred_refresh_links")


func _create_growth_tree_row_layer(width_px: int) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(maxi(200, width_px), 74)
	row.size = row.custom_minimum_size
	return row


func _create_growth_tree_node_holder(node_id: String, slot_x: int, node_def: Dictionary) -> Control:
	var holder := Control.new()
	holder.position = Vector2(slot_x, 0)
	holder.custom_minimum_size = Vector2(74, 56)
	holder.size = holder.custom_minimum_size
	var callback_name := String(node_def.get("callback", ""))
	var callback := Callable()
	if callback_name != "":
		callback = Callable(_host, callback_name)
	var btn := _create_tech_tree_node(holder, node_id, callback)
	btn.custom_minimum_size = Vector2(70, 52)
	_host.upgrade_buttons[node_id] = btn
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
	var slot_step := 82.0
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


func _growth_tree_node_defs() -> Array:
	_ensure_growth_nodes_registered()
	var defs: Array = []
	for node_id: String in growth_node_order:
		var node: TechTreeNode = growth_nodes_by_id.get(node_id, null) as TechTreeNode
		if node != null:
			defs.append(node.to_growth_def())
	return defs


func _ensure_growth_nodes_registered() -> void:
	if not growth_nodes_by_id.is_empty():
		return
	var nodes: Array = []
	nodes.append(TechTreeNode.new(
		"table",
		"基础成长",
		[],
		"_on_upgrade_table_pressed",
		"骰桌",
		Callable(self, "_growth_node_unlocked_table"),
		Callable(self, "_growth_node_level_table"),
		Callable(self, "_growth_node_max_table")
	))
	nodes.append(TechTreeNode.new(
		"auto_unlock",
		"基础成长",
		[],
		"_on_upgrade_auto_unlock_pressed",
		"自动投掷",
		Callable(self, "_growth_node_unlocked_auto_unlock"),
		Callable(self, "_growth_node_level_auto_unlock"),
		Callable()
	))
	nodes.append(TechTreeNode.new(
		"auto_speed",
		"基础成长",
		["auto_unlock"],
		"_on_upgrade_auto_speed_pressed",
		"自动间隔",
		Callable(self, "_growth_node_unlocked_auto_speed"),
		Callable(self, "_growth_node_level_auto_speed"),
		Callable(self, "_growth_node_max_auto_speed")
	))
	nodes.append(TechTreeNode.new(
		"expedition_unlock",
		"远征科技（货币1）",
		[],
		"_on_tech_expedition_unlock_pressed",
		"远征入口",
		Callable(self, "_growth_node_unlocked_expedition_unlock"),
		Callable(self, "_growth_node_level_expedition_unlock"),
		Callable()
	))
	nodes.append(TechTreeNode.new(
		"expedition_delete",
		"远征科技（货币1）",
		["expedition_unlock"],
		"_on_tech_delete_expedition_pressed",
		"删骰远征",
		Callable(self, "_growth_node_unlocked_expedition_delete"),
		Callable(self, "_growth_node_level_expedition_delete"),
		Callable()
	))
	nodes.append(TechTreeNode.new(
		"expedition_synth",
		"远征科技（货币1）",
		["expedition_delete"],
		"_on_tech_synth_expedition_pressed",
		"合成远征",
		Callable(self, "_growth_node_unlocked_expedition_synth"),
		Callable(self, "_growth_node_level_expedition_synth"),
		Callable()
	))
	nodes.append(TechTreeNode.new(
		"dice_cap_tech",
		"远征科技（货币1）",
		["expedition_unlock"],
		"_on_tech_dice_cap_pressed",
		"骰子上限",
		Callable(self, "_growth_node_unlocked_dice_cap"),
		Callable(self, "_growth_node_level_dice_cap"),
		Callable(self, "_growth_node_max_dice_cap")
	))
	nodes.append(TechTreeNode.new(
		"exp_acquire_n",
		"远征科技（货币1）",
		["expedition_unlock"],
		"_on_tech_acquire_n_pressed",
		"得骰候选",
		Callable(self, "_growth_node_unlocked_exp_acquire_n"),
		Callable(self, "_growth_node_level_exp_acquire_n"),
		Callable(self, "_growth_node_max_exp_acquire_n")
	))
	nodes.append(TechTreeNode.new(
		"exp_delete_n",
		"远征科技（货币1）",
		["expedition_delete"],
		"_on_tech_delete_n_pressed",
		"删骰候选",
		Callable(self, "_growth_node_unlocked_exp_delete_n"),
		Callable(self, "_growth_node_level_exp_delete_n"),
		Callable(self, "_growth_node_max_exp_delete_n")
	))
	nodes.append(TechTreeNode.new(
		"exp_synth_n",
		"远征科技（货币1）",
		["expedition_synth"],
		"_on_tech_synth_n_pressed",
		"合成候选",
		Callable(self, "_growth_node_unlocked_exp_synth_n"),
		Callable(self, "_growth_node_level_exp_synth_n"),
		Callable(self, "_growth_node_max_exp_synth_n")
	))
	nodes.append(TechTreeNode.new(
		"exp_duration",
		"远征科技（货币1）",
		["expedition_unlock"],
		"_on_tech_exp_duration_pressed",
		"远征耗时",
		Callable(self, "_growth_node_unlocked_exp_duration"),
		Callable(self, "_growth_node_level_exp_duration"),
		Callable(self, "_growth_node_max_exp_duration")
	))
	for n in nodes:
		if n is TechTreeNode:
			var node: TechTreeNode = n as TechTreeNode
			growth_nodes_by_id[node.id] = node
			growth_node_order.append(node.id)


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
