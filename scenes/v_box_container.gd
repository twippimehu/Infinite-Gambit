extends VBoxContainer

func _ready():
	connect("mouse_entered", _on_hover)
	connect("mouse_exited", _on_leave)

func _on_hover():
	modulate = Color(1.1, 1.1, 0.9) # slight brighten

func _on_leave():
	modulate = Color(1, 1, 1)
