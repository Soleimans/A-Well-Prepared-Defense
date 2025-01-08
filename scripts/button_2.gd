extends Button

@onready var army_window = $"../../army_menu"
@onready var close_button = army_window.get_node("Button")

func _ready():
	pressed.connect(_on_button_pressed)
	army_window.hide()
	
func _process(_delta):
	if army_window.visible:
		var global_pos = global_position
		var local_pos = army_window.get_global_transform().affine_inverse() * global_pos
		close_button.position = local_pos

func _on_button_pressed():
	army_window.show()
