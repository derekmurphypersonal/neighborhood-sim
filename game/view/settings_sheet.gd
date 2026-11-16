extends Control
## The settings sheet, opened from the title screen and the in-game menu, in
## three sections: Sound (music and sound volume), Display (full screen, text
## size, labels on the street, the mini-map) and Play (tips, pausing in the
## background). It only shows and edits a settings dictionary; main.gd applies
## the values and decides whether to save them (never during the self-check
## or a screenshot run).

signal changed(settings: Dictionary)
signal closed

const Hud := preload("res://view/hud.gd")
const TextSize := preload("res://view/text_size.gd")

const PAPER: Color = Color("#F3E9D2")
const PAPER_DARK: Color = Color("#E4D3AE")
const TEAL: Color = Color("#2F5D62")
const TEAL_DARK: Color = Color("#22474B")
const MUSTARD: Color = Color("#E0A526")
const OPEN_SECONDS: float = 0.22
const CLOSE_SECONDS: float = 0.14
const SCREEN: Vector2 = Vector2(1280, 720)
const CARD_WIDTH: float = 560.0
const LABEL_WIDTH: float = 210.0
## The choices for the street labels, in the order of world_view's LABELS_
## constants (0 everyone, 1 household, 2 only on hover).
const LABEL_CHOICES: Array[String] = ["Everyone", "Your household", "Only on hover"]
const LABEL_TIPS: Array[String] = [
	"Everyone outdoors shows what they are doing",
	"Only your household, and whoever they are talking with; others show a name when the pointer is over them",
	"Only the selected person, and whoever is under the pointer",
]
const TEXT_CHOICES: Array[String] = ["Normal", "Large"]

var _settings: Dictionary = {}
var _card: PanelContainer
var _music_slider: HSlider
var _sound_slider: HSlider
var _music_value: Label
var _sound_value: Label
var _fullscreen: Button
var _tips: Button
var _minimap: Button
var _background: Button
var _label_buttons: Array[Button] = []
var _text_buttons: Array[Button] = []
var _tween: Tween
var _open: bool = false
var _large_text: bool = false


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
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	add_child(_card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	_card.add_child(column)
	var title: Label = Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", MUSTARD)
	column.add_child(title)
	column.add_child(HSeparator.new())

	column.add_child(_section("Sound"))
	var music: Array = _slider_row(column, "Music volume", "The background music, by day and in the evening  (M turns it on or off)")
	_music_slider = music[0]
	_music_value = music[1]
	_music_slider.value_changed.connect(func(value: float) -> void: _on_volume("music_volume", value))
	var sound: Array = _slider_row(column, "Sounds volume", "Chimes, clicks and doors, and the birds and crickets outside  (N turns them on or off)")
	_sound_slider = sound[0]
	_sound_value = sound[1]
	_sound_slider.value_changed.connect(func(value: float) -> void: _on_volume("sound_volume", value))

	column.add_child(_section("Display"))
	_fullscreen = _switch_row(column, "Full screen", "F11 also switches", _on_fullscreen)
	_text_buttons = _choice_row(column, "Text size", TEXT_CHOICES,
			["The usual size", "Larger text in the side panel, the news and the sheets"],
			func(index: int) -> void: _on_choice("large_text", index == 1))
	_label_buttons = _choice_row(column, "Labels on the street", LABEL_CHOICES, LABEL_TIPS,
			func(index: int) -> void: _on_choice("label_mode", index))
	_minimap = _switch_row(column, "Mini-map", "A small map of the whole street in the corner, showing where the view is", _on_switch.bind("minimap"))

	column.add_child(_section("Play"))
	_tips = _switch_row(column, "Show tips", "Short tips the first time something happens. Switching them back on shows them all again.", _on_switch.bind("show_tips"))
	_background = _switch_row(column, "Pause in the background", "Stop the clock while the game's window is not the one in use, and carry on when you come back", _on_switch.bind("pause_in_background"))

	column.add_child(HSeparator.new())
	var foot: HBoxContainer = HBoxContainer.new()
	column.add_child(foot)
	var hint: Label = Label.new()
	hint.text = "Settings are kept on this computer for next time.\nL also changes the street labels."
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(PAPER, 0.6))
	foot.add_child(hint)
	var done: Button = Button.new()
	done.text = "Done"
	done.tooltip_text = "Esc"
	done.focus_mode = Control.FOCUS_NONE
	done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	done.custom_minimum_size = Vector2(90, 0)
	done.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	done.pressed.connect(close)
	foot.add_child(done)


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
	# Choices shown side by side; the one chosen is mustard.
	t.set_type_variation("Choice", "Button")
	t.set_font_size("font_size", "Choice", 13)
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


func _section(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", MUSTARD)
	return label


func _row_label(text: String, tip: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(LABEL_WIDTH, 0)
	label.add_theme_color_override("font_color", PAPER)
	label.add_theme_font_size_override("font_size", 15)
	label.tooltip_text = tip
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	return label


func _row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	return row


func _slider_row(column: VBoxContainer, text: String, tip: String) -> Array:
	var row: HBoxContainer = _row()
	row.add_child(_row_label(text, tip))
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


## A row with an On/Off button.
func _switch_row(column: VBoxContainer, text: String, tip: String, on_toggle: Callable) -> Button:
	var row: HBoxContainer = _row()
	row.add_child(_row_label(text, tip))
	var switch: Button = Button.new()
	switch.toggle_mode = true
	switch.focus_mode = Control.FOCUS_NONE
	switch.custom_minimum_size = Vector2(90, 0)
	switch.tooltip_text = tip
	switch.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	switch.toggled.connect(on_toggle)
	row.add_child(switch)
	column.add_child(row)
	return switch


## A row of choices side by side, one of which is chosen.
func _choice_row(column: VBoxContainer, text: String, choices: Array[String], tips: Array[String], on_choose: Callable) -> Array[Button]:
	var row: HBoxContainer = _row()
	row.add_child(_row_label(text, "\n".join(PackedStringArray(tips))))
	var group: ButtonGroup = ButtonGroup.new()
	var buttons: Array[Button] = []
	var choices_box: HBoxContainer = HBoxContainer.new()
	choices_box.add_theme_constant_override("separation", 4)
	row.add_child(choices_box)
	for index: int in choices.size():
		var button: Button = Button.new()
		button.theme_type_variation = "Choice"
		button.text = choices[index]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = tips[index]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(func() -> void: on_choose.call(index))
		choices_box.add_child(button)
		buttons.append(button)
	column.add_child(row)
	return buttons


## Opens the sheet showing these settings (a copy is edited).
func open(settings: Dictionary) -> void:
	_settings = settings.duplicate()
	_music_slider.set_value_no_signal(roundf(float(_settings["music_volume"]) * 100.0))
	_sound_slider.set_value_no_signal(roundf(float(_settings["sound_volume"]) * 100.0))
	_fullscreen.set_pressed_no_signal(bool(_settings["fullscreen"]))
	_tips.set_pressed_no_signal(bool(_settings.get("show_tips", true)))
	_minimap.set_pressed_no_signal(bool(_settings.get("minimap", true)))
	_background.set_pressed_no_signal(bool(_settings.get("pause_in_background", true)))
	_show_values()
	if _open:
		return
	_open = true
	visible = true
	if _tween != null:
		_tween.kill()
	_place_card()
	modulate.a = 0.0
	_card.scale = Vector2(0.94, 0.94)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, OPEN_SECONDS)
	_tween.tween_property(_card, "scale", Vector2.ONE, OPEN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_settle()


## Wrapped text takes its height only once laid out at its width, so the
## card is sized and centred again a frame after it opens.
func _settle() -> void:
	await get_tree().process_frame
	if _open:
		_place_card()


## Centres the card on the screen at its natural size.
func _place_card() -> void:
	_card.reset_size()
	_card.size = _card.get_combined_minimum_size()
	_card.position = ((SCREEN - _card.size) / 2.0).round()
	_card.pivot_offset = _card.size / 2.0


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


## Larger text on the sheet itself, to match the setting.
func set_large_text(large: bool) -> void:
	if large == _large_text:
		return
	_large_text = large
	TextSize.scale_overrides(_card, TextSize.factor(large))
	if _open:
		_place_card()


## Sets a slider as the player would; used by the self-check.
func set_music_percent(percent: int) -> void:
	_music_slider.value = percent


## Chooses a street label setting as the player would (self-check).
func choose_label_mode(index: int) -> void:
	_label_buttons[index].button_pressed = true
	_label_buttons[index].pressed.emit()


## Switches the mini-map as the player would (self-check).
func set_minimap(on: bool) -> void:
	_minimap.button_pressed = on


## Chooses Normal (false) or Large (true) text as the player would (self-check).
func choose_large_text(large: bool) -> void:
	var button: Button = _text_buttons[1 if large else 0]
	button.button_pressed = true
	button.pressed.emit()


## Reflects a change made elsewhere (F11, or L for the labels) while the
## sheet is open.
func show_fullscreen(on: bool) -> void:
	_settings["fullscreen"] = on
	_fullscreen.set_pressed_no_signal(on)
	_show_values()


func show_label_mode(mode: int) -> void:
	_settings["label_mode"] = mode
	_show_values()


func _on_volume(key: String, value: float) -> void:
	_settings[key] = value / 100.0
	_show_values()
	changed.emit(_settings.duplicate())


func _on_fullscreen(on: bool) -> void:
	_settings["fullscreen"] = on
	_show_values()
	changed.emit(_settings.duplicate())


func _on_switch(on: bool, key: String) -> void:
	_settings[key] = on
	_show_values()
	changed.emit(_settings.duplicate())


func _on_choice(key: String, value: Variant) -> void:
	_settings[key] = value
	_show_values()
	changed.emit(_settings.duplicate())


func _show_values() -> void:
	_music_value.text = "Off" if _music_slider.value <= 0 else "%d%%" % int(_music_slider.value)
	_sound_value.text = "Off" if _sound_slider.value <= 0 else "%d%%" % int(_sound_slider.value)
	for button: Button in [_fullscreen, _tips, _minimap, _background]:
		button.text = "On" if button.button_pressed else "Off"
	var mode: int = clampi(int(_settings.get("label_mode", 0)), 0, LABEL_CHOICES.size() - 1)
	for index: int in _label_buttons.size():
		_label_buttons[index].set_pressed_no_signal(index == mode)
	var large: bool = bool(_settings.get("large_text", false))
	for index: int in _text_buttons.size():
		_text_buttons[index].set_pressed_no_signal(index == (1 if large else 0))
