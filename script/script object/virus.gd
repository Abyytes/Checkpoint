class_name Virus
extends Node2D
## Virus pengejar. Diam di tempatnya sampai player masuk jarak deteksi, berhenti
## sebentar sebagai peringatan, lalu mengejar player SEL DEMI SEL lewat jalur
## yang bisa dilalui (tembok, Gates, dan RhythmGate yang tertutup menghalangi virus
## seperti menghalangi player). Menyentuh player = player mati.
## Kalau player menjauh melewati jarak lepas, atau player mati, virus kembali ke
## posisi awalnya.
##
## Kecepatan virus jauh di bawah slide player, jadi player bisa kabur atau
## menjebaknya di belakang tembok.
##
## Mandiri: tidak butuh perubahan di LevelBase. Player dicari lewat group "player"
## dan sinyal died dipakai untuk reset.
##
## TAMPILAN lewat node anak, dikenali dari NAMA-nya (semuanya opsional):
##   Body       (Node2D / Sprite2D)  badan virus, berdenyut selama aktif
##   AlertMark  (CanvasItem)         tanda seru, tampil selama fase peringatan

enum State { IDLE, ALERT, CHASE, RETURN }

@export_group("Pengejaran")
## Jarak (tile, garis lurus) player masuk sampai virus mulai mengejar
@export var detect_tiles: float = 5.0
## Jarak (tile) player menjauh sampai virus menyerah dan pulang. Harus lebih besar dari detect_tiles
@export var lose_tiles: float = 8.0
## Kecepatan virus dalam tile per detik (slide player jauh lebih cepat)
@export var speed_tiles: float = 3.0
## Jeda peringatan sebelum mulai mengejar (detik)
@export var alert_time: float = 0.4
## Jalur terjauh yang dicari virus (dalam tile). Membatasi beban hitung
@export var max_path_tiles: int = 24

@export_group("Sentuhan")
## Jarak (tile) dari tengah virus yang mematikan player
@export var kill_radius_tiles: float = 0.45

@export_group("Grid")
## Ukuran tile. Saat game jalan, diambil otomatis dari TileSet "Walls"
@export var tile_size := Vector2(32, 32)
## Snap ke tengah tile terdekat saat game dimulai
@export var snap_to_grid: bool = true

var state: State = State.IDLE

var _walls: TileMapLayer
var _gates: TileMapLayer
var _player: Node2D
var _home_cell := Vector2i.ZERO
var _cell := Vector2i.ZERO
var _target_cell := Vector2i.ZERO
var _target_pos := Vector2.ZERO
var _moving := false
var _state_t := 0.0
var _time := 0.0
var _prev_pos := Vector2.ZERO
var _prev_valid := false

@onready var _body := get_node_or_null("Body") as Node2D
@onready var _alert := get_node_or_null("AlertMark") as CanvasItem


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("virus")
	_walls = _find_walls()
	if _walls == null:
		push_warning("Virus: layer 'Walls' tidak ditemukan, virus tidak aktif.")
		set_physics_process(false)
		return
	_gates = _walls.get_parent().get_node_or_null("Gates") as TileMapLayer
	if _walls.tile_set != null:
		tile_size = Vector2(_walls.tile_set.tile_size)
	_home_cell = _walls.local_to_map(_walls.to_local(global_position))
	if snap_to_grid:
		global_position = _cell_to_world(_home_cell)
	_cell = _home_cell
	if _alert != null:
		_alert.visible = false


## Kembalikan virus ke posisi awal dan berhenti mengejar
func reset() -> void:
	state = State.IDLE
	_moving = false
	_cell = _home_cell
	global_position = _cell_to_world(_home_cell)
	_prev_valid = false
	_state_t = 0.0
	if _alert != null:
		_alert.visible = false


func _physics_process(delta: float) -> void:
	_time += delta
	var p := _get_player()
	var dist := _distance_to(p)

	match state:
		State.IDLE:
			if dist <= detect_tiles * tile_size.x:
				_enter(State.ALERT)
		State.ALERT:
			_state_t += delta
			if dist > lose_tiles * tile_size.x:
				_enter(State.IDLE)
			elif _state_t >= alert_time:
				_enter(State.CHASE)
		State.CHASE:
			if dist > lose_tiles * tile_size.x:
				_enter(State.RETURN)
			else:
				_move_along(delta, _cell_of(p.global_position))
		State.RETURN:
			if dist <= detect_tiles * tile_size.x:
				_enter(State.CHASE)
			elif _cell == _home_cell and not _moving:
				_enter(State.IDLE)
			else:
				_move_along(delta, _home_cell)

	_check_kill(p)
	_apply_visual()


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0
	if _alert != null:
		_alert.visible = (s == State.ALERT)


# ---------------------------------------------------------------
# GERAK (sel demi sel, jalur dicari dengan BFS)
# ---------------------------------------------------------------
func _move_along(delta: float, goal: Vector2i) -> void:
	if _moving:
		var step := speed_tiles * tile_size.x * delta
		global_position = global_position.move_toward(_target_pos, step)
		if global_position.distance_to(_target_pos) < 0.01:
			global_position = _target_pos
			_cell = _target_cell
			_moving = false
		return

	if _cell == goal:
		return
	var nxt := _next_step(_cell, goal)
	if nxt == _cell:
		# Tidak ada jalur dalam jangkauan: menyerah dan pulang.
		# Kalau jalan pulang juga tertutup, diam di tempat (jangan hitung ulang tiap frame).
		if state == State.CHASE:
			_enter(State.RETURN)
		elif state == State.RETURN:
			_enter(State.IDLE)
		return
	_target_cell = nxt
	_target_pos = _cell_to_world(nxt)
	_moving = true


## Sel berikutnya pada jalur terpendek origin -> to. Mengembalikan origin kalau tidak ada jalur
func _next_step(origin: Vector2i, to: Vector2i) -> Vector2i:
	var blockers := get_tree().get_nodes_in_group("gate_blocker")
	var came := {origin: origin}
	var depth := {origin: 0}
	var queue: Array[Vector2i] = [origin]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		if c == to:
			break
		if depth[c] >= max_path_tiles:
			continue
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n: Vector2i = c + d
			if came.has(n) or _blocked(n, blockers):
				continue
			came[n] = c
			depth[n] = depth[c] + 1
			queue.append(n)

	if not came.has(to):
		return origin
	var step := to
	while came[step] != origin:
		step = came[step]
	return step


func _blocked(c: Vector2i, blockers: Array) -> bool:
	if _walls.get_cell_source_id(c) != -1:
		return true
	if _gates != null and _gates.get_cell_source_id(c) != -1:
		return true
	for g in blockers:
		if g.has_method("blocks_cell") and g.blocks_cell(c):
			return true
	return false


# ---------------------------------------------------------------
# SENTUHAN
# ---------------------------------------------------------------
## Cek jarak titik virus ke LINTASAN player sejak frame lalu, jadi player yang
## slide sangat cepat tidak bisa menembus virus di antara dua frame.
func _check_kill(p: Node2D) -> void:
	if p == null:
		return
	if not p.alive:
		_prev_valid = false
		return
	var cur := p.global_position
	var last := _prev_pos if _prev_valid else cur
	_prev_pos = cur
	_prev_valid = true
	if p.locked:                     # popup hoax atau level selesai: aman
		return
	var closest := Geometry2D.get_closest_point_to_segment(global_position, last, cur)
	if closest.distance_to(global_position) <= kill_radius_tiles * tile_size.x:
		p.die()


func _on_player_died() -> void:
	reset()


# ---------------------------------------------------------------
# BANTUAN
# ---------------------------------------------------------------
func _get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player != null and _player.has_signal("died") \
				and not _player.is_connected("died", _on_player_died):
			_player.connect("died", _on_player_died)
	return _player


## Jarak ke player (piksel). INF kalau player tidak ada atau sudah mati
func _distance_to(p: Node2D) -> float:
	if p == null or not p.alive:
		return INF
	return global_position.distance_to(p.global_position)


func _find_walls() -> TileMapLayer:
	var n: Node = get_parent()
	while n != null:
		var w := n.get_node_or_null("Walls") as TileMapLayer
		if w != null:
			return w
		n = n.get_parent()
	return null


func _cell_of(world_pos: Vector2) -> Vector2i:
	return _walls.local_to_map(_walls.to_local(world_pos))


func _cell_to_world(c: Vector2i) -> Vector2:
	return _walls.to_global(_walls.map_to_local(c))


# ---------------------------------------------------------------
# TAMPILAN (script hanya menggerakkan node)
# ---------------------------------------------------------------
func _apply_visual() -> void:
	if _body == null:
		return
	var rate := 14.0 if state == State.CHASE else 5.0
	var amp := 0.10 if state == State.CHASE else 0.04
	var k := 1.0 + amp * sin(_time * rate)
	_body.scale = Vector2(k, k)
