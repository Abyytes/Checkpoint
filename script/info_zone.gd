@tool
class_name InfoZone
extends Node2D
## Titik informasi. Taruh di dalam node Objects pada level (Add Node -> InfoZone).
## Saat player melewati tile ini, muncul popup. Posisi otomatis di-snap ke tengah tile.

enum Mode {
	DIALOG,   ## Kotak di tengah layar. Player berhenti, lanjut setelah ditutup.
	TOAST,    ## Banner kecil di atas. Player tidak berhenti.
}

## Wajib diisi kalau "First Time Only" dicentang (contoh: "tutorial_slide")
@export var id: String = ""
@export var mode: Mode = Mode.DIALOG
@export var title: String = ""
## Mendukung BBCode, contoh: [b]tebal[/b] dan [color=red]merah[/color]
@export_multiline var body: String = ""
## Lama banner tampil (detik), hanya untuk mode TOAST
@export var toast_duration: float = 3.0

@export_group("Pemicu")
## Hanya tampil sekali per level (selama level belum dimuat ulang)
@export var once: bool = true
## Hanya tampil sekali seumur save (cocok untuk tutorial). Butuh "Id".
@export var first_time_only: bool = false

@export_group("Tampilan")
## Tampilkan tanda "i" di peta (di editor selalu terlihat)
@export var show_marker: bool = true:
	set(v):
		show_marker = v
		queue_redraw()

var blocking: bool:
	get:
		return mode == Mode.DIALOG

var _triggered := false


func _ready() -> void:
	queue_redraw()
	if Engine.is_editor_hint():
		return
	add_to_group("info_zone")


func can_trigger() -> bool:
	if once and _triggered:
		return false
	if first_time_only and id != "":
		var sm := get_node_or_null("/root/SaveManager")
		if sm != null and sm.has_seen_info(id):
			return false
	return true


func mark_triggered() -> void:
	_triggered = true
	if first_time_only and id != "":
		var sm := get_node_or_null("/root/SaveManager")
		if sm != null:
			sm.mark_info_seen(id)
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		if not show_marker or (once and _triggered):
			return
	var col := Color(0.35, 0.8, 1.0)
	draw_circle(Vector2.ZERO, 10.0, Color(col, 0.25))
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 24, col, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-4.0, 6.0), "i",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)


func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if first_time_only and id == "":
		w.append("First Time Only butuh Id yang unik.")
	return w
