extends CanvasLayer
## HUD saat bermain: HANYA timer dan tombol pause.
## HUD ini bagian dari game.tscn, jadi scene lain (cutscene, menu) tidak punya HUD.
## Untuk menyembunyikannya sementara di dalam game.tscn: panggil game.set_gameplay_ui(false).

signal pause_pressed

var _time: Label


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE        # swipe yang dimulai di sini tetap jalan
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	_time = Label.new()
	_time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time.add_theme_font_size_override("font_size", 28)
	_time.add_theme_color_override("font_outline_color", Color.BLACK)
	_time.add_theme_constant_override("outline_size", 6)
	row.add_child(_time)

	var pause := Button.new()
	pause.text = "Pause"
	pause.focus_mode = Control.FOCUS_NONE       # Enter/Space tidak ikut menekan tombol ini
	pause.custom_minimum_size = Vector2(96, 48)
	pause.pressed.connect(func(): pause_pressed.emit())
	row.add_child(pause)

	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	set_time(0.0)


func set_time(seconds: float) -> void:
	_time.text = "%02d:%05.2f" % [int(seconds / 60.0), fmod(seconds, 60.0)]
