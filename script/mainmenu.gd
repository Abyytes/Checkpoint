extends Control
## Main menu.
##   MULAI      belum ada save -> Game Baru -> cutscene -> game
##              sudah ada save -> popup Lanjutkan / Game Baru
##   PENGATURAN membuka SettingsPanel
##   KELUAR     menutup game (disembunyikan di versi web)
##   Judul      = CreditButton, membuka panel credit (tidak perlu disambung di sini)
##
## Scene tujuan dipilih lewat Inspector (properti Cutscene Scene dan Game Scene).
## Cutscene (cutscene1.gd) pindah ke Level_1 sendiri saat selesai.

@export_file("*.tscn") var cutscene_scene: String = "res://cutscene/cutscene1.tscn"
@export_file("*.tscn") var game_scene: String = "res://tscn/game.tscn"
## Lama pesan error tampil (detik)
@export var message_time: float = 4.0

@onready var popup: Control = %startpopup
@onready var start_button: Button = %start
@onready var settings_button: Button = %settings
@onready var exit_button: Button = %exit
@onready var continue_button: Button = %continue
@onready var newgame_button: Button = %newgame
@onready var back_button: Button = %back
@onready var message_label: Label = %message
@onready var settings_panel: Node = %SettingsPanel      # SettingsPanel.tscn (settings_panel.gd)

var _busy := false
var _message_token := 0


func _ready() -> void:
	popup.visible = false
	message_label.visible = false
	exit_button.visible = not OS.has_feature("web")      # tombol keluar tidak berfungsi di browser

	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(func() -> void: settings_panel.open())
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	continue_button.pressed.connect(_on_continue_pressed)
	newgame_button.pressed.connect(_new_game)
	back_button.pressed.connect(_close_popup)
	settings_panel.closed.connect(func() -> void: settings_button.grab_focus())

	_lock_focus([continue_button, newgame_button, back_button])
	start_button.grab_focus()

	for path in [cutscene_scene, game_scene]:
		if path == "" or not ResourceLoader.exists(path):
			push_warning("MainMenu: scene '%s' tidak ditemukan. Atur di Inspector node mainmenu." % path)


# ---------------------------------------------------------------
# ALUR
# ---------------------------------------------------------------
func _on_start_pressed() -> void:
	if SaveManager.has_save():
		_open_popup()          # sudah ada save: tanya Lanjutkan atau Game Baru
	else:
		_new_game()


func _new_game() -> void:
	if _busy or not _scene_ok(cutscene_scene):
		return
	SaveManager.new_game()     # hanya reset di memori; save lama aman sampai pemain menyimpan
	_go(cutscene_scene)


func _on_continue_pressed() -> void:
	if _busy or not _scene_ok(game_scene):
		return
	if not SaveManager.load_game():
		_show_message("Save tidak bisa dibaca. Pilih Game Baru.")
		continue_button.disabled = true
		newgame_button.grab_focus()
		return
	_go(game_scene)


func _go(path: String) -> void:
	_busy = true
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		_busy = false
		push_error("MainMenu: gagal pindah ke %s (%s)" % [path, error_string(err)])
		_show_message("Gagal membuka scene: %s" % path)


func _scene_ok(path: String) -> bool:
	if path != "" and ResourceLoader.exists(path):
		return true
	push_error("MainMenu: scene '%s' tidak ditemukan. Atur di Inspector node mainmenu." % path)
	_show_message("Scene tujuan tidak ditemukan: %s" % path)
	return false


# ---------------------------------------------------------------
# POPUP LANJUTKAN / GAME BARU
# ---------------------------------------------------------------
func _open_popup() -> void:
	continue_button.disabled = false
	popup.visible = true
	continue_button.grab_focus()


func _close_popup() -> void:
	popup.visible = false
	start_button.grab_focus()


## Esc menutup popup
func _unhandled_input(event: InputEvent) -> void:
	if popup.visible and event.is_action_pressed("ui_cancel"):
		_close_popup()
		get_viewport().set_input_as_handled()


## Kunci fokus keyboard/gamepad di dalam popup (tidak lari ke tombol menu di belakangnya)
func _lock_focus(items: Array[Button]) -> void:
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


# ---------------------------------------------------------------
# PESAN ERROR
# ---------------------------------------------------------------
func _show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true
	_message_token += 1
	var token := _message_token
	await get_tree().create_timer(message_time).timeout
	if token == _message_token and is_instance_valid(message_label):
		message_label.visible = false
