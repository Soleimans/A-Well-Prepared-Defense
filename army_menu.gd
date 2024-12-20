extends Control
# Signal to notify when a unit is selected
signal unit_selected(unit_type)
# Unit costs
const UNIT_COSTS = {
	"infantry": 1000,
	"armoured": 3000,
	"garrison": 500
}

func _ready():
	# Connect unit containers
	$Panel/GridContainer/VBoxContainer/HBoxContainer/Label.gui_input.connect(
		_on_infantry_input
	)
	$Panel/GridContainer/VBoxContainer/HBoxContainer2/Label.gui_input.connect(
		_on_armoured_input
	)
	$Panel/GridContainer/VBoxContainer/HBoxContainer3/Label.gui_input.connect(
		_on_garrison_input
	)
	
	# Connect close button
	$Button.pressed.connect(_on_close_button_pressed)
	
	# Set up cost labels
	$Panel/GridContainer/VBoxContainer/HBoxContainer/Label2.text = "1000"
	$Panel/GridContainer/VBoxContainer/HBoxContainer2/Label2.text = "3000"
	$Panel/GridContainer/VBoxContainer/HBoxContainer3/Label2.text = "500"

func _on_close_button_pressed():
	hide()

func _on_infantry_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Infantry division clicked - SENDING SIGNAL") # Debug print
		unit_selected.emit("infantry")
		# Removed hide() to keep menu open

func _on_armoured_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Armoured division clicked") # Debug print
		unit_selected.emit("armoured")
		# Removed hide() to keep menu open

func _on_garrison_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Garrison division clicked") # Debug print
		unit_selected.emit("garrison")
		# Removed hide() to keep menu open
