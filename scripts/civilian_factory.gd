extends Node2D

func _ready():
	$Sprite2D/Label.text = "Civilian Factory"
	$Sprite2D/Label.add_theme_color_override("font_color", Color.WHITE)
