extends Control

const GAME_SCENE := "res://game.tscn"   # sesuaikan path scene game-mu

@onready var popup: CanvasLayer = %startpopup
@onready var continue_button: Button = %continue
@onready var newgame_button: Button = %newgame

func _ready() -> void:
	popup.visible = false

	%start.pressed.connect(_on_start_pressed)
	%exit.pressed.connect(_on_exit_pressed)
	%settings.pressed.connect(_on_exit_pressed)
	%Credit.pressed.connect(_on_credit_pressed)

	continue_button.pressed.connect(_on_continue_pressed)
	newgame_button.pressed.connect(_on_newgame_pressed)
	%back.pressed.connect(_close_popup)

	%start.grab_focus()

# --- Menu utama ---
func _on_start_pressed() -> void:
	if not SaveManager.has_save():
		# Belum ada save: langsung mulai game baru
		_start_new_game()
		return

	# Sudah ada save: tampilkan pilihan Continue / New Game
	popup.visible = true
	continue_button.grab_focus()

# --- Popup ---

func _start_new_game() -> void:
	SaveManager.new_game()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_credit_pressed() -> void:
	print("Credit ditekan")   # ganti dengan pindah ke scene credit

# --- Popup ---
func _on_continue_pressed() -> void:
	SaveManager.load_game()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_newgame_pressed() -> void:
	SaveManager.new_game()
	get_tree().change_scene_to_file(GAME_SCENE)

func _close_popup() -> void:
	popup.visible = false
	%start.grab_focus()

# Esc menutup popup
func _unhandled_input(event: InputEvent) -> void:
	if popup.visible and event.is_action_pressed("ui_cancel"):
		_close_popup()
		get_viewport().set_input_as_handled()
