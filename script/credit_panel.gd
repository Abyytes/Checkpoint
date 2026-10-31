class_name CreditPanel
extends CanvasLayer
## Panel credit: bisa digulir atas-bawah, ada tombol tutup, dan animasi buka/tutup.
## Isi teks diedit langsung di node Content (RichTextLabel, mendukung BBCode)
## pada CreditPanel.tscn.
##
## Cara tutup: tombol X, tombol Esc, atau klik area gelap di luar panel.
## Cara gulir: roda mouse, geser jari, panah atas/bawah, PageUp/PageDown.

signal opened
signal closed

@export_group("Animasi")
@export var open_time: float = 0.28
@export var close_time: float = 0.18
## Skala panel saat mulai muncul / saat selesai menutup
@export var start_scale: float = 0.88

@export_group("Gulir")
## Jarak gulir per penekanan panah (piksel)
@export var key_scroll_step: int = 60
## Gulir otomatis ala credit film (piksel/detik). 0 = mati.
## Berhenti sendiri begitu pemain menggulir manual.
@export var auto_scroll_speed: float = 0.0

@onready var dim: ColorRect = %Dim
@onready var panel: PanelContainer = %Panel
@onready var scroll: ScrollContainer = %Scroll
@onready var close_button: Button = %CloseButton

var _closing := false
var _opening := false
var _auto_active := false
var _auto_acc := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # tetap jalan saat game di-pause
	visible = false

	close_button.pressed.connect(close)
	dim.gui_input.connect(_on_dim_input)
	scroll.gui_input.connect(_on_scroll_input)
	scroll.get_v_scroll_bar().gui_input.connect(_on_scroll_input)

	# Kunci fokus keyboard/gamepad pada tombol X (tidak lari ke tombol di belakang panel)
	var self_path := close_button.get_path_to(close_button)
	close_button.focus_neighbor_top = self_path
	close_button.focus_neighbor_bottom = self_path
	close_button.focus_neighbor_left = self_path
	close_button.focus_neighbor_right = self_path
	close_button.focus_next = self_path
	close_button.focus_previous = self_path


func open() -> void:
	if visible or _opening or _closing:
		return
	_opening = true
	_size_panel()
	scroll.scroll_vertical = 0
	_auto_active = auto_scroll_speed > 0.0
	_auto_acc = 0.0

	dim.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.scale = Vector2.ONE * start_scale
	visible = true
	close_button.grab_focus()

	await get_tree().process_frame               # tunggu layout supaya ukuran panel benar
	panel.pivot_offset = panel.size / 2.0
	var t := create_tween().set_parallel(true)
	t.tween_property(dim, "modulate:a", 1.0, open_time)
	t.tween_property(panel, "modulate:a", 1.0, open_time)
	t.tween_property(panel, "scale", Vector2.ONE, open_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished
	_opening = false
	opened.emit()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_auto_active = false
	var t := create_tween().set_parallel(true)
	t.tween_property(dim, "modulate:a", 0.0, close_time)
	t.tween_property(panel, "modulate:a", 0.0, close_time)
	t.tween_property(panel, "scale", Vector2.ONE * start_scale, close_time) \
		.set_ease(Tween.EASE_IN)
	await t.finished
	visible = false
	_closing = false
	_opening = false
	closed.emit()


func _process(delta: float) -> void:
	if not visible or not _auto_active:
		return
	_auto_acc += auto_scroll_speed * delta
	var step := int(_auto_acc)
	if step <= 0:
		return
	_auto_acc -= step
	var before := scroll.scroll_vertical
	scroll.scroll_vertical += step
	if scroll.scroll_vertical == before:         # sudah mentok di bawah
		_auto_active = false


func _input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return

	var delta := 0
	if event.is_action_pressed("ui_down", true):
		delta = key_scroll_step
	elif event.is_action_pressed("ui_up", true):
		delta = -key_scroll_step
	elif event.is_action_pressed("ui_page_down", true):
		delta = maxi(int(scroll.size.y * 0.9), key_scroll_step)
	elif event.is_action_pressed("ui_page_up", true):
		delta = -maxi(int(scroll.size.y * 0.9), key_scroll_step)
	if delta != 0:
		_auto_active = false
		scroll.scroll_vertical += delta
		get_viewport().set_input_as_handled()


## Klik area gelap di luar panel menutup panel
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		close()


## Pemain menggulir sendiri: hentikan gulir otomatis
func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenDrag \
			or (event is InputEventMouseMotion and event.button_mask != 0):
		_auto_active = false


## Sesuaikan ukuran panel dengan layar (penting untuk layar HP yang kecil)
func _size_panel() -> void:
	var vp := get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(minf(560.0, vp.x * 0.92), minf(440.0, vp.y * 0.86))
