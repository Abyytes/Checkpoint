extends Node
## Autoload "Audio": efek suara + BGM. Semua file di res://sfx/ dimuat otomatis,
## dipanggil dengan nama file tanpa ekstensi (coin.wav -> "coin").
##
## Contoh:
##   Audio.play_sfx("coin", 0.0, 0.05)
##   Audio.play_sfx("wall_hit", -4.0, 0.1)
##   Audio.play_music_named("game_bgm")
##   Audio.stop_music()

const SFX_DIR := "res://sfx/"
const EXTS := ["wav", "ogg", "mp3"]

var _sounds := {}
var _last_play := {}
var _music: AudioStreamPlayer
var _current: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # tetap bunyi saat game di-pause
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"                     # bus tidak ada -> otomatis ke Master
	add_child(_music)
	_scan_folder()


func _scan_folder() -> void:
	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		push_warning("Audio: folder %s tidak ditemukan." % SFX_DIR)
		return
	for f in dir.get_files():
		var fname := f.trim_suffix(".import").trim_suffix(".remap")  # untuk build export
		if fname.get_extension().to_lower() in EXTS:
			var s := load(SFX_DIR + fname) as AudioStream
			if s:
				_sounds[fname.get_basename()] = s
	print("Audio: dimuat -> ", _sounds.keys())


## Efek suara. Suara dengan nama sama tidak diulang dalam 60 ms (anti-menumpuk).
func play_sfx(sfx_name: String, volume_db := 0.0, pitch_var := 0.0) -> void:
	if not _sounds.has(sfx_name):
		push_warning("Audio: suara '%s' tidak ada di %s" % [sfx_name, SFX_DIR])
		return
	var now := Time.get_ticks_msec()
	var last: int = _last_play.get(sfx_name, -1000)
	if now - last < 60:
		return
	_last_play[sfx_name] = now
	var p := AudioStreamPlayer.new()
	p.stream = _sounds[sfx_name]
	p.volume_db = volume_db
	p.bus = &"SFX"                            # bus tidak ada -> otomatis ke Master
	if pitch_var > 0.0:
		p.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## BGM dari nama file di folder sfx, mis. Audio.play_music_named("menu_bgm").
func play_music_named(music_name: String, fade := 0.8) -> void:
	if _sounds.has(music_name):
		play_music(_sounds[music_name], fade)
	else:
		push_warning("Audio: musik '%s' tidak ada." % music_name)


## BGM dari stream langsung (mis. dari @export). Lagu yang sama tidak diulang.
func play_music(stream: AudioStream, fade := 0.8) -> void:
	if stream == null or (stream == _current and _music.playing):
		return
	_current = stream
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(func():
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play())
	tw.tween_property(_music, "volume_db", 0.0, fade)


func stop_music(fade := 0.8) -> void:
	_current = null
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(_music.stop)
