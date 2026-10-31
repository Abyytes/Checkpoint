class_name SpeedBar
extends CanvasLayer
## Bar energi untuk skill speed up milik Player. Hanya membaca status player
## (lewat speed_state() dan speed_ratio() di player.gd), tidak mengubah apa pun.
##
##   SIAP      bar penuh, hijau       -> speed up boleh dinyalakan
##   AKTIF     bar menguras, kuning   -> sisa durasi speed up
##   COOLDOWN  bar mengisi, biru      -> menunggu sampai bisa dipakai lagi
##   DITOLAK   bar berkedip merah sebentar saat speed up dinyalakan sewaktu cooldown
##
## PASANG sebagai ANAK node Player (di player.tscn). Bar langsung memakai induknya
## sebagai player, jadi tiap ada Player otomatis ada bar-nya. CanvasLayer tidak ikut
## posisi, skala, atau rotasi Player, jadi bar tetap menempel di layar.
## Kalau dipasang di tempat lain (misal di level), bar mencari player lewat group "player".
## Butuh player.gd versi terbaru (yang punya skill speed up).
##
## Node anak yang dikenali dari NAMA-nya:
##   Root (Control) berisi Bar (ProgressBar) dan Label (Label)
## Posisi dan ukuran diatur lewat node Root di editor.

@export_group("Warna")
@export var color_ready := Color(0.35, 0.85, 0.45)
@export var color_active := Color(0.98, 0.72, 0.2)
@export var color_cooldown := Color(0.45, 0.55, 0.75)
@export var color_denied := Color(0.95, 0.3, 0.3)

@export_group("Teks")
## Placeholder: {mult} = 2 atau 3, {time} = sisa detik
@export var text_ready := "SPEED SIAP"
@export var text_active := "SPEED {mult}x  {time} dtk"
@export var text_cooldown := "COOLDOWN  {time} dtk"
@export_group("")

## Sembunyikan bar kalau skill speed up dimatikan di Player (speed_skill_enabled = false)
@export var hide_when_disabled := true

var _player: Node
var _fill: StyleBoxFlat
var _denied_t := 0.0

@onready var _root := get_node_or_null("Root") as Control
@onready var _bar := get_node_or_null("Root/Bar") as ProgressBar
@onready var _label := get_node_or_null("Root/Label") as Label


func _ready() -> void:
	if _bar != null:
		_fill = _bar.get_theme_stylebox("fill") as StyleBoxFlat


func _process(delta: float) -> void:
	if _root == null or _bar == null:
		return
	var p := _get_player()
	# Belum ada player, atau player.gd lama yang belum punya skill speed up
	if p == null or not p.has_method("speed_ratio"):
		_root.visible = false
		return
	if hide_when_disabled and not p.speed_skill_enabled:
		_root.visible = false
		return
	_root.visible = true

	var col := color_ready
	var text := text_ready
	match p.speed_state():
		&"active":
			col = color_active
			var t := "--"
			if p.speed_duration > 0.0:
				t = "%.1f" % p.speed_time_left
			text = text_active.format({"mult": p.speed_mult, "time": t})
		&"cooldown":
			col = color_cooldown
			text = text_cooldown.format({"time": "%.1f" % p.speed_cooldown_left})

	if _denied_t > 0.0:
		_denied_t -= delta
		col = color_denied

	_bar.value = p.speed_ratio()
	if _fill != null:
		_fill.bg_color = col
	if _label != null:
		_label.text = text


## Induk langsung kalau induknya player, kalau tidak cari lewat group "player"
func _get_player() -> Node:
	if _player == null or not is_instance_valid(_player):
		var parent := get_parent()
		if parent != null and parent.has_method("speed_ratio"):
			_player = parent
		else:
			_player = get_tree().get_first_node_in_group("player")
		if _player != null and _player.has_signal("speed_denied") \
				and not _player.is_connected("speed_denied", _on_denied):
			_player.connect("speed_denied", _on_denied)
	return _player


func _on_denied(_cooldown_left: float) -> void:
	_denied_t = 0.35
