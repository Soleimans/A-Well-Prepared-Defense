extends Node2D

func _ready():
	$Sprite2D/Label.text = "Military Factory"
	# Always set label to white regardless of building ownership
	$Sprite2D/Label.add_theme_color_override("font_color", Color.WHITE)
