extends Node2D

var level = 1
@onready var label = $Sprite2D/Label

func _ready():
	# Hide our label by default
	if label:
		label.hide()
	
	# Only show label if we're the first/base fort
	var parent = get_parent()
	if parent and parent.scene_file_path and parent.scene_file_path.ends_with("fort.tscn"):
		# We're a stacked fort, keep label hidden
		pass
	else:
		# We're the base fort, show our label
		if label:
			# Start at level 1 by default
			level = max(1, level)
			update_label()
			label.show()

func set_level(new_level):
	level = max(1, new_level)  # Ensure minimum level is 1
	update_label()

func update_label():
	if label:
		label.text = str(level)
		# Always set label to white regardless of building ownership
		label.add_theme_color_override("font_color", Color.WHITE)

# Add a method to force update the level from outside
func force_update_level(new_level):
	level = max(1, new_level)  # Ensure minimum level is 1
	update_label()
