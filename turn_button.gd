extends Button

@onready var label = %Label  # Path to Build label
var value = 1000  # Starting value

func _ready():
	pressed.connect(_on_button_pressed)
	# Initialize the label with starting value
	label.text = "Build " + str(value)

func _on_button_pressed():
	print("Turn ended!")
	value += 100
	label.text = "Build " + str(value)
