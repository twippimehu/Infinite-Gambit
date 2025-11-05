extends Control

@onready var btn_new_run: Button = $NewRun

func _ready() -> void:
	if btn_new_run:
		btn_new_run.pressed.connect(_start_run)
	else:
		push_error("Button 'NewRun' not found in scene")

func _start_run() -> void:
	print("New Run clicked")
	Game.start_new_run()

	# Defer one frame to ensure we're inside the tree
	call_deferred("_go_to_draft")
	

func _go_to_draft() -> void:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		(loop as SceneTree).change_scene_to_file("res://scenes/draft.tscn")
	else:
		push_error("Main loop is not a SceneTree")
