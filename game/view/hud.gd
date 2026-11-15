extends Control
## Clock, speed controls, household and relationship panel, and event feed.
## Presentation only: reads simulation state and emits the player's choices.
##
## The look is one Theme built here in code (warm paper panels, teal, mustard
## and cherry), so no font or image files are needed and every control picks
## it up from this node.

signal speed_chosen(index: int)
signal person_chosen(person_id: String)
signal order_given(person_id: String, order: Dictionary)
signal music_toggled(on: bool)
signal sound_toggled(on: bool)
signal week_requested
signal menu_requested
signal sheet_closed

const Simulation := preload("res://sim/simulation.gd")
const SimDate := preload("res://sim/clock/sim_date.gd")
const Records := preload("res://sim/state/records.gd")
const Describe := preload("res://view/describe.gd")

const SPEED_LABELS: Array[String] = ["Pause", "1 min/s", "10 min/s", "1 hour/s"]
## Keyboard shortcuts as handled in main.gd's _unhandled_key_input.
const SPEED_TIPS: Array[String] = [
	"Pause the clock  (Space toggles pause)",
	"One game minute each second  (1)",
	"Ten game minutes each second  (2)",
	"One game hour each second  (3)",
]
const MONTH_NAMES: Array[String] = [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
]
const FEED_LINES: int = 7
## How long a new line in the feed stays highlighted, in real milliseconds.
const FEED_FRESH_MS: int = 5000
const NEED_LABELS: Dictionary = {"hunger": "Fed", "rest": "Rested", "company": "Company", "fun": "Fun"}
## Need levels, in percent, at which a bar turns amber and then red.
const NEED_GOOD_PERCENT: int = 60
const NEED_LOW_PERCENT: int = 30
## Hours shown with a moon instead of a sun in the top bar (presentation only).
const DAY_STARTS_MINUTE: int = 6 * 60
const NIGHT_STARTS_MINUTE: int = 19 * 60

const PAPER: Color = Color("#F3E9D2")
const PAPER_DARK: Color = Color("#E4D3AE")
const PAPER_ROW: Color = Color("#EADDC0")
const TEAL: Color = Color("#2F5D62")
const TEAL_DARK: Color = Color("#22474B")
const MUSTARD: Color = Color("#E0A526")
const CHERRY: Color = Color("#B5442F")
const INK: Color = Color("#3B2F2A")
const INK_SOFT: Color = Color("#7A6658")
const LEAF: Color = Color("#5E8C4A")
const SHADOW: Color = Color(0.12, 0.08, 0.05, 0.30)

var simulation: Simulation
var _date_label: Label
var _time_label: Label
var _sky: Control
var _sky_is_night: bool = false
var _speed_buttons: Array[Button] = []
var _member_buttons: Dictionary = {}
var _message_label: Label
var _selected_label: RichTextLabel
var _need_bars: Dictionary = {}
var _need_values: Dictionary = {}
var _need_fills: Array[StyleBoxFlat] = []
var _neighbor_rows: Dictionary = {}
var _money_label: RichTextLabel
var _feed: RichTextLabel
var _player_ids: Array = []
var _music_button: Button
var _sound_button: Button
## event id -> the moment it first appeared in the feed
var _first_shown: Dictionary = {}
var _sheet_layer: Control
var _sheet: PanelContainer
var _sheet_title: Label
var _sheet_text: RichTextLabel
var _sheet_buttons: HBoxContainer


func setup(sim: Simulation) -> void:
	simulation = sim
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _make_theme()
	_need_fills = [_box(LEAF, 6), _box(MUSTARD, 6), _box(CHERRY, 6)]
	_build_top_bar()
	_build_side_panel()
	_build_feed()
	_build_sheet()


func show_message(text: String) -> void:
	_message_label.text = text


# --- The look ----------------------------------------------------------------

func _box(color: Color, radius: int, margin_x: int = 0, margin_y: int = 0) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	return box


func _with_border(box: StyleBoxFlat, color: Color, width: int) -> StyleBoxFlat:
	box.border_color = color
	box.set_border_width_all(width)
	return box


func _with_shadow(box: StyleBoxFlat, size: int) -> StyleBoxFlat:
	box.shadow_color = SHADOW
	box.shadow_size = size
	box.shadow_offset = Vector2(0, 2)
	return box


func _set_button_styles(theme_value: Theme, type_name: String, normal: Color, hover: Color, on: Color, radius: int, margin_x: int, margin_y: int) -> void:
	var edge: Color = normal.darkened(0.25)
	theme_value.set_stylebox("normal", type_name, _with_border(_box(normal, radius, margin_x, margin_y), edge, 1))
	theme_value.set_stylebox("hover", type_name, _with_border(_box(hover, radius, margin_x, margin_y), edge, 1))
	theme_value.set_stylebox("pressed", type_name, _with_border(_box(on, radius, margin_x, margin_y), on.darkened(0.3), 1))
	theme_value.set_stylebox("hover_pressed", type_name, _with_border(_box(on.lightened(0.1), radius, margin_x, margin_y), on.darkened(0.3), 1))
	theme_value.set_stylebox("disabled", type_name, _box(Color(normal, 0.45), radius, margin_x, margin_y))
	theme_value.set_stylebox("focus", type_name, StyleBoxEmpty.new())


func _make_theme() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = 14

	t.set_stylebox("panel", "PanelContainer", _with_shadow(_with_border(_box(PAPER, 10, 14, 12), PAPER_DARK.darkened(0.15), 1), 6))
	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", INK)

	_set_button_styles(t, "Button", PAPER_DARK, PAPER, MUSTARD, 6, 10, 4)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.45))

	# Household members, shown as tabs; the selected one is lit.
	t.set_type_variation("MemberTab", "Button")
	_set_button_styles(t, "MemberTab", PAPER_DARK, PAPER, MUSTARD, 8, 12, 4)

	# Small teal buttons inside list rows.
	t.set_type_variation("RowButton", "Button")
	_set_button_styles(t, "RowButton", TEAL, TEAL.lightened(0.15), MUSTARD, 5, 10, 1)
	t.set_font_size("font_size", "RowButton", 12)
	for key: String in ["font_color", "font_hover_color", "font_hover_pressed_color"]:
		t.set_color(key, "RowButton", PAPER)

	t.set_type_variation("RowA", "PanelContainer")
	t.set_stylebox("panel", "RowA", _box(PAPER_ROW, 5, 8, 3))
	t.set_type_variation("RowB", "PanelContainer")
	t.set_stylebox("panel", "RowB", _box(Color(PAPER_ROW, 0.0), 5, 8, 3))

	t.set_type_variation("TopBar", "PanelContainer")
	var bar: StyleBoxFlat = _with_shadow(_box(TEAL, 0, 20, 6), 8)
	bar.border_color = MUSTARD
	bar.border_width_bottom = 3
	t.set_stylebox("panel", "TopBar", bar)

	t.set_type_variation("Badge", "PanelContainer")
	t.set_stylebox("panel", "Badge", _with_shadow(_with_border(_box(CHERRY, 11, 12, 2), PAPER, 2), 3))

	t.set_type_variation("Note", "PanelContainer")
	t.set_stylebox("panel", "Note", _box(Color(PAPER, 0.88), 9, 12, 2))

	t.set_type_variation("Sheet", "PanelContainer")
	t.set_stylebox("panel", "Sheet", _with_shadow(_with_border(_box(TEAL_DARK, 12, 22, 18), MUSTARD, 3), 18))

	t.set_type_variation("Heading", "Label")
	t.set_color("font_color", "Heading", TEAL)
	t.set_font_size("font_size", "Heading", 16)
	t.set_type_variation("Caption", "Label")
	t.set_color("font_color", "Caption", INK_SOFT)
	t.set_font_size("font_size", "Caption", 11)

	t.set_stylebox("background", "ProgressBar", _box(PAPER_DARK, 6))
	t.set_stylebox("fill", "ProgressBar", _box(LEAF, 6))

	t.set_stylebox("separator", "HSeparator", _box(Color(MUSTARD, 0.6), 1, 0, 1))
	t.set_constant("separation", "HSeparator", 6)

	t.set_stylebox("scroll", "VScrollBar", _box(Color(PAPER_DARK, 0.6), 4, 3, 0))
	t.set_stylebox("grabber", "VScrollBar", _box(Color(TEAL, 0.55), 4, 3, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", _box(TEAL, 4, 3, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", _box(TEAL_DARK, 4, 3, 0))

	t.set_stylebox("panel", "TooltipPanel", _with_shadow(_with_border(_box(INK, 6, 10, 6), MUSTARD, 1), 4))
	t.set_color("font_color", "TooltipLabel", PAPER)
	t.set_font_size("font_size", "TooltipLabel", 13)
	return t


# --- Building the layout -----------------------------------------------------

func _build_top_bar() -> void:
	var strip: PanelContainer = PanelContainer.new()
	strip.theme_type_variation = "TopBar"
	strip.position = Vector2.ZERO
	strip.custom_minimum_size = Vector2(1280, 42)
	add_child(strip)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	strip.add_child(bar)

	_sky = Control.new()
	_sky.custom_minimum_size = Vector2(22, 22)
	_sky.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sky.draw.connect(_draw_sky)
	bar.add_child(_sky)
	_time_label = Label.new()
	_time_label.custom_minimum_size = Vector2(82, 0)
	_time_label.add_theme_font_size_override("font_size", 22)
	_time_label.add_theme_color_override("font_color", MUSTARD)
	_time_label.add_theme_color_override("font_outline_color", TEAL_DARK)
	_time_label.add_theme_constant_override("outline_size", 4)
	bar.add_child(_time_label)
	_date_label = Label.new()
	_date_label.custom_minimum_size = Vector2(232, 0)
	_date_label.add_theme_font_size_override("font_size", 16)
	_date_label.add_theme_color_override("font_color", PAPER)
	bar.add_child(_date_label)

	for index: int in SPEED_LABELS.size():
		var button: Button = Button.new()
		button.text = SPEED_LABELS[index]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = SPEED_TIPS[index]
		button.pressed.connect(func() -> void: speed_chosen.emit(index))
		bar.add_child(button)
		_speed_buttons.append(button)
	bar.add_child(_spacer(10))
	_music_button = _toggle("Music", func(on: bool) -> void: music_toggled.emit(on))
	_music_button.tooltip_text = "Turn the music on or off  (M)"
	bar.add_child(_music_button)
	_sound_button = _toggle("Chimes", func(on: bool) -> void: sound_toggled.emit(on))
	_sound_button.tooltip_text = "Turn the chimes for news on or off"
	bar.add_child(_sound_button)
	var filler: Control = Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(filler)
	var week: Button = _button("This week", func() -> void: week_requested.emit())
	week.tooltip_text = "How the week is going for your household"
	bar.add_child(week)
	var menu: Button = _button("Menu", func() -> void: menu_requested.emit())
	menu.tooltip_text = "Save, load and pause  (Esc)"
	bar.add_child(menu)

	var note: PanelContainer = PanelContainer.new()
	note.theme_type_variation = "Note"
	note.position = Vector2(20, 47)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(note)
	_message_label = Label.new()
	_message_label.text = "Click one of your household (blue), then a house or a neighbor. Right-click a building for details. Scroll to zoom, drag to look around."
	_message_label.add_theme_font_size_override("font_size", 12)
	note.add_child(_message_label)

	if simulation.area.placeholder:
		# Required on screen by the project rules (D-035): this street is made up.
		var badge: PanelContainer = PanelContainer.new()
		badge.theme_type_variation = "Badge"
		badge.position = Vector2(915, 47)
		badge.custom_minimum_size = Vector2(350, 0)
		badge.tooltip_text = "Fixture Street is a development stand-in. It is not Linden and not a real place."
		add_child(badge)
		var banner: Label = Label.new()
		banner.text = "FICTIONAL TEST STREET: not a real place"
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.add_theme_font_size_override("font_size", 12)
		banner.add_theme_color_override("font_color", PAPER)
		badge.add_child(banner)


func _draw_sky() -> void:
	var middle: Vector2 = _sky.size / 2.0
	if _sky_is_night:
		_sky.draw_circle(middle, 9.0, PAPER)
		_sky.draw_circle(middle + Vector2(4, -3), 8.0, TEAL)
	else:
		for ray: int in 8:
			var direction: Vector2 = Vector2.RIGHT.rotated(ray * TAU / 8.0)
			_sky.draw_line(middle + direction * 8.0, middle + direction * 11.0, MUSTARD, 2.0)
		_sky.draw_circle(middle, 6.0, MUSTARD)


func _build_side_panel() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(915, 78)
	panel.custom_minimum_size = Vector2(350, 627)
	add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)

	var household: Dictionary = simulation.state.households[simulation.state.player_household_id()]
	_player_ids = household["member_ids"]
	column.add_child(_caption("YOUR HOUSEHOLD"))
	column.add_child(_heading(household["name"]))
	var members: HBoxContainer = HBoxContainer.new()
	members.add_theme_constant_override("separation", 4)
	column.add_child(members)
	for person_id: String in _player_ids:
		var button: Button = Button.new()
		button.theme_type_variation = "MemberTab"
		button.text = simulation.state.people[person_id]["given_name"]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: person_chosen.emit(person_id))
		members.add_child(button)
		_member_buttons[person_id] = button

	_selected_label = RichTextLabel.new()
	_selected_label.bbcode_enabled = true
	_selected_label.fit_content = true
	_selected_label.scroll_active = false
	_selected_label.add_theme_font_size_override("normal_font_size", 13)
	_selected_label.add_theme_font_size_override("bold_font_size", 17)
	column.add_child(_selected_label)
	for need_name: String in Records.NEED_NAMES:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label: Label = Label.new()
		label.text = NEED_LABELS[need_name]
		label.custom_minimum_size = Vector2(70, 0)
		label.add_theme_font_size_override("font_size", 13)
		row.add_child(label)
		var bar: ProgressBar = ProgressBar.new()
		bar.max_value = Records.NEED_MAX
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(0, 12)
		row.add_child(bar)
		var value: Label = Label.new()
		value.custom_minimum_size = Vector2(36, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_size_override("font_size", 12)
		value.add_theme_color_override("font_color", INK_SOFT)
		row.add_child(value)
		column.add_child(row)
		_need_bars[need_name] = bar
		_need_values[need_name] = value

	column.add_child(HSeparator.new())
	column.add_child(_heading("Household money"))
	_money_label = RichTextLabel.new()
	_money_label.bbcode_enabled = true
	_money_label.fit_content = true
	_money_label.scroll_active = false
	_money_label.add_theme_font_size_override("normal_font_size", 13)
	_money_label.add_theme_font_size_override("bold_font_size", 13)
	column.add_child(_money_label)

	column.add_child(HSeparator.new())
	column.add_child(_heading("Neighbors"))
	column.add_child(_caption("Regard each way, and how often they have talked"))
	# The list scrolls, so a long street never pushes anything off the panel.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var neighbors: VBoxContainer = VBoxContainer.new()
	neighbors.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	neighbors.add_theme_constant_override("separation", 1)
	scroll.add_child(neighbors)
	for person_id: String in simulation.state.sorted_person_ids():
		if _player_ids.has(person_id):
			continue
		var person: Dictionary = simulation.state.people[person_id]
		if simulation.world["schedules"][person["schedule_id"]].get("housebound", false):
			continue
		var shaded: PanelContainer = PanelContainer.new()
		shaded.theme_type_variation = "RowA" if _neighbor_rows.size() % 2 == 0 else "RowB"
		var row: HBoxContainer = HBoxContainer.new()
		shaded.add_child(row)
		var label: Label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		label.add_theme_font_size_override("font_size", 12)
		row.add_child(label)
		var talk: Button = Button.new()
		talk.theme_type_variation = "RowButton"
		talk.text = "Talk"
		talk.focus_mode = Control.FOCUS_NONE
		talk.tooltip_text = "Send the selected member of your household to talk to %s" % person["given_name"]
		talk.pressed.connect(func() -> void: _talk_pressed(person_id))
		row.add_child(talk)
		neighbors.add_child(shaded)
		_neighbor_rows[person_id] = label


func _build_feed() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(20, 512)
	panel.custom_minimum_size = Vector2(880, 193)
	add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	column.add_child(_heading("What has happened"))
	_feed = RichTextLabel.new()
	_feed.bbcode_enabled = true
	_feed.scroll_active = false
	_feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_feed.add_theme_font_size_override("normal_font_size", 13)
	_feed.add_theme_font_size_override("bold_font_size", 13)
	_feed.add_theme_constant_override("line_separation", 1)
	column.add_child(_feed)


## A sheet laid over the middle of the screen for something to read: the
## week's summary, what is known about a building, the menu. The rest of the
## screen is dimmed and does not take clicks while it is open.
func _build_sheet() -> void:
	_sheet_layer = Control.new()
	_sheet_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet_layer.visible = false
	add_child(_sheet_layer)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.10, 0.07, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet_layer.add_child(dim)

	_sheet = PanelContainer.new()
	_sheet.theme_type_variation = "Sheet"
	_sheet.position = Vector2(330, 70)
	_sheet.custom_minimum_size = Vector2(620, 0)
	_sheet_layer.add_child(_sheet)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_sheet.add_child(column)
	_sheet_title = Label.new()
	_sheet_title.add_theme_font_size_override("font_size", 22)
	_sheet_title.add_theme_color_override("font_color", MUSTARD)
	column.add_child(_sheet_title)
	column.add_child(HSeparator.new())
	_sheet_text = RichTextLabel.new()
	_sheet_text.bbcode_enabled = true
	_sheet_text.custom_minimum_size = Vector2(0, 420)
	_sheet_text.add_theme_color_override("default_color", PAPER)
	_sheet_text.add_theme_font_size_override("normal_font_size", 14)
	_sheet_text.add_theme_font_size_override("bold_font_size", 15)
	_sheet_text.add_theme_constant_override("line_separation", 2)
	column.add_child(_sheet_text)
	_sheet_buttons = HBoxContainer.new()
	_sheet_buttons.alignment = BoxContainer.ALIGNMENT_END
	_sheet_buttons.add_theme_constant_override("separation", 10)
	column.add_child(_sheet_buttons)


## Shows the sheet. actions is a list of [label, Callable] for extra buttons;
## a button to close the sheet is always added.
func show_sheet(title: String, text: String, actions: Array = [], close_label: String = "Continue") -> void:
	_sheet_title.text = title
	_sheet_text.text = text
	for child: Node in _sheet_buttons.get_children():
		_sheet_buttons.remove_child(child)
		child.queue_free()
	for action: Array in actions:
		_sheet_buttons.add_child(_button(action[0], action[1]))
	var close: Button = _button(close_label, close_sheet)
	close.tooltip_text = "Esc"
	_sheet_buttons.add_child(close)
	_sheet_layer.visible = true
	_sheet.reset_size()


func close_sheet() -> void:
	if _sheet_layer.visible:
		_sheet_layer.visible = false
		sheet_closed.emit()


func sheet_is_open() -> bool:
	return _sheet_layer.visible


func _button(text: String, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_press)
	return button


func _toggle(text: String, on_change: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_pressed = true
	button.focus_mode = Control.FOCUS_NONE
	button.toggled.connect(on_change)
	return button


func _heading(text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = "Heading"
	label.text = text
	return label


func _caption(text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = "Caption"
	label.text = text
	return label


func _spacer(width: int) -> Control:
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(width, 0)
	return gap


var _selected_for_talk: String = ""


func _talk_pressed(other_id: String) -> void:
	if _player_ids.has(_selected_for_talk):
		order_given.emit(_selected_for_talk, {"kind": "talk_to", "other_id": other_id})
	else:
		show_message("Choose one of your household first.")


## "Monday, 3 April 1950"
func _long_date(day_index: int) -> String:
	var date: Dictionary = SimDate.from_day_index(day_index)
	return "%s, %d %s %d" % [SimDate.weekday_name(day_index), date["day"], MONTH_NAMES[int(date["month"]) - 1], date["year"]]


## "4:00 pm"
func _twelve_hour(minute_of_day: int) -> String:
	@warning_ignore("integer_division")
	var hour: int = minute_of_day / 60
	var shown: int = hour % 12
	if shown == 0:
		shown = 12
	return "%d:%02d %s" % [shown, minute_of_day % 60, "am" if hour < 12 else "pm"]


func _hex(color: Color) -> String:
	return "#" + color.to_html(false)


# --- Refreshing --------------------------------------------------------------

func refresh(selected_id: String, speed_index: int, music_on: bool, sound_on: bool) -> void:
	_selected_for_talk = selected_id
	var minute: int = simulation.clock.minute_of_day
	_date_label.text = _long_date(simulation.clock.day_index)
	_time_label.text = _twelve_hour(minute)
	var night: bool = minute < DAY_STARTS_MINUTE or minute >= NIGHT_STARTS_MINUTE
	if night != _sky_is_night:
		_sky_is_night = night
		_sky.queue_redraw()
	for index: int in _speed_buttons.size():
		_speed_buttons[index].set_pressed_no_signal(index == speed_index)
	_music_button.set_pressed_no_signal(music_on)
	_music_button.text = "Music on" if music_on else "Music off"
	_sound_button.set_pressed_no_signal(sound_on)
	_sound_button.text = "Chimes on" if sound_on else "Chimes off"
	for person_id: String in _member_buttons:
		(_member_buttons[person_id] as Button).set_pressed_no_signal(person_id == selected_id)

	var person: Dictionary = simulation.state.people[selected_id]
	var age: int = SimDate.age_on(person["birth_day"], simulation.clock.day_index)
	var traits: String = ", ".join(person["traits"]) if not person["traits"].is_empty() else "no marked traits"
	_selected_label.text = "[b]%s %s[/b]  [color=%s]age %d, %s[/color]\n[color=%s]%s[/color]" % [
		person["given_name"], person["family_name"], _hex(INK_SOFT), age, traits,
		_hex(TEAL), Describe.activity(simulation, person),
	]
	for need_name: String in Records.NEED_NAMES:
		var level: int = person["needs"][need_name]
		@warning_ignore("integer_division")
		var percent: int = level * 100 / Records.NEED_MAX
		var bar: ProgressBar = _need_bars[need_name]
		bar.value = level
		var fill: StyleBoxFlat = _need_fills[0]
		if percent < NEED_LOW_PERCENT:
			fill = _need_fills[2]
		elif percent <= NEED_GOOD_PERCENT:
			fill = _need_fills[1]
		bar.add_theme_stylebox_override("fill", fill)
		(_need_values[need_name] as Label).text = "%d%%" % percent

	var viewer: String = selected_id if _player_ids.has(selected_id) else _player_ids[0]
	var viewer_name: String = simulation.state.people[viewer]["given_name"]
	for other_id: String in _neighbor_rows:
		var other: Dictionary = simulation.state.people[other_id]
		var key: String = Records.relationship_key(viewer, other_id)
		var text: String = "%s: not met" % other["given_name"]
		if simulation.state.relationships.has(key):
			var record: Dictionary = simulation.state.relationships[key]
			text = "%s: %s %+d, %s %+d (%d %s)" % [
				other["given_name"], viewer_name, simulation.state.regard(viewer, other_id),
				other["given_name"], simulation.state.regard(other_id, viewer), record["familiarity"],
				"talk" if record["familiarity"] == 1 else "talks",
			]
		var label: Label = _neighbor_rows[other_id]
		label.text = text
		label.add_theme_color_override("font_color", INK_SOFT if not simulation.state.relationships.has(key) else INK)

	var household: Dictionary = simulation.state.households[simulation.state.player_household_id()]
	var owed: String = ""
	if household["rent_owed_cents"] != 0:
		owed = "   [color=%s][b]%s owed[/b][/color]" % [_hex(CHERRY), Describe.money(household["rent_owed_cents"])]
	_money_label.text = "In hand [b]%s[/b]      Pantry [b]%d meals[/b]\nRent [b]%s[/b] each Monday%s\nWages earned, paid Friday: [b]%s[/b]" % [
		Describe.money(household["funds_cents"]), household["pantry_meals"],
		Describe.money(household["weekly_rent_cents"]), owed, Describe.money(household["wages_due_cents"]),
	]

	var lines: Array[String] = []
	var log: Array = simulation.state.event_log
	var now: int = Time.get_ticks_msec()
	for index: int in range(log.size() - 1, maxi(0, log.size() - FEED_LINES) - 1, -1):
		var event: Dictionary = log[index]
		if not _first_shown.has(event["id"]):
			_first_shown[event["id"]] = now
		var when: String = "[b][color=%s]%s[/color][/b]" % [_hex(TEAL), Describe.event_time(event)]
		var what: String = Describe.event(simulation, event)
		if now - int(_first_shown[event["id"]]) < FEED_FRESH_MS:
			lines.append("[bgcolor=%s][b][color=%s] NEW [/color][/b]  %s  %s [/bgcolor]" % [
				"#" + Color(MUSTARD, 0.35).to_html(true), _hex(CHERRY), when, what,
			])
		else:
			lines.append("%s  [color=%s]%s[/color]" % [when, _hex(INK_SOFT.darkened(0.15)), what])
	if lines.is_empty():
		lines.append("[color=%s][i]Nothing yet. News of the street will appear here.[/i][/color]" % _hex(INK_SOFT))
	_feed.text = "\n".join(lines)
