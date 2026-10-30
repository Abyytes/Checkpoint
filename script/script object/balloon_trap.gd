@tool
class_name BalloonTrap
extends Node2D
## Balon berduri. Siklus: kecil (aman) -> membesar (aman, peringatan)
## -> duri keluar ke 8 arah, area kotak 3x3 (MEMATIKAN) -> mengempis (aman) -> ulang.
## Mandiri: tidak butuh script lain. Player dicari lewat group "player"
## (dipasang player.gd) lalu dicek berdasarkan POSISI, bukan fisika, jadi tidak
## perlu Hitbox atau pengaturan collision layer.
##
## Tampilan lewat node (bukan _draw), semuanya ada di balloon_trap.tscn:
##   "Body"   (Sprite2D) = balon. Skalanya naik-turun mengikuti siklus.
##   "Spikes" (Node2D)   = kumpulan gambar duri. Hanya tampil saat duri keluar.
## Ganti texture atau tambah anak di "Spikes" sesuka hati.
## Area mematikan berbentuk KOTAK dengan balon di tengah: spike_reach 1 = 3x3 tile,
## 2 = 5x5, dan seterusnya. Gambar duri harus menutupi area yang sama. Scene bawaan
## punya 8 duri (4 lurus + 4 diagonal) untuk spike_reach 1; kalau spike_reach lebih
## besar, tambahkan duri di "Spikes" sendiri.

enum State { IDLE, INFLATING, ARMED, DEFLATING }

const ART_SMALL_SCALE := 0.6   # skala "Body" saat kecil

@export_group("Waktu (detik)")
## Jeda awal sebelum siklus mulai (supaya beberapa balon tidak serempak)
@export var start_offset: float = 0.0
## Balon kecil dan aman
@export var idle_time: float = 1.5
## Balon membesar. Aman, berfungsi sebagai peringatan
@export var inflate_time: float = 0.6
## Duri keluar dan mematikan
@export var armed_time: float = 1.0
## Balon mengempis. Aman
@export var deflate_time: float = 0.3

@export_group("Duri")
## Jangkauan duri dari tengah ke tiap arah (termasuk diagonal), dalam tile.
## 1 = area 3x3, 2 = 5x5, 3 = 7x7
@export_range(1, 4) var spike_reach: int = 1
## Ukuran tile. Saat game jalan, nilai ini diambil otomatis dari TileSet "Walls"
@export var tile_size := Vector2(32, 32)
## Snap ke tengah tile terdekat saat game dimulai
@export var snap_to_grid: bool = true
## Pengurang ukuran area mematikan (px) agar terasa adil
@export var shape_inset: float = 4.0

@export_group("Warna Body")
## Warnai "Body" dari calm ke danger saat membesar. Matikan kalau aset sudah berwarna.
@export var tint_body: bool = true
@export var color_calm := Color(0.35, 0.75, 0.95)
@export var color_danger := Color(0.95, 0.3, 0.25)

var state: State = State.IDLE
## 0 = kecil, 1 = membesar penuh
var inflate := 0.0
var spikes_out := false

var _t := 0.0
var _deadly := false
## Player yang dicek. Kalau kosong, dicari otomatis lewat group "player"
var target: Node2D

@onready var _body := get_node_or_null("Body") as Node2D
@onready var _spikes := get_node_or_null("Spikes") as Node2D


func _ready() -> void:
	if Engine.is_editor_hint():
		# Di editor tampilkan pratinjau balon membesar + duri
		inflate = 1.0
		spikes_out = true
		_apply_visual()
		return

	add_to_group("balloon")
	if snap_to_grid:
		_snap_to_walls()
	reset()


## Ulang siklus dari awal (opsional dipanggil saat level di-restart)
func reset() -> void:
	state = State.IDLE
	_t = -start_offset
	inflate = 0.0
	spikes_out = false
	_deadly = false
	_apply_visual()


# ---------------------------------------------------------------
# SIKLUS
# ---------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_t += delta
	match state:
		State.IDLE:
			inflate = 0.0
			if _t >= idle_time:
				_enter(State.INFLATING)
		State.INFLATING:
			inflate = clampf(_t / maxf(inflate_time, 0.001), 0.0, 1.0)
			if _t >= inflate_time:
				_enter(State.ARMED)
		State.ARMED:
			inflate = 1.0
			if _t >= armed_time:
				_enter(State.DEFLATING)
		State.DEFLATING:
			inflate = 1.0 - clampf(_t / maxf(deflate_time, 0.001), 0.0, 1.0)
			if _t >= deflate_time:
				_enter(State.IDLE)

	# Selama duri keluar, player yang berdiri atau lewat di area ini mati
	if _deadly:
		_check_player()
	_apply_visual()


func _enter(s: State) -> void:
	state = s
	_t = 0.0
	spikes_out = (s == State.ARMED)
	_deadly = spikes_out


# ---------------------------------------------------------------
# AREA MEMATIKAN (kotak (2*spike_reach+1) tile, dicek lewat posisi player)
# ---------------------------------------------------------------
func _check_player() -> void:
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node2D
		if target == null:
			return
	# Player yang sudah mati atau sedang dikunci (popup hoax / level selesai) aman
	if not target.alive or target.locked:
		return
	if _in_area(target.global_position):
		target.die()


func _in_area(world_pos: Vector2) -> bool:
	var d := (world_pos - global_position).abs()
	var half := tile_size * (spike_reach + 0.5) - Vector2.ONE * shape_inset
	return d.x <= half.x and d.y <= half.y


## Cari layer "Walls" di induk-induknya: snap ke tengah tile + ambil ukuran tile
func _snap_to_walls() -> void:
	var n: Node = get_parent()
	while n != null:
		var w := n.get_node_or_null("Walls") as TileMapLayer
		if w != null:
			var c := w.local_to_map(w.to_local(global_position))
			global_position = w.to_global(w.map_to_local(c))
			if w.tile_set != null:
				tile_size = Vector2(w.tile_set.tile_size)
			return
		n = n.get_parent()


# ---------------------------------------------------------------
# TAMPILAN (lewat node Body dan Spikes)
# ---------------------------------------------------------------
func _apply_visual() -> void:
	if _body != null:
		var s := lerpf(ART_SMALL_SCALE, 1.0, inflate)
		_body.scale = Vector2(s, s)
		# Tidak mewarnai saat di editor supaya warna tidak ikut tersimpan di scene
		if tint_body and not Engine.is_editor_hint():
			_body.modulate = color_calm.lerp(color_danger, inflate)
	if _spikes != null:
		_spikes.visible = spikes_out
