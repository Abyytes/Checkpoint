extends CanvasLayer
## Panel pengaturan yang dipakai bersama oleh main menu dan pause menu.
## Pasang di root SettingsPanel.tscn. Butuh autoload "SettingsManager".
##
## Cara pakai dari scene lain:
##     settings_panel.open()
##     settings_panel.closed.connect(...)   # mis. kembalikan fokus ke tombol Settings

signal closed

@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var mute_check: CheckButton = %MuteCheck
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var back_button: Button = %BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # tetap bisa dipakai saat game di-pause
	visible = false

	music_slider.value_changed.connect(_on_music_changed)
	mute_check.toggled.connect(_on_mute_toggled)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(close)

	# Sembunyikan opsi layar penuh di platform yang tidak mendukungnya
	fullscreen_check.visible = SettingsManager.fullscreen_supported()
	_lock_focus()


func open() -> void:
	_sync_from_settings()
	visible = true
	music_slider.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	SettingsManager.flush()
	closed.emit()


## Esc / tombol batal menutup panel. Memakai _input supaya diproses sebelum pause menu
## di belakangnya, dan event ditandai selesai agar pause menu tidak ikut menutup.
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Kunci fokus keyboard/gamepad di dalam panel, supaya panah atas/bawah
## tidak lari ke tombol menu di belakangnya
func _lock_focus() -> void:
	var items: Array[Control] = []
	for c: Control in [music_slider, mute_check, fullscreen_check, back_button]:
		if c.visible:
			items.append(c)
	for i in items.size():
		var c := items[i]
		var up := items[(i - 1 + items.size()) % items.size()]
		var down := items[(i + 1) % items.size()]
		c.focus_neighbor_top = c.get_path_to(up)
		c.focus_neighbor_bottom = c.get_path_to(down)
		c.focus_previous = c.get_path_to(up)
		c.focus_next = c.get_path_to(down)
		c.focus_neighbor_left = c.get_path_to(c)
		c.focus_neighbor_right = c.get_path_to(c)


## Tampilkan nilai terkini tanpa memicu sinyal (supaya tidak menyimpan ulang)
func _sync_from_settings() -> void:
	music_slider.set_value_no_signal(SettingsManager.music_volume)
	_update_music_label(SettingsManager.music_volume)
	mute_check.set_pressed_no_signal(SettingsManager.muted)
	# Pakai mode layar yang sebenarnya aktif (pemain mungkin menekan F11/Esc di browser)
	fullscreen_check.set_pressed_no_signal(SettingsManager.is_fullscreen())


func _on_music_changed(value: float) -> void:
	SettingsManager.set_music_volume(value)
	_update_music_label(value)


func _on_mute_toggled(pressed: bool) -> void:
	SettingsManager.set_muted(pressed)


func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsManager.set_fullscreen(pressed)


func _update_music_label(value: float) -> void:
	music_value.text = "%d%%" % roundi(value * 100.0)
