class_name ComicPanelData
extends Resource
## DATA satu panel komik. Tidak menampilkan apa pun, hanya "resep" untuk ComicPanel.
##
## Cara pakai (gaya berantai, boleh disambung sesuka hati):
##   ComicPanelData.new(layout[0]) \
##       .bg(Color("#10101c")) \
##       .say("Halo!", "Nara", TextStyle.SPEECH) \
##       .fx(Enter.POP, 0.5) \
##       .hit(10.0, true)
##
## Semua titik (points) memakai koordinat 0..1 relatif terhadap layar,
## jadi otomatis menyesuaikan resolusi. (0,0)=kiri atas, (1,1)=kanan bawah.

enum Enter { FADE, SLIDE_LEFT, SLIDE_RIGHT, SLIDE_UP, SLIDE_DOWN, POP }
## PLAIN = teks polos rata tengah tanpa kotak (untuk kartu narasi di layar hitam).
enum TextStyle { CAPTION, SPEECH, SHOUT, SFX, PLAIN }
enum TextPos { BOTTOM, TOP, CENTER }

# --- Bentuk ---
## Sudut-sudut panel (minimal 3). Bisa miring supaya terasa komik.
@export var points: PackedVector2Array = PackedVector2Array()

# --- Isi gambar ---
## Warna isi kalau tidak ada gambar (placeholder sebelum art-nya jadi).
@export var fill_color: Color = Color("#1b1b2f")
## Gambar panel (SVG/PNG). Otomatis di-"cover" sehingga memenuhi panel.
@export var texture: Texture2D
## 1.0 = pas memenuhi panel. Lebih besar = lebih ter-zoom.
@export_range(1.0, 3.0, 0.01, "or_greater") var image_zoom: float = 1.0
## Geser bagian gambar yang terlihat. Satuan 0..1 dari ukuran gambar.
@export var image_offset: Vector2 = Vector2.ZERO
## Zoom perlahan setelah panel muncul (efek "push-in"). 0 = diam.
@export var drift: float = 0.0
## true = bentuk mengikuti gambar (alpha), bukan poligon. Diatur lewat cutout().
@export var shape_from_image: bool = false

# --- Teks ---
@export var speaker: String = ""
@export_multiline var text: String = ""
@export var text_style: TextStyle = TextStyle.CAPTION
@export var text_pos: TextPos = TextPos.BOTTOM
## Warna aksen (garis kotak caption, nama pembicara, teks SFX).
@export var accent: Color = Color(0.753, 0.0, 0.4)

# --- Animasi & efek ---
@export var enter: Enter = Enter.FADE
@export var enter_time: float = 0.45
## Jeda sebelum panel mulai muncul (detik).
@export var delay: float = 0.0
## Kekuatan layar bergetar saat panel muncul (piksel). 0 = tidak.
@export var shake: float = 0.0
## Kilatan putih saat panel muncul.
@export var flash: bool = false
@export var sfx: AudioStream
## Jeda tambahan di mode AUTO sebelum lanjut (detik).
@export var hold: float = 1.2


func _init(p_points: PackedVector2Array = PackedVector2Array()) -> void:
	points = p_points


# ---------------------------------------------------------------
# Method berantai (semua mengembalikan dirinya sendiri)
# ---------------------------------------------------------------

## Warna isi panel.
func bg(color: Color) -> ComicPanelData:
	fill_color = color
	return self


## Pasang gambar. zoom/offset/drift opsional.
func img(tex: Texture2D, zoom: float = 1.0, offset: Vector2 = Vector2.ZERO, drift_amount: float = 0.0) -> ComicPanelData:
	texture = tex
	image_zoom = zoom
	image_offset = offset
	drift = drift_amount
	return self


## Teks. speaker boleh kosong (untuk narasi).
func say(p_text: String, p_speaker: String = "", style: TextStyle = TextStyle.CAPTION, pos: TextPos = TextPos.BOTTOM) -> ComicPanelData:
	text = p_text
	speaker = p_speaker
	text_style = style
	text_pos = pos
	return self


## Animasi masuk.
func fx(p_enter: Enter = Enter.FADE, time: float = 0.45, wait: float = 0.0) -> ComicPanelData:
	enter = p_enter
	enter_time = time
	delay = wait
	return self


## Efek benturan: getar layar dan/atau kilat putih.
func hit(shake_strength: float = 10.0, do_flash: bool = false) -> ComicPanelData:
	shake = shake_strength
	flash = do_flash
	return self


## Suara saat panel muncul.
func audio(stream: AudioStream) -> ComicPanelData:
	sfx = stream
	return self


## Panel CUTOUT: bentuk panel = isi gambar itu sendiri. Area transparan di
## PNG/SVG tetap transparan, jadi panel di bawahnya tetap terlihat.
## place = area penempatan (0..1). Gambar dimuat UTUH di dalamnya, rasio terjaga.
## Border otomatis dimatikan: gambar bayangan mengikuti siluet gambar.
##   ComicPanelData.new().cutout(preload("res://art/nara.svg"), Rect2(0.05, 0.1, 0.45, 0.85))
func cutout(tex: Texture2D, place: Rect2) -> ComicPanelData:
	texture = tex
	shape_from_image = true
	points = ComicLayouts.rect(place.position.x, place.position.y, place.size.x, place.size.y)
	return self


## Warna aksen.
func tint(color: Color) -> ComicPanelData:
	accent = color
	return self
