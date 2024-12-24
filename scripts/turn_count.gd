extends Label

signal turn_changed(new_turn)

var current_turn: int = 0

func _ready():
	text = "Turn: " + str(current_turn)

func increment_turn():
	current_turn += 1
	text = "Turn: " + str(current_turn)
	emit_signal("turn_changed", current_turn)
	print("Turn incremented to: ", current_turn)
