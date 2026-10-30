@tool
class_name RhythmGate
extends Node2D
## Gerbang berupa objek (bukan tile). Menghalangi player selama tertutup,
## dan terbuka otomatis kalau SEMUA RhythmTile ber-gate_id yang sama sudah dicek.
## Player mengetahui gerbang ini lewat group "gate_blocker" (butuh patch _is_wall).
##
## TAMPILAN memakai node anak, dikenali dari NAMA-nya:
##   Pieces/Piece  (Node2D, WAJIB)  desain 1 tile gerbang. Script menggandakannya
##                                   sesuai Size Tiles (mis. 1x3 = 3 potongan).
##   CounterLabel  (Label)  hitungan "1/2", opsional
##   AnimationPlayer        animasi opsional "open" dan "close"
##   SfxOpen                AudioStreamPlayer atau AudioStreamPlayer2D, opsional
##   OpenFx                 CPUParticles2D / GPUParticles2D (One Shot), opsional
## Tanpa animasi "open", potongan gerbang memudar lalu hilang.

signal opened(gate: RhythmGate)

const PALETTE := [
	Color(0.95, 0.35, 0.35),   # id 1 merah
	Color(0.35, 0.85, 0.45),   # id 2 hijau
	Color(0.35, 0.60, 0.95),   # id 3 biru
	Color(0.95, 0.80, 0.30),   # id 4 kuning
	Color(0.80, 0.45, 0.95),   # id 5 ungu
]


## Warna per gate_id. Dipakai juga oleh RhythmTile supaya pasangannya mudah dikenali.
static func color_for(id: int) -> Color:
	if id >= 1 and id <= PALETTE.size():
		return PALETTE[id - 1]
	return Color(0.85, 0.85, 0.85)


## Gerbang ini dibuka oleh RhythmTile dengan gate_id yang sama
@export var gate_id: int = 1:
	set(v):
		gate_id = v
		_apply_look()
		_update_counter()
## Ukuran gerbang dalam tile (lebar, tinggi). Meluas ke kanan dan bawah dari tile asal
@export var size_tiles := Vector2i(1, 1):
	set(v):
		size_tiles = Vector2i(maxi(v.x, 1), maxi(v.y, 1))
		if is_node_ready():
			_rebuild_pieces()
			_layout_counter()
## Ukuran tile. Saat game jalan, diambil otomatis dari TileSet "Walls"
@export var tile_size := Vector2(32, 32)
## Snap ke tengah tile terdekat saat game dimulai
@export var snap_to_grid: bool = true
## Lama fade membuka (detik), dipakai kalau tidak ada animasi "open"
@export var open_duration: float = 0.5

@export_group("Tampilan")
## Warnai Pieces sesuai gate_id (matikan kalau desainmu sudah berwarna sendiri)
@export var tint_by_gate: bool = true:
	set(v):
		tint_by_gate = v
		_apply_look()
## Posisikan CounterLabel otomatis di tengah area gerbang
@export var auto_layout_label: bool = true

var is_closed := true

var _cells: Array[Vector2i] = []
var _extra: Array[Node2D] = []
var _lit := 0
var _total := 0
var _tween: Tween

@onready var _pieces := get_node_or_null("Pieces") as Node2D
@onready var _piece := get_node_or_null("Pieces/Piece") as Node2D
@onready var _counter := get_node_or_null("CounterLabel") as Label
@onready var _anim := get_node_or_null("AnimationPlayer") as AnimationPlayer


func _ready() -> void:
	_rebuild_pieces()
	_layout_counter()
	_apply_look()
	_update_counter()
	if Engine.is_editor_hint():
		return
	add_to_group("rhythm_gate")
	add_to_group("gate_blocker")
	_setup_grid()
	_rebuild_pieces()                # ukuran tile bisa berubah setelah membaca TileSet
	_layout_counter()
	_refresh.call_deferred()         # tunggu semua RhythmTile masuk group dulu


## Dipakai player.gd: apakah cell ini diblokir gerbang yang masih tertutup?
func blocks_cell(c: Vector2i) -> bool:
	return is_closed and _cells.has(c)


## Dipanggil RhythmTile lewat call_group saat statusnya berubah
func on_tile_changed(id: int) -> void:
	if id == gate_id:
		_refresh()


func open() -> void:
	if not is_closed:
		return
	is_closed = false                       # player langsung bisa lewat
	opened.emit(self)
	_update_counter()
	_play("SfxOpen")
	_burst("OpenFx")
	if not _play_anim(&"open"):
		_fade_pieces()


## Tutup lagi (opsional dipanggil saat level di-restart, setelah tile di-reset)
func reset_gate() -> void:
	is_closed = true
	if _tween != null:
		_tween.kill()
	if _pieces != null:
		_pieces.visible = true
		_pieces.modulate.a = 1.0
	_play_anim(&"close")
	_refresh()


func _refresh() -> void:
	_total = 0
	_lit = 0
	for n in get_tree().get_nodes_in_group("rhythm_tile"):
		var t := n as RhythmTile
		if t != null and t.gate_id == gate_id:
			_total += 1
			if t.is_lit:
				_lit += 1
	_update_counter()

	if _total == 0:
		push_warning("RhythmGate id %d: tidak ada RhythmTile dengan gate_id yang sama." % gate_id)
		return
	if is_closed and _lit >= _total:
		open()


# ---------------------------------------------------------------
# GRID
# ---------------------------------------------------------------
func _setup_grid() -> void:
	var w := _find_walls()
	if w == null:
		push_warning("RhythmGate: layer 'Walls' tidak ditemukan, gerbang tidak akan menghalangi.")
		return
	if w.tile_set != null:
		tile_size = Vector2(w.tile_set.tile_size)
	var origin := w.local_to_map(w.to_local(global_position))
	if snap_to_grid:
		global_position = w.to_global(w.map_to_local(origin))
	_cells.clear()
	for x in size_tiles.x:
		for y in size_tiles.y:
			_cells.append(origin + Vector2i(x, y))


func _find_walls() -> TileMapLayer:
	var n: Node = get_parent()
	while n != null:
		var w := n.get_node_or_null("Walls") as TileMapLayer
		if w != null:
			return w
		n = n.get_parent()
	return null


# ---------------------------------------------------------------
# TAMPILAN (script hanya menggandakan/menyalakan/menggerakkan node)
# ---------------------------------------------------------------
## Gandakan "Piece" untuk setiap tile tambahan (Size Tiles lebih dari 1x1)
func _rebuild_pieces() -> void:
	for p in _extra:
		if is_instance_valid(p):
			p.queue_free()
	_extra.clear()
	if _pieces == null or _piece == null:
		return
	for x in size_tiles.x:
		for y in size_tiles.y:
			if x == 0 and y == 0:
				continue
			var d := _piece.duplicate() as Node2D
			d.position = _piece.position + Vector2(x, y) * tile_size
			_pieces.add_child(d)
			_extra.append(d)


func _apply_look() -> void:
	if _pieces != null and tint_by_gate:
		_pieces.modulate = Color(color_for(gate_id), _pieces.modulate.a)


func _layout_counter() -> void:
	if _counter == null or not auto_layout_label:
		return
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_counter.position = -tile_size / 2.0
	_counter.size = Vector2(size_tiles) * tile_size


func _update_counter() -> void:
	if _counter == null:
		return
	if Engine.is_editor_hint() or _total == 0:
		_counter.text = "G%d" % gate_id
	else:
		_counter.text = "%d/%d" % [_lit, _total]
	_counter.visible = is_closed or Engine.is_editor_hint()


func _fade_pieces() -> void:
	if _pieces == null:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_pieces, "modulate:a", 0.0, open_duration)
	_tween.tween_callback(func() -> void: _pieces.visible = false)


func _play_anim(anim_name: StringName) -> bool:
	if _anim != null and _anim.has_animation(anim_name):
		_anim.play(anim_name)
		return true
	return false


func _play(node_name: String) -> void:
	var s = get_node_or_null(node_name)
	if s != null:
		s.play()


func _burst(node_name: String) -> void:
	var fx = get_node_or_null(node_name)
	if fx != null:
		fx.emitting = true
