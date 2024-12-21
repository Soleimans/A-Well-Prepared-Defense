extends Label

var current_turn: int = 0

func _ready():
	text = "Turn: " + str(current_turn)

func increment_turn():
	current_turn += 1
	text = "Turn: " + str(current_turn)
