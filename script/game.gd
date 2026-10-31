extends Node2D
## Scene utama saat bermain. Memuat level satu per satu dan menghubungkan
## HUD, pause menu, popup info, dan layar hasil ke level yang sedang aktif.
## Urutan level diatur lewat properti "Levels" di Inspector.

## Seret scene level ke sini, urutan = urutan main
@export var levels: Array[PackedScene] = []
## Scene yang dibuka tombol Menu Utama (sesuaikan dengan path mainmenu-mu)
@export_file("*.tscn") var menu_scene: String = "res://tscn/mainmenu.tscn"

@onready var holder: Node2D = $LevelHolder
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var info_popup: CanvasLayer = $InfoPopup
@onready var result: CanvasLayer = $ResultScreen

var index := 0                 # 0-based; nomor level yang tampil = index + 1
var level: LevelBase
## HUD milik level yang sedang aktif (node bernama "HUD" di dalam scene level). Boleh null.
var hud: CanvasLayer
var _deaths := 0
var _time := 0.0               # waktu level ini (detik)
var _timing := false


func _ready() -> void:
	pause_menu.restart_pressed.connect(restart_level)
	pause_menu.menu_pressed.connect(go_to_menu)
	result.next_pressed.connect(next_level)
	result.retry_pressed.connect(restart_level)
	result.menu_pressed.connect(go_to_menu)
	info_popup.closed.connect(_on_info_closed)

	if levels.is_empty():
		push_error("Game: isi daftar 'Levels' di Inspector node game.")
		return
	load_level(SaveManager.get_current_level() - 1)


func _process(delta: float) -> void:
	# Node ini ikut berhenti saat game di-pause, jadi timer otomatis berhenti.
	# Timer juga berhenti selama popup info dibaca.
	if not _timing or info_popup.is_open():
		return
	_time += delta
	SaveManager.data["time"] += delta       # total waktu bermain (kunci "time" di save)
	if hud != null:
		hud.set_time(_time)


func load_level(i: int) -> void:
	if levels.is_empty():
		return
	index = clampi(i, 0, levels.size() - 1)
	_deaths = 0
	_time = 0.0
	result.hide_screen()

	# remove_child (bukan hanya queue_free) supaya level lama langsung keluar dari
	# group "player", "coin", dll. dan tidak mengganggu level baru.
	if level != null:
		holder.remove_child(level)
		level.queue_free()
		level = null
		hud = null

	var inst := levels[index].instantiate() as LevelBase
	if inst == null:
		push_error("Game: scene level ke-%d bukan turunan LevelBase." % (index + 1))
		return

	inst.level_completed.connect(_on_level_completed)
	inst.player_died.connect(func(): _deaths += 1)
	inst.info_requested.connect(_on_info_requested)

	holder.add_child(inst)
	level = inst

	# HUD ada di dalam scene level, jadi diambil setelah level masuk tree
	hud = inst.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.pause_pressed.connect(pause_menu.open)
		hud.set_time(0.0)
	else:
		push_warning("Game: level '%s' tidak punya node HUD." % inst.level_title)

	SaveManager.set_current_level(index + 1)
	set_gameplay_ui(true)


func restart_level() -> void:
	if levels.is_empty():
		return
	load_level(index)


func next_level() -> void:
	if levels.is_empty():
		return
	load_level(index + 1)


func go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(menu_scene)


## Tampilkan/sembunyikan HUD dan izinkan/larang pause.
## Pakai ini kalau nanti ada cutscene yang diputar DI DALAM game.tscn:
##   set_gameplay_ui(false) sebelum cutscene, set_gameplay_ui(true) sesudahnya.
## Cutscene yang berupa scene sendiri (cutscene1.tscn) tidak perlu ini: HUD memang tidak ada di sana.
func set_gameplay_ui(on: bool) -> void:
	if hud != null:
		hud.visible = on
	pause_menu.can_open = on
	_timing = on and level != null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_R:
		restart_level()


# ---------------------------------------------------------------
# EVENT DARI LEVEL
# ---------------------------------------------------------------
func _on_level_completed() -> void:
	_timing = false
	pause_menu.can_open = false
	var stats := {
		"coins": level.coins_collected,
		"coins_total": level.total_coins,
		"hoax": level.hoax_killed,
		"hoax_total": level.hoax_total,
		"deaths": _deaths,
		"time": snappedf(_time, 0.01),
	}
	SaveManager.complete_level(index + 1, stats)
	var has_next := index + 1 < levels.size()
	var lvl := level
	await get_tree().create_timer(0.4).timeout
	if level != lvl:
		return                       # player sudah restart / pindah level selama jeda
	result.show_result(level.level_title, stats, has_next)


func _on_info_requested(zone: InfoZone) -> void:
	if zone.blocking:
		info_popup.show_dialog(zone.title, zone.body)
	else:
		info_popup.show_toast(zone.title, zone.body, zone.toast_duration)


## Hanya dialog yang mengirim "closed", jadi aman membuka kunci player di sini
func _on_info_closed() -> void:
	if level != null:
		level.player.unlock()
