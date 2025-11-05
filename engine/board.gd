extends Node2D

const GameStateRes = preload("res://engine/state.gd")
const PieceScene = preload("res://scenes/Piece.tscn")

var state: GameStateRes

@onready var board_sprite: Sprite2D = $BoardSprite
@onready var ui_label: Label = $UI/StatusLabel
@onready var pieces_layer: Node2D = Node2D.new()
@onready var highlight_layer: Node2D = Node2D.new()
@onready var lbl_budget: Label = $Panel/VBoxContainer/BudgetLabel

var selected_square: Vector2i = Vector2i(-1, -1)
var selected_piece_node: Node2D = null
var move_stage := 0
var current_turn := 0 # 0 = white, 1 = black
var game_over := false
var game_over_reported := false

# highlighting
var highlight_sel_color := Color(1, 1, 0, 0.35)
var highlight_dst_color := Color(0.2, 0.8, 1.0, 0.5)
var legal_targets: Array[Vector2i] = []

# sfx + undo
@export var sfx_move: AudioStream
@export var sfx_capture: AudioStream
@export var sfx_check: AudioStream
@export var sfx_mate: AudioStream
var _sfx: Dictionary = {}
var move_stack: Array = [] # {src,dst,piece,captured,captured_pos, promoted_to?, ep_marker}
var last_double_pawn: Vector2i = Vector2i(-1, -1)

# AI
@export var ai_plays_black := true
var _ai_thinking := false

# -------------------------------------------------------------------
func _ready():
	$Camera2D.make_current()
	add_child(highlight_layer)
	add_child(pieces_layer)
	highlight_layer.z_index = 5
	pieces_layer.z_index = 10
	state = GameStateRes.new()

	# Apply drafted layout (custom first rank)
	if Game.army_layout.size() == 8:
		for c in range(8):
			state.board[0][c] = null
		for c in range(8):
			var slot = Game.army_layout[c]
			if slot == null:
				continue
			state.board[0][c] = {
				"kind": slot.kind,
				"side": 0,
				"has_moved": false
			}
	_spawn_all_pieces()
	_update_status("White begins.")
	_update_gold()


func _update_gold() -> void:
	if has_node("Panel/VBoxContainer/GoldLabel"):
		var label := $Panel/VBoxContainer/GoldLabel
		label.text = "Gold: %d" % Game.gold


	# --- Apply upgrades that modify gameplay ---
	if has_node("/root/Game"):
		var upgrades: Array = Game.upgrades
		if "pawn_boost" in upgrades:
			print("Upgrade active: pawn_boost (pawns move 3 on first turn)")
			state.extra_pawn_push = 3
		else:
			state.extra_pawn_push = 2
	else:
		state.extra_pawn_push = 2

	_sfx = {
		"move": AudioStreamPlayer.new(),
		"capture": AudioStreamPlayer.new(),
		"check": AudioStreamPlayer.new(),
		"mate": AudioStreamPlayer.new()
	}
	for k in _sfx.keys():
		add_child(_sfx[k])
	_sfx["move"].stream = sfx_move
	_sfx["capture"].stream = sfx_capture
	_sfx["check"].stream = sfx_check
	_sfx["mate"].stream = sfx_mate

	_setup_ui_buttons()

# -------------------------------------------------------------------
# Helpers
func _square_size() -> Vector2:
	return (board_sprite.texture.get_size() * board_sprite.scale) / 8.0

func _board_top_left() -> Vector2:
	var scaled = board_sprite.texture.get_size() * board_sprite.scale
	return board_sprite.position - scaled * 0.5

func _board_to_pixels(r: int, c: int) -> Vector2:
	var tl = _board_top_left()
	var sq = _square_size()
	return tl + Vector2(c * sq.x + sq.x * 0.5, (7 - r) * sq.y + sq.y * 0.5)

func _update_status(text: String):
	ui_label.text = text

func _play_sfx(kind: String):
	if _sfx.has(kind) and _sfx[kind].stream:
		_sfx[kind].play()

func _respawn_piece_node(kind: String, side: int, r: int, c: int) -> Node2D:
	var p: Node2D = PieceScene.instantiate()
	p.kind = kind
	p.side = side
	p.position = _board_to_pixels(r, c)
	var icon: Sprite2D = p.get_node("Icon")
	if icon.texture:
		var sq = _square_size()
		var tex_size = icon.texture.get_size()
		icon.scale = Vector2(sq.x / tex_size.x, sq.y / tex_size.y) * 0.9
	pieces_layer.add_child(p)
	return p

func _find_piece_node_at(square: Vector2i) -> Node2D:
	for p in pieces_layer.get_children():
		if p.position.distance_to(_board_to_pixels(square.x, square.y)) < 5.0:
			return p
	return null

# -------------------------------------------------------------------
# Piece setup
func _spawn_all_pieces():
	var sq = _square_size()
	for r in state.N:
		for c in state.N:
			var cell = state.board[r][c]
			if cell == null:
				continue
			var p: Node2D = PieceScene.instantiate()
			p.kind = cell.kind
			p.side = cell.side
			p.position = _board_to_pixels(r, c)
			var icon: Sprite2D = p.get_node("Icon")
			if icon.texture:
				var tex_size = icon.texture.get_size()
				icon.scale = Vector2(sq.x / tex_size.x, sq.y / tex_size.y) * 0.9
			pieces_layer.add_child(p)

# -------------------------------------------------------------------
# Input
func _input(event):
	if game_over: return
	if _ai_thinking: return
	if current_turn == 1 and ai_plays_black: return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos = get_viewport().get_mouse_position()
		var square = _pixel_to_board(pos)
		if square.x == -1: return
		if move_stage == 0:
			_select_piece(square)
		elif move_stage == 1:
			_try_move(square)

# -------------------------------------------------------------------
# Selection and Move
func _select_piece(square: Vector2i):
	var cell = state.board[square.x][square.y]
	if cell == null or cell.side != current_turn:
		return
	selected_square = square
	move_stage = 1
	legal_targets = _legal_moves_from(square)
	_draw_highlight(square)
	selected_piece_node = _find_piece_node_at(square)
	var side_name = "White" if current_turn == 0 else "Black"
	_update_status(side_name + " selected " + cell.kind)

func _try_move(target: Vector2i):
	if selected_square == target:
		move_stage = 0
		_clear_highlights()
		return

	var src = selected_square
	var piece = state.board[src.x][src.y]
	var prev_has_moved: bool = bool(piece.get("has_moved", false))
	var rook_prev_has_moved: bool = false   # filled only if we castle
	if not _is_legal_move(src, target, piece):
		_clear_highlights()
		move_stage = 0
		selected_piece_node = null
		return

	# simulate for self-check
	var saved_src = state.board[src.x][src.y]
	var saved_dst = state.board[target.x][target.y]
	state.board[target.x][target.y] = piece
	state.board[src.x][src.y] = null
	var still_check = _is_check(piece.side)
	state.board[src.x][src.y] = saved_src
	state.board[target.x][target.y] = saved_dst
	if still_check:
		_clear_highlights()
		move_stage = 0
		selected_piece_node = null
		return

	var captured = state.board[target.x][target.y]
	var captured_pos = target

	# En passant
	if piece.kind == "P" and captured == null and src.y != target.y:
		var dir = 1 if piece.side == 0 else -1
		if Vector2i(target.x, target.y) == last_double_pawn and target.x == src.x + dir:
			captured_pos = Vector2i(src.x, target.y)
			captured = state.board[captured_pos.x][captured_pos.y]
			state.board[captured_pos.x][captured_pos.y] = null
			for p in pieces_layer.get_children():
				if p.position.distance_to(_board_to_pixels(captured_pos.x, captured_pos.y)) < 5.0:
					p.queue_free()
					break

# Castling
	if piece.kind == "K" and abs(target.y - src.y) == 2:
		var row = src.x
		var rook_col_src = 7 if target.y > src.y else 0
		var rook_col_dst = src.y + (1 if target.y > src.y else -1)
		var rook_piece = state.board[row][rook_col_src]
		if rook_piece != null and rook_piece.kind == "R":
		# remember rook's prior flag for undo
			rook_prev_has_moved = bool(rook_piece.get("has_moved", false))

		state.board[row][rook_col_dst] = rook_piece
		state.board[row][rook_col_src] = null
		rook_piece.has_moved = true

		for p in pieces_layer.get_children():
			if p.position.distance_to(_board_to_pixels(row, rook_col_src)) < 5.0:
				var tween_r = get_tree().create_tween()
				tween_r.tween_property(p, "position", _board_to_pixels(row, rook_col_dst), 0.12)
				break



	# Normal capture
	if captured != null and captured_pos == target:
		for p in pieces_layer.get_children():
			if p.position.distance_to(_board_to_pixels(target.x, target.y)) < 5.0:
				p.queue_free()
				break

# record move (+ remember prior flags for robust undo)
	move_stack.append({
		"src": src,
		"dst": target,
		"piece": {"kind": piece.kind, "side": piece.side},
		"captured": captured,
		"captured_pos": captured_pos,
		"ep_marker": last_double_pawn,
		"prev_has_moved": prev_has_moved,
		"rook_prev_has_moved": rook_prev_has_moved
})


	# update EP eligibility
	last_double_pawn = Vector2i(-1, -1)
	if piece.kind == "P" and abs(target.x - src.x) == 2:
		var dir = 1 if piece.side == 0 else -1
		last_double_pawn = Vector2i(src.x + dir, src.y)

	# apply move
	state.board[target.x][target.y] = piece
	state.board[src.x][src.y] = null
	piece.has_moved = true

	if selected_piece_node:
		var tween = get_tree().create_tween()
		tween.tween_property(selected_piece_node, "position", _board_to_pixels(target.x, target.y), 0.12)

	# promotion
	if piece.kind == "P":
		var promote_row = 7 if piece.side == 0 else 0
		if target.x == promote_row:
			if selected_piece_node:
				selected_piece_node.queue_free()
			state.board[target.x][target.y] = {"kind": "Q", "side": piece.side, "has_moved": true}
			_respawn_piece_node("Q", piece.side, target.x, target.y)
			move_stack[-1].piece.kind = "P"
			move_stack[-1]["promoted_to"] = "Q"

	_clear_highlights()
	move_stage = 0
	selected_piece_node = null

	# check and turn swap
	var opponent := 1 - current_turn
	var check_flag := _is_check(opponent)
	var mate_flag := check_flag and not _has_legal_move(opponent)
	var stale_flag := not check_flag and not _has_legal_move(opponent)

	if mate_flag:
		var winner := "White" if current_turn == 0 else "Black"
		_update_status("%s wins by checkmate!" % winner)
		_play_sfx("mate")
		game_over = true
		_on_game_over(winner.to_lower())
		return

	if stale_flag:
		_update_status("Stalemate. Draw.")
		game_over = true
		_play_sfx("check") # or make a draw sound if available
		_on_game_over("draw")
		return


	current_turn = opponent
	if check_flag:
		_update_status("Check!")
		_play_sfx("check")
	else:
		var side_name = "White" if current_turn == 0 else "Black"
		_update_status(side_name + " to move.")

	if captured != null:
		_play_sfx("capture")
	else:
		_play_sfx("move")

	if ai_plays_black and current_turn == 1 and not game_over:
		_ai_move()

# -------------------------------------------------------------------
# Highlighting
func _draw_highlight(square: Vector2i):
	_clear_highlights()
	var sq = _square_size()
	var sel := ColorRect.new()
	sel.color = highlight_sel_color
	sel.size = sq
	sel.position = _board_to_pixels(square.x, square.y) - sq * 0.5
	highlight_layer.add_child(sel)
	for t in legal_targets:
		var dot := ColorRect.new()
		dot.color = highlight_dst_color
		dot.size = sq * 0.28
		dot.position = _board_to_pixels(t.x, t.y) - dot.size * 0.5
		dot.z_index = 6
		highlight_layer.add_child(dot)

func _legal_moves_from(square: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var cell = state.board[square.x][square.y]
	if cell == null:
		return out
	for r in 8:
		for c in 8:
			var dst = Vector2i(r, c)
			if _is_legal_move(square, dst, cell):
				var saved_src = state.board[square.x][square.y]
				var saved_dst = state.board[r][c]
				state.board[r][c] = cell
				state.board[square.x][square.y] = null
				var legal = not _is_check(cell.side)
				state.board[square.x][square.y] = saved_src
				state.board[r][c] = saved_dst
				if legal:
					out.append(dst)
	return out

func _clear_highlights():
	legal_targets.clear()
	for c in highlight_layer.get_children():
		c.queue_free()

# -------------------------------------------------------------------
# Coordinate conversion
func _pixel_to_board(pos: Vector2) -> Vector2i:
	var cam := $Camera2D
	var xform: Transform2D = cam.get_global_transform_with_canvas().affine_inverse()
	var world_pos: Vector2 = xform * pos
	var tl = _board_top_left()
	var sq = _square_size()
	var local = world_pos - tl
	var c = int(floor(local.x / sq.x))
	var r = 7 - int(floor(local.y / sq.y))
	if r < 0 or r > 7 or c < 0 or c > 7:
		return Vector2i(-1, -1)
	return Vector2i(r, c)

# -------------------------------------------------------------------
# Rules
func _is_legal_move(src: Vector2i, dst: Vector2i, piece) -> bool:
	if src == dst:
		return false

	var target = state.board[dst.x][dst.y]
	if target != null and target.side == piece.side:
		return false

	var dr = dst.x - src.x
	var dc = dst.y - src.y
	var adr = abs(dr)
	var adc = abs(dc)

	match piece.kind:
		"P":
			var dir = 1 if piece.side == 0 else -1
			var start_row = 1 if piece.side == 0 else 6
			var enemy = 1 - piece.side
			var max_push = 2

			# Only white pawns get the triple push if player has upgrade
			if piece.side == 0 and has_node("/root/Game") and "pawn_boost" in Game.upgrades:
				max_push = 3

			# forward moves
			if dc == 0 and target == null:
				if dr == dir:
					return true
				if dr == 2 * dir and src.x == start_row and state.board[src.x + dir][src.y] == null:
					return true
				if dr == 3 * dir and src.x == start_row and max_push == 3 \
				and state.board[src.x + dir][src.y] == null and state.board[src.x + 2 * dir][src.y] == null:
					return true

			# captures (including en passant)
			if dr == dir and abs(dc) == 1:
				if target != null and target.side == enemy:
					return true
				if target == null and Vector2i(dst.x, dst.y) == last_double_pawn:
					return true

			return false


		"R":
			if dr == 0 or dc == 0:
				return _path_clear(src, dst)
			return false

		"B":
			if adr == adc:
				return _path_clear(src, dst)
			return false

		"Q":
			if dr == 0 or dc == 0 or adr == adc:
				return _path_clear(src, dst)
			return false

		"N":
			return (adr == 2 and adc == 1) or (adr == 1 and adc == 2)

		"K":
			if adr <= 1 and adc <= 1:
				return true
			if adr == 0 and adc == 2:
				return _can_castle(piece.side, dc > 0)
			return false

	return false


func _path_clear(src: Vector2i, dst: Vector2i) -> bool:
	var dr = sign(dst.x - src.x)
	var dc = sign(dst.y - src.y)
	var r = src.x + dr
	var c = src.y + dc
	while r != dst.x or c != dst.y:
		if state.board[r][c] != null:
			return false
		r += dr
		c += dc
	return true

func _can_castle(side: int, king_side: bool) -> bool:
	var row = 0 if side == 0 else 7
	var king_col = 4
	var rook_col = 7 if king_side else 0
	var step = 1 if king_side else -1
	var king = state.board[row][king_col]
	var rook = state.board[row][rook_col]
	if king == null or rook == null:
		return false
	if king.get("has_moved", false) or rook.get("has_moved", false):
		return false
	var c = king_col + step
	while c != rook_col:
		if state.board[row][c] != null:
			return false
		c += step
	if _is_check(side):
		return false
	var mid_col = king_col + step
	if _is_square_attacked(Vector2i(row, mid_col), 1 - side):
		return false
	if _is_square_attacked(Vector2i(row, king_col + 2 * step), 1 - side):
		return false
	return true

func _is_square_attacked(square: Vector2i, by_side: int) -> bool:
	for r in 8:
		for c in 8:
			var cell = state.board[r][c]
			if cell != null and cell.side == by_side:
				if _is_legal_move(Vector2i(r, c), square, cell):
					return true
	return false

func _is_check(side: int) -> bool:
	var king_pos: Vector2i = Vector2i(-1, -1)
	for r in 8:
		for c in 8:
			var cell = state.board[r][c]
			if cell != null and cell.side == side and cell.kind == "K":
				king_pos = Vector2i(r, c)
				break
	if king_pos.x == -1:
		return false
	return _is_square_attacked(king_pos, 1 - side)

func _has_legal_move(side: int) -> bool:
	for r in 8:
		for c in 8:
			var cell = state.board[r][c]
			if cell == null or cell.side != side:
				continue
			for tr in 8:
				for tc in 8:
					if _is_legal_move(Vector2i(r, c), Vector2i(tr, tc), cell):
						var saved_src = state.board[r][c]
						var saved_dst = state.board[tr][tc]
						state.board[tr][tc] = cell
						state.board[r][c] = null
						var legal = not _is_check(side)
						state.board[r][c] = saved_src
						state.board[tr][tc] = saved_dst
						if legal:
							return true
	return false

# -------------------------------------------------------------------
# AI
func _ai_collect_legal_moves(side: int) -> Array:
	var moves: Array = []
	for r in 8:
		for c in 8:
			var cell = state.board[r][c]
			if cell == null or cell.side != side:
				continue
			var src := Vector2i(r, c)
			for tr in 8:
				for tc in 8:
					var dst := Vector2i(tr, tc)
					if not _is_legal_move(src, dst, cell):
						continue
					var saved_src = state.board[r][c]
					var saved_dst = state.board[tr][tc]
					state.board[tr][tc] = cell
					state.board[r][c] = null
					var legal = not _is_check(side)
					state.board[r][c] = saved_src
					state.board[tr][tc] = saved_dst
					if legal:
						moves.append({
							"src": src,
							"dst": dst,
							"captured": state.board[dst.x][dst.y]
						})
	return moves

func _ai_move():
	if _ai_thinking:
		return
	_ai_thinking = true
	await get_tree().create_timer(0.25).timeout
	var moves := _ai_collect_legal_moves(1)
	if moves.is_empty():
		_ai_thinking = false
		return
	var captures: Array = []
	for m in moves:
		if m.captured != null:
			captures.append(m)
	var pool := captures if not captures.is_empty() else moves
	var choice = pool[randi() % pool.size()]
	_clear_highlights()
	selected_square = choice.src
	move_stage = 1
	selected_piece_node = _find_piece_node_at(choice.src)
	_try_move(choice.dst)
	_ai_thinking = false

# -------------------------------------------------------------------
# Undo
func undo_last_move() -> void:
	if move_stack.is_empty():
		return
	game_over = false

	# Undo one move
	_perform_undo_step()

	# If AI mode is active, undo twice (AI + player)
	if ai_plays_black and not move_stack.is_empty():
		_perform_undo_step()

	# Restore correct turn and update UI
	var side_name := "White" if current_turn == 0 else "Black"
	_update_status(side_name + " to move.")


# -------------------------------------------------------------------
# Performs one undo step safely and typed
func _perform_undo_step() -> void:
	var m: Dictionary = move_stack.pop_back()

	# Typed variables
	var moved_kind: String = String(m["piece"]["kind"])
	var moved_side: int = int(m["piece"]["side"])
	var moved_prev_has_moved: bool = bool(m.get("prev_has_moved", false))
	var moved: Dictionary = {
		"kind": moved_kind,
		"side": moved_side,
		"has_moved": moved_prev_has_moved
	}

	# --- Clear any nodes at src or dst before respawning ---
	var existing_src_node: Node2D = _find_piece_node_at(m["src"])
	if existing_src_node:
		existing_src_node.queue_free()
	var existing_dst_node: Node2D = _find_piece_node_at(m["dst"])
	if existing_dst_node:
		existing_dst_node.queue_free()

	# --- Restore board ---
	state.board[m["src"].x][m["src"].y] = moved
	state.board[m["dst"].x][m["dst"].y] = null
	_respawn_piece_node(moved_kind, moved_side, m["src"].x, m["src"].y)

	# --- Restore captured piece if any ---
	if m.has("captured") and m["captured"] != null:
		var cap: Dictionary = m["captured"]
		state.board[m["captured_pos"].x][m["captured_pos"].y] = cap
		_respawn_piece_node(
			String(cap["kind"]),
			int(cap["side"]),
			m["captured_pos"].x,
			m["captured_pos"].y
		)

	# --- Undo castling if needed ---
	if moved_kind == "K" and abs(m["dst"].y - m["src"].y) == 2:
		var row: int = int(m["src"].x)
		var rook_col_src: int = 7 if m["dst"].y > m["src"].y else 0
		var rook_col_dst: int = m["src"].y + (1 if m["dst"].y > m["src"].y else -1)
		var rook_piece: Dictionary = state.board[row][rook_col_dst]
		if rook_piece != null and rook_piece["kind"] == "R":
			state.board[row][rook_col_src] = rook_piece
			state.board[row][rook_col_dst] = null
			rook_piece["has_moved"] = bool(m.get("rook_prev_has_moved", false))
			var rook_node: Node2D = _find_piece_node_at(Vector2i(row, rook_col_dst))
			if rook_node:
				rook_node.queue_free()
			_respawn_piece_node("R", int(rook_piece["side"]), row, rook_col_src)

	# --- Update turn + EP marker ---
	last_double_pawn = m.get("ep_marker", Vector2i(-1, -1))
	current_turn = moved_side




# -------------------------------------------------------------------
# UI buttons
func _setup_ui_buttons():
	var ui := $UI/ButtonContainer
	var undo := Button.new()
	undo.text = "Undo"
	var ai_toggle := CheckButton.new()
	ai_toggle.text = "AI Black"
	ai_toggle.button_pressed = ai_plays_black
	ai_toggle.toggled.connect(func(v): ai_plays_black = v)
	var fen_btn := Button.new()
	fen_btn.text = "Copy FEN"
	fen_btn.pressed.connect(func():
		var fen = get_fen()
		DisplayServer.clipboard_set(fen)
		_update_status("Copied FEN:\n" + fen)
	)
	ui.add_child(undo)
	ui.add_child(ai_toggle)
	ui.add_child(fen_btn)
	ui.alignment = BoxContainer.ALIGNMENT_CENTER
	undo.pressed.connect(func(): undo_last_move())

# -------------------------------------------------------------------
# FEN export
func get_fen() -> String:
	var rows: Array[String] = []
	for r in range(7, -1, -1):
		var empty := 0
		var row := ""
		for c in 8:
			var cell = state.board[r][c]
			if cell == null:
				empty += 1
			else:
				if empty > 0:
					row += str(empty)
					empty = 0
				var k = cell.kind
				if cell.side == 0:
					row += k
				else:
					row += k.to_lower()
		if empty > 0:
			row += str(empty)
		rows.append(row)
	var turn := "w" if current_turn == 0 else "b"
	return "/".join(rows) + " " + turn

func _get_turn_count() -> int:
	# Move stack already tracks every half-move.
	return move_stack.size()


# -------------------------------------------------------------------
# Game over → report to GameManager

func _on_game_over(result: String) -> void:
	if game_over_reported:
		return
	game_over_reported = true

	# Player always controls white.
	var won := (result == "white")

	print("Battle ended. Won:", won, "Result:", result, "Turns:", _get_turn_count())

	if has_node("/root/Game"):
		Game.on_battle_end(won, _get_turn_count())
	else:
		
		push_warning("No Game singleton found. Result=%s turns=%d" % [result, _get_turn_count()])
		print("DEBUG result:", result)
