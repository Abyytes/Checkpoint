@tool
class_name HoaxTileV2
extends HoaxTile
## HoaxTile versi 2: memancarkan genangan merah yang membesar tiap beberapa detik.
## Selama player berdiri di dalam genangan dan MEMULAI dash baru, arah dibalik
## (kanan jadi kiri, atas jadi bawah, dan sebaliknya).
## Dash yang sudah berjalan saat player masuk genangan TIDAK dibalik.
## Genangan hilang saat hoax dimatikan.
##
## Tampilan sekarang lewat node (bukan _draw):
##   "Puddle"  (Sprite2D) = isi genangan, diskalakan sesuai radius
##   "Ripple"  (Sprite2D) = cincin riak yang melebar lalu memudar
## Ganti texture-nya di editor kapan saja. Texture sebaiknya lingkaran penuh
## yang memenuhi gambar (radius = setengah lebar texture), supaya skala pas.
##
## Turunan dari HoaxTile, jadi LevelBase (popup, hitungan hoax, FinishGate)
## bekerja tanpa perubahan. player.gd memakai contains_point() untuk cek genangan.

## Posisi cincin pada texture Ripple (0..1 dari radius). Sesuaikan kalau ganti aset.
const RING_AT := 0.94

@export_group("Genangan")
## Radius awal (dalam tile)
@export var start_radius_tiles: float = 1.0:
	set(v):
		start_radius_tiles = v
		_update_preview()
## Tiap berapa detik genangan membesar
@export var grow_interval: float = 4.0
## Tambahan radius tiap kali membesar (dalam tile)
@export var grow_step_tiles: float = 1.0
## Lama animasi membesar (detik)
@export var grow_duration: float = 0.6
## Radius maksimum (dalam tile)
@export var max_radius_tiles: float = 5.0
## Jeda sebelum pertumbuhan pertama dimulai (detik)
@export var start_delay: float = 0.0
@export var zone_color := Color(0.9, 0.15, 0.15):
	set(v):
		zone_color = v
		_update_preview()
@export_range(0.0, 1.0) var zone_alpha: float = 0.28:
	set(v):
		zone_alpha = v
		_update_preview()

## Radius genangan saat ini (piksel)
var radius_px := 0.0

var _tile_px := 32.0
var _target_tiles := 0.0
var _grow_t := 0.0
var _time := 0.0
var _tween: Tween

@onready var _puddle := get_node_or_null("Puddle") as Sprite2D
@onready var _ripple := get_node_or_null("Ripple") as Sprite2D


func _ready() -> void:
	if Engine.is_editor_hint():
		_update_preview()
		return
	super()
	_fetch_tile_size()
	add_to_group("reverse_zone")
	reset_zone()


## Dipakai player.gd: apakah titik dunia ini ada di dalam genangan aktif?
func contains_point(world_pos: Vector2) -> bool:
	if not is_alive or radius_px <= 0.0:
		return false
	return world_pos.distance_to(global_position) <= radius_px + 0.5


## Kembalikan genangan ke ukuran awal (opsional dipanggil saat level di-restart)
func reset_zone() -> void:
	if _tween != null:
		_tween.kill()
	_target_tiles = start_radius_tiles
	radius_px = start_radius_tiles * _tile_px if is_alive else 0.0
	_grow_t = -start_delay
	_apply_puddle()


func kill() -> void:
	if not is_alive:
		return
	super()                                   # status mati + sinyal killed dari HoaxTile
	_tween_radius(0.0, 0.4)                   # genangan menyusut lalu hilang


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	if is_alive:
		_grow_t += delta
		if _grow_t >= grow_interval and _target_tiles < max_radius_tiles:
			_grow_t = 0.0
			_target_tiles = minf(_target_tiles + grow_step_tiles, max_radius_tiles)
			_tween_radius(_target_tiles * _tile_px, grow_duration)
	_apply_puddle()


func _tween_radius(to: float, duration: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "radius_px", to, duration)


## Ambil ukuran tile dari TileSet "Walls" supaya radius selalu pas dengan grid
func _fetch_tile_size() -> void:
	var n: Node = get_parent()
	while n != null:
		var w := n.get_node_or_null("Walls") as TileMapLayer
		if w != null:
			if w.tile_set != null:
				_tile_px = float(w.tile_set.tile_size.x)
			return
		n = n.get_parent()


# ---------------------------------------------------------------
# TAMPILAN (lewat node Puddle dan Ripple)
# ---------------------------------------------------------------
## Radius texture dalam piksel (setengah lebar). Dipakai untuk menghitung skala.
func _tex_radius(s: Sprite2D) -> float:
	if s.texture == null:
		return 64.0
	return s.texture.get_width() * 0.5


func _apply_puddle() -> void:
	var show_it := radius_px > 0.5
	if _puddle != null:
		_puddle.visible = show_it
	if _ripple != null:
		_ripple.visible = show_it
	if not show_it:
		return

	var r := radius_px * (1.0 + 0.015 * sin(_time * 3.0))      # tepi sedikit bergelombang
	if _puddle != null:
		var k := r / _tex_radius(_puddle)
		_puddle.scale = Vector2(k, k)
		_puddle.modulate = Color(zone_color, zone_alpha)

	# Riak: cincin kecil yang melebar lalu memudar
	if _ripple != null:
		var ripple := fmod(_time * 0.6, 1.0)
		var kr := r * ripple / (_tex_radius(_ripple) * RING_AT)
		_ripple.scale = Vector2(kr, kr)
		_ripple.modulate = Color(zone_color, (1.0 - ripple) * 0.35)


## Pratinjau di editor: Puddle menunjukkan radius awal
func _update_preview() -> void:
	if not Engine.is_editor_hint() or _puddle == null:
		return
	var k := start_radius_tiles * _tile_px / _tex_radius(_puddle)
	_puddle.scale = Vector2(k, k)
	_puddle.modulate = Color(zone_color, zone_alpha)
