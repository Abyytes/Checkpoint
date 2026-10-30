class_name HoaxTile
extends Node2D

signal killed(tile: HoaxTile)

var is_alive := true


func _ready() -> void:
	add_to_group("hoax_tile")


func kill() -> void:
	if not is_alive:
		return
	is_alive = false
	killed.emit(self)
