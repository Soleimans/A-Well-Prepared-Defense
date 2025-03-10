extends Control

signal building_selected(building_type)
signal menu_closed

const BUILDING_COSTS = {
	"civilian_factory": 12000,
	"military_factory": 8000,
	"fort": 500
}

func _ready():
	$Panel/GridContainer/VBoxContainer/HBoxContainer/Label.gui_input.connect(
		_on_civilian_factory_input
	)
	$Panel/GridContainer/VBoxContainer/HBoxContainer2/Label.gui_input.connect(
		_on_military_factory_input
	)
	$Panel/GridContainer/VBoxContainer/HBoxContainer3/Label.gui_input.connect(
		_on_fort_input
	)
	$Panel/GridContainer/VBoxContainer/HBoxContainer4/Label.gui_input.connect(
		_on_unlock_column_input
	)
	
	$CloseButton.pressed.connect(_on_close_button_pressed)
	
	$Panel/GridContainer/VBoxContainer/HBoxContainer/Label2.text = "12000"
	$Panel/GridContainer/VBoxContainer/HBoxContainer2/Label2.text = "8000"
	$Panel/GridContainer/VBoxContainer/HBoxContainer3/Label2.text = "500/level"
	
	var war_count = get_node("/root/Main/UILayer/WarCount")
	if war_count:
		war_count.connect("turn_changed", _on_war_state_changed)
	
	var turn_count = get_node("/root/Main/UILayer/TurnCount")
	if turn_count:
		turn_count.connect("turn_changed", _on_turn_changed)
	
	update_unlock_label()

func _on_close_button_pressed():
	if visible:  
		hide()
		building_selected.emit("") 
		menu_closed.emit()

func _on_civilian_factory_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Civilian factory clicked - SENDING SIGNAL")
		building_selected.emit("civilian_factory")

func _on_military_factory_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Military factory clicked")
		building_selected.emit("military_factory")

func _on_fort_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Fort clicked")
		building_selected.emit("fort")

func _on_unlock_column_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Unlock column clicked - SENDING SIGNAL")
		var building_manager = get_node("/root/Main/Grid/BuildingManager")
		if building_manager.can_unlock_next_column():
			building_selected.emit("unlock_column")

func _on_turn_changed(current_turn: int):
	# Update label immediately when turn 30 is reached
	if current_turn == 30:
		var cost_label = $Panel/GridContainer/VBoxContainer/HBoxContainer4/Label2
		cost_label.text = "All Unlocked"

func _on_war_state_changed(_turn: int):
	update_unlock_label()

func update_unlock_label():
	var cost_label = $Panel/GridContainer/VBoxContainer/HBoxContainer4/Label2
	var building_manager = get_node("/root/Main/Grid/BuildingManager")
	var territory_manager = get_node("/root/Main/Grid/TerritoryManager")
	var turn_count = get_node("/root/Main/UILayer/TurnCount")
	
	if !building_manager:
		print("ERROR: BuildingManager not found!")
		return
	
	# Check if gaem is at turn 30 or later
	if turn_count and turn_count.current_turn >= 30:
		cost_label.text = "All Unlocked"
		return
		
	# Check if war has started
	if territory_manager and territory_manager.war_active:
		cost_label.text = "All Unlocked"
		return
	
	if building_manager.buildable_columns.size() >= building_manager.max_unlockable_column + 1:
		cost_label.text = "All Unlocked"
	else:
		var next_column = building_manager.buildable_columns.size()
		# Check if the next column is already taken by enemy
		if next_column in building_manager.enemy_buildable_columns or next_column in building_manager.all_unlocked_columns:
			cost_label.text = "All Unlocked"
		else:
			var cost = building_manager.get_next_column_cost()
			cost_label.text = str(cost)

func _on_visibility_changed():
	if visible:
		update_unlock_label()
