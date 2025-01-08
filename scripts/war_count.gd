extends Label

signal turn_changed(current_turn)

const WAR_START_TURN = 30

func _ready():
	text = "War starts in: " + str(WAR_START_TURN)
	
	var turn_count = get_node("/root/Main/UILayer/TurnCount")
	if turn_count:
		turn_count.connect("turn_changed", _on_turn_count_changed)
	else:
		print("ERROR: TurnCount not found!")

func _on_turn_count_changed(current_turn: int):
	if current_turn >= WAR_START_TURN:
		text = "WAR HAS BEGUN!"
		emit_signal("turn_changed", current_turn)
		
		var grid = get_node("/root/Main/Grid")
		if grid:
			var unit_manager = grid.get_node("UnitManager")
			if unit_manager and unit_manager.selection_handler:
				unit_manager.selection_handler.update_unit_highlights()
	else:
		text = "War starts in: " + str(WAR_START_TURN - current_turn)
