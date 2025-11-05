extends Control

@onready var panel := $Panel
@onready var buttons := $Panel/VBoxContainer.get_children()
@onready var lbl_title: Label = $Panel/VBoxContainer/Label

func _ready():
	_play_intro_animation()
	_connect_button_animations()

	# existing code
	var enemy_cfg = Game.get_current_enemy_cfg()
	var difficulty = enemy_cfg.get("stage", 1)
	lbl_title.text = "Victory! (Stage %d)" % difficulty


# ---------------------------------------------------------
# INTRO PANEL ANIMATION
# ---------------------------------------------------------
func _play_intro_animation():
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)

	var t := create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


# ---------------------------------------------------------
# BUTTON HOVER + PRESS ANIMATIONS
# ---------------------------------------------------------
func _connect_button_animations():
	for b in buttons:
		if b is Button:
			b.mouse_entered.connect(_on_button_hover.bind(b))
			b.mouse_exited.connect(_on_button_exit.bind(b))
			b.pressed.connect(_on_button_pressed.bind(b))
			b.pressed.connect(func(): _on_reward_selected(b.text))  # keep your existing logic


func _on_button_hover(btn):
	var t := create_tween()
	t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.12)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

func _on_button_exit(btn):
	var t := create_tween()
	t.tween_property(btn, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

func _on_button_pressed(btn):
	var t := create_tween()
	t.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.08)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2.ONE, 0.10)\
		.set_trans(Tween.TRANS_BACK)


# ---------------------------------------------------------
# REWARD SELECTION (unchanged)
# ---------------------------------------------------------
func _on_reward_selected(choice: String) -> void:
	var kind := ""
	var data := {}

	match choice:
		"Extra queen after promotion":
			kind = "upgrade"
			data = {"tag": "extra_queen"}
		"Pawns move 3 on first turn":
			kind = "upgrade"
			data = {"tag": "pawn_boost"}
		"Gain 5 gold":
			kind = "gold"
			data = {"amount": 5}
		_:
			kind = "gold"
			data = {"amount": 3}

	print("Chose upgrade:", choice)

	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(Callable(Game, "on_reward_chosen").bind(kind, data))
