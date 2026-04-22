extends RefCounted

const _TimeSpeedSettings := preload("res://scripts/time_speed_settings.gd")

var _host: Node

var dice_stats_dialog: AcceptDialog
var admin_grant_window: ConfirmationDialog
var admin_grant_input: LineEdit
var time_speed_window: Window
var time_speed_slider: HSlider
var time_speed_value_label: Label
var time_speed: int = 1


func _init(p_host: Node) -> void:
	_host = p_host


func init_dice_stats_dialog() -> void:
	dice_stats_dialog = AcceptDialog.new()
	dice_stats_dialog.title = "掷骰统计"
	dice_stats_dialog.ok_button_text = "关闭"
	dice_stats_dialog.dialog_autowrap = true
	dice_stats_dialog.min_size = Vector2i(440, 180)
	_host.add_child(dice_stats_dialog)


func init_admin_grant_window() -> void:
	admin_grant_window = ConfirmationDialog.new()
	admin_grant_window.title = "管理员手动加钱"
	admin_grant_window.ok_button_text = "发放"
	admin_grant_window.cancel_button_text = "取消"
	admin_grant_window.min_size = Vector2i(360, 140)
	admin_grant_window.dialog_hide_on_ok = true
	admin_grant_window.confirmed.connect(_on_admin_grant_confirmed)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	admin_grant_window.add_child(margin)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "输入要直接发放的货币1数量。"
	col.add_child(hint)
	admin_grant_input = LineEdit.new()
	admin_grant_input.placeholder_text = "例如 5000"
	admin_grant_input.max_length = 10
	admin_grant_input.text_submitted.connect(func(_text: String) -> void:
		if admin_grant_window.visible:
			_on_admin_grant_confirmed()
	)
	col.add_child(admin_grant_input)
	_host.add_child(admin_grant_window)


func init_time_speed_window() -> void:
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
	_host.add_child(time_speed_window)


func on_menu_id_pressed(id: int, game_state: GameState, status_label: Label) -> void:
	if id == 0:
		dice_stats_dialog.dialog_text = game_state.dice_face_stats.format_dialog_text()
		dice_stats_dialog.popup_centered()
	elif id == 1:
		time_speed_slider.set_value_no_signal(time_speed)
		time_speed_value_label.text = "当前倍速: %d×" % time_speed
		time_speed_window.popup_centered()
	elif id == 2:
		admin_grant_input.text = ""
		admin_grant_window.popup_centered()
		admin_grant_input.grab_focus()


func _on_time_speed_slider_changed(v: float) -> void:
	var m := _TimeSpeedSettings.clamp_mult(int(round(v)))
	time_speed_slider.set_value_no_signal(m)
	time_speed_value_label.text = "当前倍速: %d×" % m
	_TimeSpeedSettings.apply_engine_multiplier(m)
	if m == time_speed:
		return
	time_speed = m
	_host._save_game()


func _on_admin_grant_confirmed() -> void:
	var gs: GameState = _host.game_state
	var status_label: Label = _host.status_label
	var raw := admin_grant_input.text.strip_edges()
	if raw == "":
		status_label.text = "请输入发放金额。"
		admin_grant_window.popup_centered()
		admin_grant_input.grab_focus()
		return
	if not raw.is_valid_int():
		status_label.text = "金额需为整数。"
		admin_grant_window.popup_centered()
		admin_grant_input.grab_focus()
		return
	var amount := int(raw)
	var grant := gs.grant_coin_for_admin(amount)
	if not grant.get("ok", false):
		status_label.text = String(grant.get("message", "发放失败。"))
		admin_grant_window.popup_centered()
		admin_grant_input.grab_focus()
		return
	status_label.text = "管理员发放货币1：+%d" % int(grant.get("granted", amount))
	_host._save_game()
	_host._refresh_all()
