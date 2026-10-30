class_name Coin
extends Area2D

var is_collected := false


func _ready() -> void:
	add_to_group("coin")


func collect() -> void:
	if is_collected:
		return
	is_collected = true
	hide()
