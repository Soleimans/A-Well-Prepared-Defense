extends Button

@onready var army_window = $"../../army_menu"

func _ready():
	pressed.connect(_on_button_pressed)
	army_window.hide()

func _on_button_pressed():
	army_window.show()
