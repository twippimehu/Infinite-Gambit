extends Control

@onready var panel := $Panel
@onready var container := $Panel/VBoxContainer
@onready var lbl_title: Label = $Panel/VBoxContainer/Label

var buttons: Array[Button] = []
var choices: Array = []   # dictionaries from Game.generate_reward_choices()

func _ready() -> void:
	# collect button nodes (skip the title label)
	for child in container.get_children():
		if child is Button:
			buttons.append(child)

	_play_intro_animation()
	_setup_buttons_with_choices()
	_connect_button_animations()

	# title text
	var enemy_cfg = Game.get_current_enemy_cfg()
	var difficulty = enemy_cfg.get("stage", 1)
	lbl_title.text = "Victory! (Stage %d)" % difficulty


# ---------------------------------------------------------
# INTRO PANEL ANIMATION
# ---------------------------------------------------------
func _play_intro_animation() -> void:
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)

	var t := create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


# ---------------------------------------------------------
# SETUP BUTTONS FROM Game.generate_reward_choices()
# ---------------------------------------------------------
func _setup_buttons_with_choices() -> void:
	choices = Game.generate_reward_choices()

	for i in range(buttons.size()):
		var btn := buttons[i]

		if i < choices.size():
			var ch: Dictionary = choices[i]
			btn.disabled = false
			btn.visible = true	
			btn.text = String(ch.get("name", "Unknown reward"))
			btn.tooltip_text = String(ch.get("desc", ""))
			# connect to selection by index
			btn.pressed.connect(Callable(self, "_on_reward_selected").bind(i))
		else:
			# hide extra buttons if fewer than available
			btn.disabled = true
			btn.visible = false


# ---------------------------------------------------------
# BUTTON HOVER + PRESS ANIMATIONS
# ---------------------------------------------------------
func _connect_button_animations() -> void:
	for b in buttons:
		b.mouse_entered.connect(Callable(self, "_on_button_hover").bind(b))
		b.mouse_exited.connect(Callable(self, "_on_button_exit").bind(b))
		b.pressed.connect(Callable(self, "_on_button_pressed").bind(b))


func _on_button_hover(btn: Button) -> void:
	var t := create_tween()
	t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.12)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


func _on_button_exit(btn: Button) -> void:
	var t := create_tween()
	t.tween_property(btn, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


func _on_button_pressed(btn: Button) -> void:
	var t := create_tween()
	t.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.08)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2.ONE, 0.10)\
		.set_trans(Tween.TRANS_BACK)


# ---------------------------------------------------------
# REWARD SELECTION (now uses choices[index])
# ---------------------------------------------------------
func _on_reward_selected(idx: int) -> void:
	if idx < 0 or idx >= choices.size():
		return

	var choice: Dictionary = choices[idx]
	print("Chose reward:", choice)

	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(Callable(Game, "on_reward_chosen").bind(choice))
