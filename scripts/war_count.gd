extends Label

const WAR_START_TURN = 100

func _ready():
	# Set initial text
	text = "War starts in: " + str(WAR_START_TURN)
	
	# Connect to turn count label
	var turn_count = get_node("/root/Main/UILayer/TurnCount")
	if turn_count:
		# Using the connect method instead of the signal keyword
		turn_count.connect("turn_changed", _on_turn_count_changed)
	else:
		print("ERROR: TurnCount not found!")

func _on_turn_count_changed(current_turn: int):
	var turns_until_war = WAR_START_TURN - current_turn
	if turns_until_war <= 0:
		text = "WAR HAS BEGUN!"
	else:
		text = "War starts in: " + str(turns_until_war)
