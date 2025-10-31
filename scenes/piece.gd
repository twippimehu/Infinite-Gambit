extends Node2D

@export var kind: String        # "P","R","N","B","Q","K"
@export var side: int           # 0 = WHITE, 1 = BLACK

func _ready():
	var icon: Sprite2D = $Icon
	var base_path = "res://assets/chess/vector-chess-pieces/"
	var folder = "White" if side == 0 else "Black"

	var files := {
		"P": "Pawn %s Outline 288px.png" % folder,
		"R": "Rook %s Outline 288px.png" % folder,
		"N": "Knight %s Outline 288px.png" % folder,
		"B": "Bishop %s Outline 288px.png" % folder,
		"Q": "Queen %s Outline 288px.png" % folder,
		"K": "King %s Outline 288px.png" % folder
	}

	var path = "%s%s/%s" % [base_path, folder, files[kind]]
	var tex: Texture2D = load(path)
	if tex == null:
		push_warning("Missing texture: " + path)
		return

	icon.texture = tex
	icon.centered = true  # keep pivot centered
	_fit_to_square(icon)

func _fit_to_square(icon: Sprite2D):
	var board = get_parent()
	while board and not board.has_method("_square_size"):
		board = board.get_parent()
	if board == null:
		return

	var sq: Vector2 = board._square_size()
	var tex_size: Vector2 = icon.texture.get_size()
	icon.scale = Vector2(sq.x / tex_size.x, sq.y / tex_size.y) * 0.9


# center node position in its square
func _center_on_square():
	var board = get_parent()
	while board and not board.has_method("_square_size"):
		board = board.get_parent()
	if board == null:
		return

	var sq = board._square_size()
	position += sq * 0.5
