extends Label

signal turn_changed(current_turn)  # Add this signal declaration at the top

const WAR_START_TURN = 10

func _ready():
	# Set initial text
	text = "War starts in: " + str(WAR_START_TURN)
	
	# Connect to turn count label
	var turn_count = get_node("/root/Main/UILayer/TurnCount")
	if turn_count:
		turn_count.connect("turn_changed", _on_turn_count_changed)
	else:
		print("ERROR: TurnCount not found!")

func _on_turn_count_changed(current_turn: int):
	var turns_until_war = WAR_START_TURN - current_turn
	if current_turn >= WAR_START_TURN:  # Changed condition
		text = "WAR HAS BEGUN!"
		emit_signal("turn_changed", current_turn)  # Emit our own signal
	else:
		text = "War starts in: " + str(turns_until_war)
