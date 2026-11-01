extends CutscenePlayer

## CERITA cutscene 1 - file yang kamu edit untuk mengubah urutan/animasi/teks.
##
## Alur: MC selesai kerja -> doomscrolling -> kesal karena berita hoaks ->
## layar komputer bersinar oranye -> terlempar ke dunia digital & ganti baju ->
## sosok misterius muncul -> fade out -> kartu teks penutup.
##
## Semua gambar berukuran 1920x1080 dengan latar transparan, jadi setiap panel
## ditempatkan di FULL (seluruh layar) dan bentuknya mengikuti gambar (cutout).
##
## Arah animasi (dari mana panel DATANG):
##   E.SLIDE_RIGHT = datang dari kanan     E.SLIDE_LEFT = datang dari kiri
##   E.SLIDE_UP    = datang dari atas      E.SLIDE_DOWN = datang dari bawah
## Kalau menambah _ready() sendiri di sini, panggil `super()` di baris pertama.

# Singkatan
const E = ComicPanelData.Enter
const S = ComicPanelData.TextStyle
const P = ComicPanelData.TextPos

# ---- Lokasi gambar. Ubah ART kalau foldermu berbeda. ----
# Nama file harus SAMA PERSIS (huruf besar/kecil) dengan yang ada di folder.
# Disarankan nanti diseragamkan jadi huruf kecil semua, lalu ubah di sini.
const ART := "res://cutscene/Panel/"
const P1A := ART + "PageA1.png"
const P1B := ART + "PageA2.png"
const P2A := ART + "PageB1.png"
const P2B := ART + "PageB2.png"
const P2C := ART + "PageB3.png"
const P3A := ART + "PageC1.png"
const P3B := ART + "PageC2.png"
const P3C := ART + "PageC3.png"
const P4 := ART + "Page4.PNG"
const P5A := ART + "PageE1.png"
const P5B := ART + "PageE2.png"
const P5C := ART + "PageE3.png"
const P6A := ART + "PageF1.png"
const P6B := ART + "PageF2.png"
const P6C := ART + "PageF3.png"

## Warna latar halaman (terlihat di sela panel yang transparan).
## Ganti ke Color.WHITE kalau mau gaya halaman komik putih.
const PAGE_BG := Color("#0b0b12")

## Gambar 1920x1080 menutupi seluruh layar.
const FULL := Rect2(0, 0, 1, 1)

const CLOSING_TEXT := "Nowadays, people trust what's on their screens way more than actual reality"

## Setelah cutscene selesai (atau di-SKIP), CutscenePlayer pindah ke scene ini.
## Kalau game.tscn-mu ada di folder lain, ubah path ini.
const GAME_SCENE := "res://tscn/game.tscn"


func _ready() -> void:
	if next_scene == "":
		next_scene = GAME_SCENE
	super()


## Satu panel dari satu file gambar. Kalau file tidak ketemu, muncul kotak
## placeholder dan error di Output, bukan crash.
func _panel(path: String) -> ComicPanelData:
	var tex := load(path) as Texture2D
	if tex == null:
		push_error("Gambar tidak ditemukan: " + path)
	return ComicPanelData.new().cutout(tex, FULL)


func _build_pages() -> Array[ComicPageData]:
	var pages: Array[ComicPageData] = []

	# =========================================================
	# HALAMAN 1 - tugas selesai, MC meraih ponsel
	#  panel 1 ada di KANAN layar -> datang dari kanan
	#  panel 2 ada di KIRI layar  -> datang dari kiri (tangan menyambar ponsel)
	# =========================================================
	pages.append(ComicPageData.new([
		_panel(P1A).fx(E.SLIDE_RIGHT, 0.7),
		_panel(P1B).fx(E.SLIDE_LEFT, 0.45),
	]).tone(PAGE_BG))

	# =========================================================
	# HALAMAN 2 - doomscrolling. Panel kanan -> tengah -> kiri.
	# Panel tengah datang dari bawah supaya terasa seperti layar yang di-scroll.
	# =========================================================
	pages.append(ComicPageData.new([
		_panel(P2A).fx(E.SLIDE_RIGHT, 0.45),
		_panel(P2B).fx(E.SLIDE_DOWN, 0.4),
		_panel(P2C).fx(E.SLIDE_LEFT, 0.35).hit(6.0, false),   # makin kesal
	]).tone(PAGE_BG))

	# =========================================================
	# HALAMAN 3 - emosi memuncak, lalu layar bersinar oranye
	#  panel 1: ponsel retak digenggam (kanan)   -> getaran
	#  panel 2: tangan menepuk meja (tengah)     -> jatuh dari atas + getaran
	#  panel 3: mata terpantul cahaya oranye     -> fade pelan + kilatan
	# =========================================================
	pages.append(ComicPageData.new([
		_panel(P3A).fx(E.SLIDE_RIGHT, 0.35).hit(10.0, false),
		_panel(P3B).fx(E.SLIDE_UP, 0.3).hit(16.0, false),
		_panel(P3C).fx(E.FADE, 1.0, 0.25).hit(8.0, true),
	]).tone(PAGE_BG))

	# =========================================================
	# HALAMAN 4 - terlempar ke dunia digital (gambar penuh layar).
	# .cut() = tanpa fade hitam, potongan mendadak supaya terasa tersedot.
	# Jatuh dari atas dengan getaran besar + kilatan.
	# =========================================================
	pages.append(ComicPageData.new([
		_panel(P4).fx(E.SLIDE_UP, 0.45).hit(22.0, true),
	]).tone(PAGE_BG).cut())

	# =========================================================
	# HALAMAN 5 - ganti baju
	#  panel 1: MC bingung di padang rumput (kanan)
	#  panel 2: berseragam hijau, ada tulisan "Pop" -> animasi POP
	#  panel 3: tampak belakang menuju cahaya (kiri)
	# =========================================================
	pages.append(ComicPageData.new([
		_panel(P5A).fx(E.SLIDE_RIGHT, 0.55),
		_panel(P5B).fx(E.POP, 0.4).hit(6.0, false),
		_panel(P5C).fx(E.SLIDE_LEFT, 0.5),
	]).tone(PAGE_BG))

	# =========================================================
	# HALAMAN 6 - sosok misterius di depannya
	#  panel 1: punggung sosok oranye (kanan)
	#  panel 2: wajahnya menoleh -> POP
	#  panel 3: sosok utuh berdiri (kiri) -> fade pelan sebagai penutup
	# =========================================================
	pages.append(ComicPageData.new([
		_panel(P6A).fx(E.SLIDE_RIGHT, 0.6),
		_panel(P6B).fx(E.POP, 0.35).hit(8.0, false),
		_panel(P6C).fx(E.FADE, 1.0, 0.2),
	]).tone(PAGE_BG))

	# =========================================================
	# KARTU PENUTUP - layar hitam + teks muncul pelan.
	# Transisi halaman = fade-out ke hitam dulu (default), lalu teks fade-in.
	# =========================================================
	var closing := ComicLayouts.full()
	pages.append(ComicPageData.new([
		ComicPanelData.new(closing[0])
			.bg(Color(0, 0, 0, 0))   # transparan -> tanpa kotak/border
			.say(CLOSING_TEXT, "", S.PLAIN, P.CENTER)
			.fx(E.FADE, 1.4, 0.4),
	]).tone(Color.BLACK))

	return pages
