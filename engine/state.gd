extends Node
class_name GameState

const N := 8
enum Side { WHITE, BLACK }

var board: Array = []

func _init():
	board.resize(N)
	for r in N:
		board[r] = []
		for c in N:
			board[r].append(null)
	_setup_starting_position()

# -------------------------------------------------------------------
# Standard starting position
func _setup_starting_position():
	# Pawns
	for c in N:
		board[1][c] = {"kind": "P", "side": Side.WHITE, "has_moved": false}
		board[6][c] = {"kind": "P", "side": Side.BLACK, "has_moved": false}

	# Rooks
	board[0][0] = {"kind": "R", "side": Side.WHITE, "has_moved": false}
	board[0][7] = {"kind": "R", "side": Side.WHITE, "has_moved": false}
	board[7][0] = {"kind": "R", "side": Side.BLACK, "has_moved": false}
	board[7][7] = {"kind": "R", "side": Side.BLACK, "has_moved": false}

	# Knights
	board[0][1] = {"kind": "N", "side": Side.WHITE, "has_moved": false}
	board[0][6] = {"kind": "N", "side": Side.WHITE, "has_moved": false}
	board[7][1] = {"kind": "N", "side": Side.BLACK, "has_moved": false}
	board[7][6] = {"kind": "N", "side": Side.BLACK, "has_moved": false}

	# Bishops
	board[0][2] = {"kind": "B", "side": Side.WHITE, "has_moved": false}
	board[0][5] = {"kind": "B", "side": Side.WHITE, "has_moved": false}
	board[7][2] = {"kind": "B", "side": Side.BLACK, "has_moved": false}
	board[7][5] = {"kind": "B", "side": Side.BLACK, "has_moved": false}

	# Queens
	board[0][3] = {"kind": "Q", "side": Side.WHITE, "has_moved": false}
	board[7][3] = {"kind": "Q", "side": Side.BLACK, "has_moved": false}

	# Kings
	board[0][4] = {"kind": "K", "side": Side.WHITE, "has_moved": false}
	board[7][4] = {"kind": "K", "side": Side.BLACK, "has_moved": false}
