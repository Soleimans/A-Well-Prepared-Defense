extends Panel

func _ready():
	# Set size to 1/5 of screen width
	var screen_size = get_viewport_rect().size
	var top_bar_height = 32  # Adjust this value to match your top bar height
	
	# Set size (keep width at 20% but adjust total height to account for top bar)
	custom_minimum_size = Vector2(screen_size.x * 0.2, screen_size.y - top_bar_height)
	
	# Position on left side, but start below top bar
	position = Vector2(0, top_bar_height)
	
	# Set anchors to stretch vertically
	set("anchor_right", 0.2)
	set("anchor_bottom", 1.0)
