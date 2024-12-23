extends Button

@onready var politics_window = $"../../politics_menu"

func _ready():
	pressed.connect(_on_button_pressed)
	politics_window.hide()

func _on_button_pressed():
	politics_window.show()
