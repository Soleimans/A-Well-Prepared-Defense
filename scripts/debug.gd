extends Node

@onready var panel = $Panel
@onready var unit_manager = get_node("/root/Main/Grid/UnitManager")
@onready var building_manager = get_node("/root/Main/Grid/BuildingManager")

func _ready():
	panel.hide()
	# Connect all enemy unit buttons
	$Panel/GridContainer/VBoxContainer/Button.pressed.connect(_on_enemy_infantry_pressed)
	$Panel/GridContainer/VBoxContainer/Button2.pressed.connect(_on_enemy_garrison_pressed)
	$Panel/GridContainer/VBoxContainer/Button3.pressed.connect(_on_enemy_armoured_pressed)
	
	# Connect enemy building buttons
	$Panel/GridContainer/VBoxContainer/Button4.pressed.connect(_on_enemy_civilian_factory_pressed)
	$Panel/GridContainer/VBoxContainer/Button5.pressed.connect(_on_enemy_military_factory_pressed)
	$Panel/GridContainer/VBoxContainer/Button6.pressed.connect(_on_enemy_fort_pressed)
	$Panel/GridContainer/VBoxContainer/Button7.pressed.connect(_on_enemy_next_column_pressed)
	
	# Connect the visibility changed signal
	panel.visibility_changed.connect(_on_panel_visibility_changed)

func _input(event):
	if event.is_action_pressed("toggle_debug"):
		panel.visible = !panel.visible

# Existing unit placement functions
func _on_enemy_infantry_pressed():
	unit_manager.selected_unit_type = "infantry"
	unit_manager.placing_enemy = true

func _on_enemy_garrison_pressed():
	unit_manager.selected_unit_type = "garrison"
	unit_manager.placing_enemy = true

func _on_enemy_armoured_pressed():
	unit_manager.selected_unit_type = "armoured"
	unit_manager.placing_enemy = true

# New enemy building placement functions
func _on_enemy_civilian_factory_pressed():
	building_manager.selected_building_type = "civilian_factory"
	building_manager.placing_enemy = true

func _on_enemy_military_factory_pressed():
	building_manager.selected_building_type = "military_factory"
	building_manager.placing_enemy = true

func _on_enemy_fort_pressed():
	building_manager.selected_building_type = "fort"
	building_manager.placing_enemy = true

func _on_enemy_next_column_pressed():
	building_manager.unlock_next_enemy_column()

func _on_panel_visibility_changed():
	if not panel.visible:
		# Reset both unit and building manager states when panel is hidden
		unit_manager.selected_unit_type = ""
		unit_manager.placing_enemy = false
		building_manager.selected_building_type = ""
		building_manager.placing_enemy = false
