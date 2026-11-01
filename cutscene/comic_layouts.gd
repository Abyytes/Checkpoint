class_name ComicLayouts
extends RefCounted
## Preset tata letak panel. Setiap fungsi mengembalikan daftar poligon
## (koordinat 0..1). Urutan = urutan panel muncul saat diklik.
##
##   var L := ComicLayouts.split_diag()
##   ComicPanelData.new(L[0])   # panel kiri
##   ComicPanelData.new(L[1])   # panel kanan
##
## Mau layout sendiri? Pakai ComicLayouts.poly([x1,y1, x2,y2, ...]) atau
## ComicLayouts.rect(x, y, lebar, tinggi). Sela antar panel (gutter) ~0.04.


## Ubah daftar angka datar [x1,y1,x2,y2,...] menjadi poligon.
static func poly(c: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, c.size(), 2):
		out.append(Vector2(c[i], c[i + 1]))
	return out


static func rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return poly([x, y, x + w, y, x + w, y + h, x, y + h])


## 1 panel penuh.
static func full() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	out.append(rect(0.03, 0.05, 0.94, 0.90))
	return out


## 2 panel kiri-kanan, dibelah garis miring.
static func split_diag() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	out.append(poly([0.03, 0.05, 0.58, 0.05, 0.46, 0.95, 0.03, 0.95]))
	out.append(poly([0.62, 0.05, 0.97, 0.05, 0.97, 0.95, 0.50, 0.95]))
	return out


## 2 panel atas-bawah, dibelah garis miring.
static func stack_2() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	out.append(poly([0.03, 0.05, 0.97, 0.05, 0.97, 0.46, 0.03, 0.54]))
	out.append(poly([0.03, 0.58, 0.97, 0.50, 0.97, 0.95, 0.03, 0.95]))
	return out


## 3 panel: 1 lebar di atas, 2 di bawah.
static func three_rows() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	out.append(poly([0.03, 0.05, 0.97, 0.05, 0.97, 0.50, 0.03, 0.56]))
	out.append(poly([0.03, 0.60, 0.50, 0.57, 0.46, 0.95, 0.03, 0.95]))
	out.append(poly([0.54, 0.567, 0.97, 0.54, 0.97, 0.95, 0.50, 0.95]))
	return out


## 3 panel vertikal miring (cocok untuk adegan aksi).
static func vertical_3() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	out.append(poly([0.03, 0.05, 0.36, 0.05, 0.30, 0.95, 0.03, 0.95]))
	out.append(poly([0.39, 0.05, 0.66, 0.05, 0.60, 0.95, 0.33, 0.95]))
	out.append(poly([0.69, 0.05, 0.97, 0.05, 0.97, 0.95, 0.63, 0.95]))
	return out


## 4 panel kotak 2x2.
static func grid_2x2() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	out.append(rect(0.03, 0.05, 0.46, 0.44))
	out.append(rect(0.51, 0.05, 0.46, 0.44))
	out.append(rect(0.03, 0.51, 0.46, 0.44))
	out.append(rect(0.51, 0.51, 0.46, 0.44))
	return out
