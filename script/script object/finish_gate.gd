class_name FinishGate
extends Node2D
## Gerbang selesai. Tersembunyi sampai semua hoax mati.
## Posisinya dipindah ke PlayerStart oleh LevelBase.

var is_open := false


func _ready() -> void:
	close()


func close() -> void:
	is_open = false
	hide()


func appear() -> void:
	if is_open:
		return
	is_open = true
	show()
