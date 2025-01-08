extends Panel

func _ready():
	var screen_size = get_viewport_rect().size
	var top_bar_height = 32  
	
	custom_minimum_size = Vector2(screen_size.x * 0.13, screen_size.y - top_bar_height)
	
	position = Vector2(0, top_bar_height)
	
	set("anchor_right", 0.2)
	set("anchor_bottom", 1.0)
