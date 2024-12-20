extends Control
# Signal to notify when a building is selected
signal building_selected(building_type)
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
	
	# Connect close button
	$CloseButton.pressed.connect(_on_close_button_pressed)
	
	# Set up cost labels
	$Panel/GridContainer/VBoxContainer/HBoxContainer/Label2.text = "10800"
	$Panel/GridContainer/VBoxContainer/HBoxContainer2/Label2.text = "7200"
	$Panel/GridContainer/VBoxContainer/HBoxContainer3/Label2.text = "500/level"

func _on_close_button_pressed():
	hide()

func _on_civilian_factory_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Civilian factory clicked - SENDING SIGNAL") # Debug print
		building_selected.emit("civilian_factory")
		# Removed hide() to keep menu open

func _on_military_factory_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Military factory clicked") # Debug print
		building_selected.emit("military_factory")
		# Removed hide() to keep menu open

func _on_fort_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Fort clicked") # Debug print
		building_selected.emit("fort")
		# Removed hide() to keep menu open
