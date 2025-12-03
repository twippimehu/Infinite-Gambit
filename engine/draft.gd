extends Control

const COSTS := {"P":1,"N":3,"B":3,"R":5,"Q":9,"K":0}

var selected_slot: int = -1
var slots: Array = []
var budget: int = 0
var piece_buttons := []

@onready var slot_buttons: Array = [
	$Panel/VBoxContainer/HBoxContainer/Slot0,
	$Panel/VBoxContainer/HBoxContainer/Slot1,
	$Panel/VBoxContainer/HBoxContainer/Slot2,
	$Panel/VBoxContainer/HBoxContainer/Slot3,
	$Panel/VBoxContainer/HBoxContainer/Slot4,
	$Panel/VBoxContainer/HBoxContainer/Slot5,
	$Panel/VBoxContainer/HBoxContainer/Slot6,
	$Panel/VBoxContainer/HBoxContainer/Slot7
]

@onready var budget_label: Label = $Panel/VBoxContainer/BudgetLabel
@onready var info_label: Label   = $Panel/VBoxContainer/InfoLabel

@onready var btn_pawn: Button   = $Panel/VBoxContainer/HBoxContainer2/BtnPawn
@onready var btn_knight: Button = $Panel/VBoxContainer/HBoxContainer2/BtnKnight
@onready var btn_bishop: Button = $Panel/VBoxContainer/HBoxContainer2/BtnBishop
@onready var btn_rook: Button   = $Panel/VBoxContainer/HBoxContainer2/BtnRook
@onready var btn_queen: Button  = $Panel/VBoxContainer/HBoxContainer2/BtnQueen
@onready var btn_king: Button   = $Panel/VBoxContainer/HBoxContainer2/BtnKing

@onready var btn_confirm: Button = $Panel/VBoxContainer/HBoxContainer3/BtnConfirm
@onready var btn_clear: Button   = $Panel/VBoxContainer/HBoxContainer3/BtnClear
@onready var btn_random: Button  = $Panel/VBoxContainer/HBoxContainer3/BtnRandom

# Small white piece icons for the draft slots
var PIECE_ICONS := {
	"P": preload("res://assets/chess/vector-chess-pieces/White/Pawn White Outline 72px.png"),
	"N": preload("res://assets/chess/vector-chess-pieces/White/Knight White Outline 72px.png"),
	"B": preload("res://assets/chess/vector-chess-pieces/White/Bishop White Outline 72px.png"),
	"R": preload("res://assets/chess/vector-chess-pieces/White/Rook White Outline 72px.png"),
	"Q": preload("res://assets/chess/vector-chess-pieces/White/Queen White Outline 72px.png"),
	"K": preload("res://assets/chess/vector-chess-pieces/White/King White Outline 72px.png"),
}


# ---------------------------------------------------------
func _ready() -> void:
	print("draft.gd ready")

	# Load the budget from Game autoload
	if has_node("/root/Game"):
		budget = int(Game.player_budget)
	else:
		budget = 20
	if budget <= 0:
		budget = 20
		if has_node("/root/Game"):
			Game.player_budget = budget
	print("Loaded budget:", budget)

	# Initialize slots
	slots.resize(8)
	for i in range(8):
		slots[i] = null
		# connect using Callable and bind the index
		slot_buttons[i].pressed.connect(Callable(self, "_on_slot_pressed").bind(i))
		slot_buttons[i].tooltip_text = "Slot %d" % i

	# Piece buttons (connect to _pick_piece with bound kind)
	btn_pawn.pressed.connect(Callable(self, "_pick_piece").bind("P"))
	btn_knight.pressed.connect(Callable(self, "_pick_piece").bind("N"))
	btn_bishop.pressed.connect(Callable(self, "_pick_piece").bind("B"))
	btn_rook.pressed.connect(Callable(self, "_pick_piece").bind("R"))
	btn_queen.pressed.connect(Callable(self, "_pick_piece").bind("Q"))
	btn_king.pressed.connect(Callable(self, "_pick_piece").bind("K"))

	btn_confirm.pressed.connect(Callable(self, "_confirm"))
	btn_clear.pressed.connect(Callable(self, "_clear_all"))
	btn_random.pressed.connect(Callable(self, "_random_fill"))

	piece_buttons = [
		btn_pawn, btn_knight, btn_bishop,
		btn_rook, btn_queen, btn_king
]

	_update_ui()
	_update_info_text()



# ---------------- helpers ----------------
func _on_slot_pressed(i: int) -> void:
	selected_slot = i
	print("Slot selected:", i)
	_highlight_slots()

func _highlight_slots() -> void:
	for i in range(slot_buttons.size()):
		var btn = slot_buttons[i]
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.self_modulate = Color(1, 1, 1)  # normal

		if selected_slot >= 0:
			var sb = slot_buttons[selected_slot]
			sb.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
			sb.self_modulate = Color(1.1, 1.05, 0.9)


func _set_info(t: String) -> void:
	if is_instance_valid(info_label):
		info_label.text = t

func _update_info_text() -> void:
	var base := "Click a slot, then a piece."

	# Only show enemy preview if we have the 'scout_ahead' upgrade
	if has_node("/root/Game") and Game.has_upgrade("scout_ahead"):
		var enemy_cfg: Dictionary = Game.get_next_enemy_cfg()
		var stage_num: int = int(enemy_cfg.get("stage", Game.stage))
		var budget: int = int(enemy_cfg.get("budget", 0))
		var ai_cfg: Dictionary = enemy_cfg.get("ai", {})
		var depth: int = int(ai_cfg.get("depth", 1))
		var noise: float = float(ai_cfg.get("noise", 0.0))

		var preview := "Next enemy (Stage %d): budget %d, AI depth %d, noise %.2f" \
			% [stage_num, budget, depth, noise]

		_set_info(preview + "\n" + base)
	else:
		_set_info(base)


func _affordable_candidates(rem_gold: int, kinds: Array) -> Array:
	var out: Array = []
	for k in kinds:
		if COSTS[k] <= rem_gold:
			out.append(k)
	return out

func _cheapest_kind(candidates: Array) -> String:
	var best: String = ""
	var best_cost: int = 1 << 30
	for k in candidates:
		var c_variant = COSTS.get(k, 999999)
		var c: int = int(c_variant)  # explicit cast to int to avoid Variant typing
		if c < best_cost:
			best_cost = c
			best = String(k)
	return best


func _clear_piece_highlights() -> void:
	for b in [btn_pawn, btn_knight, btn_bishop, btn_rook, btn_queen, btn_king]:
		b.self_modulate = Color(1, 1, 1)


# ---------------- actions ----------------
func _pick_piece(kind: String) -> void:
	_clear_piece_highlights()

	match kind:
		"P": btn_pawn.self_modulate = Color(1.1, 1.05, 0.9)
		"N": btn_knight.self_modulate = Color(1.1, 1.05, 0.9)
		"B": btn_bishop.self_modulate = Color(1.1, 1.05, 0.9)
		"R": btn_rook.self_modulate   = Color(1.1, 1.05, 0.9)
		"Q": btn_queen.self_modulate  = Color(1.1, 1.05, 0.9)
		"K": btn_king.self_modulate   = Color(1.1, 1.05, 0.9)

	if selected_slot < 0:
		_set_info("Select a slot first.")
		return

	# enforce single king
	if kind == "K" and _count_kings() >= 1 and (slots[selected_slot] == null or slots[selected_slot].kind != "K"):
		_set_info("Only one king allowed.")
		return

	var tentative := slots.duplicate()
	tentative[selected_slot] = {"kind": kind}
	var cost := _cost_of(tentative)
	print("Try place", kind, "at", selected_slot, "cost:", cost, "/", budget)
	if cost <= budget:
		slots[selected_slot] = {"kind": kind}
		_set_info("Placed %s at %d." % [kind, selected_slot])
	else:
		_set_info("Over budget.")
	_update_ui()


func _clear_all() -> void:
	for i in range(8):
		slots[i] = null
	_set_info("Cleared.")
	_update_ui()


func _random_fill() -> void:
	randomize()
	_clear_all()

	var kinds: Array = ["P", "N", "B", "R", "Q"]

	# Always include exactly one king at a random slot
	var king_pos: int = randi() % 8
	slots[king_pos] = {"kind": "K"}

	# Track remaining budget after all placed pieces; start with full budget
	var remaining_gold: int = budget
	# king cost is 0, but count it as included
	var placed_count: int = 1

	# Fill other slots while ensuring we never exceed budget
	for i in range(8):
		if i == king_pos:
			continue

		var candidates: Array = _affordable_candidates(remaining_gold, kinds)
		if candidates.size() == 0:
			# nothing affordable: try pawn fallback
			if COSTS["P"] <= remaining_gold:
				slots[i] = {"kind": "P"}
				remaining_gold -= COSTS["P"]
				placed_count += 1
			else:
				slots[i] = null
			continue

		# pick random affordable candidate (explicitly typed)
		var idx: int = randi() % candidates.size()
		var pick_kind: String = String(candidates[idx])

		# safety: if pick unexpectedly exceeds remaining_gold, use cheapest candidate
		var pick_cost_variant = COSTS.get(pick_kind, 999999)
		var pick_cost: int = int(pick_cost_variant)
		if pick_cost > remaining_gold:
			pick_kind = _cheapest_kind(candidates)
			pick_cost = int(COSTS.get(pick_kind, 999999))

		# place and deduct cost
		slots[i] = {"kind": pick_kind}
		remaining_gold -= pick_cost
		placed_count += 1

	# Final check: ensure exactly one king present (should always be true)
	if _count_kings() != 1:
		# try to replace cheapest non-king with king
		var cheapest_idx: int = -1
		var cheapest_cost: int = 1 << 30
		for i in range(8):
			if slots[i] == null:
				cheapest_idx = i
				break
			if slots[i].kind != "K":
				var c_variant2 = COSTS.get(slots[i].kind, 999999)
				var c2: int = int(c_variant2)
				if c2 < cheapest_cost:
					cheapest_cost = c2
					cheapest_idx = i
		if cheapest_idx >= 0:
			slots[cheapest_idx] = {"kind": "K"}

	_set_info("Randomized army (including King).")
	_update_ui()


# ---------------- calc ----------------
func _count_kings() -> int:
	var n := 0
	for s in slots:
		if s != null and s.kind == "K":
			n += 1
	return n


func _cost_of(arr: Array) -> int:
	var sum := 0
	for s in arr:
		if s == null:
			continue
		sum += int(COSTS[s.kind])
	return sum


# ---------------- ui ----------------
func _update_ui() -> void:
	# Update the 8 draft slots
	for i in range(8):
		var btn: Button = slot_buttons[i]
		var slot_cfg = slots[i]

		# detect empty state **before** applying new data
		var was_empty_before := (btn.icon == null and btn.text == "—")

		if slot_cfg != null:
			var kind: String = slot_cfg.kind

			# animate only when a piece appears in an empty slot
			if was_empty_before:
				var tween := create_tween()
				btn.scale = Vector2(0.75, 0.75)
				tween.tween_property(btn, "scale", Vector2.ONE, 0.15)\
					.set_trans(Tween.TRANS_BACK)\
					.set_ease(Tween.EASE_OUT)

			btn.text = ""
			btn.icon = PIECE_ICONS.get(kind, null)
		else:
			btn.icon = null
			btn.text = "—"

	_highlight_slots()

	var cost := _cost_of(slots)
	var gold := 0
	if has_node("/root/Game"):
		gold = Game.gold

	budget_label.text = "Cost: %d / %d   |   King: %d/1   |   Gold: %d" \
		% [cost, budget, _count_kings(), gold]

	btn_confirm.disabled = not (_count_kings() == 1 and cost <= budget)



# ---------------- proceed ----------------
func _confirm() -> void:
	if has_node("/root/Game"):
		Game.army_layout = slots.duplicate()
		Game.proceed_to_battle()
