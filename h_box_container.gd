extends HBoxContainer

func _ready():
	var style = StyleBoxFlat.new()
	style.set_bg_color(Color(0.2, 0.2, 0.2))  # Dark grey color
	set("theme_override_styles/panel", style)
