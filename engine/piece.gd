extends Node2D
class_name Piece

@export var kind: String
@export var side: int
var has_moved: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_update_texture()

func _update_texture() -> void:
	var prefix := "white_" if side == 0 else "black_"
	var path := "res://assets/chess/vector-chess-pieces/" + prefix + kind.to_lower() + "_288px.png"
	var tex := load(path)
	if tex:
		sprite.texture = tex

func move_to_square(target: Vector2) -> void:
	var tween := get_tree().create_tween()
	tween.tween_property(self, "position", target, 0.12)

func set_data(p: Dictionary) -> void:
	kind = p["kind"]
	side = p["side"]
	has_moved = p.get("has_moved", false)
	_update_texture()

func get_data() -> Dictionary:
	return {
		"kind": kind,
		"side": side,
		"has_moved": has_moved
	}
