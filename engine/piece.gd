extends Node2D
class_name Piece

@export var kind: String = "P"   # "P","N","B","R","Q","K"
@export var side: int = 0        # 0 white, 1 black

@onready var icon: Sprite2D = $Icon

func _ready() -> void:
	_apply_texture()

func set_kind(new_kind: String) -> void:
	kind = new_kind
	_apply_texture()

func set_side(new_side: int) -> void:
	side = new_side
	_apply_texture()

func _apply_texture() -> void:
	if icon == null:
		return

	var map := {
		"P": "Pawn",
		"N": "Knight",
		"B": "Bishop",
		"R": "Rook",
		"Q": "Queen",
		"K": "King"
	}

	var side_folder: String = "White" if side == 0 else "Black"
	var piece_name: String = map.get(kind, "Pawn")

	var base := "res://assets/chess/vector-chess-pieces/%s/" % side_folder
	var path := "%s%s %s Outline 288px.png" % [base, piece_name, side_folder]

	var tex: Texture2D = load(path)
	if tex:
		icon.texture = tex
		var sq_size := 80.0
		if get_tree().get_first_node_in_group("board") and get_tree().get_first_node_in_group("board").has_method("_square_size"):
			sq_size = get_tree().get_first_node_in_group("board")._square_size().x
		var tex_size := tex.get_size()
		var scale: float = min(sq_size / tex_size.x, sq_size / tex_size.y) * 0.9
		icon.scale = Vector2(scale, scale)
	else:
		push_warning("Missing texture: %s" % path)
