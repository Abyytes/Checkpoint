extends Button
## Judul game yang berfungsi sebagai tombol Credit. Saat ditekan, membuka CreditPanel
## (anak scene ini, node "CreditPanel"). Cukup di-instance ke main menu, tanpa sambungan sinyal.
##
## Teks judul diatur lewat properti Text di Inspector.

signal opened
signal closed

@export_group("Animasi")
## Skala saat kursor di atas tombol atau tombol terfokus
@export var hover_scale: float = 1.08
@export var hover_time: float = 0.12
## Skala singkat saat ditekan
@export var press_scale: float = 0.94

@onready var credit_panel: CreditPanel = %CreditPanel

var _tween: Tween
var _opened_by_keyboard := false


func _ready() -> void:
	pivot_offset = size / 2.0
	resized.connect(func() -> void: pivot_offset = size / 2.0)

	mouse_entered.connect(_refresh_hover)
	mouse_exited.connect(_refresh_hover)
	focus_entered.connect(_refresh_hover)
	focus_exited.connect(_refresh_hover)
	pressed.connect(_on_pressed)

	credit_panel.opened.connect(func() -> void: opened.emit())
	credit_panel.closed.connect(_on_panel_closed)


func _refresh_hover() -> void:
	_scale_to(hover_scale if (is_hovered() or has_focus()) else 1.0, hover_time)


func _on_pressed() -> void:
	# Ditekan lewat keyboard/gamepad (kursor tidak di atas tombol)? Kembalikan fokus saat panel ditutup.
	_opened_by_keyboard = not is_hovered()
	if not _opened_by_keyboard:
		release_focus()                          # supaya tombol tidak "menempel" membesar setelah klik mouse
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * press_scale, 0.06)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	credit_panel.open()


func _on_panel_closed() -> void:
	if _opened_by_keyboard:
		grab_focus()
	else:
		_scale_to(1.0, hover_time)
	closed.emit()


func _scale_to(target: float, duration: float) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * target, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
