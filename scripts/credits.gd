extends Control

func _ready():
	visible = true
	
	var close_button = $Panel/GridContainer/HBoxContainer/CloseCredits
	var website_button = $Panel/GridContainer/HBoxContainer/GoWebsite
	
	close_button.pressed.connect(_on_close_credits_pressed)
	website_button.pressed.connect(_on_go_website_pressed)

func _on_close_credits_pressed():
	visible = false

func _on_go_website_pressed():
	OS.shell_open("https://game-icons.net/")
