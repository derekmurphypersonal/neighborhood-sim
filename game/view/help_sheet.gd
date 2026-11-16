extends Control
## "How to play": the controls, what the panels mean, what the week's goals
## are, and that the street is made up. Opened with H or F1, from the in-game
## menu and from the title screen. Like the settings sheet it sits above
## everything with its own dimmed backdrop; main.gd pauses the clock while it
## is open. Presentation only: it reads nothing from the simulation.

signal closed

const Hud := preload("res://view/hud.gd")
const TextSize := preload("res://view/text_size.gd")

const PAPER: Color = Color("#F3E9D2")
const PAPER_DARK: Color = Color("#E4D3AE")
const TEAL: Color = Color("#2F5D62")
const TEAL_DARK: Color = Color("#22474B")
const MUSTARD: Color = Color("#E0A526")
const CHERRY: Color = Color("#B5442F")
const INK: Color = Color("#3B2F2A")
const CARD_WIDTH: float = 900.0
const SCREEN: Vector2 = Vector2(1280, 720)
const OPEN_SECONDS: float = 0.22
const CLOSE_SECONDS: float = 0.14
const KEY_FONT_SIZE: int = 12
const TEXT_FONT_SIZE: int = 13
const LEFT_WIDTH: float = 360.0
const NOTE_WIDTH: float = 380.0
## With Large text the card and its wrapped text are this much wider, so it
## still fits the screen's height.
const LARGE_WIDEN: float = 1.25

## Each row: the keys (shown as key caps) and what they do.
const KEYS: Array[Array] = [
	[["Click"], "Pick a family member, then a neighbor, house or room"],
	[["Right-click"], "Read about a building"],
	[["Space"], "Pause or carry on"],
	[["1", "2", "3"], "Speed: 1 minute, 10 minutes or 1 hour a second"],
	[["Scroll"], "Zoom in and out (also + and -)"],
	[["Drag", "Arrows"], "Look around the street (also W A S D)"],
	[["R"], "Put the view back"],
	[["F"], "Follow the selected person"],
	[["Tab", "Shift+Tab"], "Next or previous family member"],
	[["L"], "Labels on the street: everyone, household, on hover"],
	[["Esc"], "Menu: save, load, settings"],
	[["H", "F1"], "This help"],
	[["M", "N"], "Music, and the other sounds, on or off"],
	[["F11"], "Full screen"],
	[["F12"], "Save a picture of the screen"],
]

## The panels on screen and what they are for.
const PANELS: Array[Array] = [
	["Your household", "The tabs are your family. The card shows the selected person's mood and what they are doing; the bars are their needs. Click a tab again to find them on the street."],
	["Household money", "Money in hand, the pantry, rent (taken on Monday) and wages (paid on Friday for the days worked), with this week's money in and out."],
	["Neighbors", "How your selected person stands with each neighbor; the two bars are what each thinks of the other. Talk sends them over. Click a name to find that neighbor."],
	["What has happened", "News of the street, newest first. Click a line to see where it happened."],
]

var _card: PanelContainer
var _tween: Tween
var _open: bool = false
var _large_text: bool = false
var _wrapped: Array[Label] = []
var _left: VBoxContainer
var _keys: GridContainer
var _column: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = Hud.make_theme()
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.07, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_card = PanelContainer.new()
	_card.theme_type_variation = "Sheet"
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	add_child(_card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_card.add_child(column)
	_column = column

	var head: HBoxContainer = HBoxContainer.new()
	column.add_child(head)
	var title: Label = Label.new()
	title.text = "How to play"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", MUSTARD)
	head.add_child(title)
	var filler: Control = Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(filler)
	var made_up: PanelContainer = PanelContainer.new()
	made_up.theme_type_variation = "Badge"
	made_up.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(made_up)
	var made_up_text: Label = Label.new()
	# Required by the project rules (D-035): the street is made up.
	made_up_text.text = "Fixture Street is made up: not a real place"
	made_up_text.add_theme_font_size_override("font_size", 12)
	made_up_text.add_theme_color_override("font_color", PAPER)
	made_up.add_child(made_up_text)
	column.add_child(HSeparator.new())

	var halves: HBoxContainer = HBoxContainer.new()
	halves.add_theme_constant_override("separation", 26)
	column.add_child(halves)
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size = Vector2(LEFT_WIDTH, 0)
	_left = left
	left.add_theme_constant_override("separation", 6)
	halves.add_child(left)
	left.add_child(_section("The week"))
	left.add_child(_text("You look after one household for a week in spring 1950, minute by minute. The neighbors live their own lives, and so does your family unless you step in: send them to talk, visit, shop, or use a room at home."))
	left.add_child(_gap(4))
	left.add_child(_section("Things to try this week"))
	left.add_child(_text("The card on the left lists a few things to try. They tick themselves off as they happen; hover over one for a hint. There is no score: they are prompts, and a new set comes each Monday with the paper's summary of the week."))
	left.add_child(_gap(4))
	left.add_child(_section("A made-up street"))
	left.add_child(_text("Fixture Street is a test street used while the game is built. It is not Linden and not a real place, and everyone on it is invented."))

	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	halves.add_child(right)
	right.add_child(_section("Controls"))
	var keys: GridContainer = GridContainer.new()
	keys.columns = 2
	keys.add_theme_constant_override("h_separation", 10)
	keys.add_theme_constant_override("v_separation", 3)
	_keys = keys
	right.add_child(keys)
	for row: Array in KEYS:
		var caps: HBoxContainer = HBoxContainer.new()
		caps.add_theme_constant_override("separation", 3)
		caps.custom_minimum_size = Vector2(104, 0)
		for key_name: String in row[0]:
			caps.add_child(_key_cap(key_name))
		keys.add_child(caps)
		var what: Label = Label.new()
		what.text = row[1]
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		what.clip_text = true
		what.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
		what.add_theme_color_override("font_color", PAPER)
		keys.add_child(what)

	column.add_child(HSeparator.new())
	column.add_child(_section("On screen"))
	var panels: GridContainer = GridContainer.new()
	panels.columns = 2
	panels.add_theme_constant_override("h_separation", 12)
	panels.add_theme_constant_override("v_separation", 8)
	column.add_child(panels)
	for entry: Array in PANELS:
		panels.add_child(_panel_note(entry[0], entry[1]))

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	var done: Button = Button.new()
	done.text = "Back"
	done.tooltip_text = "Esc, H or F1"
	done.focus_mode = Control.FOCUS_NONE
	done.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	done.pressed.connect(close)
	buttons.add_child(done)


func _gap(height: float) -> Control:
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	return gap


func _section(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", MUSTARD)
	return label


## Wrapped text needs a set width, or its height is worked out for a width of
## nothing and the card opens far too tall.
func _text(text: String, width: float = LEFT_WIDTH) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(width, 0)
	label.set_meta("normal_width", width)
	_wrapped.append(label)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
	label.add_theme_color_override("font_color", PAPER)
	label.add_theme_constant_override("line_spacing", 1)
	return label


## A key drawn as a small raised paper cap.
func _key_cap(text: String) -> PanelContainer:
	var cap: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = PAPER
	box.border_color = PAPER_DARK.darkened(0.35)
	box.set_border_width_all(1)
	box.border_width_bottom = 3
	box.set_corner_radius_all(4)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	cap.add_theme_stylebox_override("panel", box)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", KEY_FONT_SIZE)
	# Key caps stay small with Large text, so the list of keys fits.
	label.set_meta(TextSize.FIXED_META, true)
	label.set_meta("normal_font_size", KEY_FONT_SIZE)
	label.add_theme_color_override("font_color", INK)
	cap.add_child(label)
	return cap


## One panel described in a soft box: its name and what it is for.
func _panel_note(title: String, text: String) -> PanelContainer:
	var note: PanelContainer = PanelContainer.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(PAPER, 0.08)
	box.border_color = Color(MUSTARD, 0.35)
	box.set_border_width_all(1)
	box.border_width_left = 3
	box.set_corner_radius_all(6)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 6
	note.add_theme_stylebox_override("panel", box)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 1)
	note.add_child(inner)
	var heading: Label = Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", MUSTARD.lightened(0.25))
	inner.add_child(heading)
	var body: Label = _text(text, NOTE_WIDTH)
	body.add_theme_font_size_override("font_size", 12)
	inner.add_child(body)
	return note


func open() -> void:
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


## Centres the card at its natural size.
func _place_card() -> void:
	_card.reset_size()
	_card.size = _card.get_combined_minimum_size()
	_card.position = ((SCREEN - _card.size) / 2.0).round()
	_card.pivot_offset = _card.size / 2.0


## Larger text, to match the setting.
func set_large_text(large: bool) -> void:
	if large == _large_text:
		return
	_large_text = large
	TextSize.scale_overrides(_card, TextSize.factor(large))
	var widen: float = LARGE_WIDEN if large else 1.0
	_card.custom_minimum_size.x = roundf(CARD_WIDTH * widen)
	_left.custom_minimum_size.x = roundf(LEFT_WIDTH * widen)
	for label: Label in _wrapped:
		label.custom_minimum_size.x = roundf(float(label.get_meta("normal_width")) * widen)
	# Rows a little closer together, so the taller text still fits the screen.
	_keys.add_theme_constant_override("v_separation", 0 if large else 3)
	_column.add_theme_constant_override("separation", 5 if large else 8)
	if _open:
		_place_card()


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
