extends CanvasLayer
## Popup hoax versi paling sederhana: label "HOAX" dan satu tombol "Delete".
## Kontrak dengan LevelBase (tidak berubah dari sebelumnya):
##   - open()          dipanggil LevelBase saat player berhenti di tile hoax
##   - sinyal confirmed dipancarkan saat tombol ditekan. LevelBase lalu mematikan
##                      hoax-nya dan membuka kunci player
##
## Node yang dikenali dari NAMA-nya: Root/Center/Box/Title (Label) dan
## Root/Center/Box/DeleteButton (Button). Desain dan posisinya bebas diubah di editor.

signal confirmed

## Teks label. Bisa juga diubah langsung di node Title
@export var label_text: String = "HOAX"
## Teks tombol. Bisa juga diubah langsung di node DeleteButton
@export var button_text: String = "Delete"

var _is_open := false

@onready var _label := get_node_or_null("Root/Center/Box/Title") as Label
@onready var _button := get_node_or_null("Root/Center/Box/DeleteButton") as Button


func _ready() -> void:
	visible = false
	if _label != null:
		_label.text = label_text
	if _button != null:
		_button.text = button_text
		_button.pressed.connect(_on_delete_pressed)


## Tampilkan popup. Tombol langsung terfokus, jadi Enter/Spasi juga bisa menekannya
func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	if _button != null:
		_button.grab_focus()


func _on_delete_pressed() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	confirmed.emit()
