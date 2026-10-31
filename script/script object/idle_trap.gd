extends Area2D
## Papan duri (jebakan seperti di Tomb of the Mask). Taruh papan ini di sebelah
## lorong, biasanya di tile tembok. Saat player melewati salah satu dari 4 tile di
## sisinya (atas, kanan, bawah, kiri), tile sisi itu berkedip sebagai peringatan.
## Setelah jeda, duri keluar di tile sisi tersebut dan membunuh player yang masih
## di sana atau melewatinya. Beberapa saat kemudian duri masuk lagi dan siap dipicu lagi.
## Tiap sisi bekerja sendiri-sendiri. Mandiri: tidak perlu mengubah LevelBase.
## Node anak (opsional): "SpikeUp", "SpikeRight", "SpikeDown", "SpikeLeft" = gambar
## duri di tile sisi masing-masing. Posisi dan arahnya diatur otomatis oleh script.

enum State { SAFE, WARN, SPIKED }

const SIDES := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const SPIKE_NODES := ["SpikeUp", "SpikeRight", "SpikeDown", "SpikeLeft"]

## Jeda (detik) dari player melewati sisi sampai duri keluar: waktu untuk kabur
@export_range(0.3, 10.0, 0.1) var delay: float = 2.0
## Lama (detik) duri tetap keluar sebelum masuk lagi
@export_range(0.2, 10.0, 0.1) var spike_time: float = 1.0
## Kecepatan kedip saat peringatan
@export_range(1.0, 20.0, 0.5) var blink_per_second: float = 6.0

var _state: Array[int] = [0, 0, 0, 0]
var _timer: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _walls: TileMapLayer
var _player: Node2D


func _ready() -> void:
	add_to_group("spike_board")
	monitoring = false
	monitorable = false
	if not _find_refs():
		push_error("Papan duri: 'Walls' atau 'Player' tidak ditemukan di level.")
		return
	for i in 4:
		var s := get_node_or_null(SPIKE_NODES[i]) as Node2D
		if s != null:
			s.position = Vector2(SIDES[i]) * _tile()
			s.rotation = float(i) * PI / 2.0        # duri menghadap menjauhi papan
			s.visible = false
	if _player.has_signal("moved_to_cell"):
		_player.connect("moved_to_cell", _on_player_moved)


func _physics_process(delta: float) -> void:
	if _walls == null or _player == null:
		return
	if not _player.alive:
		_reset_all()
		return
	if _player.locked:
		return                                  # popup atau tarikan magnet: hitungan berhenti
	# Cadangan: player berhenti di tile sisi tanpa lewat sinyal
	# (ditarik magnet, keluar dari teleporter, atau respawn)
	if not _player.sliding:
		_trigger_at(_player.cell)

	for i in 4:
		match _state[i]:
			State.WARN:
				_timer[i] += delta
				var on := int(_timer[i] * blink_per_second * 2.0) % 2 == 0
				_show_side(i, 0.8 if on else 0.3)
				if _timer[i] >= delay:
					_state[i] = State.SPIKED
					_timer[i] = 0.0
					_show_side(i, 1.0)
			State.SPIKED:
				_check_kill(i)
				_timer[i] += delta
				if _timer[i] >= spike_time:
					_state[i] = State.SAFE
					_timer[i] = 0.0
					_hide_side(i)


func _on_player_moved(c: Vector2i) -> void:
	if _player.alive:
		_trigger_at(c)


func _trigger_at(c: Vector2i) -> void:
	var m := _my_cell()
	for i in 4:
		if c == m + SIDES[i] and _state[i] == State.SAFE:
			_state[i] = State.WARN
			_timer[i] = 0.0


func _check_kill(i: int) -> void:
	if not _player.alive:
		return
	var side_center := _center(_my_cell() + SIDES[i])
	if _player.global_position.distance_to(side_center) < _tile() * 0.6:
		_player.die()


func _reset_all() -> void:
	for i in 4:
		if _state[i] != State.SAFE:
			_state[i] = State.SAFE
			_timer[i] = 0.0
			_hide_side(i)


func _show_side(i: int, alpha: float) -> void:
	var s := get_node_or_null(SPIKE_NODES[i]) as CanvasItem
	if s != null:
		s.visible = true
		s.modulate.a = alpha


func _hide_side(i: int) -> void:
	var s := get_node_or_null(SPIKE_NODES[i]) as CanvasItem
	if s != null:
		s.visible = false


func _tile() -> float:
	if _walls != null and _walls.tile_set != null:
		return float(_walls.tile_set.tile_size.x)
	return 32.0


func _find_refs() -> bool:
	var n: Node = get_parent()
	while n != null:
		var w := n.get_node_or_null("Walls")
		if w is TileMapLayer:
			_walls = w as TileMapLayer
			_player = n.get_node_or_null("Player") as Node2D
			return _player != null
		n = n.get_parent()
	return false


func _my_cell() -> Vector2i:
	return _walls.local_to_map(_walls.to_local(global_position))


func _center(c: Vector2i) -> Vector2:
	return _walls.to_global(_walls.map_to_local(c))
