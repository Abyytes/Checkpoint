class_name CutscenePlayer
extends Control
## PEMUTAR cutscene komik (mesin). Jangan taruh cerita di sini.
## Cerita ada di file turunan (mis. cutscene1.gd) yang `extends CutscenePlayer`
## dan meng-override _build_pages().
##
## Node yang dibutuhkan di scene (nama persis):
##   Background, PageLayer, Flash, Fade, Music, UI/Buttons/AutoButton,
##   UI/Buttons/SkipButton, UI/Hint
##
## Setelah halaman terakhir (atau SKIP):
##   - sinyal `finished` dipancarkan
##   - kalau `next_scene` terisi -> change_scene_to_file(next_scene)
##   - kalau kosong -> queue_free() (cutscene tertanam di scene lain)

signal finished

@export var panel_scene: PackedScene
@export_file("*.tscn") var next_scene: String = ""

@onready var _bg: ColorRect = $Background
@onready var _page_layer: Control = $PageLayer
@onready var _flash: ColorRect = $Flash
@onready var _fade: ColorRect = $Fade
@onready var _music: AudioStreamPlayer = $Music
@onready var _auto_btn: Button = $UI/Buttons/AutoButton
@onready var _skip_btn: Button = $UI/Buttons/SkipButton

var _pages: Array[ComicPageData] = []
var _page_i := -1
var _panels: Array[ComicPanel] = []
var _next_panel_i := 0
var _transitioning := false
var _auto := false
var _ending := false
var _auto_token := 0
var _shake_tween: Tween
var _flash_tween: Tween
var _fade_tween: Tween


## Override di cutscene turunan.
func _build_pages() -> Array[ComicPageData]:
	return []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.color.a = 1.0
	_flash.color.a = 0.0
	_auto_btn.toggled.connect(_on_auto_toggled)
	_skip_btn.pressed.connect(_end)
	if panel_scene == null:
		panel_scene = load("res://cutscene/comic_panel.tscn") as PackedScene
	_pages = _build_pages()
	if _pages.is_empty() or panel_scene == null:
		push_error("CutscenePlayer: tidak ada halaman / panel_scene kosong.")
		_end()
		return
	await get_tree().process_frame   # tunggu layout selesai
	_show_page(0)


# ---------------------------------------------------------------
# INPUT
# ---------------------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------
# ALUR HALAMAN & PANEL
# ---------------------------------------------------------------
func _show_page(i: int) -> void:
	_transitioning = true
	var page := _pages[i]
	var is_fade := page.transition == ComicPageData.Transition.FADE

	if _page_i >= 0 and is_fade:
		await _fade_to(1.0, 0.4)
	if _ending:
		return

	_clear_page()
	_page_i = i
	_bg.color = page.bg_color
	if page.music:
		_music.stream = page.music
		_music.play()

	if is_fade or i == 0:
		await _fade_to(0.0, 0.4)
	else:
		_fade.color.a = 0.0
	if _ending:
		return

	_transitioning = false
	if page.panels.is_empty():
		_go_forward()
	else:
		_spawn_next_panel()


func _clear_page() -> void:
	for c in _page_layer.get_children():
		c.queue_free()
	_panels.clear()
	_next_panel_i = 0
	_page_layer.position = Vector2.ZERO


func _spawn_next_panel() -> void:
	var d := _pages[_page_i].panels[_next_panel_i]
	_next_panel_i += 1
	var p := panel_scene.instantiate() as ComicPanel
	_page_layer.add_child(p)
	p.setup(d, get_viewport_rect().size)
	p.impact.connect(_on_impact)
	p.finished.connect(_on_panel_finished.bind(p))
	_panels.append(p)
	p.play()


## Klik / spasi: selesaikan animasi panel, atau lanjut ke panel/halaman berikut.
func _advance() -> void:
	if _ending or _transitioning or _panels.is_empty():
		return
	_auto_token += 1
	if not _panels.back().is_done:
		_panels.back().finish_now()
		return
	_go_forward()


func _go_forward() -> void:
	if _ending or _transitioning:
		return
	_auto_token += 1
	if _next_panel_i < _pages[_page_i].panels.size():
		_spawn_next_panel()
	elif _page_i + 1 < _pages.size():
		_show_page(_page_i + 1)
	else:
		_end()


func _on_panel_finished(p: ComicPanel) -> void:
	if _auto and not _panels.is_empty() and p == _panels.back():
		_schedule_auto(p.data.hold)


# ---------------------------------------------------------------
# AUTO
# ---------------------------------------------------------------
func _on_auto_toggled(on: bool) -> void:
	_auto = on
	if on and not _panels.is_empty() and _panels.back().is_done:
		_schedule_auto(_panels.back().data.hold)


func _schedule_auto(wait: float) -> void:
	var token := _auto_token
	await get_tree().create_timer(wait).timeout
	if token == _auto_token and _auto:
		_go_forward()


# ---------------------------------------------------------------
# EFEK
# ---------------------------------------------------------------
func _on_impact(strength: float, do_flash: bool) -> void:
	if do_flash:
		if _flash_tween:
			_flash_tween.kill()
		_flash.color.a = 0.85
		_flash_tween = create_tween()
		_flash_tween.tween_property(_flash, "color:a", 0.0, 0.35)
	if strength > 0.0:
		if _shake_tween:
			_shake_tween.kill()
		_shake_tween = create_tween()
		var steps := 7
		for k in steps:
			var amp := strength * (1.0 - float(k) / steps)
			_shake_tween.tween_property(_page_layer, "position",
				Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.04)
		_shake_tween.tween_property(_page_layer, "position", Vector2.ZERO, 0.04)


func _fade_to(alpha: float, t: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", alpha, t)
	await _fade_tween.finished


# ---------------------------------------------------------------
# SELESAI
# ---------------------------------------------------------------
func _end() -> void:
	if _ending:
		return
	_ending = true
	_auto_token += 1
	await _fade_to(1.0, 0.5)
	finished.emit()
	if next_scene == "":
		queue_free()
		return
	if not ResourceLoader.exists(next_scene):
		push_error("CutscenePlayer: next_scene '%s' tidak ditemukan." % next_scene)
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(next_scene)
