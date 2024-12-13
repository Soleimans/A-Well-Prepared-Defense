extends Button

@onready var build_window = $"../../build_menu"

func _ready():
	pressed.connect(_on_button_pressed)
	build_window.hide()

func _on_button_pressed():
	build_window.show()
