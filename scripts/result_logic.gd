class_name ResultLogic
extends RefCounted


static func build_ranked_results(game_state: GameState) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for player in game_state.players:
		var upper_subtotal := game_state.get_upper_subtotal(player)
		var upper_bonus := game_state.get_upper_bonus(player)
		rows.append({
			"name": player["name"],
			"upper_subtotal": upper_subtotal,
			"upper_bonus": upper_bonus,
			"total": game_state.get_total_score(player)
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["total"] > b["total"]
	)
	return rows


static func build_result_text(game_state: GameState) -> String:
	var ranked := build_ranked_results(game_state)
	if ranked.is_empty():
		return "没有可用结果。"

	var lines: Array[String] = ["最终排名："]
	for index in range(ranked.size()):
		var row := ranked[index]
		lines.append(
			"%d. %s  总分:%d  (上半区:%d + 奖励:%d)" % [
				index + 1, row["name"], row["total"], row["upper_subtotal"], row["upper_bonus"]
			]
		)

	var top_score: int = ranked[0]["total"]
	var winners: Array[String] = []
	for row in ranked:
		if row["total"] == top_score:
			winners.append(row["name"])
	if winners.size() == 1:
		lines.append("")
		lines.append("胜者：%s" % [winners[0]])
	else:
		lines.append("")
		lines.append("平局：%s" % [", ".join(winners)])

	return "\n".join(lines)
