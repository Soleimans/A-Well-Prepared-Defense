extends Control

func _ready():
	# Add a close button if you want
	$CloseButton.pressed.connect(_on_close_button_pressed)

func _on_close_button_pressed():
	hide()

func _on_building_selected(building_type):
	# Handle building selection
	print("Selected: ", building_type)
	hide()
