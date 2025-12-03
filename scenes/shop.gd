extends Control

@onready var panel := $Panel
@onready var container := $Panel/VBoxContainer
@onready var lbl_title: Label = $Panel/VBoxContainer/Label
@onready var btn_skip: Button = $Panel/VBoxContainer/BtnSkip
@onready var gold_label: Label = $Panel/VBoxContainer/GoldLabel
@onready var btn_reroll: Button = $BtnReroll


var buttons: Array[Button] = []   # only item buttons, not skip
var choices: Array = []           # dictionaries from Game.generate_reward_choices()

func _update_gold_label() -> void:
	if gold_label:
		gold_label.text = "Gold: %d" % Game.gold

func _ready() -> void:
	# collect item buttons (all buttons except BtnSkip)
	for child in container.get_children():
		if child is Button and child != btn_skip:
			buttons.append(child)

	# connect buy callback ONCE
	for i in range(buttons.size()):
		buttons[i].pressed.connect(Callable(self, "_on_buy_pressed").bind(i))

	_update_gold_label()

	lbl_title.text = "Shop"

	_play_intro_animation()
	_setup_buttons_with_choices()
	_connect_button_animations()

	btn_skip.pressed.connect(_on_skip_pressed)
	btn_reroll.pressed.connect(_on_reroll_pressed)



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
	choices = Game.generate_shop_choices()

	for i in range(buttons.size()):
		var btn = buttons[i]

		if i < choices.size():
			var ch: Dictionary = choices[i]
			btn.disabled = false
			btn.visible = true

			# name & price
			var name := String(ch.get("name", ""))
			var price := Game.get_shop_price(ch)

			btn.text = "%s (%d gold)" % [name, price]
			btn.tooltip_text = String(ch.get("desc", ""))

			# IMPORTANT — THIS IS WHAT MAKES THE BUTTONS WORK
			btn.pressed.connect(Callable(self, "_on_buy_pressed").bind(i))
		else:
			btn.disabled = true
			btn.visible = false



# ---------------------------------------------------------
# BUTTON HOVER + PRESS ANIMATIONS
# ---------------------------------------------------------
func _connect_button_animations() -> void:
	for b in buttons:
		b.mouse_entered.connect(Callable(self, "_on_button_hover").bind(b))
		b.mouse_exited.connect(Callable(self, "_on_button_exit").bind(b))
		b.pressed.connect(Callable(self, "_on_button_pressed").bind(b), CONNECT_DEFERRED)


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

func _on_reroll_pressed() -> void:
	var cost := 2
	if not Game.try_spend_gold(cost):
		print("Not enough gold for reroll.")
		return

	_update_gold_label()

	# generate new shop items
	choices = Game.generate_shop_choices()
	_setup_buttons_with_choices()
	print("Rerolled shop.")


	# generate new shop items
	choices = Game.generate_shop_choices()
	_setup_buttons_with_choices()
	print("Rerolled shop.")


# ---------------------------------------------------------
# BUY / SKIP
# ---------------------------------------------------------
func _on_buy_pressed(idx: int) -> void:
	if idx < 0 or idx >= choices.size():
		return

	var choice: Dictionary = choices[idx]
	var price: int = Game.get_shop_price(choice)
	if not Game.try_spend_gold(price):
		print("Not enough gold.")
		return

	Game.apply_shop_purchase(choice)
	_update_gold_label()

	print("Bought:", choice.get("id", "?"), "for", price, "gold. Now have", Game.gold)

	# disable so player can’t buy twice
	buttons[idx].disabled = true




func _on_skip_pressed() -> void:
	Game.proceed_to_draft()
