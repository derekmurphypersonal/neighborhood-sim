extends Control
## The settings sheet, opened from the title screen and the in-game menu:
## music and sound volume, and full screen. It only shows and edits a
## settings dictionary; main.gd applies the values and decides whether to
## save them (never during the self-check or a screenshot run).

signal changed(settings: Dictionary)
signal closed

const Hud := preload("res://view/hud.gd")

const PAPER: Color = Color("#F3E9D2")
const PAPER_DARK: Color = Color("#E4D3AE")
const TEAL: Color = Color("#2F5D62")
const TEAL_DARK: Color = Color("#22474B")
const MUSTARD: Color = Color("#E0A526")
const OPEN_SECONDS: float = 0.22
const CLOSE_SECONDS: float = 0.14

var _settings: Dictionary = {}
var _card: PanelContainer
var _music_slider: HSlider
var _sound_slider: HSlider
var _music_value: Label
var _sound_value: Label
var _fullscreen: Button
var _tips: Button
var _tween: Tween
var _open: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = _sheet_theme()
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.07, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_card = PanelContainer.new()
	_card.theme_type_variation = "Sheet"
	_card.custom_minimum_size = Vector2(460, 0)
	_card.position = Vector2(410, 170)
	add_child(_card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_card.add_child(column)
	var title: Label = Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", MUSTARD)
	column.add_child(title)
	column.add_child(HSeparator.new())

	var music: Array = _slider_row(column, "Music volume", "The background music, by day and in the evening  (M turns it on or off)")
	_music_slider = music[0]
	_music_value = music[1]
	_music_slider.value_changed.connect(func(value: float) -> void: _on_volume("music_volume", value))
	var sound: Array = _slider_row(column, "Sounds volume", "Chimes, clicks and doors, and the birds and crickets outside  (N turns them on or off)")
	_sound_slider = sound[0]
	_sound_value = sound[1]
	_sound_slider.value_changed.connect(func(value: float) -> void: _on_volume("sound_volume", value))

	var screen_row: HBoxContainer = HBoxContainer.new()
	var screen_label: Label = _row_label("Full screen")
	screen_label.tooltip_text = "F11 also switches"
	screen_label.mouse_filter = Control.MOUSE_FILTER_PASS
	screen_row.add_child(screen_label)
	_fullscreen = Button.new()
	_fullscreen.toggle_mode = true
	_fullscreen.focus_mode = Control.FOCUS_NONE
	_fullscreen.custom_minimum_size = Vector2(90, 0)
	_fullscreen.toggled.connect(_on_fullscreen)
	screen_row.add_child(_fullscreen)
	column.add_child(screen_row)

	var tips_row: HBoxContainer = HBoxContainer.new()
	var tips_label: Label = _row_label("Show tips")
	tips_label.tooltip_text = "Short tips the first time something happens. Switching them back on shows them all again."
	tips_label.mouse_filter = Control.MOUSE_FILTER_PASS
	tips_row.add_child(tips_label)
	_tips = Button.new()
	_tips.toggle_mode = true
	_tips.focus_mode = Control.FOCUS_NONE
	_tips.custom_minimum_size = Vector2(90, 0)
	_tips.tooltip_text = tips_label.tooltip_text
	_tips.toggled.connect(_on_tips)
	tips_row.add_child(_tips)
	column.add_child(tips_row)

	var hint: Label = Label.new()
	hint.text = "Settings are kept on this computer for next time."
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(PAPER, 0.6))
	column.add_child(hint)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var done: Button = Button.new()
	done.text = "Done"
	done.tooltip_text = "Esc"
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(close)
	buttons.add_child(done)
	column.add_child(buttons)


func _sheet_theme() -> Theme:
	var t: Theme = Hud.make_theme()
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(PAPER, 0.25)
	track.set_corner_radius_all(4)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var filled: StyleBoxFlat = StyleBoxFlat.new()
	filled.bg_color = MUSTARD
	filled.set_corner_radius_all(4)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", filled)
	var filled_lit: StyleBoxFlat = filled.duplicate()
	filled_lit.bg_color = MUSTARD.lightened(0.15)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled_lit)
	t.set_icon("grabber", "HSlider", _knob(PAPER))
	t.set_icon("grabber_highlight", "HSlider", _knob(Color.WHITE))
	return t


## A round slider knob, drawn into a small image at start-up (no image files).
func _knob(color: Color) -> ImageTexture:
	var size: int = 18
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var middle: Vector2 = Vector2(size, size) / 2.0
	for y: int in size:
		for x: int in size:
			var distance: float = Vector2(x + 0.5, y + 0.5).distance_to(middle)
			var edge: float = clampf(size / 2.0 - distance, 0.0, 1.0)
			var ring: bool = distance > size / 2.0 - 2.5
			var pixel: Color = MUSTARD.darkened(0.3) if ring else color
			image.set_pixel(x, y, Color(pixel, edge))
	return ImageTexture.create_from_image(image)


func _row_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(150, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", PAPER)
	label.add_theme_font_size_override("font_size", 16)
	return label


func _slider_row(column: VBoxContainer, text: String, tip: String) -> Array:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label: Label = _row_label(text)
	label.size_flags_horizontal = Control.SIZE_FILL
	label.tooltip_text = tip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.tooltip_text = tip
	row.add_child(slider)
	var value: Label = Label.new()
	value.custom_minimum_size = Vector2(48, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_color_override("font_color", MUSTARD)
	row.add_child(value)
	column.add_child(row)
	return [slider, value]


## Opens the sheet showing these settings (a copy is edited).
func open(settings: Dictionary) -> void:
	_settings = settings.duplicate()
	_music_slider.set_value_no_signal(roundf(float(_settings["music_volume"]) * 100.0))
	_sound_slider.set_value_no_signal(roundf(float(_settings["sound_volume"]) * 100.0))
	_fullscreen.set_pressed_no_signal(bool(_settings["fullscreen"]))
	_tips.set_pressed_no_signal(bool(_settings.get("show_tips", true)))
	_show_values()
	if _open:
		return
	_open = true
	visible = true
	if _tween != null:
		_tween.kill()
	_card.reset_size()
	_card.pivot_offset = _card.size / 2.0
	modulate.a = 0.0
	_card.scale = Vector2(0.94, 0.94)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, OPEN_SECONDS)
	_tween.tween_property(_card, "scale", Vector2.ONE, OPEN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not _open:
		return
	_open = false
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, CLOSE_SECONDS)
	_tween.tween_callback(func() -> void: visible = false)
	closed.emit()


func is_open() -> bool:
	return _open


## Sets a slider as the player would; used by the self-check.
func set_music_percent(percent: int) -> void:
	_music_slider.value = percent


## Reflects a change made elsewhere (F11) while the sheet is open.
func show_fullscreen(on: bool) -> void:
	_settings["fullscreen"] = on
	_fullscreen.set_pressed_no_signal(on)
	_show_values()


func _on_volume(key: String, value: float) -> void:
	_settings[key] = value / 100.0
	_show_values()
	changed.emit(_settings.duplicate())


func _on_fullscreen(on: bool) -> void:
	_settings["fullscreen"] = on
	_show_values()
	changed.emit(_settings.duplicate())


func _on_tips(on: bool) -> void:
	_settings["show_tips"] = on
	_show_values()
	changed.emit(_settings.duplicate())


func _show_values() -> void:
	_music_value.text = "Off" if _music_slider.value <= 0 else "%d%%" % int(_music_slider.value)
	_sound_value.text = "Off" if _sound_slider.value <= 0 else "%d%%" % int(_sound_slider.value)
	_fullscreen.text = "On" if _fullscreen.button_pressed else "Off"
	_tips.text = "On" if _tips.button_pressed else "Off"
