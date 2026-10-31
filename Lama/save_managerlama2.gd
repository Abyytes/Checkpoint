extends Node
## Autoload "SaveManager". Satu-satunya yang membaca dan menulis file save.
## Main menu, pause menu, dan game hanya memanggil fungsi di sini.
##
## Alur data:
##   new_game()   -> reset data di MEMORI saja (file lama aman sampai pemain menyimpan)
##   save_game()  -> tulis data ke file (dipanggil tombol Save di pause / autosave)
##   load_game()  -> baca file ke data, mengembalikan true/false
##   has_save()   -> true hanya kalau file ada DAN isinya bisa dibaca

signal saved(success: bool)

const SAVE_PATH := "user://savegame.json"
const TEMP_PATH := "user://savegame.tmp"
const VERSION := 1

## Nilai awal game baru. Tambahkan kunci baru di sini.
const DEFAULT_DATA := {
	"level": 1,            # level yang akan dimainkan saat Continue
	"unlocked": 1,         # level tertinggi yang sudah terbuka
	"score": 0,
	"time": 0.0,           # total waktu bermain (detik)
	"intro_seen": false,   # cutscene pembuka sudah ditonton
	"results": {},        # hasil terbaik per level: "1": {coins, coins_total, hoax, hoax_total, deaths}
	"seen_info": [],      # id InfoZone yang sudah tampil (tutorial sekali seumur save)
	# --- kunci lama, hapus kalau tidak dipakai ---
	"hp": 100,
	"position_x": 0.0,
	"position_y": 0.0,
}
## Kunci yang harus bertipe int (JSON mengembalikan angka sebagai float, mis. 4 -> 4.0)
const INT_KEYS := ["level", "unlocked", "score", "hp"]

## Data game yang sedang berjalan
var data: Dictionary = DEFAULT_DATA.duplicate(true)


## True hanya kalau file ada dan isinya valid
func has_save() -> bool:
	return _read_file() != null


## Mulai dari awal. Hanya mereset data di memori, file save lama TIDAK disentuh.
func new_game() -> void:
	data = DEFAULT_DATA.duplicate(true)


## Tulis data ke file. Menulis ke file sementara dulu, lalu menggantinya,
## jadi save lama tidak rusak kalau penulisan gagal di tengah jalan.
func save_game() -> bool:
	var payload := data.duplicate(true)
	payload["version"] = VERSION

	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: gagal menyimpan (%s)" % error_string(FileAccess.get_open_error()))
		saved.emit(false)
		return false
	file.store_string(JSON.stringify(payload))
	file.close()

	var err := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("SaveManager: gagal mengganti file save (%s)" % error_string(err))
		saved.emit(false)
		return false
	saved.emit(true)
	return true


## Baca file ke data. Mengembalikan false kalau tidak ada atau rusak (data tidak berubah).
func load_game() -> bool:
	var loaded = _read_file()
	if loaded == null:
		return false
	data = _normalize(loaded)
	return true


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# ---------------------------------------------------------------
# PROGRES LEVEL DAN POPUP INFO (dipakai game.gd dan InfoZone)
# ---------------------------------------------------------------
func get_current_level() -> int:
	return maxi(1, int(data["level"]))


func get_unlocked() -> int:
	return maxi(1, int(data["unlocked"]))


## Hanya mengubah memori. Masuk ke file saat save_game() dipanggil.
func set_current_level(n: int) -> void:
	data["level"] = n


## Dipanggil saat level n selesai: simpan hasil terbaik, buka level berikutnya,
## lalu AUTOSAVE ke file.
func complete_level(n: int, stats: Dictionary) -> void:
	var key := str(n)
	var best: Dictionary = stats.duplicate()
	var old: Dictionary = data["results"].get(key, {})
	if not old.is_empty():
		best["coins"] = maxi(int(old.get("coins", 0)), int(stats.get("coins", 0)))
		best["hoax"] = maxi(int(old.get("hoax", 0)), int(stats.get("hoax", 0)))
		best["deaths"] = mini(int(old.get("deaths", 999)), int(stats.get("deaths", 0)))
	data["results"][key] = best
	data["unlocked"] = maxi(get_unlocked(), n + 1)
	data["level"] = n + 1
	save_game()


func has_seen_info(id: String) -> bool:
	return id in data["seen_info"]


## Hanya mengubah memori; tersimpan pada autosave berikutnya.
func mark_info_seen(id: String) -> void:
	if not has_seen_info(id):
		data["seen_info"].append(id)


# ---------------------------------------------------------------
# INTERNAL
# ---------------------------------------------------------------
## Mengembalikan Dictionary kalau file valid, selain itu null
func _read_file() -> Variant:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: gagal membaca save (%s)" % error_string(FileAccess.get_open_error()))
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("SaveManager: file save rusak, diabaikan.")
		return null
	if not (json.data is Dictionary):
		push_warning("SaveManager: isi file save tidak valid, diabaikan.")
		return null
	return json.data


## Gabungkan dengan nilai awal (kunci yang hilang terisi) dan perbaiki tipe angka
func _normalize(loaded: Dictionary) -> Dictionary:
	var result: Dictionary = DEFAULT_DATA.duplicate(true)
	for key in loaded:
		if key != "version":
			result[key] = loaded[key]
	for key in INT_KEYS:
		result[key] = _to_int(result[key], int(DEFAULT_DATA[key]))
	result["time"] = _to_float(result["time"], 0.0)
	result["intro_seen"] = bool(result["intro_seen"]) if typeof(result["intro_seen"]) == TYPE_BOOL else false
	if not (result["results"] is Dictionary):
		result["results"] = {}
	if not (result["seen_info"] is Array):
		result["seen_info"] = []
	return result


func _to_int(value: Variant, fallback: int) -> int:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT, TYPE_BOOL:
			return int(value)
	return fallback


func _to_float(value: Variant, fallback: float) -> float:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return float(value)
	return fallback
