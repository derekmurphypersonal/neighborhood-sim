extends Control
## Clock, speed controls, household and relationship panel, and event feed.
## Presentation only: reads simulation state and emits the player's choices.

signal speed_chosen(index: int)
signal person_chosen(person_id: String)
signal order_given(person_id: String, order: Dictionary)

const Simulation := preload("res://sim/simulation.gd")
const SimDate := preload("res://sim/clock/sim_date.gd")
const Records := preload("res://sim/state/records.gd")

const SPEED_LABELS: Array[String] = ["Pause", "1 min/s", "10 min/s", "1 hour/s"]
const FEED_LINES: int = 9
const NEED_LABELS: Dictionary = {"hunger": "Fed", "rest": "Rested", "company": "Company"}

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


func setup(sim: Simulation) -> void:
	simulation = sim
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_bar()
	_build_side_panel()
	_build_feed()


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
	if simulation.area.placeholder:
		var banner: Label = Label.new()
		banner.text = "  FICTIONAL TEST STREET: not a real place"
		banner.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
		bar.add_child(banner)
	_message_label = Label.new()
	_message_label.position = Vector2(20, 48)
	_message_label.text = "Click one of your household (blue), then a house to send them there, or a neighbor to talk."
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

	column.add_child(_heading("Neighbors: the regard each has for the other"))
	for person_id: String in simulation.state.sorted_person_ids():
		if _player_ids.has(person_id):
			continue
		var person: Dictionary = simulation.state.people[person_id]
		if simulation.world["schedules"][person["schedule_id"]].get("housebound", false):
			continue
		var row: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		label.custom_minimum_size = Vector2(280, 0)
		label.clip_text = true
		label.add_theme_font_size_override("font_size", 13)
		row.add_child(label)
		var talk: Button = Button.new()
		talk.text = "Talk"
		talk.focus_mode = Control.FOCUS_NONE
		talk.pressed.connect(func() -> void: _talk_pressed(person_id))
		row.add_child(talk)
		column.add_child(row)
		_neighbor_rows[person_id] = label

	column.add_child(_heading("Household money"))
	_money_label = RichTextLabel.new()
	_money_label.fit_content = true
	_money_label.scroll_active = false
	column.add_child(_money_label)


func _build_feed() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(20, 512)
	panel.custom_minimum_size = Vector2(880, 193)
	add_child(panel)
	_feed = RichTextLabel.new()
	_feed.scroll_active = false
	_feed.add_theme_font_size_override("normal_font_size", 13)
	panel.add_child(_feed)


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

func refresh(selected_id: String, speed_index: int) -> void:
	_selected_for_talk = selected_id
	_clock_label.text = simulation.clock.describe()
	for index: int in _speed_buttons.size():
		_speed_buttons[index].set_pressed_no_signal(index == speed_index)

	var person: Dictionary = simulation.state.people[selected_id]
	var age: int = SimDate.age_on(person["birth_day"], simulation.clock.day_index)
	var traits: String = ", ".join(person["traits"]) if not person["traits"].is_empty() else "no marked traits"
	_selected_label.text = "[b]%s %s[/b], %d  (%s)\n%s" % [
		person["given_name"], person["family_name"], age, traits, describe_activity(person),
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

	var money: Array[String] = []
	for household_id: String in simulation.state.sorted_household_ids():
		var household: Dictionary = simulation.state.households[household_id]
		money.append("%s: $%.2f" % [household["name"], household["funds_cents"] / 100.0])
	_money_label.text = "\n".join(money) + "\n(settled each Friday)"

	var lines: Array[String] = []
	var log: Array = simulation.state.event_log
	for index: int in range(maxi(0, log.size() - FEED_LINES), log.size()):
		lines.append(describe_event(log[index]))
	_feed.text = "What has happened\n" + "\n".join(lines)


func _name(person_id: String) -> String:
	return simulation.state.people[person_id]["given_name"]


func describe_activity(person: Dictionary) -> String:
	var action: Dictionary = person["action"]
	if action.is_empty():
		return "Deciding what to do"
	var kind: String = action["kind"]
	if not action["started"]:
		match kind:
			"work": return "Leaving for work"
			"school": return "Leaving for school"
			"call_on": return "Going to talk to " + _name(action["other_id"])
			"visit": return "Walking over to call on a neighbor"
			"sit_out": return "Stepping outside"
			"go_to": return "Walking where you sent them"
		return "Heading home"
	match kind:
		"sleep": return "Asleep"
		"eat": return "Having a meal"
		"work": return "Away at work"
		"school": return "Away at school"
		"be_home": return "At home"
		"sit_out": return "Sitting out front"
		"visit": return "Calling at a neighbor's door"
		"go_to": return "Waiting where you sent them"
		"call_on": return "Looking for " + _name(action["other_id"])
		"talk": return "Talking with " + _name(action["other_id"])
	return kind


func describe_event(event: Dictionary) -> String:
	@warning_ignore("integer_division")
	var when: String = "%s %02d:%02d" % [SimDate.weekday_name(event["day"]).left(3), event["minute"] / 60, event["minute"] % 60]
	match event["type"]:
		"conversation":
			var first: String = " (their first meeting)" if event["first_meeting"] else ""
			return "%s  %s and %s talked for %d minutes%s. Regard: %s %+d, %s %+d." % [
				when, _name(event["a"]), _name(event["b"]), event["minutes"], first,
				_name(event["a"]), event["a_change"], _name(event["b"]), event["b_change"],
			]
		"birthday":
			return "%s  %s turned %d." % [when, _name(event["person_id"]), event["age"]]
		"household_short_of_money":
			return "%s  The %s is short of money." % [when, simulation.state.households[event["household_id"]]["name"]]
		"order_failed":
			return "%s  %s could not find %s: away from the street." % [when, _name(event["person_id"]), _name(event["other_id"])]
	return "%s  %s" % [when, event["type"]]
