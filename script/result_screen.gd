extends CanvasLayer
## Layar hasil setelah level selesai. Dibangun lewat kode.

signal next_pressed
signal retry_pressed
signal menu_pressed

var _root: Control
var _title: Label
var _name: Label
var _stats: Label
var _note: Label
var _next: Button
var _retry: Button


func _ready() -> void:
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
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(380, 0)
	panel.add_child(box)

	_title = _label("LEVEL SELESAI", 30)
	_title.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	box.add_child(_title)

	_name = _label("", 20)
	box.add_child(_name)

	_stats = _label("", 22)
	box.add_child(_stats)

	_note = _label("", 18)
	box.add_child(_note)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	_next = _button("Lanjut")
	_next.pressed.connect(func(): next_pressed.emit())
	row.add_child(_next)

	_retry = _button("Ulangi")
	_retry.pressed.connect(func(): retry_pressed.emit())
	row.add_child(_retry)

	var menu := _button("Menu")
	menu.pressed.connect(func(): menu_pressed.emit())
	row.add_child(menu)


func show_result(level_name: String, stats: Dictionary, has_next: bool) -> void:
	_name.text = level_name
	var t: float = stats.get("time", 0.0)
	_stats.text = "Waktu: %02d:%05.2f\nHoax: %d/%d\nKoin: %d/%d\nMati: %dx" % [
		int(t / 60.0), fmod(t, 60.0),
		stats.get("hoax", 0), stats.get("hoax_total", 0),
		stats.get("coins", 0), stats.get("coins_total", 0),
		stats.get("deaths", 0)]
	_next.visible = has_next
	_note.text = "" if has_next else "Semua level selesai!"
	_root.modulate.a = 0.0
	_root.show()
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.25)
	(_next if has_next else _retry).grab_focus()


func hide_screen() -> void:
	_root.hide()


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(110, 48)
	return b
