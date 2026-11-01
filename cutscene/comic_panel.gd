class_name ComicPanel
extends Node2D
## Tampilan SATU panel komik: bentuk poligon, gambar, border, bayangan, teks,
## dan animasi masuknya. Dibuat & dikendalikan oleh CutscenePlayer.
##
## Pivot panel ada di TENGAH bentuknya, jadi scale/rotation terasa natural.

signal impact(shake_strength: float, do_flash: bool)
signal finished

## Jarak awal untuk animasi SLIDE_* (piksel).
const SLIDE_DISTANCE := 180.0
## Offset bayangan keras di belakang panel.
const SHADOW_OFFSET := Vector2(10, 12)
## Kemiringan teks bergaya SHOUT/SFX (derajat).
const TILT_DEG := -4.0

@onready var shadow: Polygon2D = $Shadow
@onready var fill: Polygon2D = $Fill
@onready var border: Line2D = $Border
@onready var text_layer: Control = $TextLayer
@onready var box: PanelContainer = $TextLayer/Box
@onready var speaker_label: Label = $TextLayer/Box/Margin/VBox/Speaker
@onready var body: RichTextLabel = $TextLayer/Box/Margin/VBox/Body
@onready var sfx_player: AudioStreamPlayer = $Sfx

var data: ComicPanelData
var is_done := false

var _bbox := Rect2()
var _local_pts := PackedVector2Array()
var _final_pos := Vector2.ZERO
var _began := false
var _tween: Tween
var _text_tween: Tween
var _drift_tween: Tween


# ---------------------------------------------------------------
# SETUP (dipanggil sekali setelah panel masuk scene tree)
# ---------------------------------------------------------------
func setup(d: ComicPanelData, page_size: Vector2) -> void:
	data = d
	if d.points.size() < 3:
		push_error("ComicPanel: points minimal 3 titik")
		return

	# 1) koordinat 0..1 -> piksel
	var pts := PackedVector2Array()
	for v in d.points:
		pts.append(v * page_size)

	# 2) kotak pembatas & titik tengah (jadi pivot)
	_bbox = Rect2(pts[0], Vector2.ZERO)
	for v in pts:
		_bbox = _bbox.expand(v)
	var center := _bbox.get_center()
	_final_pos = center
	position = center

	# 3) titik relatif terhadap pivot
	_local_pts = PackedVector2Array()
	for v in pts:
		_local_pts.append(v - center)

	shadow.position = SHADOW_OFFSET

	if d.shape_from_image and d.texture:
		# MODE CUTOUT: bentuk = isi gambar, transparan tetap transparan
		_setup_cutout()
	else:
		# MODE POLIGON: bentuk dari points, gambar dipotong mengikutinya
		shadow.polygon = _local_pts
		fill.polygon = _local_pts
		border.points = _local_pts
		border.closed = true
		if d.texture:
			fill.texture = d.texture
			fill.color = Color.WHITE
			_apply_uv(d.image_zoom)
		else:
			fill.texture = null
			fill.uv = PackedVector2Array()
			fill.color = d.fill_color
			# Panel hanya-teks (warna transparan, tanpa gambar): tanpa border & bayangan
			if d.fill_color.a <= 0.0:
				shadow.visible = false
				border.visible = false

	_setup_text()
	modulate.a = 0.0   # tak terlihat sampai play()


## Gambar utuh (rasio terjaga) di tengah area `points`. Bayangan = gambar yang
## sama diwarnai hitam, sehingga bayangan mengikuti siluet gambar.
func _setup_cutout() -> void:
	var tex := data.texture
	var tex_size := tex.get_size()
	var s := minf(_bbox.size.x / tex_size.x, _bbox.size.y / tex_size.y)
	var half := tex_size * s * 0.5
	var quad := PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	var uvs := PackedVector2Array([
		Vector2(0, 0), Vector2(tex_size.x, 0), tex_size, Vector2(0, tex_size.y),
	])
	fill.polygon = quad
	fill.uv = uvs
	fill.texture = tex
	fill.color = Color.WHITE
	shadow.polygon = quad
	shadow.uv = uvs
	shadow.texture = tex
	shadow.color = Color(0, 0, 0, 0.55)
	border.visible = false


## Pasang UV supaya gambar "cover" (memenuhi) panel, dengan zoom & geser.
func _apply_uv(zoom: float) -> void:
	if data == null or data.texture == null:
		return
	var tex_size := data.texture.get_size()
	var s := maxf(_bbox.size.x / tex_size.x, _bbox.size.y / tex_size.y) * zoom
	var uvs := PackedVector2Array()
	for v in _local_pts:
		uvs.append(v / s + tex_size * 0.5 + data.image_offset * tex_size)
	fill.uv = uvs


func _setup_text() -> void:
	var has_text := data.text.strip_edges() != ""
	box.visible = has_text

	# Layer teks menutupi seluruh kotak pembatas panel
	text_layer.position = _bbox.position - _bbox.get_center()
	text_layer.size = _bbox.size
	text_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in text_layer.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not has_text:
		return

	var style := data.text_style
	var shouting := style == ComicPanelData.TextStyle.SHOUT or style == ComicPanelData.TextStyle.SFX

	speaker_label.visible = data.speaker.strip_edges() != "" and not shouting
	speaker_label.text = data.speaker.to_upper()
	speaker_label.add_theme_color_override("font_color", data.accent)
	speaker_label.add_theme_font_size_override("font_size", 20)

	body.text = data.text
	body.visible_ratio = 0.0

	# --- Gaya kotak ---
	var sb := StyleBoxFlat.new()
	var font_size := 28
	var text_color := Color.WHITE
	match style:
		ComicPanelData.TextStyle.CAPTION:
			sb.bg_color = Color(0.04, 0.04, 0.08, 0.9)
			sb.border_width_left = 8
			sb.border_color = data.accent
		ComicPanelData.TextStyle.SPEECH:
			sb.bg_color = Color.WHITE
			sb.set_corner_radius_all(18)
			sb.set_border_width_all(3)
			sb.border_color = Color.BLACK
			text_color = Color(0.05, 0.05, 0.08)
		ComicPanelData.TextStyle.SHOUT:
			sb.bg_color = Color(0, 0, 0, 0)
			font_size = 60
		ComicPanelData.TextStyle.SFX:
			sb.bg_color = Color(0, 0, 0, 0)
			font_size = 90
			text_color = data.accent
		ComicPanelData.TextStyle.PLAIN:
			sb.bg_color = Color(0, 0, 0, 0)
			font_size = 40
			body.text = "[center]" + data.text + "[/center]"
	box.add_theme_stylebox_override("panel", sb)
	body.add_theme_font_size_override("normal_font_size", font_size)
	body.add_theme_color_override("default_color", text_color)
	if shouting:
		body.add_theme_constant_override("outline_size", 12)
		body.add_theme_color_override("font_outline_color", Color.BLACK)

	# --- Posisi kotak di dalam panel ---
	var m := 20.0
	match data.text_pos:
		ComicPanelData.TextPos.BOTTOM:
			box.anchor_left = 0.0
			box.anchor_right = 1.0
			box.anchor_top = 1.0
			box.anchor_bottom = 1.0
			box.offset_left = m
			box.offset_right = -m
			box.offset_bottom = -m
			box.offset_top = -m - 8.0
			box.grow_vertical = Control.GROW_DIRECTION_BEGIN   # tumbuh ke atas
		ComicPanelData.TextPos.TOP:
			box.anchor_left = 0.0
			box.anchor_right = 1.0
			box.anchor_top = 0.0
			box.anchor_bottom = 0.0
			box.offset_left = m
			box.offset_right = -m
			box.offset_top = m
			box.offset_bottom = m + 8.0
			box.grow_vertical = Control.GROW_DIRECTION_END
		ComicPanelData.TextPos.CENTER:
			box.anchor_left = 0.5
			box.anchor_right = 0.5
			box.anchor_top = 0.5
			box.anchor_bottom = 0.5
			box.offset_left = 0.0
			box.offset_right = 0.0
			box.offset_top = 0.0
			box.offset_bottom = 0.0
			box.grow_horizontal = Control.GROW_DIRECTION_BOTH
			box.grow_vertical = Control.GROW_DIRECTION_BOTH
			body.custom_minimum_size.x = _bbox.size.x * 0.7


# ---------------------------------------------------------------
# ANIMASI MASUK
# ---------------------------------------------------------------
func play() -> void:
	if data == null:
		return
	var t := maxf(data.enter_time, 0.01)

	# Keadaan awal sesuai jenis animasi
	var start_pos := _final_pos
	match data.enter:
		ComicPanelData.Enter.SLIDE_LEFT:
			start_pos.x -= SLIDE_DISTANCE
		ComicPanelData.Enter.SLIDE_RIGHT:
			start_pos.x += SLIDE_DISTANCE
		ComicPanelData.Enter.SLIDE_UP:
			start_pos.y -= SLIDE_DISTANCE
		ComicPanelData.Enter.SLIDE_DOWN:
			start_pos.y += SLIDE_DISTANCE
		ComicPanelData.Enter.POP:
			scale = Vector2(0.6, 0.6)
			rotation_degrees = randf_range(-4.0, 4.0)
	position = start_pos

	_tween = create_tween()
	if data.delay > 0.0:
		_tween.tween_interval(data.delay)
	_tween.tween_callback(_begin)

	match data.enter:
		ComicPanelData.Enter.FADE:
			_tween.tween_property(self, "modulate:a", 1.0, t)
		ComicPanelData.Enter.POP:
			_tween.tween_property(self, "modulate:a", 1.0, t * 0.4)
			_tween.parallel().tween_property(self, "scale", Vector2.ONE, t) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "rotation_degrees", 0.0, t) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_:   # semua SLIDE_*
			_tween.tween_property(self, "modulate:a", 1.0, t * 0.5)
			_tween.parallel().tween_property(self, "position", _final_pos, t) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	_tween.tween_callback(_start_text)


## Dipanggil tepat saat panel mulai muncul: suara, getar, kilat, push-in.
func _begin(play_fx: bool = true) -> void:
	if _began:
		return
	_began = true
	if play_fx:
		if data.sfx:
			sfx_player.stream = data.sfx
			sfx_player.play()
		if data.shake > 0.0 or data.flash:
			impact.emit(data.shake, data.flash)
	if data.texture and not data.shape_from_image and absf(data.drift) > 0.0:
		_drift_tween = create_tween()
		_drift_tween.tween_method(_apply_uv, data.image_zoom, data.image_zoom + data.drift, 10.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _is_shouting() -> bool:
	return data.text_style == ComicPanelData.TextStyle.SHOUT \
		or data.text_style == ComicPanelData.TextStyle.SFX


func _apply_tilt() -> void:
	box.pivot_offset = box.size * 0.5
	box.rotation_degrees = TILT_DEG


func _start_text() -> void:
	if is_done:
		return
	if not box.visible:
		_complete()
		return
	await get_tree().process_frame   # tunggu ukuran kotak teks selesai dihitung
	if is_done:
		return

	if _is_shouting():
		# SHOUT / SFX: langsung tampil, "menghantam" dari besar ke normal
		_apply_tilt()
		box.scale = Vector2(1.6, 1.6)
		body.visible_ratio = 1.0
		_text_tween = create_tween()
		_text_tween.tween_property(box, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_text_tween.tween_callback(_complete)
	else:
		# CAPTION / SPEECH: efek mesin ketik
		var dur := clampf(data.text.length() * 0.025, 0.25, 3.0)
		_text_tween = create_tween()
		_text_tween.tween_property(body, "visible_ratio", 1.0, dur)
		_text_tween.tween_callback(_complete)


## Lompat langsung ke keadaan akhir (dipakai saat pemain klik di tengah animasi).
func finish_now() -> void:
	if is_done:
		return
	for tw in [_tween, _text_tween]:
		if tw:
			tw.kill()
	_begin(false)
	modulate.a = 1.0
	position = _final_pos
	scale = Vector2.ONE
	rotation = 0.0
	if box.visible:
		body.visible_ratio = 1.0
		box.scale = Vector2.ONE
		if _is_shouting():
			_apply_tilt()
	_complete()


func _complete() -> void:
	if is_done:
		return
	is_done = true
	finished.emit()
