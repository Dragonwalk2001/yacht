extends Node2D

var score1: int = 0
var score2: int = 0

@onready var score_label: Label = $ScoreLabel

func score(player: int) -> void:
	if player == 1:
		score1 += 1
	else:
		score2 += 1
	score_label.text = "%d  :  %d" % [score1, score2]
