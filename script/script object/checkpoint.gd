extends Area2D
## Checkpoint. Saat player menyentuhnya, titik respawn (node PlayerStart) dipindah
## ke tile ini. Setelah mati, player muncul di checkpoint terakhir yang disentuh,
## bukan di awal level. Hoax yang sudah mati dan koin yang sudah diambil tidak di-reset.
## Mandiri: tidak perlu mengubah LevelBase. Syarat: induk level punya anak
## "Walls" (TileMapLayer), "Player", dan "PlayerStart".
## Node anak (opsional): "Sprite2D" = diredupkan saat belum aktif.

signal activated(checkpoint: Area2D)

@export var inactive_color: Color = Color(0.55, 0.55, 0.55)
@export var active_color: Color = Color.WHITE

var is_active := false

var _level: Node
var _walls: TileMapLayer
var _player: Node2D
var _start: Node2D


func _ready() -> void:
	add_to_group("checkpoint")
	monitoring = false
	monitorable = false
	set_active(false)
	if not _find_refs():
		push_error("Checkpoint: 'Walls', 'Player', atau 'PlayerStart' tidak ditemukan di level.")
		return
	if _player.has_signal("moved_to_cell"):
		_player.connect("moved_to_cell", _on_player_moved)


func _physics_process(_delta: float) -> void:
	# Cadangan: player berhenti di tile ini tanpa lewat sinyal
	# (ditarik magnet, keluar dari teleporter, atau respawn)
	if _player == null or is_active:
		return
	if _player.alive and not _player.sliding and _player.cell == _my_cell():
		_activate()


func _on_player_moved(c: Vector2i) -> void:
	if not is_active and _player.alive and c == _my_cell():
		_activate()


func _activate() -> void:
	# Hanya satu checkpoint aktif dalam satu level: yang terakhir disentuh
	for cp in get_tree().get_nodes_in_group("checkpoint"):
		if cp != self and cp.get("_level") == _level and cp.has_method("set_active"):
			cp.set_active(false)
	set_active(true)
	_start.global_position = _center(_my_cell())
	activated.emit(self)


func set_active(a: bool) -> void:
	is_active = a
	var s := get_node_or_null("Sprite2D") as CanvasItem
	if s != null:
		s.modulate = active_color if a else inactive_color


func _find_refs() -> bool:
	var n: Node = get_parent()
	while n != null:
		var w := n.get_node_or_null("Walls")
		if w is TileMapLayer:
			_level = n
			_walls = w as TileMapLayer
			_player = n.get_node_or_null("Player") as Node2D
			_start = n.get_node_or_null("PlayerStart") as Node2D
			return _player != null and _start != null
		n = n.get_parent()
	return false


func _my_cell() -> Vector2i:
	return _walls.local_to_map(_walls.to_local(global_position))


func _center(c: Vector2i) -> Vector2:
	return _walls.to_global(_walls.map_to_local(c))
