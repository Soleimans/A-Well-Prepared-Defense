extends Control

# Signal to notify when a building is selected
signal building_selected(building_type)
# Signal for when menu is closed
signal menu_closed

# Building costs
const BUILDING_COSTS = {
	"civilian_factory": 10800,
	"military_factory": 7200,
	"fort": 500
}

func _ready():
	# Connect building containers based on your actual node structure
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
	
	# Connect close button
	$CloseButton.pressed.connect(_on_close_button_pressed)
	
	# Set up cost labels
	$Panel/GridContainer/VBoxContainer/HBoxContainer/Label2.text = "10800"
	$Panel/GridContainer/VBoxContainer/HBoxContainer2/Label2.text = "7200"
	$Panel/GridContainer/VBoxContainer/HBoxContainer3/Label2.text = "500/level"
	
	# Connect to war count signal
	var war_count = get_node("/root/Main/UILayer/WarCount")
	if war_count:
		war_count.turn_changed.connect(_on_war_state_changed)
	
	# Initialize unlock label
	update_unlock_label()

func _on_close_button_pressed():
	hide()
	building_selected.emit("")  # Clear building selection
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

func _on_war_state_changed(_turn: int):
	update_unlock_label()

func update_unlock_label():
	var cost_label = $Panel/GridContainer/VBoxContainer/HBoxContainer4/Label2
	var building_manager = get_node("/root/Main/Grid/BuildingManager")
	var territory_manager = get_node("/root/Main/Grid/TerritoryManager")
	
	if !building_manager:
		print("ERROR: BuildingManager not found!")
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

# Function to refresh the UI when the menu is shown
func _on_visibility_changed():
	if visible:
		update_unlock_label()
