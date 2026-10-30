extends Node2D

signal moved_to_cell(cell: Vector2i)
signal stopped(cell: Vector2i)
signal died
## Player dipindah teleport (posisi lama dan baru). Dipakai Virus agar lintasan lompatan tidak dihitung sebagai sentuhan
signal teleported(from_pos: Vector2, to_pos: Vector2)

## Kecepatan dasar (px/detik) pada multiplier 1x
@export var base_speed: float = 600.0
## Multiplier kecepatan, 1 sampai 3 (di keyboard: tombol 1/2/3)
@export_range(1, 3) var speed_mult: int = 1
## Jarak swipe minimum (piksel layar) agar dihitung sebagai swipe
@export var swipe_threshold: float = 40.0
## Simpan 1 perintah arah saat sedang slide, dijalankan begitu berhenti
@export var use_input_buffer: bool = true
## Kosongkan agar otomatis mencari node "Walls" (TileMapLayer)
@export var walls_path: NodePath

var walls: TileMapLayer
var gates: TileMapLayer
var cell := Vector2i.ZERO
var dir := Vector2i.ZERO
var queued_dir := Vector2i.ZERO
var sliding := false
## Pengali kecepatan dari pegas, kembali ke 1 saat berhenti
var boost := 1.0
var alive := true
## true = input diabaikan (saat popup hoax terbuka atau level selesai)
var locked := false

var _swipe_active := false
var _swipe_start := Vector2.ZERO
var _touch_index := -1


func _ready() -> void:
	add_to_group("player")           # dipakai BalloonTrap untuk menemukan player
	walls = _find_walls()
	if walls == null:
		push_error("Player: node 'Walls' (TileMapLayer) tidak ditemukan.")
		set_process_unhandled_input(false)
		set_physics_process(false)
		return
	gates = walls.get_parent().get_node_or_null("Gates") as TileMapLayer
	_snap_to_grid()


## Cari "Walls" di saudara, lalu naik ke induk-induknya kalau belum ketemu
func _find_walls() -> TileMapLayer:
	if walls_path != NodePath():
		return get_node_or_null(walls_path) as TileMapLayer
	var n: Node = get_parent()
	while n != null:
		var w := n.get_node_or_null("Walls")
		if w is TileMapLayer:
			return w
		n = n.get_parent()
	return null


func _snap_to_grid() -> void:
	cell = walls.local_to_map(walls.to_local(global_position))
	global_position = walls.to_global(walls.map_to_local(cell))


# ---------------------------------------------------------------
# INPUT: keyboard (WASD / panah), swipe sentuh (HP), swipe mouse
# ---------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		return

	if event is InputEventKey:
		_handle_key(event)
	elif event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_swipe_move(event.position)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		# Abaikan mouse "palsu" hasil emulasi dari sentuhan
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_swipe_move(event.position)


func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	# physical_keycode = posisi tombol, jadi WASD tetap benar di AZERTY dll.
	match event.physical_keycode:
		KEY_W, KEY_UP: _command(Vector2i.UP)
		KEY_S, KEY_DOWN: _command(Vector2i.DOWN)
		KEY_A, KEY_LEFT: _command(Vector2i.LEFT)
		KEY_D, KEY_RIGHT: _command(Vector2i.RIGHT)
		KEY_1: speed_mult = 1
		KEY_2: speed_mult = 2
		KEY_3: speed_mult = 3


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touch_index == -1:           # hanya lacak 1 jari
			_touch_index = event.index
			_swipe_begin(event.position)
	elif event.index == _touch_index:
		_touch_index = -1
		_swipe_active = false


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return                           # sentuhan sudah ditangani ScreenTouch
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_swipe_begin(event.position)
	else:
		_swipe_active = false


func _swipe_begin(pos: Vector2) -> void:
	_swipe_active = true
	_swipe_start = pos


func _swipe_move(pos: Vector2) -> void:
	if not _swipe_active:
		return
	var delta := pos - _swipe_start
	if delta.length() < swipe_threshold:
		return
	_swipe_active = false                # 1 swipe = 1 perintah
	if absf(delta.x) > absf(delta.y):
		_command(Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT)
	else:
		_command(Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP)


## Pintu masuk tunggal untuk semua jenis input
func _command(d: Vector2i) -> void:
	if not alive or locked or d == Vector2i.ZERO:
		return
	if sliding:
		if use_input_buffer:
			queued_dir = d
		return
	_start_slide(d)


# ---------------------------------------------------------------
# GERAK
# ---------------------------------------------------------------
func _start_slide(d: Vector2i) -> void:
	# Genangan merah (HoaxTileV2): dash BARU yang dimulai dari dalam genangan
	# dibalik arahnya. Dash yang sedang berjalan tidak terpengaruh, jadi cukup
	# dicek di sini (termasuk untuk perintah yang tersimpan di input buffer).
	if _in_reverse_zone():
		d = -d
	if _is_wall(cell + d):
		return                           # langsung nabrak, tidak bergerak
	dir = d
	sliding = true


func _physics_process(delta: float) -> void:
	if not sliding:
		return

	# "Anggaran jarak" per frame: di speed tinggi bisa melewati beberapa
	# tile dalam satu frame, tapi tembok dicek di setiap tile.
	var budget := base_speed * speed_mult * boost * delta
	while sliding and budget > 0.0:
		var target := walls.to_global(walls.map_to_local(cell + dir))
		var dist := global_position.distance_to(target)

		if budget < dist:
			global_position = global_position.move_toward(target, budget)
			budget = 0.0
		else:
			global_position = target
			budget -= dist
			cell += dir
			moved_to_cell.emit(cell)
			if not sliding:              # dihentikan pihak luar (Hoax / Finish)
				break
			_try_teleport()              # pindah tempat, slide tetap berjalan
			if _is_wall(cell + dir):
				_stop()


func _stop() -> void:
	sliding = false
	boost = 1.0
	dir = Vector2i.ZERO
	stopped.emit(cell)
	if queued_dir != Vector2i.ZERO:
		var q := queued_dir
		queued_dir = Vector2i.ZERO
		_start_slide(q)
		if sliding:
			return                       # langsung lanjut slide berikutnya
	_squash()


func _is_wall(c: Vector2i) -> bool:
	if walls.get_cell_source_id(c) != -1:
		return true
	if gates != null and gates.get_cell_source_id(c) != -1:
		return true
	# RhythmGate (objek gerbang) yang masih tertutup ikut menghalangi
	for g in get_tree().get_nodes_in_group("gate_blocker"):
		if g.has_method("blocks_cell") and g.blocks_cell(c):
			return true
	return false


## True kalau player berdiri di dalam genangan aktif (HoaxTileV2, group "reverse_zone")
func _in_reverse_zone() -> bool:
	for z in get_tree().get_nodes_in_group("reverse_zone"):
		if z.has_method("contains_point") and z.contains_point(global_position):
			return true
	return false


## Cek apakah sel yang baru dicapai adalah portal Teleport (group "teleport")
func _try_teleport() -> void:
	for t in get_tree().get_nodes_in_group("teleport"):
		if t.has_method("try_teleport") and t.try_teleport(self):
			return                           # berhenti mencari agar portal tujuan tidak memantulkan balik


## Efek kecil saat berhenti (placeholder)
func _squash() -> void:
	scale = Vector2(1.2, 0.8)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.12)


# ---------------------------------------------------------------
# DIPANGGIL DARI LUAR (LevelBase)
# ---------------------------------------------------------------
## Teleport: pindah ke sel lain TANPA menghentikan slide. Arah, kecepatan (boost),
## input buffer, dan sisa jarak pada frame ini dipertahankan.
func teleport_to(dest: Vector2i) -> void:
	var from_pos := global_position
	cell = dest
	global_position = walls.to_global(walls.map_to_local(dest))
	teleported.emit(from_pos, global_position)


## Pegas: ganti arah slide dan naikkan kecepatan sampai berhenti
func launch(d: Vector2i, boost_mult: float) -> void:
	if not sliding or d == Vector2i.ZERO:
		return
	dir = d
	boost = boost_mult


## Hentikan player di tile sekarang dan kunci input
func stop_here() -> void:
	sliding = false
	boost = 1.0
	dir = Vector2i.ZERO
	queued_dir = Vector2i.ZERO
	_swipe_active = false
	locked = true
	_squash()


func unlock() -> void:
	locked = false


func die() -> void:
	if not alive:
		return
	alive = false
	sliding = false
	boost = 1.0
	queued_dir = Vector2i.ZERO
	died.emit()
	hide()


## Dipanggil Level/Main saat restart tanpa memuat ulang scene
func respawn(at_global_pos: Vector2) -> void:
	alive = true
	sliding = false
	boost = 1.0
	locked = false
	dir = Vector2i.ZERO
	queued_dir = Vector2i.ZERO
	_swipe_active = false
	_touch_index = -1
	scale = Vector2.ONE
	global_position = at_global_pos
	_snap_to_grid()
	show()
