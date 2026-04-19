class_name DiceFaceStats
extends RefCounted

var counts: Array[int] = []


func _init() -> void:
	reset()


func reset() -> void:
	counts = [0, 0, 0, 0, 0, 0]


func record_all_faces(values: Array) -> void:
	for v in values:
		_bump(int(v))


func record_rerolled_only(holds: Array, next_values: Array) -> void:
	for i in range(next_values.size()):
		if i >= holds.size() or not bool(holds[i]):
			_bump(int(next_values[i]))


func total_rolled_faces() -> int:
	var s := 0
	for c in counts:
		s += int(c)
	return s


func format_scoreboard_line() -> String:
	var t := total_rolled_faces()
	if t == 0:
		return "掷骰统计(逻辑): 尚无样本（不含投掷动画里的假随机）"
	var parts: PackedStringArray = []
	for f in range(1, 7):
		var c := int(counts[f - 1])
		var pct := 100.0 * float(c) / float(t)
		parts.append("%d:%d(%.1f%%)" % [f, c, pct])
	return "掷骰统计(逻辑) n=%d  %s" % [t, " ".join(parts)]


func format_dialog_text() -> String:
	return "%s\n\n说明：仅统计逻辑层随机结果（每次实际重掷的骰子）；不包含投掷动画中的假随机。" % format_scoreboard_line()


func _bump(face: int) -> void:
	var f := clampi(face, DiceLogic.FACE_MIN, DiceLogic.FACE_MAX)
	counts[f - 1] += 1
