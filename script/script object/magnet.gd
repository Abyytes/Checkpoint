extends Area2D
## Penarik (magnet). Player yang masuk ke area (bawaan 3x3 tile) ditarik ke
## tile tengah dan berhenti di sana. Dari tengah, player bebas di-swipe keluar.
## Mandiri: tidak perlu mengubah LevelBase. Syarat: induk level punya anak
## "Walls" (TileMapLayer) dan "Player" yang punya sinyal moved_to_cell.

## Waktu (detik) tarikan ke tengah
@export_range(0.02, 1.0, 0.01) var pull_time: float = 0.15
## Jarak area dari tengah dalam tile: 1 = 3x3, 2 = 5x5.
## Kalau diubah, skala AreaSprite ikut disesuaikan.
@export_range(1, 3) var radius: int = 1

var _walls: TileMapLayer
var _player: Node2D
var _pulling := false


func _ready() -> void:
	add_to_group("magnet")
	monitoring = false
	monitorable = false
	if not _find_refs():
		push_error("Magnet: 'Walls' atau 'Player' tidak ditemukan di level.")
		return
	if _player.has_signal("moved_to_cell"):
		_player.connect("moved_to_cell", _on_player_moved)
	else:
		push_error("Magnet: Player tidak punya sinyal moved_to_cell.")


func _on_player_moved(c: Vector2i) -> void:
	if _pulling or not _player.alive or _player.locked:
		return
	var m := _cell_of(global_position)
	if not _in_area(c, m):
		return
	# Hanya menangkap saat MASUK dari luar area, supaya player bisa keluar dari tengah
	var d: Vector2i = _player.dir
	if d == Vector2i.ZERO or _in_area(c - d, m):
		return
	_pulling = true
	_player.sliding = false
	_player.dir = Vector2i.ZERO
	_player.queued_dir = Vector2i.ZERO
	if "boost" in _player:
		_player.boost = 1.0
	_begin_pull.call_deferred(m)


func _begin_pull(m: Vector2i) -> void:
	# Dibatalkan kalau di tile masuk player mati atau dikunci (misalnya popup hoax)
	if not is_instance_valid(_player) or not _player.alive or _player.locked:
		_pulling = false
		return
	_player.locked = true
	var t := create_tween()
	t.tween_property(_player, "global_position", _center(m), pull_time)
	await t.finished
	if is_instance_valid(_player) and _player.alive:
		_player.cell = m
		_player.global_position = _center(m)
		_player.locked = false
	_pulling = false


func _in_area(c: Vector2i, m: Vector2i) -> bool:
	return absi(c.x - m.x) <= radius and absi(c.y - m.y) <= radius


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


func _cell_of(world_pos: Vector2) -> Vector2i:
	return _walls.local_to_map(_walls.to_local(world_pos))


func _center(c: Vector2i) -> Vector2:
	return _walls.to_global(_walls.map_to_local(c))
