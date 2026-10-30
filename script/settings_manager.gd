extends Node
## Autoload "SettingsManager". Menyimpan dan MENERAPKAN pengaturan sejak game dibuka,
## jadi volume dan mode layar sudah benar sebelum panel pengaturan pernah ditampilkan.
## Disimpan di user://settings.cfg (terpisah dari save game, jadi New Game tidak
## menghapus pengaturan).

signal changed

const PATH := "user://settings.cfg"
const MUSIC_BUS := &"Music"
const MASTER_BUS := &"Master"

## Volume musik, 0.0 sampai 1.0 (linear)
var music_volume: float = 0.8
## Bisukan SEMUA suara (bus Master)
var muted: bool = false
## Layar penuh (true) atau jendela (false)
var fullscreen: bool = false

var _dirty := false
var _timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # tetap jalan saat game di-pause
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 0.5
	_timer.timeout.connect(flush)
	add_child(_timer)

	_ensure_music_bus()
	load_settings()
	_apply_music()
	_apply_mute()
	# Di browser, layar penuh hanya boleh dimulai oleh klik pemain, jadi jangan dipaksa saat start
	if not OS.has_feature("web") and fullscreen_supported():
		_apply_fullscreen()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()


# ---------------------------------------------------------------
# API untuk panel dan scene lain
# ---------------------------------------------------------------
func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_music()
	_mark_dirty()


func set_muted(value: bool) -> void:
	muted = value
	_apply_mute()
	_mark_dirty()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_fullscreen()
	_mark_dirty()


## Mode layar yang SEBENARNYA sedang aktif (bisa berbeda kalau pemain menekan F11/Esc di browser)
func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## False di platform yang tidak punya konsep jendela/layar penuh (aplikasi mobile, Safari iPhone)
func fullscreen_supported() -> bool:
	if OS.has_feature("android") or OS.has_feature("ios"):
		return false
	if OS.has_feature("web_ios"):
		return false
	return true


## Tulis ke disk sekarang juga (dipanggil saat panel ditutup dan saat game ditutup)
func flush() -> void:
	if not _dirty:
		return
	_dirty = false
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "mute", muted)
	cfg.set_value("display", "fullscreen", fullscreen)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("SettingsManager: gagal menyimpan pengaturan (%s)" % error_string(err))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return                                   # belum ada file: pakai nilai awal
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	muted = bool(cfg.get_value("audio", "mute", muted))
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))


# ---------------------------------------------------------------
# INTERNAL
# ---------------------------------------------------------------
func _mark_dirty() -> void:
	_dirty = true
	_timer.start()                               # simpan 0,5 detik setelah perubahan terakhir
	changed.emit()


## Buat bus "Music" kalau belum ada di Audio Bus Layout.
## Pasang AudioStreamPlayer musikmu ke bus "Music" supaya slider berpengaruh.
func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, MUSIC_BUS)
	AudioServer.set_bus_send(idx, MASTER_BUS)


func _apply_music() -> void:
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx == -1:
		return
	var db := -80.0 if music_volume <= 0.001 else linear_to_db(music_volume)
	AudioServer.set_bus_volume_db(idx, db)


func _apply_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MASTER_BUS), muted)


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)
