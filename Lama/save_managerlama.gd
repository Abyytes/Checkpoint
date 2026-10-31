extends Node

const SAVE_PATH := "user://savegame.json"

# Data game yang sedang berjalan
var data := {}

# Cek apakah file save sudah ada
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# Buat data awal untuk game baru, lalu simpan
func new_game() -> void:
	data = {
		"level": 1,
		"hp": 100,
		"position_x": 0.0,
		"position_y": 0.0,
	}
	save_game()

# Tulis data ke file
func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Gagal menyimpan: " + str(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data))

# Baca file ke dalam data
func load_game() -> void:
	if not has_save():
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Gagal membaca save: " + str(FileAccess.get_open_error()))
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		data = parsed
