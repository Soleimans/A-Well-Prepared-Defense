extends Control

@onready var panel = $Panel
@onready var label = $Panel/Label
@onready var restart_button = $Panel/GridContainer/HBoxContainer/Restart
@onready var exit_button = $Panel/GridContainer/HBoxContainer/Exit
@onready var territory_manager = get_node("/root/Main/Grid/TerritoryManager")

var game_ended = false

func _ready():
	hide()
	
	restart_button.pressed.connect(_on_restart_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	if event.is_action_pressed("ui_cancel"):  
		if visible:
			hide()
		else:
			check_game_state()
			show()

func check_game_state():
	if !territory_manager:
		label.text = "The battle is ongoing!"
		return
		
	var player_territory = 0
	var enemy_territory = 0
	var total_tiles = territory_manager.grid.grid_size.x * territory_manager.grid.grid_size.y
	
	# Count territories
	for x in range(territory_manager.grid.grid_size.x):
		for y in range(territory_manager.grid.grid_size.y):
			var pos = Vector2(x, y)
			var owner = territory_manager.get_territory_owner(pos)
			match owner:
				"player":
					player_territory += 1
				"enemy":
					enemy_territory += 1
	
	if player_territory == total_tiles:
		label.text = "You have WON!"
		game_ended = true
	elif enemy_territory == total_tiles:
		label.text = "You have LOST!"
		game_ended = true
	else:
		label.text = "The battle is ongoing!"
		game_ended = false

func _on_restart_pressed():
	get_tree().reload_current_scene()

func _on_exit_pressed():
	get_tree().quit()

func force_show():
	check_game_state()
	show()
