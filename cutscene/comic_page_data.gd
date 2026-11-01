class_name ComicPageData
extends Resource
## Satu HALAMAN komik = kumpulan panel yang tampil bersama di layar.
## Saat pemain klik, panel muncul satu per satu. Setelah panel terakhir,
## klik berikutnya pindah ke halaman berikutnya.
##
##   ComicPageData.new([panelA, panelB, panelC]).tone(Color("#0b0b12")).cut()

enum Transition { FADE, CUT }

@export var panels: Array[ComicPanelData] = []
@export var bg_color: Color = Color("#0b0b12")
@export var transition: Transition = Transition.FADE
## Musik latar mulai di halaman ini (kosong = lanjutkan musik sebelumnya).
@export var music: AudioStream


func _init(p_panels: Array = []) -> void:
	for p in p_panels:
		panels.append(p)


## Warna latar halaman (terlihat di sela-sela panel).
func tone(color: Color) -> ComicPageData:
	bg_color = color
	return self


## Pindah ke halaman ini tanpa fade hitam (potongan langsung).
func cut() -> ComicPageData:
	transition = Transition.CUT
	return self


## Mulai musik latar di halaman ini.
func bgm(stream: AudioStream) -> ComicPageData:
	music = stream
	return self
