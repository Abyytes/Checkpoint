@tool
extends Area2D
## Kanon laser. Menembakkan sinar lurus dari kanon sampai tembok di ujung koridor.
## Siklus: mati -> peringatan (garis tipis berkedip) -> laser menyala -> mati.
## Letakkan kanon di tile tembok, sinar mulai dari tile di depannya.
## Mandiri: tidak perlu mengubah LevelBase.
## Node anak: "Sprite2D" = badan kanon (berputar sesuai arah), "Beam" = Line2D sinar.

enum Dir { UP, RIGHT, DOWN, LEFT }
enum State { OFF, WARN, ON }

@export var direction: Dir = Dir.RIGHT:
	set(v):
		direction = v
		_apply_direction()
		_update_preview()
## Lama (detik) laser mati
@export_range(0.2, 10.0, 0.1) var off_time: float = 2.0
## Lama (detik) peringatan sebelum laser menyala
@export_range(0.1, 5.0, 0.1) var warn_time: float = 0.6
## Lama (detik) laser menyala
@export_range(0.1, 5.0, 0.1) var on_time: float = 0.8
## Penundaan awal (detik) supaya beberapa kanon bisa bergantian
@export_range(0.0, 10.0, 0.1) var start_delay: float = 0.0
## Batas jarak (tile) kalau tidak ada tembok di ujung
@export_range(1, 200) var max_range_tiles: int = 40
@export var warn_width: float = 3.0
@export var on_width: float = 14.0

var _state := State.OFF
var _timer := 0.0
var _length := 0.0
var _walls: TileMapLayer
var _gates: TileMapLayer
var _player: Node2D


func _ready() -> void:
	_apply_direction()
	if Engine.is_editor_hint():
		_update_preview()
		return
	add_to_group("laser_cannon")
	monitoring = false
	monitorable = false
	if not _find_refs() or _player == null:
		push_error("LaserCannon: 'Walls' atau 'Player' tidak ditemukan di level.")
	_timer = -start_delay
	_hide_beam()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _walls == null or _player == null:
		return
	if _player.locked:
		return                                  # popup atau tarikan magnet: siklus berhenti
	_timer += delta
	match _state:
		State.OFF:
			if _timer >= off_time:
				_state = State.WARN
				_timer = 0.0
				_refresh_geometry()
				_show_beam(warn_width, 0.7)
		State.WARN:
			_show_beam(warn_width, 0.9 if int(_timer * 16.0) % 2 == 0 else 0.35)
			if _timer >= warn_time:
				_state = State.ON
				_timer = 0.0
				_show_beam(on_width, 1.0)
		State.ON:
			if _player.alive:
				_check_hit()
			if _timer >= on_time:
				_state = State.OFF
				_timer = 0.0
				_hide_beam()


func _check_hit() -> void:
	var d := Vector2(_dir_vec())
	var rel := _player.global_position - global_position
	var along := rel.dot(d)
	var across := absf(rel.cross(d))
	if along > 0.0 and along <= _length and across < _tile() * 0.4:
		_player.die()


## Hitung ulang panjang sinar (gerbang bisa terbuka di tengah game)
func _refresh_geometry() -> void:
	var end_point := _compute_end()
	_length = maxf((end_point - global_position).dot(Vector2(_dir_vec())), 0.0)
	var beam := get_node_or_null("Beam") as Line2D
	if beam != null:
		beam.points = PackedVector2Array([Vector2.ZERO, to_local(end_point)])


## Titik akhir sinar (global): pinggir tile bebas terakhir sebelum tembok
func _compute_end() -> Vector2:
	if _walls == null:
		return global_position
	var start_cell := _cell_of(global_position)
	var step := _dir_vec()
	var k := 1
	while k <= max_range_tiles and not _is_wall(start_cell + step * k):
		k += 1
	var last_free := start_cell + step * (k - 1)
	return _center(last_free) + Vector2(step) * (_tile() * 0.5)


func _is_wall(c: Vector2i) -> bool:
	if _walls.get_cell_source_id(c) != -1:
		return true
	return _gates != null and _gates.get_cell_source_id(c) != -1


func _dir_vec() -> Vector2i:
	match direction:
		Dir.UP: return Vector2i.UP
		Dir.RIGHT: return Vector2i.RIGHT
		Dir.DOWN: return Vector2i.DOWN
		_: return Vector2i.LEFT


func _apply_direction() -> void:
	var s := get_node_or_null("Sprite2D") as Node2D
	if s != null:
		s.rotation = float(direction) * PI / 2.0


## Di editor: garis tipis menunjukkan jalur laser. Diperbarui saat Direction diubah
## atau scene dibuka ulang.
func _update_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_find_refs()
	var beam := get_node_or_null("Beam") as Line2D
	if beam == null or _walls == null:
		return
	beam.visible = true
	beam.width = warn_width
	beam.modulate.a = 0.5
	beam.points = PackedVector2Array([Vector2.ZERO, to_local(_compute_end())])


func _show_beam(width: float, alpha: float) -> void:
	var beam := get_node_or_null("Beam") as Line2D
	if beam != null:
		beam.visible = true
		beam.width = width
		beam.modulate.a = alpha


func _hide_beam() -> void:
	var beam := get_node_or_null("Beam") as Line2D
	if beam != null:
		beam.visible = false


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
			_gates = n.get_node_or_null("Gates") as TileMapLayer
			_player = n.get_node_or_null("Player") as Node2D
			return true
		n = n.get_parent()
	return false


func _cell_of(world_pos: Vector2) -> Vector2i:
	return _walls.local_to_map(_walls.to_local(world_pos))


func _center(c: Vector2i) -> Vector2:
	return _walls.to_global(_walls.map_to_local(c))
