class_name DiceFacePreview
extends HBoxContainer

const _DieT := preload("res://scripts/die_definition.gd")

const FACE_TEXTURES := {
	1: preload("res://assets/dice/die_1.svg"),
	2: preload("res://assets/dice/die_2.svg"),
	3: preload("res://assets/dice/die_3.svg"),
	4: preload("res://assets/dice/die_4.svg"),
	5: preload("res://assets/dice/die_5.svg"),
	6: preload("res://assets/dice/die_6.svg")
}


func _ready() -> void:
	add_theme_constant_override("separation", 4)


func apply_die(d: Variant) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	if not (d is _DieT):
		var ph := Label.new()
		ph.text = "—"
		add_child(ph)
		return
	var die := d as _DieT
	var rarity := clampi(int(die.rarity), 0, 2)
	var cell := Vector2(40, 40)
	for i in range(6):
		var v := clampi(int(die.faces[i]), 1, 6)
		var wrap := PanelContainer.new()
		wrap.custom_minimum_size = cell
		wrap.add_theme_stylebox_override("panel", _rarity_cell_stylebox(rarity))
		var tr := TextureRect.new()
		tr.texture = FACE_TEXTURES.get(v, FACE_TEXTURES[1])
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(tr)
		add_child(wrap)


static func _rarity_cell_stylebox(rarity: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.55)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	match rarity:
		1:
			sb.border_color = Color(0.45, 0.78, 0.92, 0.95)
		2:
			sb.border_color = Color(0.95, 0.72, 0.28, 0.98)
		_:
			sb.border_color = Color(0.28, 0.31, 0.36, 0.75)
	sb.set_content_margin_all(3)
	return sb
