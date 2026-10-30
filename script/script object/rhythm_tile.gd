@tool
class_name RhythmTile
extends Node2D
## Tombol di jalur. Saat player MELINTAS (atau berdiri di dekatnya), tekan
## Enter/Spasi, atau klik/tap singkat di layar. Tombol yang sudah ditekan menyala
## permanen. Kalau semua tombol ber-gate_id sama sudah menyala, RhythmGate dengan
## gate_id itu terbuka.
##
## Tidak ada hitungan waktu: yang dicek hanya jarak player ke tombol saat ditekan
## (lihat press_range_tiles). Tidak butuh fungsi tambahan di player.gd selain
## group "player" (sudah dipasang player.gd).
##
## TAMPILAN memakai node anak, dikenali dari NAMA-nya (semuanya opsional):
##   Base          (Sprite2D / apa saja bertipe CanvasItem)  tombol saat belum ditekan
##   Lit           (CanvasItem)  tombol saat sudah ditekan
##   Glow          (CanvasItem)  menyala selama player cukup dekat (boleh ditekan)
##   IdLabel       (Label)       menampilkan nomor gate_id
##   AnimationPlayer             animasi opsional bernama "check" dan "miss"
##   SfxCheck, SfxMiss           AudioStreamPlayer atau AudioStreamPlayer2D
##   CheckFx                     CPUParticles2D / GPUParticles2D (One Shot)
## Node "ApproachRing" dari versi ritme tidak dipakai lagi (disembunyikan kalau ada).

signal checked(tile: RhythmTile)

## Tombol keyboard (default ui_accept = Enter/Spasi). Bisa diganti action buatan sendiri.
@export var check_action: StringName = &"ui_accept"
## Gerbang mana yang dibuka tombol ini
@export var gate_id: int = 1:
	set(v):
		gate_id = v
		_apply_look()
## Ukuran tile. Saat game jalan, diambil otomatis dari TileSet "Walls"
@export var tile_size := Vector2(32, 32)

@export_group("Tombol")
## Seberapa dekat player harus ada saat ditekan (dalam tile, dari tengah tombol ini).
## Player yang sedang slide hanya dihitung kalau tombol ada di lajur geraknya.
@export var press_range_tiles: float = 2.5
## Jeda setelah tiap penekanan (kena atau meleset). Mencegah spam. 0 = tanpa jeda
@export var press_cooldown: float = 0.25
## Klik/tap singkat (tanpa geser) di layar juga dihitung sebagai tekan tombol
@export var tap_counts_as_press: bool = true
## Geser maksimum (piksel layar) agar sentuhan masih dihitung tap, bukan swipe
@export var tap_max_move: float = 20.0
## Lama maksimum (detik) dari sentuh sampai lepas agar dihitung tap
@export var tap_max_time: float = 0.3

@export_group("Tampilan")
## Warnai node tampilan sesuai gate_id (matikan kalau desainmu sudah berwarna sendiri)
@export var tint_by_gate: bool = true:
	set(v):
		tint_by_gate = v
		_apply_look()

var is_lit := false

static var _lockout_until := 0.0     # dipakai bersama semua tombol
static var _tap_active := false      # pelacak tap, dipakai bersama
static var _tap_pos := Vector2.ZERO
static var _tap_time := 0.0

var _player: Node2D

@onready var _base := get_node_or_null("Base") as CanvasItem
@onready var _lit := get_node_or_null("Lit") as CanvasItem
@onready var _glow := get_node_or_null("Glow") as CanvasItem
@onready var _ring := get_node_or_null("ApproachRing") as CanvasItem
@onready var _id_label := get_node_or_null("IdLabel") as Label
@onready var _anim := get_node_or_null("AnimationPlayer") as AnimationPlayer


func _ready() -> void:
	_apply_look()
	if Engine.is_editor_hint():
		return              # di editor semua node tetap terlihat agar mudah didesain
	add_to_group("rhythm_tile")
	_snap_to_walls()
	_apply_state()


# ---------------------------------------------------------------
# INPUT
# ---------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not _is_press_event(event):
		return
	# Tombol pertama yang menerima event mengurus SEMUA tombol lain, lalu event ditandai selesai.
	get_viewport().set_input_as_handled()
	_process_press()


## Enter/Spasi, atau tap/klik singkat tanpa geser
func _is_press_event(event: InputEvent) -> bool:
	if event.is_action_pressed(check_action):
		return true
	if not tap_counts_as_press:
		return false

	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch:
		pos = event.position
		pressed = event.pressed
	elif event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return false
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return false             # sentuhan sudah ditangani ScreenTouch
		pos = event.position
		pressed = event.pressed
	else:
		return false

	var now := Time.get_ticks_msec() / 1000.0
	if pressed:
		_tap_active = true
		_tap_pos = pos
		_tap_time = now
		return false
	var is_tap := _tap_active \
		and pos.distance_to(_tap_pos) <= tap_max_move \
		and now - _tap_time <= tap_max_time
	_tap_active = false
	return is_tap


func _process_press() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _lockout_until:
		return
	_lockout_until = now + press_cooldown

	# Pilih tombol belum-menyala yang paling dekat dengan player dan masih dalam jangkauan
	var best: RhythmTile = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("rhythm_tile"):
		var t := n as RhythmTile
		if t == null or t.is_lit:
			continue
		var d := t._player_distance()
		if d <= t._range_px() and d < best_d:
			best = t
			best_d = d

	if best != null:
		best.check()
	else:
		get_tree().call_group("rhythm_tile", "flash_miss")


## Tandai tombol ini sudah ditekan
func check() -> void:
	if is_lit:
		return
	is_lit = true
	checked.emit(self)
	get_tree().call_group("rhythm_gate", "on_tile_changed", gate_id)
	_apply_state()
	_play("SfxCheck")
	_burst("CheckFx")
	if not _play_anim(&"check"):
		scale = Vector2(1.35, 1.35)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.2)


## Tombol ditekan tapi tidak ada tombol dalam jangkauan: tombol di dekat player memberi isyarat
func flash_miss() -> void:
	if is_lit or _player_distance() > _range_px() * 3.0:
		return
	_play("SfxMiss")
	if not _play_anim(&"miss") and _base != null:
		_base.modulate = Color(0.55, 0.55, 0.55)
		create_tween().tween_property(_base, "modulate", Color.WHITE, 0.25)


## Matikan lagi (opsional dipanggil saat level di-restart)
func reset_tile() -> void:
	is_lit = false
	_apply_state()
	get_tree().call_group("rhythm_gate", "on_tile_changed", gate_id)


# ---------------------------------------------------------------
# JARAK KE PLAYER
# ---------------------------------------------------------------
func _range_px() -> float:
	return press_range_tiles * tile_size.x


## Jarak (piksel) ke player, atau INF kalau player tidak bisa menekan tombol ini
## (mati, sedang dikunci popup/selesai, atau sedang slide di lajur lain).
func _player_distance() -> float:
	var p := _get_player()
	if p == null or not p.alive or p.locked:
		return INF

	var o := global_position - p.global_position
	if p.sliding:
		# Hanya hitung kalau tombol ada di jalur slide (satu lajur dengan arah gerak)
		var v := Vector2(p.dir)
		if absf(o.cross(v)) > tile_size.x * 0.5:
			return INF
	return o.length()


func _get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	return _player


func _snap_to_walls() -> void:
	var n: Node = get_parent()
	while n != null:
		var w := n.get_node_or_null("Walls") as TileMapLayer
		if w != null:
			if w.tile_set != null:
				tile_size = Vector2(w.tile_set.tile_size)
			var c := w.local_to_map(w.to_local(global_position))
			global_position = w.to_global(w.map_to_local(c))
			return
		n = n.get_parent()


# ---------------------------------------------------------------
# TAMPILAN (script hanya menyalakan/mematikan node)
# ---------------------------------------------------------------
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _glow != null:
		_glow.visible = (not is_lit) and _player_distance() <= _range_px()


func _tint() -> Color:
	return RhythmGate.color_for(gate_id) if tint_by_gate else Color.WHITE


## Warna dan nomor sesuai gate_id (ikut berubah langsung di editor)
func _apply_look() -> void:
	if _id_label != null:
		_id_label.text = str(gate_id)
	if not tint_by_gate:
		return
	var col := _tint()
	for n in [_base, _lit, _glow]:
		if n != null:
			n.self_modulate = col


## Status menyala / belum (dipanggil saat mulai, ditekan, dan reset)
func _apply_state() -> void:
	if _base != null:
		_base.visible = not is_lit
	if _lit != null:
		_lit.visible = is_lit
	if _glow != null:
		_glow.visible = false
	if _ring != null:
		_ring.visible = false            # sisa dari versi ritme


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
