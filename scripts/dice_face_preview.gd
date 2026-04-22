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
const DIE_STYLE_CORNER_RADIUS := 6
const DIE_STYLE_BORDER_WIDTH := 2
const DIE_STYLE_CONTENT_MARGIN := 3
const DIE_BG_COLOR := Color(0.06, 0.07, 0.09, 1.0)


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
	var display_faces: Array[int] = []
	for i in range(6):
		display_faces.append(clampi(int(die.faces[i]), 1, 6))
	display_faces.sort()
	for i in range(6):
		var v := display_faces[i]
		var wrap := PanelContainer.new()
		wrap.custom_minimum_size = cell
		var visual := die_visual(v, rarity, 0.55)
		wrap.add_theme_stylebox_override("panel", visual["style"] as StyleBoxFlat)
		var tr := TextureRect.new()
		tr.texture = visual["texture"] as Texture2D
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(tr)
		add_child(wrap)


static func rarity_border_color(rarity: int) -> Color:
	match clampi(rarity, 0, 2):
		1:
			return Color(0.45, 0.78, 0.92, 0.95)
		2:
			return Color(0.95, 0.72, 0.28, 0.98)
		_:
			return Color(0.28, 0.31, 0.36, 0.75)


static func die_visual(face_value: int, rarity: int, bg_alpha: float = 0.55) -> Dictionary:
	var v := clampi(face_value, 1, 6)
	return {
		"texture": FACE_TEXTURES.get(v, FACE_TEXTURES[1]),
		"style": rarity_cell_stylebox(rarity, bg_alpha)
	}


static func rarity_cell_stylebox(rarity: int, bg_alpha: float = 0.55) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(DIE_BG_COLOR.r, DIE_BG_COLOR.g, DIE_BG_COLOR.b, clampf(bg_alpha, 0.0, 1.0))
	sb.set_corner_radius_all(DIE_STYLE_CORNER_RADIUS)
	sb.set_border_width_all(DIE_STYLE_BORDER_WIDTH)
	sb.border_color = rarity_border_color(rarity)
	sb.set_content_margin_all(DIE_STYLE_CONTENT_MARGIN)
	return sb
