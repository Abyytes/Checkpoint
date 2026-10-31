class_name LevelBase
extends Node2D
## Script induk untuk semua level (level_1 ... level_5).
## Pasang di root LevelBase.tscn. Level turunan otomatis memakainya.

signal level_completed
signal player_died
## Untuk HUD nanti: "Hoax 1/3"
signal hoax_changed(killed: int, total: int)
## Untuk HUD nanti: "Koin 2/5"
signal coins_changed(collected: int, total: int)
## Player menyentuh InfoZone. game.gd yang menampilkan popup-nya.
signal info_requested(zone: InfoZone)

@export var level_title: String = "Level"
## Jeda (detik) antara player mati dan muncul lagi di PlayerStart
@export var respawn_delay: float = 0.5

@export_group("Kamera")
## Batasi kamera di tepi peta (berdasarkan tile di layer Walls).
## Matikan untuk level yang lebih kecil dari layar.
@export var limit_camera: bool = true
## Ruang kosong di luar peta yang boleh terlihat (dalam jumlah tile)
@export var camera_margin_tiles: int = 2

@onready var walls: TileMapLayer = $Walls
@onready var gates: TileMapLayer = $Gates
@onready var objects: Node2D = $Objects
@onready var player: Node2D = $Player
@onready var start: Marker2D = $PlayerStart
@onready var finish_gate: Area2D = objects.get_node("FinishGate")
@onready var hoax_popup: CanvasLayer = $HoaxPopup
## Layer tilemap opsional bernama "Coins": koin yang dilukis sebagai tile.
## Boleh dipakai bersamaan dengan node Coin biasa. Kalau layernya tidak ada, diabaikan.
@onready var coin_tiles := get_node_or_null("Coins") as TileMapLayer

var total_coins: int = 0
var coins_collected: int = 0
var hoax_total: int = 0
var hoax_killed: int = 0

var _completed := false
var _hoax_by_cell: Dictionary = {}     # Vector2i -> HoaxTile
var _coin_by_cell: Dictionary = {}     # Vector2i -> Coin
var _coin_tile_by_cell: Dictionary = {} # Vector2i (sel Walls) -> Vector2i (sel layer Coins)
var _spike_by_cell: Dictionary = {}    # Vector2i -> Spike
var _spring_by_cell: Dictionary = {}   # Vector2i -> node pegas (spring.gd)
var _info_by_cell: Dictionary = {}     # Vector2i -> InfoZone
var _pending_hoax: HoaxTile
var _finish_cell := Vector2i.ZERO


func _ready() -> void:
	player.died.connect(_on_player_died)
	player.moved_to_cell.connect(_on_player_moved)
	hoax_popup.confirmed.connect(_on_hoax_confirmed)

	_setup_finish_gate()
	_setup_coins()
	_setup_spikes()
	_setup_springs()
	_setup_info_zones()
	_setup_hoax()
	restart_player()
	if limit_camera:
		_apply_camera_limits()


# ---------------------------------------------------------------
# SETUP
# ---------------------------------------------------------------
func _setup_finish_gate() -> void:
	_finish_cell = _cell_of(start.global_position)
	finish_gate.global_position = _cell_center(_finish_cell)
	finish_gate.close()


func _setup_coins() -> void:
	_coin_by_cell.clear()
	for n in get_tree().get_nodes_in_group("coin"):
		var coin := n as Coin
		if coin == null or not is_ancestor_of(coin):
			continue
		var c := _cell_of(coin.global_position)
		coin.global_position = _cell_center(c)     # snap ke tengah tile
		_coin_by_cell[c] = coin

	# Koin tilemap: tiap tile yang terlukis di layer "Coins" dihitung sebagai 1 koin.
	# Sel dicocokkan lewat posisi dunia, jadi layer Coins tidak harus berada di
	# koordinat yang sama dengan Walls.
	_coin_tile_by_cell.clear()
	if coin_tiles != null:
		for tc in coin_tiles.get_used_cells():
			var c := _cell_of(coin_tiles.to_global(coin_tiles.map_to_local(tc)))
			if not _coin_by_cell.has(c):               # kalau ada node Coin di sel yang sama, node yang dipakai
				_coin_tile_by_cell[c] = tc

	total_coins = _coin_by_cell.size() + _coin_tile_by_cell.size()
	coins_collected = 0
	coins_changed.emit(coins_collected, total_coins)


func _setup_spikes() -> void:
	_spike_by_cell.clear()
	for n in get_tree().get_nodes_in_group("spike"):
		var node := n as Node2D
		if node == null or not is_ancestor_of(node):
			continue
		var c := _cell_of(node.global_position)
		node.global_position = _cell_center(c)     # snap ke tengah tile
		_spike_by_cell[c] = node


func _setup_springs() -> void:
	_spring_by_cell.clear()
	for n in get_tree().get_nodes_in_group("spring"):
		var node := n as Node2D
		if node == null or not is_ancestor_of(node):
			continue
		var c := _cell_of(node.global_position)
		node.global_position = _cell_center(c)     # snap ke tengah tile
		_spring_by_cell[c] = node


func _setup_info_zones() -> void:
	_info_by_cell.clear()
	for n in get_tree().get_nodes_in_group("info_zone"):
		var zone := n as InfoZone
		if zone == null or not is_ancestor_of(zone):
			continue
		var c := _cell_of(zone.global_position)
		zone.global_position = _cell_center(c)     # snap ke tengah tile
		_info_by_cell[c] = zone


func _setup_hoax() -> void:
	_hoax_by_cell.clear()
	for n in get_tree().get_nodes_in_group("hoax_tile"):
		var tile := n as HoaxTile
		if tile == null or not is_ancestor_of(tile):
			continue
		var c := _cell_of(tile.global_position)
		tile.global_position = _cell_center(c)     # snap ke tengah tile
		_hoax_by_cell[c] = tile
	hoax_total = _hoax_by_cell.size()
	hoax_killed = 0
	hoax_changed.emit(hoax_killed, hoax_total)
	if hoax_total == 0:
		finish_gate.appear()                       # level tanpa hoax: gerbang langsung ada


# ---------------------------------------------------------------
# ALUR PERMAINAN
# ---------------------------------------------------------------
## Dipanggil setiap player masuk ke sebuah tile (termasuk saat melintas)
func _on_player_moved(c: Vector2i) -> void:
	if _completed:
		return

	# 1) Spike: player mati, tidak perlu cek yang lain
	if _spike_by_cell.has(c):
		player.die()
		return

	# 2) FinishGate (hanya kalau sudah muncul)
	if finish_gate.is_open and c == _finish_cell:
		player.stop_here()
		complete()
		return

	# 3) Coin: diambil sambil lewat, player tidak berhenti
	var coin: Coin = _coin_by_cell.get(c)
	if coin != null and not coin.is_collected:
		coin.collect()
		coins_collected += 1
		coins_changed.emit(coins_collected, total_coins)

	# 3b) Koin tilemap: tile dihapus, diambil sambil lewat
	if _coin_tile_by_cell.has(c):
		coin_tiles.erase_cell(_coin_tile_by_cell[c])
		_coin_tile_by_cell.erase(c)
		coins_collected += 1
		coins_changed.emit(coins_collected, total_coins)

	# 4) HoaxTile yang masih hidup
	var tile: HoaxTile = _hoax_by_cell.get(c)
	if tile != null and tile.is_alive:
		_pending_hoax = tile
		player.stop_here()
		hoax_popup.open()

	# 5) InfoZone: popup informasi. Dilewati kalau player sudah dihentikan (hoax di tile yang sama).
	# Mode DIALOG menghentikan player; dibuka lagi oleh game.gd saat popup ditutup.
	var info: InfoZone = _info_by_cell.get(c)
	if info != null and not player.locked and info.can_trigger():
		info.mark_triggered()
		if info.blocking:
			player.stop_here()
		info_requested.emit(info)

	# 6) Pegas: ganti arah slide dan naikkan kecepatan.
	# Dilewati kalau player sudah dihentikan (misalnya oleh hoax di tile yang sama).
	var spring: Node2D = _spring_by_cell.get(c)
	if spring != null and player.sliding:
		player.launch(spring.get_direction(), spring.boost)


func _on_hoax_confirmed() -> void:
	if _pending_hoax != null:
		_pending_hoax.kill()
		_pending_hoax = null
		hoax_killed += 1
		hoax_changed.emit(hoax_killed, hoax_total)
		if hoax_killed >= hoax_total:
			finish_gate.appear()                   # semua hoax mati -> gerbang muncul di start
	player.unlock()


## Dipanggil saat player menyentuh FinishGate
func complete() -> void:
	if _completed:
		return
	_completed = true
	print("LEVEL SELESAI: ", level_title)          # sementara; layar hasil dibuat nanti
	level_completed.emit()


## Taruh player di PlayerStart (dipakai saat mulai dan saat restart)
func restart_player() -> void:
	_completed = false
	player.respawn(start.global_position)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.force_update_scroll()
		cam.reset_smoothing()   # kamera langsung di posisi, tidak "meluncur"


## Hapus semua tile gerbang di layer Gates (untuk dipakai nanti)
func open_gates() -> void:
	gates.clear()



## Player mati (kena spike): tunggu sebentar lalu muncul lagi di PlayerStart.
## Hoax yang sudah mati dan koin yang sudah diambil tidak di-reset.
func _on_player_died() -> void:
	player_died.emit()
	await get_tree().create_timer(respawn_delay).timeout
	restart_player()


# ---------------------------------------------------------------
# UTILITAS
# ---------------------------------------------------------------
func _cell_of(world_pos: Vector2) -> Vector2i:
	return walls.local_to_map(walls.to_local(world_pos))


func _cell_center(c: Vector2i) -> Vector2:
	return walls.to_global(walls.map_to_local(c))


func _apply_camera_limits() -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null or walls.tile_set == null:
		return
	var used := walls.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var ts := Vector2(walls.tile_set.tile_size)
	var m := Vector2i(camera_margin_tiles, camera_margin_tiles)
	var top_left := walls.to_global(Vector2(used.position - m) * ts)
	var bottom_right := walls.to_global(Vector2(used.end + m) * ts)
	cam.limit_left = int(top_left.x)
	cam.limit_top = int(top_left.y)
	cam.limit_right = int(bottom_right.x)
	cam.limit_bottom = int(bottom_right.y)
