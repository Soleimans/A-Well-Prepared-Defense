extends Control

@onready var minister_manager = get_node("/root/Main/Grid/MinisterManager")
@onready var first_minister_label = get_node("Panel/GridContainer/VBoxContainer/HBoxContainer/Label")
@onready var industry_minister_label = get_node("Panel/GridContainer/VBoxContainer/HBoxContainer2/Label")
@onready var military_minister_label = get_node("Panel/GridContainer/VBoxContainer/HBoxContainer3/Label")
@onready var fort_minister_label = get_node("Panel/GridContainer/VBoxContainer/HBoxContainer4/Label")

func _ready():
	$Button.pressed.connect(_on_close_button_pressed)
	
	if first_minister_label:
		first_minister_label.gui_input.connect(_on_minister_label_clicked.bind("Panel/GridContainer/VBoxContainer/HBoxContainer/Label"))
		first_minister_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
	if industry_minister_label:
		industry_minister_label.gui_input.connect(_on_minister_label_clicked.bind("Panel/GridContainer/VBoxContainer/HBoxContainer2/Label"))
		industry_minister_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
	if military_minister_label:
		military_minister_label.gui_input.connect(_on_minister_label_clicked.bind("Panel/GridContainer/VBoxContainer/HBoxContainer3/Label"))
		military_minister_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
	if fort_minister_label:
		fort_minister_label.gui_input.connect(_on_minister_label_clicked.bind("Panel/GridContainer/VBoxContainer/HBoxContainer4/Label"))
		fort_minister_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _on_minister_label_clicked(event: InputEvent, label_path: String):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var minister = minister_manager.get_minister_by_label_path(label_path)
		if minister:
			if minister.active:
				minister_manager.dismiss_minister(minister)
				update_minister_label(label_path, false)
			else:
				if minister_manager.hire_minister(minister):
					update_minister_label(label_path, true)

func update_minister_label(label_path: String, is_active: bool):
	var label = get_node(label_path)
	if label:
		var minister = minister_manager.get_minister_by_label_path(label_path)
		if minister:
			var status = "(Active)" if is_active else "(Available)"
			label.text = minister.name + " " + status

func _on_close_button_pressed():
	hide()

func _process(_delta):
	if visible:
		for minister in minister_manager.available_ministers + minister_manager.active_ministers:
			update_minister_label(minister.label_path, minister.active)
