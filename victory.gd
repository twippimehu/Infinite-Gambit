extends Control

@onready var lbl_title: Label      = $Panel/VBoxContainer/Label_Title
@onready var lbl_stats: Label      = $Panel/VBoxContainer/Label_Stats
@onready var lbl_upgrades: Label   = $Panel/VBoxContainer/Label_Upgrades
@onready var btn_new_run: Button   = $Panel/VBoxContainer/HBoxContainer/Btn_NewRun
@onready var btn_menu: Button      = $Panel/VBoxContainer/HBoxContainer/Btn_Menu




func _ready() -> void:
	# Title
	lbl_title.text = "CLASSIC MODE CLEARED!"

	# Basic run stats from Game singleton
	var stage := Game.stage
	var wins := Game.wins
	var gold := Game.gold
	var last_turns := int(Game.last_battle_result.get("turns", 0))

	lbl_stats.text = "Stage reached: %d\nBattles won: %d\nLast battle turns: %d\nFinal gold: %d" \
		% [stage, wins, last_turns, gold]

	# Upgrades summary
	if Game.upgrades.is_empty():
		lbl_upgrades.text = "Upgrades: None"
	else:
		var lines: Array[String] = []
		lines.append("Upgrades:")
		for id in Game.upgrades:
			lines.append(" • " + Game.get_upgrade_name(id))
		lbl_upgrades.text = "\n".join(lines)

	# Hook up buttons
	btn_new_run.pressed.connect(_on_new_run_pressed)
	btn_menu.pressed.connect(_on_menu_pressed)


func _on_new_run_pressed() -> void:
	# Start a fresh classic run
	Game.start_new_run()


func _on_menu_pressed() -> void:
	# Go back to main menu; keep stats in memory if you want future screens
	Game.run_active = false
	Game._change_scene(Game.SCN_MENU)
