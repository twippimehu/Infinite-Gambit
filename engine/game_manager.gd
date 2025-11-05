extends Node
class_name GameManager

signal run_started(stage: int)
signal battle_started(stage: int, enemy_cfg: Dictionary)
signal battle_ended(stage: int, won: bool, turns: int)
signal reward_granted(kind: String, data: Dictionary)

# ---------- Run state ----------
var run_active: bool = false
var seed: int = 0
var rng: RandomNumberGenerator
var stage: int = 0
var wins: int = 0
var gold: int = 0
var upgrades: Array = []
var player_budget: int = 20
var army_layout: Array = []
var last_battle_result: Dictionary = {}
var enemy_history: Array = []  # list of {stage, budget, ai:{depth,noise}, fen?}

# Scene paths
const SCN_MENU := "res://scenes/menu.tscn"
const SCN_DRAFT := "res://scenes/draft.tscn"
const SCN_BOARD := "res://scenes/board.tscn"
const SCN_REWARD := "res://scenes/reward.tscn"

func _ready() -> void:
	pass


# ---------- Run control ----------
func start_new_run(_seed: int = Time.get_unix_time_from_system()) -> void:
	seed = int(_seed)
	rng = RandomNumberGenerator.new()
	rng.seed = seed
	run_active = true
	stage = 1
	wins = 0
	gold = 0
	upgrades.clear()
	enemy_history.clear()
	emit_signal("run_started", stage)
	_change_scene(SCN_DRAFT)


func proceed_to_battle() -> void:
	assert(run_active)
	var enemy_cfg := _make_enemy_cfg(stage)
	enemy_history.append(enemy_cfg)
	emit_signal("battle_started", stage, enemy_cfg)
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


func on_battle_end(won: bool, turns: int) -> void:
	print("Battle ended. Won:", won, "Turns:", turns)
	if won:
		get_tree().change_scene_to_file(SCN_REWARD)
	else:
		start_new_run()


func on_reward_chosen(kind: String, data: Dictionary) -> void:
	match kind:
		"gold":
			gold += int(data.get("amount", 0))
			if has_node("/root/Board"):
				var board = get_node("/root/Board")
				if board.has_method("_update_gold"):
					board._update_gold()
		"upgrade":
			var tag := String(data.get("tag", ""))
			if tag != "":
				upgrades.append(tag)
				emit_signal("reward_granted", kind, data)
		"budget_inc":
			player_budget += int(data.get("amount", 0))
		_:
			pass
	stage += 1
	proceed_to_battle()


# ---------- Data accessors ----------
func get_run_summary() -> Dictionary:
	return {
		"stage": stage,
		"wins": wins,
		"gold": gold,
		"upgrades": upgrades.duplicate(),
		"player_budget": player_budget
	}


func get_current_enemy_cfg() -> Dictionary:
	if enemy_history.is_empty():
		return _make_enemy_cfg(stage)
	return enemy_history[enemy_history.size() - 1]


# ---------- Reward generation ----------
func generate_reward_choices() -> Array:
	var choices: Array = []
	var upgrades_data := _load_upgrades_data()
	if upgrades_data.is_empty():
		push_warning("No upgrades.json found or empty.")
		return []

	# rarity weights (lower chance for higher rarity)
	var weights := {1: 60, 2: 30, 3: 10}

	# Pick upgrades by category
	var gold_upgrade := upgrades_data.filter(_is_gold)
	if gold_upgrade.size() > 0:
		choices.append(gold_upgrade[randi() % gold_upgrade.size()])

	var passive_upgrade := upgrades_data.filter(_is_passive)
	if passive_upgrade.size() > 0:
		choices.append(passive_upgrade[randi() % passive_upgrade.size()])

	choices.append(_pick_random_upgrade(upgrades_data, weights))
	return choices


func _pick_random_upgrade(upgrades_data: Array, weights: Dictionary) -> Dictionary:
	var pool: Array = []
	for u in upgrades_data:
		var r: int = int(u.get("rarity", 1))
		if r < 1 or r > 3:
			r = 1
		for i in range(weights[r]):
			pool.append(u)
	return pool[randi() % pool.size()]


func _is_gold(u: Dictionary) -> bool:
	return u.get("type", "") == "gold"


func _is_passive(u: Dictionary) -> bool:
	return u.get("type", "") == "passive"


# ---------- JSON loader ----------
func _load_upgrades_data() -> Array:
	var path := "res://content/upgrades.json"
	print("Loading upgrades from:", path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Failed to open upgrades.json.")
		return []
	var txt := f.get_as_text()
	print("File text length:", txt.length())
	var data: Array = JSON.parse_string(txt)
	if typeof(data) == TYPE_ARRAY:
		print("Loaded upgrades count:", data.size())
		return data
	else:
		push_error("upgrades.json invalid format.")
		return []


# ---------- Scaling & generation ----------
func _make_enemy_cfg(at_stage: int) -> Dictionary:
	var budget := 16 + 2 * at_stage + int(0.5 * max(at_stage - 5, 0))
	var depth: int = clamp(1 + int((at_stage - 1) / 3), 1, 4)
	var noise: float = clamp(0.25 - 0.03 * at_stage, 0.05, 0.25)
	return {
		"stage": at_stage,
		"budget": budget,
		"ai": {"depth": depth, "noise": noise}
	}


# ---------- Scene control ----------
func _change_scene(path: String) -> void:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Scene change failed: %s" % path)
