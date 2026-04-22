extends RefCounted


static func node_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.14, 1.0)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.32, 0.35, 0.4, 1.0)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	return sb


static func node_stylebox_compact() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.14, 1.0)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.3, 0.33, 0.38, 1.0)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(4)
	return sb
