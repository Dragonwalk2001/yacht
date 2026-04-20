class_name DieDefinition
extends RefCounted

var faces: PackedInt32Array
var rarity: int = 0
var buff_key: String = ""


func _init(p_faces: PackedInt32Array = PackedInt32Array()) -> void:
	if p_faces.size() == 6:
		faces = p_faces
	else:
		faces = PackedInt32Array([1, 2, 3, 4, 5, 6])
	_clamp_faces()


func _clamp_faces() -> void:
	for i in range(faces.size()):
		faces[i] = clampi(int(faces[i]), 1, 6)


func roll_value() -> int:
	var idx := randi_range(0, 5)
	return clampi(int(faces[idx]), 1, 6)


func average_face() -> float:
	var s := 0.0
	for i in range(6):
		s += float(faces[i])
	return s / 6.0


func summary_label() -> String:
	return "均%.1f·稀%d" % [average_face(), rarity]


static func create_standard() -> RefCounted:
	return new(PackedInt32Array([1, 2, 3, 4, 5, 6]))


static func create_random_biased() -> RefCounted:
	var arr: Array[int] = []
	for _i in range(6):
		if randf() < 0.38:
			arr.append(randi_range(4, 6))
		else:
			arr.append(randi_range(1, 6))
	var p := PackedInt32Array()
	for v in arr:
		p.append(v)
	var d: RefCounted = new(p)
	d.rarity = randi_range(0, 2)
	return d


static func merge(a: RefCounted, b: RefCounted) -> RefCounted:
	var p := PackedInt32Array()
	for i in range(6):
		p.append(maxi(int(a.faces[i]), int(b.faces[i])))
	var out: RefCounted = new(p)
	out.rarity = maxi(a.rarity, b.rarity)
	if a.buff_key != "" and b.buff_key != "":
		out.buff_key = a.buff_key + "+" + b.buff_key
	elif b.buff_key != "":
		out.buff_key = b.buff_key
	else:
		out.buff_key = a.buff_key
	return out


func duplicate_die() -> RefCounted:
	var p := PackedInt32Array()
	for i in range(6):
		p.append(int(faces[i]))
	var out: RefCounted = new(p)
	out.rarity = rarity
	out.buff_key = buff_key
	return out


func to_dict() -> Dictionary:
	var fa: Array = []
	for i in range(6):
		fa.append(int(faces[i]))
	return {"faces": fa, "rarity": rarity, "buff": buff_key}


static func from_dict(d: Dictionary) -> RefCounted:
	var raw: Variant = d.get("faces", [])
	var p := PackedInt32Array()
	if raw is Array:
		for v in raw:
			p.append(clampi(int(v), 1, 6))
	while p.size() < 6:
		p.append(1)
	if p.size() > 6:
		var trim := PackedInt32Array()
		for i in range(6):
			trim.append(p[i])
		p = trim
	var out: RefCounted = new(p)
	out.rarity = maxi(0, int(d.get("rarity", 0)))
	out.buff_key = String(d.get("buff", ""))
	return out
