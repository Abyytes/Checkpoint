extends Node
## Pembungkus game: memuat level ke LevelHolder dan menampilkan HUD
## (nama level, timer, tombol pause, menu jeda, layar level selesai).
## HUD otomatis muncul di semua level yang ada di daftar `levels`.
##
## Menambah level: cukup simpan scene bernama Level_2.tscn, Level_3.tscn, dst. di folder
## yang sama dengan Level_1 -> otomatis ditemukan (lihat `auto_discover`).
## Cara manual tetap bisa: isi `levels` di Inspector (kalau lebih panjang dari hasil scan,
## daftar manual yang dipakai).
## Level dianggap selesai kalau level (atau Objects/FinishGate) memancarkan salah satu
## sinyal di `finish_signals`. Atau panggil `complete_level()` dari script level.

## Daftar level berurutan. Level_1 = uid://dmwa85x6tsu5h
@export var levels: Array[String] = ["uid://dmwa85x6tsu5h"]
## true = cari otomatis Level_1.tscn, Level_2.tscn, ... di folder level.
@export var auto_discover: bool = true
## Folder pencarian. Kosong = folder tempat levels[0] berada.
@export_dir var level_folder: String = ""
## Scene setelah level TERAKHIR selesai (mis. cutscene ending). Kosong = kembali ke menu.
@export_file("*.tscn") var ending_scene: String = ""
## Mulai dari level ke berapa (0 = pertama)
@export var start_index: int = 0
## Scene menu utama (mainmenu.tscn)
@export_file("*.tscn") var menu_scene: String = "uid://cg31uyyaecm63"
## Nama sinyal "level selesai" yang dicari di level / FinishGate
@export var finish_signals: PackedStringArray = [
	"level_completed", "level_finished", "level_complete", "goal_reached",
	"reached_goal", "finished", "completed", "player_entered",
]

@onready var holder: Node = %LevelHolder
@onready var level_label: Label = %LevelLabel
@onready var timer_label: Label = %TimerLabel
@onready var pause_button: Button = %PauseButton
@onready var pause_panel: Control = %PausePanel
@onready var pause_resume: Button = %PauseResume
@onready var pause_restart: Button = %PauseRestart
@onready var pause_menu: Button = %PauseMenu
@onready var result_panel: Control = %ResultPanel
@onready var result_time: Label = %ResultTime
@onready var result_next: Button = %ResultNext
@onready var result_menu: Button = %ResultMenu

var _index := 0
var _level: Node = null
var _time := 0.0
var _running := false


func _ready() -> void:
	pause_panel.visible = false
	result_panel.visible = false
	pause_button.pressed.connect(func() -> void: _set_paused(true))
	pause_resume.pressed.connect(func() -> void: _set_paused(false))
	pause_restart.pressed.connect(restart_level)
	pause_menu.pressed.connect(go_menu)
	result_next.pressed.connect(next_level)
	result_menu.pressed.connect(go_menu)
	if auto_discover:
		var found := _discover_levels()
		if found.size() > levels.size():
			levels = found
	print("Game: daftar level = ", levels)
	load_level(clampi(start_index, 0, maxi(levels.size() - 1, 0)))


func _process(delta: float) -> void:
	if _running and not get_tree().paused:
		_time += delta
		timer_label.text = _fmt(_time)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not result_panel.visible:
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------
# LEVEL
# ---------------------------------------------------------------
func load_level(i: int) -> void:
	if i < 0 or i >= levels.size():
		push_error("Game: indeks level %d tidak ada." % i)
		return
	var packed := load(levels[i]) as PackedScene
	if packed == null:
		push_error("Game: gagal memuat level '%s'." % levels[i])
		return

	if _level != null:
		holder.remove_child(_level)
		_level.queue_free()
		_level = null

	_index = i
	_level = packed.instantiate()
	holder.add_child(_level)
	_hook_finish(_level)
	_hook_finish(_level.get_node_or_null("Objects/FinishGate"))

	_time = 0.0
	_running = true
	timer_label.text = _fmt(0.0)
	level_label.text = "Level %d" % (i + 1)
	result_panel.visible = false
	pause_panel.visible = false
	get_tree().paused = false


func restart_level() -> void:
	load_level(_index)


func next_level() -> void:
	if _index + 1 < levels.size():
		load_level(_index + 1)
	else:
		_finish_game()


## Setelah level terakhir: ke ending_scene kalau ada, kalau tidak ke menu.
func _finish_game() -> void:
	get_tree().paused = false
	if ending_scene != "" and ResourceLoader.exists(ending_scene):
		get_tree().change_scene_to_file(ending_scene)
	else:
		go_menu()


func go_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(menu_scene)


## Dipanggil saat level selesai (otomatis lewat sinyal, atau manual dari script level).
func complete_level(_a = null, _b = null) -> void:
	if not _running:
		return
	_running = false
	result_time.text = "Waktu: " + _fmt(_time)
	result_next.text = "Level Berikutnya" if _index + 1 < levels.size() else "Selesai"
	result_panel.visible = true
	result_next.grab_focus()


## Sambungkan sinyal "selesai" milik node target ke complete_level().
func _hook_finish(target: Node) -> void:
	if target == null:
		return
	var names: Array[String] = []
	for sig in target.get_signal_list():
		names.append(sig["name"])
	for n in finish_signals:
		if n in names and not target.is_connected(n, complete_level):
			target.connect(n, complete_level)
			return


# ---------------------------------------------------------------
# AUTO-DISCOVER LEVEL
# ---------------------------------------------------------------
## UID (uid://...) -> path biasa. Path biasa dikembalikan apa adanya.
func _resolve_path(p: String) -> String:
	if p.begins_with("uid://"):
		var id := ResourceUID.text_to_id(p)
		if ResourceUID.has_id(id):
			return ResourceUID.get_id_path(id)
	return p


## Cari file Level_<angka>.tscn di folder level, urut menurut angka.
func _discover_levels() -> Array[String]:
	var out: Array[String] = []
	if levels.is_empty():
		return out
	var folder := level_folder
	if folder == "":
		folder = _resolve_path(levels[0]).get_base_dir()
	var dir := DirAccess.open(folder)
	if dir == null:
		return out
	var re := RegEx.create_from_string("^[Ll]evel_(\\d+)\\.tscn$")
	var found := {}
	for f in dir.get_files():
		var fname := f.trim_suffix(".remap")   # build export menambah .remap
		var m: RegExMatch = re.search(fname)
		if m:
			found[int(m.get_string(1))] = folder.path_join(fname)
	var keys := found.keys()
	keys.sort()
	for k in keys:
		out.append(String(found[k]))
	return out


# ---------------------------------------------------------------
# PAUSE
# ---------------------------------------------------------------
func _set_paused(value: bool) -> void:
	get_tree().paused = value
	pause_panel.visible = value
	if value:
		pause_resume.grab_focus()


# ---------------------------------------------------------------
# UTIL
# ---------------------------------------------------------------
func _fmt(t: float) -> String:
	var m := int(t / 60.0)
	var s := int(t) % 60
	var cs := int((t - floorf(t)) * 100.0)
	return "%02d:%02d.%02d" % [m, s, cs]
