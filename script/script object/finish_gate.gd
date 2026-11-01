class_name FinishGate
extends Node2D
## Gerbang selesai. Tersembunyi sampai semua hoax mati.
## Posisinya dipindah ke PlayerStart oleh LevelBase.
##
## Saat player masuk ke gerbang, LevelBase memanggil go_next_level() dan gerbang
## membuka LEVEL BERIKUTNYA:
##   - Otomatis: nomor di akhir nama file level dinaikkan satu.
##     level_1.tscn -> level_2.tscn -> level_3.tscn dan seterusnya
##     (level_01 -> level_02 juga jalan, angka nol di depan dipertahankan).
##   - Kalau file level berikutnya tidak ada, dianggap level terakhir: membuka
##     final_scene_path kalau diisi, kalau kosong hanya berhenti di level itu.
##   - next_level_path bisa diisi untuk menentukan tujuan sendiri (mengalahkan otomatis).

var is_open := false

@export_group("Level berikutnya")
## Isi untuk menentukan level tujuan sendiri. Kosongkan untuk otomatis memakai
## nomor berikutnya (level_1 -> level_2)
@export_file("*.tscn") var next_level_path: String = ""
## Scene yang dibuka kalau tidak ada level berikutnya (menu, kredit, dan sebagainya).
## Kosongkan untuk hanya berhenti di level terakhir
@export_file("*.tscn") var final_scene_path: String = ""
## Jeda sebelum pindah level (detik), memberi waktu untuk efek atau suara
@export var transition_delay: float = 0.6

var _leaving := false


func _ready() -> void:
	close()


func close() -> void:
	is_open = false
	hide()


func appear() -> void:
	if is_open:
		return
	is_open = true
	show()


# ---------------------------------------------------------------
# PINDAH LEVEL
# ---------------------------------------------------------------
## Dipanggil LevelBase.complete() saat player masuk ke gerbang
func go_next_level() -> void:
	if _leaving:
		return
	var target := next_level_path
	if target == "":
		var next := _derive_next_path(_level_scene_path())
		if next != "" and ResourceLoader.exists(next):
			target = next
		else:
			target = final_scene_path
	if target == "":
		print("FinishGate: tidak ada level berikutnya (level terakhir).")
		return

	_leaving = true
	if transition_delay > 0.0:
		await get_tree().create_timer(transition_delay).timeout
	if not is_inside_tree():
		return                               # level sudah diganti pihak lain
	var err := get_tree().change_scene_to_file(target)
	if err != OK:
		push_warning("FinishGate: gagal membuka %s (kode %d)" % [target, err])
		_leaving = false


## Path file scene level yang sedang berjalan (induk LevelBase, atau scene utama)
func _level_scene_path() -> String:
	var n: Node = self
	while n != null:
		if n.has_signal("level_completed") and n.scene_file_path != "":
			return n.scene_file_path
		n = n.get_parent()
	var cs := get_tree().current_scene
	return cs.scene_file_path if cs != null else ""


## "res://tscn/level_1.tscn" -> "res://tscn/level_2.tscn". Kosong kalau namanya tidak berangka
func _derive_next_path(path: String) -> String:
	var re := RegEx.new()
	re.compile("^(.*?)(\\d+)(\\.[A-Za-z]+)$")
	var m := re.search(path)
	if m == null:
		return ""
	var digits := m.get_string(2)
	var nxt := str(int(digits) + 1)
	if digits.begins_with("0"):
		nxt = nxt.pad_zeros(digits.length())
	return m.get_string(1) + nxt + m.get_string(3)
