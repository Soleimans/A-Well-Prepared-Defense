extends Control



func _ready():
	# Connect close button
	$Button.pressed.connect(_on_close_button_pressed)
	
func _on_close_button_pressed():
	hide()
