extends Button

@onready var politics_window = $"../../politics_menu"
@onready var close_button = politics_window.get_node("Button")

func _ready():
	pressed.connect(_on_button_pressed)
	politics_window.hide()
	
func _process(_delta):
	if politics_window.visible:
		var global_pos = global_position
		var local_pos = politics_window.get_global_transform().affine_inverse() * global_pos
		close_button.position = local_pos

func _on_button_pressed():
	politics_window.show()
