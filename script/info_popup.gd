extends CanvasLayer
## Popup informasi. Dua jenis:
##   show_dialog(title, body)          -> kotak tengah layar, efek ketik, emit "closed" saat ditutup
##   show_toast(title, body, durasi)   -> banner kecil di atas, hilang sendiri
## Seluruh UI dibangun lewat kode, jadi node ini cukup kosong di game.tscn.

signal closed

const TYPE_SPEED := 45.0          # karakter per detik

var _root: Control
var _title: Label
var _body: RichTextLabel
var _button: Button
var _toast: PanelContainer
var _toast_title: Label
var _toast_body: RichTextLabel
var _type_tween: Tween
var _toast_tween: Tween
var _toast_id := 0
var _dialog_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_dialog()
	_build_toast()


func is_open() -> bool:
	return _dialog_open


# ---------------------------------------------------------------
# DIALOG
# ---------------------------------------------------------------
func show_dialog(title: String, body: String) -> void:
	if _dialog_open:
		return
	_dialog_open = true
	_title.text = title
	_title.visible = title != ""
	_body.text = body
	_body.visible_ratio = 0.0
	_root.show()
	_button.grab_focus()

	var duration := maxf(0.2, _body.get_total_character_count() / TYPE_SPEED)
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(_body, "visible_ratio", 1.0, duration)


## Tekan pertama: tampilkan teks penuh. Tekan kedua: tutup.
func _advance() -> void:
	if not _dialog_open:
		return
	if _body.visible_ratio < 1.0:
		if _type_tween:
			_type_tween.kill()
		_body.visible_ratio = 1.0
		return
	_dialog_open = false
	_root.hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if _dialog_open and event.is_action_pressed("ui_cancel"):
		_advance()
		get_viewport().set_input_as_handled()


func _build_dialog() -> void:
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP     # klik tidak tembus ke game
	_root.hide()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.1, 0.11, 0.16, 0.97), 16))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	box.add_child(_title)

	box.add_child(HSeparator.new())

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(420, 0)
	_body.add_theme_font_size_override("normal_font_size", 20)
	_body.add_theme_font_size_override("bold_font_size", 20)
	box.add_child(_body)

	_button = Button.new()
	_button.text = "Lanjut"
	_button.custom_minimum_size = Vector2(0, 48)
	_button.pressed.connect(_advance)
	box.add_child(_button)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()


# ---------------------------------------------------------------
# TOAST
# ---------------------------------------------------------------
func show_toast(title: String, body: String, duration: float = 3.0) -> void:
	_toast_id += 1
	var id := _toast_id
	if _toast_tween:
		_toast_tween.kill()

	_toast_title.text = title
	_toast_title.visible = title != ""
	_toast_body.text = body
	_toast.modulate.a = 0.0
	_toast.show()

	await get_tree().process_frame            # tunggu ukuran panel dihitung ulang
	if id != _toast_id:
		return
	_toast.reset_size()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 80.0                  # di bawah HUD

	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(_toast.hide)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE     # tidak mengganggu swipe
	_toast.add_theme_stylebox_override("panel", _make_style(Color(0.1, 0.11, 0.16, 0.9), 12))
	_toast.hide()
	add_child(_toast)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_child(box)

	_toast_title = Label.new()
	_toast_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_title.add_theme_font_size_override("font_size", 20)
	_toast_title.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	box.add_child(_toast_title)

	_toast_body = RichTextLabel.new()
	_toast_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_body.bbcode_enabled = true
	_toast_body.fit_content = true
	_toast_body.scroll_active = false
	_toast_body.custom_minimum_size = Vector2(360, 0)
	_toast_body.add_theme_font_size_override("normal_font_size", 18)
	box.add_child(_toast_body)


func _make_style(color: Color, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(12)
	s.set_border_width_all(2)
	s.border_color = Color(0.45, 0.85, 1.0, 0.6)
	s.set_content_margin_all(margin)
	return s
