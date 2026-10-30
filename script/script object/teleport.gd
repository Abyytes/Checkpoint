@tool
class_name Teleport
extends Node2D
## Portal teleport. Pasang 2 Teleport dengan teleport_id yang SAMA: player yang
## masuk ke salah satunya langsung muncul di pasangannya.
##
## MOMENTUM TIDAK HILANG: player tidak berhenti. Arah, kecepatan (termasuk boost
## pegas), sisa jarak pada frame itu, dan perintah di input buffer semuanya
## dipertahankan, jadi dash terus berlanjut dari portal tujuan ke arah yang sama.
## Kalau sel setelah portal tujuan berupa tembok, player berhenti di portal tujuan.
##
## Portal tujuan TIDAK memicu teleport saat player tiba (tidak ada pantulan balik).
## Teleport hanya terjadi saat player masuk ke portal dengan slide.
##
## Tiap id sebaiknya punya tepat 2 portal. Kalau lebih dari 2, portal berpindah
## melingkar sesuai urutan di scene (1 -> 2 -> 3 -> 1).
##
## Jangan taruh coin, spike, atau objek lain di sel portal, karena player tidak
## berhenti di sana.
##
## TAMPILAN memakai node anak, dikenali dari NAMA-nya (semuanya opsional):
##   Sprite2D (Node2D)  gambar portal. Berputar pelan dan berdenyut saat dipakai
##   IdLabel  (Label)   menampilkan nomor teleport_id
##   SfxTeleport        AudioStreamPlayer atau AudioStreamPlayer2D
##   TeleportFx         CPUParticles2D / GPUParticles2D (One Shot), muncul di kedua portal

const PALETTE := [
	Color(0.95, 0.35, 0.35),   # id 1 merah
	Color(0.35, 0.85, 0.45),   # id 2 hijau
	Color(0.35, 0.60, 0.95),   # id 3 biru
	Color(0.95, 0.80, 0.30),   # id 4 kuning
	Color(0.80, 0.45, 0.95),   # id 5 ungu
	Color(0.30, 0.85, 0.90),   # id 6 cyan
]


## Warna per id (id lebih dari 6 mengulang dari awal)
static func color_for(id: int) -> Color:
	if id < 1:
		return Color(0.85, 0.85, 0.85)
	return PALETTE[(id - 1) % PALETTE.size()]


## Portal dengan id yang sama saling terhubung
@export var teleport_id: int = 1:
	set(v):
		teleport_id = v
		_apply_look()
## Portal ini hanya MENERIMA player. Masuk ke sini tidak memindahkan siapa pun
@export var exit_only: bool = false
## Ukuran tile. Saat game jalan, diambil otomatis dari TileSet "Walls"
@export var tile_size := Vector2(32, 32)
## Snap ke tengah tile terdekat saat game dimulai
@export var snap_to_grid: bool = true

@export_group("Tampilan")
## Warnai Sprite2D sesuai teleport_id (matikan kalau desainmu sudah berwarna sendiri)
@export var tint_by_id: bool = true:
	set(v):
		tint_by_id = v
		_apply_look()
## Kecepatan putar gambar portal (radian/detik). 0 = tidak berputar
@export var spin_speed: float = 1.5

## Sel grid tempat portal ini berada (diisi saat game jalan)
var cell := Vector2i.ZERO

@onready var _sprite := get_node_or_null("Sprite2D") as Node2D
@onready var _label := get_node_or_null("IdLabel") as Label


func _ready() -> void:
	_apply_look()
	if Engine.is_editor_hint():
		return
	add_to_group("teleport")
	var w := _find_walls()
	if w == null:
		push_warning("Teleport: layer 'Walls' tidak ditemukan, portal tidak aktif.")
		return
	if w.tile_set != null:
		tile_size = Vector2(w.tile_set.tile_size)
	cell = w.local_to_map(w.to_local(global_position))
	if snap_to_grid:
		global_position = w.to_global(w.map_to_local(cell))
	_check_pair.call_deferred()      # tunggu semua portal masuk group dulu


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _sprite != null and spin_speed != 0.0:
		_sprite.rotation += spin_speed * delta


# ---------------------------------------------------------------
# TELEPORT
# ---------------------------------------------------------------
## Dipanggil player.gd tiap kali player sampai di sebuah sel saat slide.
## Mengembalikan true kalau player dipindahkan.
func try_teleport(p: Node2D) -> bool:
	if exit_only or p.cell != cell:
		return false
	var dest := _next_portal()
	if dest == null:
		return false
	p.teleport_to(dest.cell)         # slide TIDAK dihentikan
	_use_effect()
	dest._use_effect()
	return true


## Portal tujuan: pasangan dengan id sama. Kalau lebih dari 2, giliran melingkar
func _next_portal() -> Teleport:
	var peers: Array[Teleport] = []
	for n in get_tree().get_nodes_in_group("teleport"):
		var t := n as Teleport
		if t != null and t.teleport_id == teleport_id:
			peers.append(t)
	if peers.size() < 2:
		return null
	var i := peers.find(self)
	return peers[(i + 1) % peers.size()]


func _check_pair() -> void:
	if _next_portal() == null:
		push_warning("Teleport id %d: tidak ada pasangan dengan teleport_id yang sama." % teleport_id)


func _find_walls() -> TileMapLayer:
	var n: Node = get_parent()
	while n != null:
		var w := n.get_node_or_null("Walls") as TileMapLayer
		if w != null:
			return w
		n = n.get_parent()
	return null


# ---------------------------------------------------------------
# TAMPILAN (script hanya menyalakan/menggerakkan node)
# ---------------------------------------------------------------
## Warna dan nomor sesuai teleport_id (ikut berubah langsung di editor)
func _apply_look() -> void:
	if _label != null:
		_label.text = str(teleport_id)
	if _sprite != null and tint_by_id:
		_sprite.self_modulate = color_for(teleport_id)


func _use_effect() -> void:
	_play("SfxTeleport")
	_burst("TeleportFx")
	if _sprite != null:
		_sprite.scale = Vector2(1.6, 1.6)
		create_tween().tween_property(_sprite, "scale", Vector2.ONE, 0.25)


func _play(node_name: String) -> void:
	var s = get_node_or_null(node_name)
	if s != null:
		s.play()


func _burst(node_name: String) -> void:
	var fx = get_node_or_null(node_name)
	if fx != null:
		fx.emitting = true
