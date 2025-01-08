extends Node2D

var level = 1
@onready var label = $Sprite2D/Label

func _ready():
	if label:
		label.hide()
	
	var parent = get_parent()
	if parent and parent.scene_file_path and parent.scene_file_path.ends_with("fort.tscn"):
		pass
	else:
		if label:
			level = max(1, level)
			update_label()
			label.show()

func set_level(new_level):
	level = max(1, new_level)  
	update_label()

func update_label():
	if label:
		label.text = str(level)
		label.add_theme_color_override("font_color", Color.WHITE)

func force_update_level(new_level):
	level = max(1, new_level)  
	update_label()
