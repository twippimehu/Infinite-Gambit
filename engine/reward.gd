extends Control

@onready var buttons := $Panel/VBoxContainer.get_children()
@onready var lbl_title: Label = $Panel/VBoxContainer/Label

func _ready():
	modulate.a = 0.0
	var t := get_tree().create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.5)

	for b in buttons:
		if b is Button:
			b.pressed.connect(func(): _on_reward_selected(b.text))

	var enemy_cfg = Game.get_current_enemy_cfg()
	var difficulty = enemy_cfg.get("stage", 1)

	lbl_title.text = "Victory! (Stage %d)" % difficulty


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

	var t := get_tree().create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(Callable(Game, "on_reward_chosen").bind(kind, data))
