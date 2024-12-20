extends Node

@onready var panel = $"."

func _ready():
	# Hide the debug menu when the game starts
	panel.hide()
	
	# Set up the panel position and size
	setup_panel_layout()

func setup_panel_layout():
	# Get the viewport size
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Set panel properties
	panel.anchor_left = 1.0  # Anchor to right side
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	
	# Set the panel size (width of 200 pixels)
	panel.position.x = -200  # Negative because we're anchored to the right
	panel.position.y = 0
	panel.size.x = 200
	panel.size.y = viewport_size.y
	
	# Optional: Add some padding/margin
	panel.add_theme_constant_override("margin_right", 10)
	panel.add_theme_constant_override("margin_left", 10)
	panel.add_theme_constant_override("margin_top", 10)
	panel.add_theme_constant_override("margin_bottom", 10)

func _input(event):
	if event.is_action_pressed("toggle_debug"):
		panel.visible = !panel.visible
