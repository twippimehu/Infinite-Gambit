extends Node
class_name GameManager

signal run_started(stage:int)
signal battle_started(stage:int, enemy_cfg:Dictionary)
signal battle_ended(stage:int, won:bool, turns:int)
signal reward_granted(kind:String, data:Dictionary)

# ---------- Run state ----------
var run_active: bool = false
var seed: int = 0
var rng: RandomNumberGenerator
var stage: int = 0               # starts at 1 on first battle
var wins: int = 0
var gold: int = 0
var upgrades: Array = []         # simple string tags for now, e.g. ["+1pawn_cap","rook_buff"]
var player_budget: int = 20      # draft budget for player at start; adjust if you have a different value
var army_layout: Array = []
var last_battle_result: Dictionary = {}

# For opponent generation between battles
var enemy_history: Array = []    # list of {stage, budget, ai:{depth,noise}, fen?}

# Scene paths (adjust if your paths differ)
const SCN_MENU   := "res://scenes/menu.tscn"
const SCN_DRAFT  := "res://scenes/draft.tscn"
const SCN_BOARD  := "res://scenes/board.tscn"
const SCN_REWARD := "res://scenes/reward.tscn"

func _ready() -> void:
	# Autoload expected. If not autoloaded, add this script as a singleton.
	pass

# ---------- Run control ----------
func start_new_run(_seed:int = Time.get_unix_time_from_system()) -> void:
	seed = int(_seed)
	rng = RandomNumberGenerator.new()
	rng.seed = seed
	run_active = true

	# Only reset gold on very first stage
	if stage <= 1:
		gold = 0

	stage = 1
	wins = 0
	upgrades.clear()
	enemy_history.clear()

	emit_signal("run_started", stage)
	_change_scene(SCN_DRAFT)

func proceed_to_battle() -> void:
	assert(run_active)
	var enemy_cfg := _make_enemy_cfg(stage)
	enemy_history.append(enemy_cfg)
	emit_signal("battle_started", stage, enemy_cfg)
	# board.gd should read this via GameManager.get_current_enemy_cfg()
	_change_scene(SCN_BOARD)

func proceed_to_reward(_won: bool, _turns: int) -> void:
	last_battle_result = {"won": _won, "turns": _turns}
	emit_signal("battle_ended", stage, _won, _turns)

	if _won:
		wins += 1
		var base := 5 + int(2.0 * stage)
		var quick_bonus := 2 if (_turns > 0 and _turns <= 30) else 0
		gold += base + quick_bonus
		_change_scene(SCN_REWARD)
	else:
		run_active = false
		_change_scene(SCN_MENU)


# Called by board.gd when a battle ends
func on_battle_end(won: bool, turns: int) -> void:
	print("Battle ended. Won:", won, "Turns:", turns)

	if won:
		# Progress to reward screen
		get_tree().change_scene_to_file("res://scenes/reward.tscn")
	else:
		# Lost — start a new run
		start_new_run()

# Called by reward.gd after player takes a reward
func on_reward_chosen(kind:String, data:Dictionary) -> void:
	match kind:
		"gold":
			gold += int(data.get("amount", 0))
			# Update gold label if board is open
			if has_node("/root/Board"):
				var board = get_node("/root/Board")
				if board.has_method("_update_gold"):
					board._update_gold()

		"upgrade":
			var tag := String(data.get("tag",""))
			if tag != "":
				upgrades.append(tag)
				emit_signal("reward_granted", kind, data)
		"budget_inc":
			player_budget += int(data.get("amount", 0))
		_:
			pass

	stage += 1
	proceed_to_battle()


# ---------- Data accessors used by scenes ----------
func get_run_summary() -> Dictionary:
	return {
		"stage": stage,
		"wins": wins,
		"gold": gold,
		"upgrades": upgrades.duplicate(),
		"player_budget": player_budget
	}

func get_current_enemy_cfg() -> Dictionary:
	# Last appended enemy
	if enemy_history.is_empty():
		return _make_enemy_cfg(stage) # fallback
	return enemy_history[enemy_history.size()-1]

# Reward generation for reward.gd UI
func generate_reward_choices() -> Array:
	# Three options: scaled gold, one upgrade tag, and a draft budget increase
	var choices:Array = []

	var gold_amt := 3 + 2 * stage
	choices.append({
		"kind":"gold",
		"title":"+%d Gold" % gold_amt,
		"desc":"Gain gold for shops and future features.",
		"data":{"amount":gold_amt}
	})

	var up_tag := _roll_upgrade_tag()
	choices.append({
		"kind":"upgrade",
		"title":"Upgrade: %s" % up_tag,
		"desc":"Adds a passive modifier for this run.",
		"data":{"tag":up_tag}
	})

	var budget_amt := 2 + int(stage/2)
	choices.append({
		"kind":"budget_inc",
		"title":"+%d Draft Budget" % budget_amt,
		"desc":"Increase starting piece budget for next battles.",
		"data":{"amount":budget_amt}
	})

	return choices

# ---------- Scaling & generation ----------
func _make_enemy_cfg(at_stage:int) -> Dictionary:
	# Enemy draft budget and AI settings scale with stage
	var budget := 16 + 2 * at_stage + int(0.5 * max(at_stage-5, 0))
	var depth: int = clamp(1 + int((at_stage - 1) / 3), 1, 4)
	var noise: float = clamp(0.25 - 0.03 * at_stage, 0.05, 0.25)

	return {
		"stage": at_stage,
		"budget": budget,
		"ai": {"depth": depth, "noise": noise}
	}

func _roll_upgrade_tag() -> String:
	# Light pool. Expand later.
	var pool := [
		"+1pawn_cap",          # allow 1 extra pawn in future enemy/player drafts
		"minor_mobility",      # small move-bonus hooks you can apply in board.gd later
		"opening_bonus",       # start with +1 random minor piece in draft if budget allows
		"bank_interest",       # +1 gold after each win
		"tactics_hint"         # future: show more legal targets
	]
	if upgrades.size() >= 1 and "bank_interest" in upgrades:
		# reduce duplicate bias
		pool.erase("bank_interest")
	return pool[rng.randi_range(0, pool.size()-1)]

# ---------- Scene jump ----------
func _change_scene(path:String) -> void:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Scene change failed: %s" % path)
