extends Node
class_name GameManager

signal run_started(stage: int)
signal battle_started(stage: int, enemy_cfg: Dictionary)
signal battle_ended(stage: int, won: bool, turns: int)
signal reward_granted(id: String)

# -----------------------------
#  RUN STATE
# -----------------------------
var run_active: bool = false
var seed: int = 0
var rng: RandomNumberGenerator
var stage: int = 0
var wins: int = 0
var gold: int = 0
var upgrades: Array[String] = []          # owned passive IDs
var player_budget: int = 20
var army_layout: Array = []
var last_battle_result: Dictionary = {}
var enemy_history: Array = []
var game_mode: String = "classic"  # "classic" or "infinite"

# upgrades.json
var upgrades_db: Array = []
const UPGRADES_PATH := "res://content/upgrades.json"

# temporarily disabled upgrades (not implemented yet)
const DISABLED_UPGRADES := ["extra_slot"]

# SCENES
const SCN_MENU   := "res://scenes/menu.tscn"
const SCN_DRAFT  := "res://scenes/draft.tscn"
const SCN_BOARD  := "res://scenes/board.tscn"
const SCN_REWARD := "res://scenes/reward.tscn"
const SCN_SHOP   := "res://scenes/shop.tscn"
const MUTATOR_POOL := {
	"fields":  ["extra_pawns"],
	"ruins":   ["aggressive_ai"],
	"citadel": ["queen_wall", "cold_precision"]
}


func _ready() -> void:
	_load_upgrades()


# -----------------------------
#  HELPERS
# -----------------------------
func has_upgrade(id: String) -> bool:
	return upgrades.has(id)


func try_spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if gold < amount:
		return false
	gold -= amount
	return true

# -----------------------------
#  START NEW RUN
# -----------------------------
func start_new_run(_seed: int = Time.get_unix_time_from_system(), mode: String = "classic") -> void:
	game_mode = mode

	seed = int(_seed)
	rng = RandomNumberGenerator.new()
	rng.seed = seed

	run_active = true
	stage = 0
	wins = 0
	gold = 0
	upgrades.clear()
	enemy_history.clear()
	army_layout.clear()
	player_budget = 20

	emit_signal("run_started", stage)
	_change_scene(SCN_DRAFT)



# -----------------------------
#  SHOP PRICING
# -----------------------------
func get_shop_price(up: Dictionary) -> int:
	var rarity := int(up.get("rarity", 1))
	var price := 0

	match rarity:
		1:
			price = 5
		2:
			price = 8
		3:
			price = 12
		_:
			price = 5

	price += int(stage / 3)

	if has_upgrade("merchant"):
		price -= 2

	return max(price, 1)


# -----------------------------
#  PROCEED TO BATTLE
# -----------------------------
func proceed_to_battle() -> void:
	assert(run_active)

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = seed

	var enemy_cfg := _make_enemy_cfg(stage)
	enemy_history.append(enemy_cfg)

	emit_signal("battle_started", stage, enemy_cfg)
	_change_scene(SCN_BOARD)


# -----------------------------
#  POST-BATTLE → REWARD
# -----------------------------
func proceed_to_reward(_won: bool, _turns: int) -> void:
	last_battle_result = {"won": _won, "turns": _turns}
	emit_signal("battle_ended", stage, _won, _turns)

	if _won:
		wins += 1

		var base := 5 + stage
		var quick_bonus := 0
		if _turns > 0 and _turns <= 30:
			quick_bonus = 2

		var total := base + quick_bonus

		if has_upgrade("bank_interest"):
			total += 1

		if has_upgrade("golden_touch"):
			total = int(round(total * 1.5))

		gold += total

		if has_node("/root/Board"):
			var board = get_node("/root/Board")
			if board.has_method("_update_gold"):
				board._update_gold()

		_change_scene(SCN_REWARD)
	else:
		run_active = false
		_change_scene(SCN_MENU)


func on_battle_end(won: bool, turns: int) -> void:
	proceed_to_reward(won, turns)


# -----------------------------
#  APPLY REWARD SELECTION
# -----------------------------
func on_reward_chosen(choice: Dictionary) -> void:
	var tp := String(choice.get("type", ""))

	if tp == "gold":
		var gain := int(choice.get("amount", 0))
		if has_upgrade("golden_touch"):
			gain = int(round(gain * 1.5))
		gold += gain

	elif tp == "passive":
		var id := String(choice.get("id", ""))
		if id != "" and not upgrades.has(id):
			upgrades.append(id)
			emit_signal("reward_granted", id)
			_apply_immediate_upgrade_effect(id)

	# go next stage and return to draft
	stage += 1
	_change_scene(SCN_SHOP)

# -----------------------------
#  APPLY SHOP PURCHASE
# -----------------------------
func apply_shop_purchase(choice: Dictionary) -> void:
	var tp := String(choice.get("type", ""))

	if tp == "passive":
		var id := String(choice.get("id", ""))
		if id != "" and not upgrades.has(id):
			upgrades.append(id)
			emit_signal("reward_granted", id)
			_apply_immediate_upgrade_effect(id)

	# (no gold items appear in shop)

	if has_node("/root/Board"):
		var board = get_node("/root/Board")
		if board.has_method("_update_gold"):
			board._update_gold()


func _apply_immediate_upgrade_effect(id: String) -> void:
	match id:
		"budget_boost":
			player_budget += 3
		_:
			pass


# -----------------------------
#  SHOP CHOICE GENERATION
# -----------------------------
func generate_shop_choices() -> Array:
	var pool: Array = []

	for u in upgrades_db:
		var tp := String(u.get("type", ""))
		var id := String(u.get("id", ""))

		if DISABLED_UPGRADES.has(id):
			continue
		if tp == "gold":
			continue
		if tp == "passive" and upgrades.has(id):
			continue

		pool.append(u)

	if pool.is_empty():
		return []

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = seed

	pool.shuffle()

	var count: int = min(3, pool.size())
	return pool.slice(0, count)



func get_upgrade_name(id: String) -> String:
	for u in upgrades_db:
		if String(u.get("id", "")) == id:
			return String(u.get("name", id))
	return id  # fallback

# -----------------------------
#  REWARD CHOICE GENERATION
# -----------------------------
func generate_reward_choices() -> Array:
	var pool: Array = []

	for u in upgrades_db:
		var id := String(u.get("id", ""))
		var tp := String(u.get("type", ""))

		if DISABLED_UPGRADES.has(id):
			continue
		if tp == "passive" and upgrades.has(id):
			continue

		pool.append(u)

	if pool.is_empty():
		return []

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = seed

	pool.shuffle()

	var count: int = min(3, pool.size())
	return pool.slice(0, count)



# -----------------------------
#  ENEMY GENERATION
# -----------------------------
const CLASSIC_ACTS := {
	1: {"act": 1, "theme": "Fields",  "start": 1,  "end": 10},
	2: {"act": 2, "theme": "Ruins",   "start": 11, "end": 20},
	3: {"act": 3, "theme": "Citadel", "start": 21, "end": 30}
}

func _get_act_for_stage(s: int) -> Dictionary:
	for act_data in CLASSIC_ACTS.values():
		var start_s: int = int(act_data.get("start", 1))
		var end_s: int = int(act_data.get("end", 10))
		if s >= start_s and s <= end_s:
			return act_data
	return CLASSIC_ACTS[1]



func _stage_type(s: int) -> String:
	if game_mode == "classic":
		if s == 10 or s == 20:
			return "boss"
		if s == 30:
			return "final_boss"
		if s % 4 == 3:
			return "elite"
		return "normal"
	# infinite mode not implemented yet
	return "normal"


func _make_enemy_cfg(at_stage: int) -> Dictionary:
	# --- base scaling ---
	var budget := 16 + 2 * at_stage + int(0.5 * max(at_stage - 5, 0))
	var depth: int = clamp(1 + int((at_stage - 1) / 3), 1, 4)
	var noise: float = clamp(0.25 - 0.03 * at_stage, 0.05, 0.25)

	# --- stage meta ---
	var stype: String = _stage_type(at_stage)
	var act_data: Dictionary = _get_act_for_stage(at_stage)
	var act_idx: int = int(act_data.get("act", 1))
	var theme_str: String = String(act_data.get("theme", "Fields"))
	var theme_key: String = theme_str.to_lower()

	# --- ensure RNG for mutator selection ---
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = seed

	var mutators: Array = []

	if MUTATOR_POOL.has(theme_key):
		var pool: Array = MUTATOR_POOL[theme_key]

		if not pool.is_empty():
			match stype:
				"elite":
					# In Act 3, elites use ALL mutators (Queen Wall + Cold Precision)
					if act_idx == 3:
						mutators = pool.duplicate()
					else:
						# Act 1 & 2 elites: single random mutator
						var idx := rng.randi_range(0, pool.size() - 1)
						mutators.append(pool[idx])
				"boss":
					mutators = pool.duplicate()
				"final_boss":
					mutators = pool.duplicate()
					mutators.append("mirror_reinforcements")
					mutators.append("reinforced_king")
				_:
					pass

	return {
		"stage": at_stage,
		"type": stype,
		"act": act_idx,
		"theme": theme_str,
		"mutators": mutators,
		"budget": budget,
		"ai": {"depth": depth, "noise": noise}
	}




func proceed_to_draft() -> void:
	if not run_active:
		return
	_change_scene(SCN_DRAFT)

# -----------------------------
#  LOAD JSON
# -----------------------------
func _load_upgrades() -> void:
	if not FileAccess.file_exists(UPGRADES_PATH):
		push_warning("upgrades.json NOT FOUND")
		return

	var f := FileAccess.open(UPGRADES_PATH, FileAccess.READ)
	if f == null:
		push_warning("Failed to open upgrades.json")
		return

	var txt := f.get_as_text()
	var data: Array = JSON.parse_string(txt)

	if typeof(data) == TYPE_ARRAY:
		upgrades_db = data
		print("Loaded upgrades:", upgrades_db.size())
	else:
		push_warning("Invalid upgrades.json format")

func get_current_enemy_cfg() -> Dictionary:
	if enemy_history.is_empty():
		return _make_enemy_cfg(stage)
	return enemy_history[enemy_history.size() - 1]
	
func get_next_enemy_cfg() -> Dictionary:
	# Always returns the config for the upcoming enemy at the current stage.
	# 'stage' is already advanced after rewards, so this is safe to use in Draft.
	return _make_enemy_cfg(stage)


# -----------------------------
#  SCENE SWITCHING
# -----------------------------
func _change_scene(path: String) -> void:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Scene change failed: %s" % path)
