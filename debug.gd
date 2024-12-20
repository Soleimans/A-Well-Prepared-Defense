extends Node

@onready var panel = $Panel
@onready var unit_manager = get_node("/root/Main/Grid/UnitManager")

func _ready():
	panel.hide()
	$Panel/GridContainer/VBoxContainer/Button.pressed.connect(_on_enemy_button_pressed)

func _input(event):
	if event.is_action_pressed("toggle_debug"):
		panel.visible = !panel.visible

func _on_enemy_button_pressed():
	unit_manager.selected_unit_type = "infantry"
	unit_manager.placing_enemy = true
