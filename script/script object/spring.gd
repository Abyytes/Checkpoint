@tool
extends Area2D
## Pegas. Saat player melintas, arah slide diganti ke arah pegas
## dan kecepatan dikali "boost" sampai player berhenti.
## Aset harus menghadap ATAS pada rotasi 0. Node berputar mengikuti "direction".
## Mandiri: tidak butuh script lain.

enum Dir { UP, RIGHT, DOWN, LEFT }

@export var direction: Dir = Dir.RIGHT:
	set(v):
		direction = v
		rotation = float(v) * PI / 2.0
## Pengali kecepatan di atas kecepatan player (1x/2x/3x)
@export_range(1.0, 5.0, 0.1) var boost: float = 2.0


func _ready() -> void:
	rotation = float(direction) * PI / 2.0
	add_to_group("spring")


func get_direction() -> Vector2i:
	match direction:
		Dir.UP: return Vector2i.UP
		Dir.RIGHT: return Vector2i.RIGHT
		Dir.DOWN: return Vector2i.DOWN
		_: return Vector2i.LEFT
