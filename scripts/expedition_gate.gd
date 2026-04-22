extends RefCounted


static func active_expedition_table_index(timers: Array) -> int:
	for i in range(timers.size()):
		var tm: Timer = timers[i] as Timer
		if tm != null and tm.time_left > 0.0:
			return i
	return -1


static func is_flow_locked(waiting_result_choice: bool, timers: Array) -> bool:
	return waiting_result_choice or active_expedition_table_index(timers) >= 0
