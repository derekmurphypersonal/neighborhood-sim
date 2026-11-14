extends Control
## Clock, speed controls, household and relationship panel, and event feed.
## Presentation only: reads simulation state and emits the player's choices.

signal speed_chosen(index: int)
signal person_chosen(person_id: String)
signal order_given(person_id: String, order: Dictionary)
signal music_toggled(on: bool)
signal sound_toggled(on: bool)
signal week_requested
signal sheet_closed

const Simulation := preload("res://sim/simulation.gd")
const SimDate := preload("res://sim/clock/sim_date.gd")
const Records := preload("res://sim/state/records.gd")
const Describe := preload("res://view/describe.gd")

const SPEED_LABELS: Array[String] = ["Pause", "1 min/s", "10 min/s", "1 hour/s"]
const FEED_LINES: int = 7
## How long a new line in the feed stays highlighted, in real milliseconds.
const FEED_FRESH_MS: int = 5000
const NEED_LABELS: Dictionary = {"hunger": "Fed", "rest": "Rested", "company": "Company", "fun": "Fun"}

var simulation: Simulation
var _clock_label: Label
var _speed_buttons: Array[Button] = []
var _message_label: Label
var _selected_label: RichTextLabel
var _need_bars: Dictionary = {}
var _neighbor_rows: Dictionary = {}
var _money_label: RichTextLabel
var _feed: RichTextLabel
var _player_ids: Array = []
var _music_button: Button
var _sound_button: Button
## event id -> the moment it first appeared in the feed
var _first_shown: Dictionary = {}
var _sheet: PanelContainer
var _sheet_title: Label
var _sheet_text: RichTextLabel
var _sheet_buttons: HBoxContainer


func setup(sim: Simulation) -> void:
	simulation = sim
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_bar()
	_build_side_panel()
	_build_feed()
	_build_sheet()


func show_message(text: String) -> void:
	_message_label.text = text


# --- Building the layout -----------------------------------------------------

func _build_top_bar() -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.position = Vector2(20, 14)
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)
	_clock_label = Label.new()
	_clock_label.custom_minimum_size = Vector2(290, 0)
	_clock_label.add_theme_font_size_override("font_size", 20)
	bar.add_child(_clock_label)
	for index: int in SPEED_LABELS.size():
		var button: Button = Button.new()
		button.text = SPEED_LABELS[index]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: speed_chosen.emit(index))
		bar.add_child(button)
		_speed_buttons.append(button)
	_music_button = _toggle("Music", func(on: bool) -> void: music_toggled.emit(on))
	bar.add_child(_music_button)
	_sound_button = _toggle("Chimes", func(on: bool) -> void: sound_toggled.emit(on))
	bar.add_child(_sound_button)
	bar.add_child(_button("This week", func() -> void: week_requested.emit()))
	if simulation.area.placeholder:
		var banner: Label = Label.new()
		banner.text = "FICTIONAL TEST STREET: not a real place"
		banner.add_theme_font_size_override("font_size", 13)
		banner.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
		bar.add_child(banner)
	_message_label = Label.new()
	_message_label.position = Vector2(20, 48)
	_message_label.text = "Click one of your household (blue), then a house or a neighbor. Right-click a building to see what is known about it."
	_message_label.add_theme_font_size_override("font_size", 13)
	add_child(_message_label)


func _build_side_panel() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(915, 60)
	panel.custom_minimum_size = Vector2(350, 645)
	add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	var household: Dictionary = simulation.state.households[simulation.state.player_household_id()]
	_player_ids = household["member_ids"]
	column.add_child(_heading("Your household: " + household["name"]))
	var members: HBoxContainer = HBoxContainer.new()
	column.add_child(members)
	for person_id: String in _player_ids:
		var button: Button = Button.new()
		button.text = simulation.state.people[person_id]["given_name"]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: person_chosen.emit(person_id))
		members.add_child(button)

	_selected_label = RichTextLabel.new()
	_selected_label.bbcode_enabled = true
	_selected_label.fit_content = true
	_selected_label.scroll_active = false
	column.add_child(_selected_label)
	for need_name: String in Records.NEED_NAMES:
		var row: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		label.text = NEED_LABELS[need_name]
		label.custom_minimum_size = Vector2(80, 0)
		row.add_child(label)
		var bar: ProgressBar = ProgressBar.new()
		bar.max_value = Records.NEED_MAX
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(240, 14)
		row.add_child(bar)
		column.add_child(row)
		_need_bars[need_name] = bar

	column.add_child(_heading("Household money"))
	_money_label = RichTextLabel.new()
	_money_label.fit_content = true
	_money_label.scroll_active = false
	_money_label.add_theme_font_size_override("normal_font_size", 13)
	column.add_child(_money_label)

	column.add_child(_heading("Neighbors: the regard each has for the other"))
	# The list scrolls, so a long street never pushes anything off the panel.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var neighbors: VBoxContainer = VBoxContainer.new()
	neighbors.add_theme_constant_override("separation", 2)
	scroll.add_child(neighbors)
	for person_id: String in simulation.state.sorted_person_ids():
		if _player_ids.has(person_id):
			continue
		var person: Dictionary = simulation.state.people[person_id]
		if simulation.world["schedules"][person["schedule_id"]].get("housebound", false):
			continue
		var row: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		label.custom_minimum_size = Vector2(268, 0)
		label.clip_text = true
		label.add_theme_font_size_override("font_size", 13)
		row.add_child(label)
		var talk: Button = Button.new()
		talk.text = "Talk"
		talk.focus_mode = Control.FOCUS_NONE
		talk.pressed.connect(func() -> void: _talk_pressed(person_id))
		row.add_child(talk)
		neighbors.add_child(row)
		_neighbor_rows[person_id] = label


func _build_feed() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(20, 512)
	panel.custom_minimum_size = Vector2(880, 193)
	add_child(panel)
	_feed = RichTextLabel.new()
	_feed.bbcode_enabled = true
	_feed.scroll_active = false
	_feed.add_theme_font_size_override("normal_font_size", 13)
	panel.add_child(_feed)


## A sheet laid over the middle of the screen for something to read: the
## week's summary, what is known about a building, the menu.
func _build_sheet() -> void:
	_sheet = PanelContainer.new()
	_sheet.position = Vector2(290, 80)
	_sheet.custom_minimum_size = Vector2(600, 520)
	_sheet.visible = false
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.13, 0.15, 0.19, 0.97)
	box.border_color = Color(1.0, 0.92, 0.55)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(16)
	_sheet.add_theme_stylebox_override("panel", box)
	add_child(_sheet)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_sheet.add_child(column)
	_sheet_title = Label.new()
	_sheet_title.add_theme_font_size_override("font_size", 20)
	column.add_child(_sheet_title)
	_sheet_text = RichTextLabel.new()
	_sheet_text.bbcode_enabled = true
	_sheet_text.custom_minimum_size = Vector2(0, 400)
	_sheet_text.add_theme_font_size_override("normal_font_size", 14)
	_sheet_text.add_theme_font_size_override("bold_font_size", 14)
	column.add_child(_sheet_text)
	_sheet_buttons = HBoxContainer.new()
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
	_sheet_buttons.add_child(_button(close_label, close_sheet))
	_sheet.visible = true
	_sheet.reset_size()


func close_sheet() -> void:
	if _sheet.visible:
		_sheet.visible = false
		sheet_closed.emit()


func sheet_is_open() -> bool:
	return _sheet.visible


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
	label.text = text
	label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	return label


var _selected_for_talk: String = ""


func _talk_pressed(other_id: String) -> void:
	if _player_ids.has(_selected_for_talk):
		order_given.emit(_selected_for_talk, {"kind": "talk_to", "other_id": other_id})
	else:
		show_message("Choose one of your household first.")


# --- Refreshing --------------------------------------------------------------

func refresh(selected_id: String, speed_index: int, music_on: bool, sound_on: bool) -> void:
	_selected_for_talk = selected_id
	_clock_label.text = simulation.clock.describe()
	for index: int in _speed_buttons.size():
		_speed_buttons[index].set_pressed_no_signal(index == speed_index)
	_music_button.set_pressed_no_signal(music_on)
	_music_button.text = "Music: on" if music_on else "Music: off"
	_sound_button.set_pressed_no_signal(sound_on)
	_sound_button.text = "Chimes: on" if sound_on else "Chimes: off"

	var person: Dictionary = simulation.state.people[selected_id]
	var age: int = SimDate.age_on(person["birth_day"], simulation.clock.day_index)
	var traits: String = ", ".join(person["traits"]) if not person["traits"].is_empty() else "no marked traits"
	_selected_label.text = "[b]%s %s[/b], %d  (%s)\n%s" % [
		person["given_name"], person["family_name"], age, traits, Describe.activity(simulation, person),
	]
	for need_name: String in Records.NEED_NAMES:
		(_need_bars[need_name] as ProgressBar).value = person["needs"][need_name]

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
		(_neighbor_rows[other_id] as Label).text = text

	var household: Dictionary = simulation.state.households[simulation.state.player_household_id()]
	var owed: String = "" if household["rent_owed_cents"] == 0 else ", %s owed" % Describe.money(household["rent_owed_cents"])
	_money_label.text = "In hand %s.  Pantry: %d meals.\nRent %s each Monday%s.\nWages earned, paid Friday: %s." % [
		Describe.money(household["funds_cents"]), household["pantry_meals"],
		Describe.money(household["weekly_rent_cents"]), owed, Describe.money(household["wages_due_cents"]),
	]

	var lines: Array[String] = []
	var log: Array = simulation.state.event_log
	var now: int = Time.get_ticks_msec()
	for index: int in range(maxi(0, log.size() - FEED_LINES), log.size()):
		var event: Dictionary = log[index]
		if not _first_shown.has(event["id"]):
			_first_shown[event["id"]] = now
		var line: String = "%s  %s" % [Describe.event_time(event), Describe.event(simulation, event)]
		if now - int(_first_shown[event["id"]]) < FEED_FRESH_MS:
			line = "[color=#ffe98c][b]NEW[/b]  %s[/color]" % line
		lines.append(line)
	_feed.text = "[b]What has happened[/b]\n" + "\n".join(lines)
