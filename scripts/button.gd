extends Button

@onready var build_window = $"../../build_menu"
@onready var close_button = build_window.get_node("CloseButton")

func _ready():
	pressed.connect(_on_button_pressed)
	build_window.hide()
	
func _process(_delta):
	if build_window.visible:
		# Get the global position of the open button
		var global_pos = global_position
		# Convert global position to build_window's local position
		var local_pos = build_window.get_global_transform().affine_inverse() * global_pos
		# Update close button position
		close_button.position = local_pos

func _on_button_pressed():
	build_window.show()
