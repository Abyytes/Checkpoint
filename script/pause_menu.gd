extends CanvasLayer
## Menu pause. Esc membuka dan menutupnya. game.gd mengatur "can_open"
## (false saat layar hasil atau cutscene, supaya pause tidak bisa dibuka).
## Dibangun lewat kode. Memakai SettingsPanel yang sama dengan main menu.

signal restart_pressed
signal menu_pressed

@export_file("*.tscn") var settings_scene: String = "res://tscn/SettingsPanel.tscn"

var can_open := false

var _root: Control
var _resume: Button
var _settings_button: Button
var _settings: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS        # tetap jalan saat game di-pause
	_build()


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if _root.visible or not can_open:
		return
	get_tree().paused = true
	_root.show()
	_resume.grab_focus()


func close() -> void:
	if not _root.visible:
		return
	_root.hide()
	get_tree().paused = false


## Esc yang sudah dipakai popup info atau panel pengaturan tidak sampai ke sini,
## jadi tidak ada tabrakan.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _root.visible:
		close()
	elif can_open:
		open()
	else:
		return
	get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.hide()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.16, 0.97)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(300, 0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "JEDA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

	_resume = _button("Lanjut", box)
	_resume.pressed.connect(close)

	var restart := _button("Ulangi Level", box)
	restart.pressed.connect(func():
		close()
		restart_pressed.emit())

	_settings_button = _button("Pengaturan", box)

	var menu := _button("Menu Utama", box)
	menu.pressed.connect(func():
		close()                      # buka pause dulu, kalau tidak scene berikutnya ikut terpause
		menu_pressed.emit())

	_load_settings()


func _load_settings() -> void:
	var packed: PackedScene = null
	if settings_scene != "":
		packed = load(settings_scene) as PackedScene
	if packed == null:
		_settings_button.hide()
		return
	_settings = packed.instantiate() as CanvasLayer
	add_child(_settings)
	_settings.layer = layer + 1                  # harus di atas menu pause
	_settings_button.pressed.connect(_settings.open)
	_settings.closed.connect(func(): _settings_button.grab_focus())


func _button(text: String, parent: Node) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	parent.add_child(b)
	return b
