extends Control

@onready var btn_new_run: Button       = $VBoxContainer/NewRun
@onready var btn_continue: Button      = $VBoxContainer/BtnContinue
@onready var btn_options: Button       = $VBoxContainer/BtnOptions
@onready var btn_quit: Button          = $VBoxContainer/BtnQuit
@onready var title_label: Label        = $TitleLabel

# --- NEW SOUND PLAYERS ---
@onready var sfx_hover: AudioStreamPlayer   = $SfxHover
@onready var sfx_click: AudioStreamPlayer   = $SfxClick
@onready var sfx_newrun: AudioStreamPlayer  = $SfxNewRun   # optional
# --------------------------

func _ready() -> void:
	# Connect button presses (already existed)
	btn_new_run.pressed.connect(_on_new_run)
	btn_continue.pressed.connect(_on_continue)
	btn_options.pressed.connect(_on_options)
	btn_quit.pressed.connect(_on_quit)

	# NEW: Connect HOVER events for sound
	var buttons = [
		btn_new_run,
		btn_continue,
		btn_options,
		btn_quit
	]

	for b in buttons:
		b.mouse_entered.connect(_on_button_hover)
		b.pressed.connect(_on_button_pressed)

	# Disable continue if no run active
	btn_continue.disabled = not Game.run_active

	# Title animation
	var tween = create_tween()
	title_label.modulate = Color(1, 1, 1, 0)
	tween.tween_property(title_label, "modulate:a", 3.0, 3.0)


# --- NEW: SOUND HANDLERS ------------------------------------------------------

func _on_button_hover() -> void:
	if sfx_hover:
		sfx_hover.play()

func _on_button_pressed() -> void:
	if sfx_click:
		sfx_click.play()

# ------------------------------------------------------------------------------


func _on_new_run() -> void:
	# Optional bigger thunk
	if sfx_newrun:
		sfx_newrun.play()

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
