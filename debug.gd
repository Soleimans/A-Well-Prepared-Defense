extends Node

@onready var panel = $Panel
@onready var unit_manager = get_node("/root/Main/Grid/UnitManager")

func _ready():
	panel.hide()
	# Connect all enemy unit buttons
	$Panel/GridContainer/VBoxContainer/Button.pressed.connect(_on_enemy_infantry_pressed)
	$Panel/GridContainer/VBoxContainer/Button2.pressed.connect(_on_enemy_garrison_pressed)
	$Panel/GridContainer/VBoxContainer/Button3.pressed.connect(_on_enemy_armoured_pressed)
	# Connect the visibility changed signal
	panel.visibility_changed.connect(_on_panel_visibility_changed)

func _input(event):
	if event.is_action_pressed("toggle_debug"):
		panel.visible = !panel.visible

func _on_enemy_infantry_pressed():
	unit_manager.selected_unit_type = "infantry"
	unit_manager.placing_enemy = true

func _on_enemy_garrison_pressed():
	unit_manager.selected_unit_type = "garrison"
	unit_manager.placing_enemy = true

func _on_enemy_armoured_pressed():
	unit_manager.selected_unit_type = "armoured"
	unit_manager.placing_enemy = true

func _on_panel_visibility_changed():
	if not panel.visible:
		# Reset unit manager state when panel is hidden
		unit_manager.selected_unit_type = ""
		unit_manager.placing_enemy = false
