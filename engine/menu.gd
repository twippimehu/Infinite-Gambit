extends Control

@onready var btn_new_run: Button = $VBoxContainer/NewRun
@onready var btn_continue: Button = $VBoxContainer/BtnContinue
@onready var btn_options: Button = $VBoxContainer/BtnOptions
@onready var btn_quit: Button = $VBoxContainer/BtnQuit
@onready var title_label: Label = $TitleLabel

func _ready() -> void:
	btn_new_run.pressed.connect(_on_new_run)
	btn_continue.pressed.connect(_on_continue)
	btn_options.pressed.connect(_on_options)
	btn_quit.pressed.connect(_on_quit)

	# Disable continue if no run active
	btn_continue.disabled = not Game.run_active

	# Title animation
	var tween = create_tween()
	title_label.modulate = Color(1, 1, 1, 0)
	tween.tween_property(title_label, "modulate:a", 3.0, 3.0)

func _on_new_run() -> void:
	Game.start_new_run()

func _on_continue() -> void:
	if Game.run_active:
		Game.proceed_to_battle()

func _on_options() -> void:
	var dlg := AcceptDialog.new()
	dlg.dialog_text = "Options coming soon with sound, fullscreen and piece themes :D"
	add_child(dlg)
	dlg.popup_centered()

func _on_quit() -> void:
	get_tree().quit()
