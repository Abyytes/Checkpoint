extends CanvasLayer
## Popup untuk mematikan hoax. Pasang di root HoaxPopup.tscn.
## Struktur node yang dibutuhkan ada di panduan (nama harus persis).

signal confirmed

const COLOR_ALIVE := Color(0.2, 0.8, 0.35)
const COLOR_DEAD := Color(0.9, 0.2, 0.2)

@onready var indicator: ColorRect = $Root/Center/Panel/Box/Indicator
@onready var kill_button: Button = $Root/Center/Panel/Box/KillButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # tetap bisa diklik saat game dipause
	kill_button.pressed.connect(_on_kill_pressed)
	hide()                                    # di editor biarkan terlihat, di game disembunyikan


func open() -> void:
	indicator.color = COLOR_ALIVE
	kill_button.disabled = false
	show()
	kill_button.grab_focus()                  # Enter / Space juga bisa menekan tombol


func _on_kill_pressed() -> void:
	kill_button.disabled = true
	var t := create_tween()
	t.tween_property(indicator, "color", COLOR_DEAD, 0.35)   # hijau -> merah
	t.tween_interval(0.25)
	await t.finished
	hide()
	confirmed.emit()
