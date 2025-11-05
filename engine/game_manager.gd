extends Node
class_name GameManager

signal run_started(stage: int)
signal battle_started(stage: int, enemy_cfg: Dictionary)
signal battle_ended(stage: int, won: bool, turns: int)
signal reward_granted(id: String)

# ---------- Run state ----------
var run_active: bool = false
var seed: int = 0
var rng: RandomNumberGenerator
var stage: int = 0
var wins: int = 0
var gold: int = 0
var upgrades: Array[String] = []          # upgrade ids, e.g. ["pawn_boost","bank_interest"]
var player_budget: int = 20
var army_layout: Array = []
var last_battle_result: Dictionary = {}
var enemy_history: Array = []             # list of {stage, budget, ai:{depth,noise}}

# Upgrades DB from JSON
var upgrades_db: Array = []

# Scene paths
const SCN_MENU   := "res://scenes/menu.tscn"
const SCN_DRAFT  := "res://scenes/draft.tscn"
const SCN_BOARD  := "res://scenes/board.tscn"
const SCN_REWARD := "res://scenes/reward.tscn"

# upgrades.json location
const UPGRADES_PATH := "res://content/upgrades.json"

func _ready() -> void:
	_load_upgrades()

# ---------- Helpers ----------
func has_upgrade(id: String) -> bool:
	return upgrades.has(id)

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
	army_layout.clear()
	player_budget = 20   # base; passives like budget_boost will add to this

	emit_signal("run_started", stage)
	_change_scene(SCN_DRAFT)


func proceed_to_battle() -> void:
	assert(run_active)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = seed

	var enemy_cfg := _make_enemy_cfg(stage)
	enemy_history.append(enemy_cfg)
	emit_signal("battle_started", stage, enemy_cfg)
	_change_scene(SCN_BOARD)


func proceed_to_reward(_won: bool, _turns: int) -> void:
	last_battle_result = {"won": _won, "turns": _turns}
	emit_signal("battle_ended", stage, _won, _turns)

	if _won:
		wins += 1

		# base gold for victory
		var base := 5 + int(1 * stage)
		var quick_bonus := 2 if (_turns > 0 and _turns <= 30) else 0
		var total := base + quick_bonus

		# passive: Bank Interest (+1 per win)
		if has_upgrade("bank_interest"):
			total += 1

		# passive: Golden Touch (50% more victory gold)
		if has_upgrade("golden_touch"):
			total = int(round(float(total) * 1.5))

		gold += total

		# if board still exists, update gold label
		if has_node("/root/Board"):
			var board = get_node("/root/Board")
			if board.has_method("_update_gold"):
				board._update_gold()

		_change_scene(SCN_REWARD)
	else:
		run_active = false
		_change_scene(SCN_MENU)


# called by board.gd
func on_battle_end(won: bool, turns: int) -> void:
	proceed_to_reward(won, turns)


# called by reward.gd
# 'choice' is one of the dictionaries from upgrades_db / generate_reward_choices()
func on_reward_chosen(choice: Dictionary) -> void:
	var t := String(choice.get("type", ""))
	match t:
		"gold":
			var base := int(choice.get("amount", 0))
			var gain := base
			# Golden Touch also boosts direct gold rewards
			if has_upgrade("golden_touch"):
				gain = int(round(float(gain) * 1.5))
			gold += gain

			# update board gold label if present
			if has_node("/root/Board"):
				var board = get_node("/root/Board")
				if board.has_method("_update_gold"):
					board._update_gold()

		"passive":
			var id := String(choice.get("id", ""))
			if id != "" and not upgrades.has(id):
				upgrades.append(id)
				emit_signal("reward_granted", id)
				_apply_immediate_upgrade_effect(id)

		_:
			pass

	# go next stage
	stage += 1
	proceed_to_battle()


func _apply_immediate_upgrade_effect(id: String) -> void:
	match id:
		"budget_boost":
			player_budget += 3
		# The rest are applied in board/draft/battle logic later
		_:
			pass


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


# ---------- Reward generation using upgrades.json ----------
func generate_reward_choices() -> Array:
	var result: Array = []

	if upgrades_db.is_empty():
		push_warning("No upgrades in upgrades_db, using fallback.")
		# simple fallback
		var gold_amt := 3 + 2 * stage
		result.append({
			"id": "gold_fallback",
			"name": "+%d Gold" % gold_amt,
			"desc": "Gain gold for future upgrades.",
			"type": "gold",
			"amount": gold_amt,
			"rarity": 1
		})
		result.append({
			"id": "pawn_boost",
			"name": "Rapid Pawns",
			"desc": "Your pawns move 3 on their first turn.",
			"type": "passive",
			"rarity": 2
		})
		result.append({
			"id": "budget_boost",
			"name": "Budget Boost",
			"desc": "Increase draft budget by +3.",
			"type": "passive",
			"rarity": 2
		})
		return result

	# weighted pool: lower rarity = more common
	var pool: Array = []
	for u in upgrades_db:
		var id := String(u.get("id", ""))
		var tp := String(u.get("type", ""))
		var r := int(u.get("rarity", 1))

		# don't offer a passive we already own
		if tp == "passive" and upgrades.has(id):
			continue

		var weight := 1
		match r:
			1:
				weight = 5
			2:
				weight = 3
			3:
				weight = 1

		for i in weight:
			pool.append(u)

	if pool.is_empty():
		pool = upgrades_db.duplicate()

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = seed

	var picks: int = min(3, pool.size())
	var used_ids: Array[String] = []

	for i in picks:
		var choice: Dictionary = {}
		var attempts := 0
		while attempts < 16:
			var candidate: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
			var cid := String(candidate.get("id", ""))
			if not used_ids.has(cid):
				choice = candidate
				used_ids.append(cid)
				break
			attempts += 1

		if choice.size() > 0:
			result.append(choice.duplicate(true))

	return result


# ---------- Scaling & enemy generation ----------
func _make_enemy_cfg(at_stage: int) -> Dictionary:
	var budget := 16 + 2 * at_stage + int(0.5 * max(at_stage - 5, 0))
	var depth: int = clamp(1 + int((at_stage - 1) / 3), 1, 4)
	var noise: float = clamp(0.25 - 0.03 * at_stage, 0.05, 0.25)
	return {
		"stage": at_stage,
		"budget": budget,
		"ai": {"depth": depth, "noise": noise}
	}


# ---------- Load upgrades.json once ----------
func _load_upgrades() -> void:
	if not FileAccess.file_exists(UPGRADES_PATH):
		push_warning("upgrades.json not found at: %s" % UPGRADES_PATH)
		return

	var f := FileAccess.open(UPGRADES_PATH, FileAccess.READ)
	if f == null:
		push_warning("Failed to open upgrades.json at: %s" % UPGRADES_PATH)
		return

	var txt := f.get_as_text()
	var data = JSON.parse_string(txt)
	if typeof(data) == TYPE_ARRAY:
		upgrades_db = data
		print("Loaded upgrades:", upgrades_db.size())
	else:
		push_warning("upgrades.json has invalid JSON format.")


# ---------- Scene control ----------
func _change_scene(path: String) -> void:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Scene change failed: %s" % path)
