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
signal help_requested
## The player asked to see something on the street: kind is "person" or
## "building". main.gd moves the camera and highlights it.
signal focus_requested(kind: String, id: String)
signal sheet_closed

const Simulation := preload("res://sim/simulation.gd")
const SimDate := preload("res://sim/clock/sim_date.gd")
const Records := preload("res://sim/state/records.gd")
const Describe := preload("res://view/describe.gd")
const HudArt := preload("res://view/hud_art.gd")
const WeekPaper := preload("res://view/week_paper.gd")
const WeekSummary := preload("res://sim/reports/week_summary.gd")
const WorldView := preload("res://view/world_view.gd")
const BuildingPage := preload("res://view/building_page.gd")
const Tips := preload("res://view/tips.gd")
const TextSize := preload("res://view/text_size.gd")

const SPEED_LABELS: Array[String] = ["Pause", "1 min/s", "10 min/s", "1 hour/s"]
## Keyboard shortcuts as handled in main.gd's _unhandled_key_input.
const SPEED_TIPS: Array[String] = [
	"Pause the clock  (Space)",
	"One game minute each second  (1)",
	"Ten game minutes each second  (2)",
	"One game hour each second  (3)",
]
const MONTH_NAMES: Array[String] = [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
]
const FEED_LINES: int = 7
## With Large text the feed shows one line fewer, each a little taller.
const FEED_LINES_LARGE: int = 6
const FEED_ROW_HEIGHT_LARGE: int = 22
## The feed's filters: id, tab label, tooltip.
const FEED_FILTERS: Array[Array] = [
	["all", "All", "Everything that happens on the street"],
	["household", "Your household", "News about your own family: their talks, money, birthdays and errands"],
	["money", "Money", "Wages, rent, shopping and empty pantries, for every household"],
	["neighbors", "Neighbors", "Conversations on the street: your family's with the neighbors, and the neighbors' among themselves"],
]
const FEED_EMPTY_TEXT: Dictionary = {
	"all": "Nothing yet. News of the street will appear here.",
	"household": "Nothing about your household yet.",
	"money": "No money news yet: rent is taken on Monday, wages paid on Friday.",
	"neighbors": "No conversations yet.",
}
const MONEY_EVENTS: Array[String] = ["payday", "rent_paid", "shopping", "empty_pantry", "household_short_of_money", "missed_work"]
## Similar events within this many game minutes of the next are folded
## together, once there are at least FEED_COLLAPSE_AT more of them.
const FEED_GROUP_MINUTES: int = 120
const FEED_COLLAPSE_AT: int = 2
## Event types that may be folded, with the words for one and for several.
const FEED_NOUNS: Dictionary = {
	"conversation": ["conversation", "conversations"], "shopping": ["shopping trip", "shopping trips"],
	"payday": ["payday", "paydays"], "rent_paid": ["rent payment", "rent payments"],
	"empty_pantry": ["empty pantry", "empty pantries"], "household_short_of_money": ["money trouble", "money troubles"],
	"missed_work": ["missed day of work", "missed days of work"],
}
## How long a new line in the feed stays highlighted, in real milliseconds.
const FEED_FRESH_MS: int = 5000
const NEED_LABELS: Dictionary = {"hunger": "Fed", "rest": "Rested", "company": "Company", "fun": "Fun"}
## What fills each need, as sim/systems/needs.gd has it.
const NEED_TIPS: Dictionary = {
	"hunger": "Fed: falls all day, more slowly asleep.\nFilled by a meal at home, if there is food in the pantry.",
	"rest": "Rested: falls while awake.\nFilled by sleeping at home.",
	"company": "Company: falls when alone.\nFilled by talking with someone from another household.",
	"fun": "Fun: falls while awake, except at work or school.\nFilled by a pastime at home, playing outside (children),\nlooking around the store, and a little by talking.",
}
## Width kept free at the left of the selected member's tab for a portrait.
const TAB_FACE: float = 20.0
const TAB_FACE_PAD: String = "      "
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
const SHEET_OPEN_SECONDS: float = 0.22
const SHEET_CLOSE_SECONDS: float = 0.14
const SHEET_TEXT_MIN_HEIGHT: int = 90
const SHEET_TEXT_MAX_HEIGHT: int = 440
## Left plus right content margin of the "Sheet" panel style.
const SHEET_SIDE_MARGINS: float = 44.0
const SCREEN_HEIGHT: float = 720.0
## The goals card sits in the left column, between the home cutaway drawn by
## world_view (ending at y 370) and the feed (starting at y 512).
const GOALS_RECT: Rect2 = Rect2(20, 378, 232, 130)
const GOAL_ROWS: int = 7
const GOAL_ROW_HEIGHT: int = 15
const GOAL_FONT_SIZE: int = 12
const GOAL_METER_WIDTH: float = 22.0
const GOAL_COUNT_WIDTH: float = 28.0
## How long a goal's row shines after it is done, in real milliseconds.
const GOAL_SHINE_MS: int = 1400
## How quickly need bars glide to a new value (per second), and how long a
## new feed line takes to slide in (real milliseconds).
const NEED_GLIDE_RATE: float = 6.0
const FEED_SLIDE_MS: int = 380
const FEED_ROW_HEIGHT: int = 20
## Regard shown as a full bar in the neighbors list.
const REGARD_METER_SPAN: int = 40
const METER_WIDTH: float = 46.0
## Room at the left of the meter for the chevron after a change, and how long
## the chevron stays, in real milliseconds.
const METER_MARK_WIDTH: float = 10.0
const METER_CHANGE_MS: int = 15000
const MESSAGE_FONT_SIZE: int = 12
## The note under the top bar stops short of the side panel and its badge.
const MESSAGE_MAX_WIDTH: float = 860.0
const SPEED_DIAL_SIZE: Vector2 = Vector2(34, 26)
## How long one sweep of the fast-forward shimmer takes, in real milliseconds.
const SHIMMER_MS: int = 1600
const FEED_HOVER: Color = Color(0.18, 0.36, 0.38, 0.10)
const NEIGHBOR_NAME_WIDTH: int = 78
const WORD_COLORS: Dictionary = {
	"Friend": Color("#3E7A33"), "Friendly": Color("#5E8C4A"), "Acquaintance": Color("#3B2F2A"),
	"Cool": Color("#4F6E8C"), "Unfriendly": Color("#B5442F"), "Stranger": Color("#9A8676"),
}

var simulation: Simulation
var _date_label: Label
var _time_label: Label
var _sky: Control
var _sky_is_night: bool = false
var _speed_buttons: Array[Button] = []
var _member_buttons: Dictionary = {}
var _message_label: Label
var _selected_label: RichTextLabel
var _portrait: Control
var _mood_face: Control
var _mood_label: Label
var _activity_label: Label
var _shown_person: String = ""
var _shown_face: String = ""
var _need_bars: Dictionary = {}
var _need_values: Dictionary = {}
## need -> the level the bar shows now, gliding toward the person's level
var _need_shown: Dictionary = {}
var _last_tick_ms: int = -1
var _need_fills: Array[StyleBoxFlat] = []
var _need_warnings: Dictionary = {}
## person id -> {panel, name, word, meter, mine, theirs, met}
var _neighbor_rows: Dictionary = {}
var _neighbor_list: VBoxContainer
var _neighbor_order: Array = []
var _money_label: RichTextLabel
var _ledger: Control
var _week_summary: Dictionary = {}
var _week_summary_key: String = ""
## One drawn row per feed line: {row, text, event_id}
var _feed_rows: Array[Dictionary] = []
var _feed_empty: Label
var _feed_tabs: Dictionary = {}
var _feed_filter: String = "all"
var _feed_slots: int = FEED_LINES
## Groups of folded lines the player has opened, by group id.
var _feed_expanded: Dictionary = {}
var _feed_cache_key: String = ""
var _feed_shown: Array[Dictionary] = []
var _chevron_up: ImageTexture
var _chevron_down: ImageTexture
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
var _sheet_dim: ColorRect
var _sheet_open: bool = false
var _sheet_tween: Tween
var _paused_pill: PanelContainer
var _pill_tween: Tween
## "Things to try this week": one drawn row per goal, from sim/reports/week_goals.gd.
var _goal_rows: Array[Control] = []
var _goals: Array = []
## goal id -> status last shown, and id -> when it began to shine
var _goal_seen: Dictionary = {}
var _goal_shine: Dictionary = {}
var _goal_track: StyleBoxFlat
var _goal_fill: StyleBoxFlat
var _goal_fill_done: StyleBoxFlat
var _sheet_content: VBoxContainer
## The first-time tips; main.gd offers them and keeps the list of those seen.
var tips: Tips
## person id -> the small portrait on that member's tab, shown when selected
var _member_faces: Dictionary = {}
var _member_tips: Dictionary = {}
var _tab_selected: String = ""
var _tab_face_kind: String = ""
var _neighbor_scroll: ScrollContainer
var _hover_neighbor: String = ""
## The neighbors list is sized once to a whole number of rows, so the last
## row shown is never cut in half by the panel's edge.
var _neighbor_rows_fitted: bool = false
var _speed_dial: Control
var _shimmer: Control
var _speed_index: int = -1
## The dial's needle, in radians, gliding toward the speed chosen.
var _dial_angle: float = -1.0
var _dial_target: float = 0.0
var _message_note: PanelContainer
var _side_panel: PanelContainer
var _feed_panel: PanelContainer
var _large_text: bool = false
## Frames to wait before the neighbors list is fitted again (after the text
## size changes, the rows need a frame to take their new height).
var _refit_wait: int = 0
var _money_height: float = -1.0


func setup(sim: Simulation) -> void:
	simulation = sim
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _make_theme()
	_need_fills = [_box(LEAF, 6), _box(MUSTARD, 6), _box(CHERRY, 6)]
	_goal_track = _with_border(_box(Color(PAPER_DARK, 0.9), 3), PAPER_DARK.darkened(0.2), 1)
	_goal_fill = _box(TEAL, 3)
	_goal_fill_done = _box(LEAF, 3)
	_build_top_bar()
	_build_side_panel()
	_build_feed()
	_build_goals()
	tips = Tips.new()
	add_child(tips)
	_build_sheet()


func show_message(text: String) -> void:
	_message_label.text = text
	# A long message is cut with an ellipsis before it reaches the side panel;
	# the whole of it is in the tooltip.
	# A label that trims has no width of its own, so it is given one here.
	var font: Font = ThemeDB.fallback_font
	var width: float = ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, MESSAGE_FONT_SIZE).x) + 2.0
	var wide: bool = width > MESSAGE_MAX_WIDTH
	_message_label.clip_text = wide
	_message_label.custom_minimum_size.x = minf(width, MESSAGE_MAX_WIDTH)
	_message_note.visible = text != ""
	_message_note.tooltip_text = text if wide else ""
	_message_note.mouse_filter = Control.MOUSE_FILTER_STOP if wide else Control.MOUSE_FILTER_IGNORE
	_message_note.reset_size()


# --- The look ----------------------------------------------------------------

static func _box(color: Color, radius: int, margin_x: int = 0, margin_y: int = 0) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	return box


static func _with_border(box: StyleBoxFlat, color: Color, width: int) -> StyleBoxFlat:
	box.border_color = color
	box.set_border_width_all(width)
	return box


static func _with_shadow(box: StyleBoxFlat, size: int) -> StyleBoxFlat:
	box.shadow_color = SHADOW
	box.shadow_size = size
	box.shadow_offset = Vector2(0, 2)
	return box


static func _set_button_styles(theme_value: Theme, type_name: String, normal: Color, hover: Color, on: Color, radius: int, margin_x: int, margin_y: int) -> void:
	var edge: Color = normal.darkened(0.25)
	# Raised at rest, a little brighter under the pointer, and pushed in when
	# pressed: the lip below goes away and the text drops by a pixel.
	var rest: StyleBoxFlat = _with_border(_box(normal, radius, margin_x, margin_y), edge, 1)
	rest.border_width_bottom = 2
	var lit: StyleBoxFlat = _with_border(_box(hover.lightened(0.08), radius, margin_x, margin_y), edge.lightened(0.1), 1)
	lit.border_width_bottom = 2
	lit.shadow_color = Color(1.0, 0.95, 0.80, 0.18)
	lit.shadow_size = 3
	var down: StyleBoxFlat = _with_border(_box(on, radius, margin_x, margin_y), on.darkened(0.3), 1)
	down.content_margin_top = margin_y + 1
	down.content_margin_bottom = maxi(margin_y - 1, 0)
	var down_lit: StyleBoxFlat = _with_border(_box(on.lightened(0.12), radius, margin_x, margin_y), on.darkened(0.3), 1)
	down_lit.content_margin_top = margin_y + 1
	down_lit.content_margin_bottom = maxi(margin_y - 1, 0)
	theme_value.set_stylebox("normal", type_name, rest)
	theme_value.set_stylebox("hover", type_name, lit)
	theme_value.set_stylebox("pressed", type_name, down)
	theme_value.set_stylebox("hover_pressed", type_name, down_lit)
	theme_value.set_stylebox("disabled", type_name, _box(Color(normal, 0.45), radius, margin_x, margin_y))
	theme_value.set_stylebox("focus", type_name, StyleBoxEmpty.new())


## The game's one theme; the title screen and settings sheet use it too.
static func make_theme() -> Theme:
	return _make_theme()


static func _make_theme() -> Theme:
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

	# The feed's filter tabs: small, the chosen one teal.
	t.set_type_variation("FeedTab", "Button")
	_set_button_styles(t, "FeedTab", PAPER_ROW, PAPER, TEAL, 9, 8, 0)
	t.set_font_size("font_size", "FeedTab", 11)
	for key: String in ["font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(key, "FeedTab", PAPER)

	t.set_type_variation("RowA", "PanelContainer")
	t.set_stylebox("panel", "RowA", _box(PAPER_ROW, 5, 8, 3))
	t.set_type_variation("RowB", "PanelContainer")
	t.set_stylebox("panel", "RowB", _box(Color(PAPER_ROW, 0.0), 5, 8, 3))

	t.set_type_variation("RowHover", "PanelContainer")
	var hover_row: StyleBoxFlat = _with_border(_box(Color("#F3DDA0"), 5, 8, 3), Color(MUSTARD, 0.75), 1)
	t.set_stylebox("panel", "RowHover", hover_row)

	t.set_type_variation("TopBar", "PanelContainer")
	var bar: StyleBoxFlat = _with_shadow(_box(TEAL, 0, 20, 6), 8)
	bar.border_color = MUSTARD
	bar.border_width_bottom = 3
	t.set_stylebox("panel", "TopBar", bar)

	t.set_type_variation("Badge", "PanelContainer")
	t.set_stylebox("panel", "Badge", _with_shadow(_with_border(_box(CHERRY, 11, 12, 2), PAPER, 2), 3))

	t.set_type_variation("Note", "PanelContainer")
	t.set_stylebox("panel", "Note", _box(Color(PAPER, 0.88), 9, 12, 2))

	t.set_type_variation("PersonCard", "PanelContainer")
	t.set_stylebox("panel", "PersonCard", _with_border(_box(PAPER_ROW, 8, 8, 6), PAPER_DARK.darkened(0.1), 1))

	t.set_type_variation("GoalsCard", "PanelContainer")
	t.set_stylebox("panel", "GoalsCard", _with_shadow(_with_border(_box(PAPER, 10, 10, 6), PAPER_DARK.darkened(0.15), 1), 6))

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
	# A faint light sweeping across the clock while time runs at its fastest.
	_shimmer = Control.new()
	_shimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shimmer.clip_contents = true
	_shimmer.draw.connect(_draw_shimmer)
	_time_label.add_child(_shimmer)
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
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(func() -> void: speed_chosen.emit(index))
		bar.add_child(button)
		_speed_buttons.append(button)
	_speed_dial = Control.new()
	_speed_dial.custom_minimum_size = Vector2(SPEED_DIAL_SIZE.x, SPEED_DIAL_SIZE.y)
	_speed_dial.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_speed_dial.mouse_filter = Control.MOUSE_FILTER_STOP
	_speed_dial.draw.connect(_draw_speed_dial)
	bar.add_child(_speed_dial)
	bar.add_child(_spacer(6))
	_music_button = _toggle("Music", func(on: bool) -> void: music_toggled.emit(on))
	_music_button.tooltip_text = "Turn the music on or off  (M)"
	bar.add_child(_music_button)
	_sound_button = _toggle("Sounds", func(on: bool) -> void: sound_toggled.emit(on))
	_sound_button.tooltip_text = "Turn the sounds on or off: the chimes for news and the birds and crickets outside  (N)"
	bar.add_child(_sound_button)
	bar.add_child(_spacer(12))
	_build_paused_pill(bar)
	var filler: Control = Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(filler)
	var week: Button = _button("This week", func() -> void: week_requested.emit())
	week.tooltip_text = "How the week is going for your household: money, neighbors and things to try"
	bar.add_child(week)
	var help: Button = _button("Help", func() -> void: help_requested.emit())
	help.tooltip_text = "How to play: controls, panels and goals  (H or F1)"
	bar.add_child(help)
	var menu: Button = _button("Menu", func() -> void: menu_requested.emit())
	menu.tooltip_text = "Save, load, settings and the main menu  (Esc)"
	bar.add_child(menu)

	var note: PanelContainer = PanelContainer.new()
	note.theme_type_variation = "Note"
	note.position = Vector2(20, 47)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(note)
	_message_note = note
	_message_label = Label.new()
	_message_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_message_label.add_theme_font_size_override("font_size", MESSAGE_FONT_SIZE)
	note.add_child(_message_label)
	show_message("Click one of your household (blue), then a house or a neighbor. Right-click a building for details. H for help.")

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


## A little gauge beside the speed buttons: four ticks from pause (left) to
## 1 hour/s (right) and a needle that swings to the speed in use.
func _draw_speed_dial() -> void:
	var centre: Vector2 = Vector2(_speed_dial.size.x / 2.0, _speed_dial.size.y - 6.0)
	var radius: float = 13.0
	_speed_dial.draw_arc(centre, radius, PI, TAU, 24, Color(PAPER, 0.30), 3.0, true)
	if _dial_angle > PI + 0.01:
		_speed_dial.draw_arc(centre, radius, PI, _dial_angle, 24, MUSTARD, 3.0, true)
	for index: int in SPEED_LABELS.size():
		var angle: float = PI + PI * float(index) / float(SPEED_LABELS.size() - 1)
		var direction: Vector2 = Vector2.from_angle(angle)
		var lit: bool = index <= _speed_index
		_speed_dial.draw_line(centre + direction * (radius + 2.0), centre + direction * (radius + 5.0),
				MUSTARD if lit else Color(PAPER, 0.45), 1.5, true)
	var needle: Vector2 = Vector2.from_angle(_dial_angle)
	_speed_dial.draw_line(centre, centre + needle * (radius - 2.0), PAPER, 2.0, true)
	_speed_dial.draw_circle(centre, 3.0, CHERRY if _speed_index == 0 else MUSTARD)


## While time runs at its fastest, a soft band of light sweeps over the clock.
func _draw_shimmer() -> void:
	if _speed_index != SPEED_LABELS.size() - 1:
		return
	var phase: float = float(Time.get_ticks_msec() % SHIMMER_MS) / float(SHIMMER_MS)
	var x: float = lerpf(-30.0, _shimmer.size.x + 30.0, phase)
	var h: float = _shimmer.size.y
	_shimmer.draw_colored_polygon(PackedVector2Array([
		Vector2(x - 10, h), Vector2(x + 2, 0), Vector2(x + 14, 0), Vector2(x + 2, h),
	]), Color(1.0, 0.97, 0.85, 0.22))
	_shimmer.draw_colored_polygon(PackedVector2Array([
		Vector2(x + 6, h), Vector2(x + 18, 0), Vector2(x + 22, 0), Vector2(x + 10, h),
	]), Color(1.0, 0.97, 0.85, 0.12))


## Keeps the dial and shimmer in step with the speed (called every refresh).
func _refresh_speed(speed_index: int) -> void:
	if speed_index != _speed_index:
		_speed_index = speed_index
		_dial_target = PI + PI * float(speed_index) / float(SPEED_LABELS.size() - 1)
		_speed_dial.tooltip_text = "Speed now: %s\nKeys 1, 2 and 3 set the speed; Space pauses" % (
			"paused" if speed_index == 0 else SPEED_LABELS[speed_index])
		_shimmer.queue_redraw()
	if _dial_angle < 0.0:
		_dial_angle = _dial_target
		_speed_dial.queue_redraw()
	if not is_equal_approx(_dial_angle, _dial_target):
		_dial_angle = move_toward(_dial_angle, _dial_target, 0.12)
		_speed_dial.queue_redraw()
	if _speed_index == SPEED_LABELS.size() - 1:
		_shimmer.queue_redraw()


## A small "Paused" tag in the top bar, shown while the clock is stopped. It
## sits before the bar's filler, so showing it never moves the other buttons.
func _build_paused_pill(bar: HBoxContainer) -> void:
	_paused_pill = PanelContainer.new()
	_paused_pill.theme_type_variation = "Badge"
	_paused_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_paused_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paused_pill.visible = false
	var label: Label = Label.new()
	label.text = "PAUSED"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", PAPER)
	_paused_pill.add_child(label)
	bar.add_child(_paused_pill)


func _show_paused(paused: bool) -> void:
	if paused == _paused_pill.visible:
		return
	_paused_pill.visible = paused
	if _pill_tween != null:
		_pill_tween.kill()
		_pill_tween = null
	_paused_pill.modulate.a = 1.0
	if paused:
		# A slow breathing pulse, so the stopped clock is noticed but not nagging.
		_pill_tween = create_tween().set_loops()
		_pill_tween.tween_property(_paused_pill, "modulate:a", 0.55, 0.9).set_trans(Tween.TRANS_SINE)
		_pill_tween.tween_property(_paused_pill, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


func _build_side_panel() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(915, 78)
	panel.custom_minimum_size = Vector2(350, 627)
	add_child(panel)
	_side_panel = panel
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)

	var household: Dictionary = simulation.state.households[simulation.state.player_household_id()]
	_player_ids = household["member_ids"]
	var title: HBoxContainer = HBoxContainer.new()
	column.add_child(title)
	var house_name: Label = _heading(household["name"])
	house_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	house_name.clip_text = true
	house_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	house_name.tooltip_text = household["name"]
	house_name.mouse_filter = Control.MOUSE_FILTER_PASS
	title.add_child(house_name)
	var caption: Label = _caption("YOUR HOUSEHOLD")
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(caption)
	var members: HBoxContainer = HBoxContainer.new()
	members.add_theme_constant_override("separation", 4)
	column.add_child(members)
	for person_id: String in _player_ids:
		var button: Button = Button.new()
		button.theme_type_variation = "MemberTab"
		button.text = simulation.state.people[person_id]["given_name"]
		# The tabs share the panel's width exactly, so their text keeps its size.
		button.set_meta(TextSize.FIXED_META, true)
		button.set_meta("normal_font_size", 14)
		button.add_theme_font_size_override("font_size", 14)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(func() -> void: _tab_pressed(person_id))
		members.add_child(button)
		_member_buttons[person_id] = button
		# A tiny portrait at the left of the tab, shown while it is selected.
		var tab_face: Control = Control.new()
		tab_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab_face.size = Vector2(TAB_FACE, TAB_FACE)
		tab_face.position = Vector2(7, 3)
		tab_face.visible = false
		tab_face.draw.connect(func() -> void: _draw_tab_face(tab_face, person_id))
		button.add_child(tab_face)
		_member_faces[person_id] = tab_face

	# The person card: a portrait as on the street, name and age, mood, doing.
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = "PersonCard"
	card.tooltip_text = "The selected person: name, age and traits, how they seem, and what they are doing.\nMood follows their lowest need. Press F to follow them on the street."
	column.add_child(card)
	var card_row: HBoxContainer = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 10)
	card.add_child(card_row)
	_portrait = Control.new()
	_portrait.custom_minimum_size = Vector2(60, 60)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.draw.connect(_draw_portrait)
	card_row.add_child(_portrait)
	var about: VBoxContainer = VBoxContainer.new()
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about.add_theme_constant_override("separation", 1)
	card_row.add_child(about)
	_selected_label = RichTextLabel.new()
	_selected_label.bbcode_enabled = true
	_selected_label.fit_content = true
	_selected_label.scroll_active = false
	_selected_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_selected_label.clip_contents = true
	_selected_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selected_label.add_theme_font_size_override("normal_font_size", 12)
	_selected_label.add_theme_font_size_override("bold_font_size", 17)
	about.add_child(_selected_label)
	var mood: HBoxContainer = HBoxContainer.new()
	mood.add_theme_constant_override("separation", 5)
	about.add_child(mood)
	_mood_face = Control.new()
	_mood_face.custom_minimum_size = Vector2(16, 16)
	_mood_face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mood_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mood_face.draw.connect(func() -> void: HudArt.face(_mood_face, _mood_face.size / 2.0, 7.0, _shown_face, true))
	mood.add_child(_mood_face)
	_mood_label = Label.new()
	_mood_label.add_theme_font_size_override("font_size", 13)
	mood.add_child(_mood_label)
	_activity_label = Label.new()
	_activity_label.clip_text = true
	_activity_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_activity_label.add_theme_font_size_override("font_size", 12)
	_activity_label.add_theme_color_override("font_color", TEAL)
	about.add_child(_activity_label)

	for need_name: String in Records.NEED_NAMES:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.tooltip_text = NEED_TIPS[need_name] + "\nBelow %d%% a warning mark shows beside the bar." % NEED_LOW_PERCENT
		var icon: Control = Control.new()
		icon.custom_minimum_size = Vector2(16, 16)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.draw.connect(func() -> void: HudArt.need_icon(icon, icon.size / 2.0, need_name, TEAL, PAPER))
		row.add_child(icon)
		var label: Label = Label.new()
		label.text = NEED_LABELS[need_name]
		label.custom_minimum_size = Vector2(62, 0)
		label.add_theme_font_size_override("font_size", 13)
		row.add_child(label)
		var bar: ProgressBar = ProgressBar.new()
		bar.max_value = Records.NEED_MAX
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(0, 11)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bar)
		# A small warning mark when the need runs low, so it reads without the
		# bar's colour. Its space is always kept, so the row never shifts.
		var warn: Control = Control.new()
		warn.custom_minimum_size = Vector2(13, 13)
		warn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		warn.visible = true
		warn.set_meta("low", false)
		warn.draw.connect(func() -> void: _draw_need_warning(warn))
		row.add_child(warn)
		_need_warnings[need_name] = warn
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
	_money_label.add_theme_font_size_override("normal_font_size", 12)
	_money_label.add_theme_font_size_override("bold_font_size", 12)
	_money_label.tooltip_text = "Money the household has now and the meals in its pantry.\nRent is taken on Monday; wages for the days worked are paid on Friday."
	column.add_child(_money_label)
	_ledger = Control.new()
	_ledger.custom_minimum_size = Vector2(0, 54)
	_ledger.tooltip_text = "Money in and out since Monday, counted from the week's events.\n\"This week\" in the top bar has the whole story."
	_ledger.draw.connect(_draw_ledger)
	column.add_child(_ledger)

	column.add_child(HSeparator.new())
	var neighbors_title: HBoxContainer = HBoxContainer.new()
	column.add_child(neighbors_title)
	neighbors_title.add_child(_heading("Neighbors"))
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	neighbors_title.add_child(gap)
	var key: Label = _caption("bars: yours, then theirs")
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key.mouse_filter = Control.MOUSE_FILTER_STOP
	key.tooltip_text = "Each neighbor has two small bars: what your selected person thinks of them (top)\nand what they think back (bottom). A bar grows right, pointed, for warm; left for cool.\nAfter a talk a small chevron shows which way your person's regard moved."
	neighbors_title.add_child(key)
	# The list scrolls, so a long street never pushes anything off the panel.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_neighbor_scroll = scroll
	_neighbor_list = VBoxContainer.new()
	_neighbor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_neighbor_list.add_theme_constant_override("separation", 1)
	scroll.add_child(_neighbor_list)
	for person_id: String in simulation.state.sorted_person_ids():
		if _player_ids.has(person_id):
			continue
		var person: Dictionary = simulation.state.people[person_id]
		if simulation.world["schedules"][person["schedule_id"]].get("housebound", false):
			continue
		_neighbor_list.add_child(_neighbor_row(person_id))
		_neighbor_order.append(person_id)
	_restripe_neighbors()


## One row of the neighbors list: name, a word for how they stand, a small
## meter of regard each way, and a Talk button.
func _neighbor_row(person_id: String) -> PanelContainer:
	var person: Dictionary = simulation.state.people[person_id]
	var shaded: PanelContainer = PanelContainer.new()
	shaded.mouse_filter = Control.MOUSE_FILTER_PASS
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	shaded.add_child(row)
	# The name is a link: it finds the neighbor on the street.
	var name: Label = Label.new()
	name.text = person["given_name"]
	name.custom_minimum_size = Vector2(NEIGHBOR_NAME_WIDTH, 0)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.add_theme_font_size_override("font_size", 12)
	name.mouse_filter = Control.MOUSE_FILTER_STOP
	name.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	name.tooltip_text = "Find %s on the street" % person["given_name"]
	name.mouse_entered.connect(func() -> void: name.set_meta("hover", true); name.queue_redraw())
	name.mouse_exited.connect(func() -> void: name.set_meta("hover", false); name.queue_redraw())
	name.draw.connect(func() -> void: _draw_link_underline(name))
	name.gui_input.connect(func(event: InputEvent) -> void:
		if _is_left_click(event):
			focus_requested.emit("person", person_id)
			name.accept_event())
	row.add_child(name)
	var word: Label = Label.new()
	word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	word.clip_text = true
	word.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	word.add_theme_font_size_override("font_size", 11)
	row.add_child(word)
	var meter: Control = Control.new()
	meter.custom_minimum_size = Vector2(METER_WIDTH + METER_MARK_WIDTH, 9)
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(meter)
	var talk: Button = Button.new()
	talk.theme_type_variation = "RowButton"
	talk.text = "Talk"
	talk.focus_mode = Control.FOCUS_NONE
	talk.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	talk.pressed.connect(func() -> void: _talk_pressed(person_id))
	row.add_child(talk)
	var entry: Dictionary = {
		"panel": shaded, "name": name, "word": word, "meter": meter, "mine": 0, "theirs": 0, "met": false, "talks": -1,
		"week_talks": -1, "talk": talk, "talk_tip": "", "viewer": "", "change": 0, "change_ms": 0,
	}
	meter.draw.connect(func() -> void: _draw_meter(meter, entry))
	_neighbor_rows[person_id] = entry
	return shaded


## The two regard bars, with shape cues that do not rely on colour: each bar
## ends in a small point showing which way it grows (right warm, left cool),
## and for a while after a talk an up or down chevron at the left shows which
## way the selected person's regard just moved.
func _draw_meter(meter: Control, entry: Dictionary) -> void:
	var rect: Rect2 = Rect2(Vector2(METER_MARK_WIDTH, 0), Vector2(METER_WIDTH, meter.size.y))
	HudArt.regard_meter(meter, rect, entry["mine"], entry["theirs"], entry["met"], REGARD_METER_SPAN)
	if entry["met"]:
		var middle: float = rect.position.x + rect.size.x / 2.0
		var half: float = rect.size.x / 2.0
		var row_h: float = (rect.size.y - 1.0) / 2.0
		var index: int = 0
		for value: int in [entry["mine"], entry["theirs"]]:
			if value != 0:
				var length: float = clampf(float(absi(value)) / float(REGARD_METER_SPAN), 0.0, 1.0) * half
				var y: float = rect.position.y + float(index) * (row_h + 1.0)
				var tip: float = middle + (length if value > 0 else -length)
				var out: float = 1.0 if value > 0 else -1.0
				var point: float = clampf(tip + out * 2.5, rect.position.x, rect.end.x)
				meter.draw_colored_polygon(PackedVector2Array([
					Vector2(tip, y - 0.5), Vector2(point, y + row_h / 2.0), Vector2(tip, y + row_h + 0.5),
				]), INK if value > 0 else CHERRY.darkened(0.3))
			index += 1
	var change: int = entry["change"]
	if change != 0:
		var c: Vector2 = Vector2(METER_MARK_WIDTH / 2.0 - 1.0, meter.size.y / 2.0)
		var color: Color = LEAF.darkened(0.25) if change > 0 else CHERRY
		var d: float = -1.0 if change > 0 else 1.0
		meter.draw_colored_polygon(PackedVector2Array([
			c + Vector2(-3.5, -d * 2.0), c + Vector2(0, d * 2.5), c + Vector2(3.5, -d * 2.0),
		]), color)


## Under a link's text while the pointer is on it.
func _draw_link_underline(label: Label) -> void:
	if not label.get_meta("hover", false):
		return
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var width: float = minf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, label.size.x)
	var y: float = roundf((label.size.y + font.get_height(font_size)) / 2.0) - 1.0
	label.draw_line(Vector2(0, y), Vector2(width, y), Color(TEAL, 0.8), 1.0)


static func _is_left_click(event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false
	var click: InputEventMouseButton = event
	return click.button_index == MOUSE_BUTTON_LEFT and not click.pressed


func _restripe_neighbors() -> void:
	for index: int in _neighbor_order.size():
		var person_id: String = _neighbor_order[index]
		var variation: String = "RowA" if index % 2 == 0 else "RowB"
		(_neighbor_rows[person_id]["panel"] as PanelContainer).theme_type_variation = "RowHover" if person_id == _hover_neighbor else variation


## Once the panel is laid out, makes the neighbors list exactly as tall as a
## whole number of rows, so it ends cleanly at the panel's foot; the rest
## scroll. The few pixels left over go below the list.
func _fit_neighbor_list() -> void:
	# When the money lines above change height (a third line with Large text),
	# the list is fitted again to the room left.
	if _money_label.size.y != _money_height:
		_money_height = _money_label.size.y
		_refit_neighbors()
	if _refit_wait > 0:
		_refit_wait -= 1
		return
	if _neighbor_rows_fitted or _neighbor_order.is_empty():
		return
	var first: Control = _neighbor_rows[_neighbor_order[0]]["panel"]
	var room: float = _neighbor_scroll.size.y
	if first.size.y <= 0.0 or room <= first.size.y:
		return
	_neighbor_rows_fitted = true
	var pitch: float = first.size.y + float(_neighbor_list.get_theme_constant("separation"))
	var fits: int = floori((room + float(_neighbor_list.get_theme_constant("separation"))) / pitch)
	if fits >= _neighbor_order.size():
		return
	_neighbor_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_neighbor_scroll.custom_minimum_size.y = fits * pitch - float(_neighbor_list.get_theme_constant("separation"))
	_neighbor_scroll.get_v_scroll_bar().custom_step = pitch


## Lights the neighbor row under the pointer. Worked out from the pointer's
## position, so it is right while the list scrolls or re-sorts.
func _refresh_neighbor_hover() -> void:
	var pointer: Vector2 = get_global_mouse_position()
	var over: String = ""
	if not _sheet_open and _neighbor_scroll.get_global_rect().has_point(pointer):
		for person_id: String in _neighbor_rows:
			if (_neighbor_rows[person_id]["panel"] as Control).get_global_rect().has_point(pointer):
				over = person_id
				break
	if over != _hover_neighbor:
		_hover_neighbor = over
		_restripe_neighbors()


## Talk needs one of the player's household selected and the neighbor on the
## street; otherwise the button is greyed and its tooltip says why.
func _refresh_talk_buttons(selected_id: String) -> void:
	var can_order: bool = _player_ids.has(selected_id)
	var selected_name: String = simulation.state.people[selected_id]["given_name"]
	for other_id: String in _neighbor_rows:
		var entry: Dictionary = _neighbor_rows[other_id]
		var other: Dictionary = simulation.state.people[other_id]
		var tip: String = "Send %s to talk to %s" % [selected_name, other["given_name"]]
		var allowed: bool = true
		if not can_order:
			tip = "Select one of your household first (the tabs above, or click them on the street)"
			allowed = false
		elif other["at"] == Records.AT_OFFMAP:
			tip = "%s is away from the street just now" % other["given_name"]
			allowed = false
		if tip != entry["talk_tip"]:
			entry["talk_tip"] = tip
			var talk: Button = entry["talk"]
			talk.tooltip_text = tip
			talk.disabled = not allowed


## A tab clicked while its member is already selected finds them on the street.
func _tab_pressed(person_id: String) -> void:
	if person_id == _tab_selected:
		focus_requested.emit("person", person_id)
	person_chosen.emit(person_id)


func _draw_tab_face(face_control: Control, person_id: String) -> void:
	var person: Dictionary = simulation.state.people[person_id]
	var child: bool = SimDate.age_on(person["birth_day"], simulation.clock.day_index) < WorldView.CHILD_AGE
	HudArt.portrait(face_control, Rect2(Vector2.ZERO, face_control.size), person_id, true, child, Describe.mood(person)["face"])


## Tabs: the selected one is lit and carries a tiny portrait; each tab's
## tooltip says who it is and what they are doing.
func _refresh_tabs(selected_id: String) -> void:
	for person_id: String in _member_buttons:
		var button: Button = _member_buttons[person_id]
		var person: Dictionary = simulation.state.people[person_id]
		var chosen: bool = person_id == selected_id
		button.set_pressed_no_signal(chosen)
		var tip: String = "%s %s, age %d: %s.%s" % [
			person["given_name"], person["family_name"], SimDate.age_on(person["birth_day"], simulation.clock.day_index),
			Describe.activity(simulation, person),
			"\nClick again to find them on the street." if chosen else "\nClick to select.  (Tab and Shift+Tab move between family members.)",
		]
		if tip != _member_tips.get(person_id, ""):
			_member_tips[person_id] = tip
			button.tooltip_text = tip
		(_member_faces[person_id] as Control).position.y = maxf(roundf((button.size.y - TAB_FACE) / 2.0) - 1.0, 1.0)
	var face_kind: String = Describe.mood(simulation.state.people[selected_id])["face"] if _member_faces.has(selected_id) else ""
	if selected_id == _tab_selected and face_kind == _tab_face_kind:
		return
	_tab_selected = selected_id
	_tab_face_kind = face_kind
	for person_id: String in _member_buttons:
		var chosen: bool = person_id == selected_id
		var button: Button = _member_buttons[person_id]
		var given: String = simulation.state.people[person_id]["given_name"]
		button.text = TAB_FACE_PAD + given if chosen else given
		var face_control: Control = _member_faces[person_id]
		face_control.visible = chosen
		face_control.queue_redraw()


func _build_feed() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(20, 512)
	panel.custom_minimum_size = Vector2(880, 193)
	add_child(panel)
	_feed_panel = panel
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	panel.add_child(column)
	# The heading, with the filter tabs on the same line to save height.
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	column.add_child(head)
	head.add_child(_heading("What has happened"))
	var filler: Control = Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(filler)
	var group: ButtonGroup = ButtonGroup.new()
	for entry: Array in FEED_FILTERS:
		var tab: Button = Button.new()
		tab.theme_type_variation = "FeedTab"
		tab.text = entry[1]
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = entry[0] == _feed_filter
		tab.focus_mode = Control.FOCUS_NONE
		tab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.tooltip_text = entry[2]
		var filter_id: String = entry[0]
		tab.pressed.connect(func() -> void: set_feed_filter(filter_id))
		head.add_child(tab)
		_feed_tabs[filter_id] = tab
	_feed_empty = Label.new()
	_feed_empty.text = FEED_EMPTY_TEXT["all"]
	_feed_empty.add_theme_color_override("font_color", INK_SOFT)
	_feed_empty.add_theme_font_size_override("font_size", 13)
	column.add_child(_feed_empty)
	_chevron_up = _chevron_texture(true)
	_chevron_down = _chevron_texture(false)
	for index: int in FEED_LINES:
		var row: Control = Control.new()
		row.custom_minimum_size = Vector2(0, FEED_ROW_HEIGHT)
		row.clip_contents = true
		# A line is a link to where it happened; its tooltip also shows the full
		# text when the line is cut short. A "more" line opens its group.
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var text: RichTextLabel = RichTextLabel.new()
		text.bbcode_enabled = true
		text.scroll_active = false
		text.autowrap_mode = TextServer.AUTOWRAP_OFF
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.position = Vector2(26, 1)
		text.size = Vector2(820, FEED_ROW_HEIGHT)
		text.add_theme_font_size_override("normal_font_size", 13)
		text.add_theme_font_size_override("bold_font_size", 13)
		text.add_theme_font_size_override("italics_font_size", 12)
		row.add_child(text)
		var entry: Dictionary = {"row": row, "text": text, "key": "", "item": {}, "kind": "", "slide": 0.0, "glow": 0.0, "hover": false}
		row.draw.connect(func() -> void: _draw_feed_row(entry))
		row.mouse_entered.connect(func() -> void: entry["hover"] = true; row.queue_redraw())
		row.mouse_exited.connect(func() -> void: entry["hover"] = false; row.queue_redraw())
		row.gui_input.connect(func(event: InputEvent) -> void:
			if _is_left_click(event):
				click_feed_line(index)
				row.accept_event())
		column.add_child(row)
		_feed_rows.append(entry)


## A small arrow drawn into an image at start-up (no image files), for the
## feed's regard changes: up for warmer, down for cooler. The shape carries
## the meaning; the colour only repeats it.
func _chevron_texture(up: bool) -> ImageTexture:
	var w: int = 9
	var h: int = 9
	var image: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var color: Color = LEAF.darkened(0.25) if up else CHERRY
	for y: int in h:
		for x: int in w:
			# A solid triangle, its point up or down, a pixel short of the edges.
			var row: float = float(y) + 0.5 if up else float(h - 1 - y) + 0.5
			var half: float = (row - 1.0) * 0.5
			var inside: bool = row >= 1.0 and row <= float(h) - 1.0 and absf(float(x) + 0.5 - float(w) / 2.0) <= half + 0.5
			image.set_pixel(x, y, color if inside else Color(color, 0.0))
	return ImageTexture.create_from_image(image)


## Shows one filter of the feed: "all", "household", "money" or "neighbors".
func set_feed_filter(filter_id: String) -> void:
	if not _feed_tabs.has(filter_id):
		return
	_feed_filter = filter_id
	for tab_id: String in _feed_tabs:
		(_feed_tabs[tab_id] as Button).set_pressed_no_signal(tab_id == filter_id)
	_feed_empty.text = FEED_EMPTY_TEXT[filter_id]
	_feed_cache_key = ""


func feed_filter() -> String:
	return _feed_filter


## The kinds of the feed's lines as shown, top first ("event", "more" or
## "less"); for the self-check.
func feed_line_kinds() -> Array[String]:
	_refresh_feed()
	var kinds: Array[String] = []
	for item: Dictionary in _feed_shown:
		kinds.append(str(item["kind"]))
	return kinds


## Fewer, taller lines with Large text, so the feed still fits its panel.
func _apply_feed_size() -> void:
	_feed_slots = FEED_LINES_LARGE if _large_text else FEED_LINES
	var height: int = FEED_ROW_HEIGHT_LARGE if _large_text else FEED_ROW_HEIGHT
	for entry: Dictionary in _feed_rows:
		(entry["row"] as Control).custom_minimum_size.y = height
		(entry["text"] as RichTextLabel).size.y = height
		entry["key"] = ""
	_feed_cache_key = ""


func _draw_feed_row(entry: Dictionary) -> void:
	var row: Control = entry["row"]
	var item: Dictionary = entry["item"]
	if item.is_empty():
		return
	var glow: float = entry["glow"]
	if glow > 0.0:
		row.draw_rect(Rect2(Vector2(entry["slide"], 0), Vector2(row.size.x, row.size.y - 1)), Color(MUSTARD, 0.30 * glow))
	if item.get("member", false):
		# A line inside an opened group: a thin rule down its left side.
		row.draw_line(Vector2(2, 1), Vector2(2, row.size.y - 1), Color(TEAL, 0.45), 2.0)
	var middle: Vector2 = Vector2(11.0 + float(entry["slide"]), row.size.y / 2.0)
	if item["kind"] != "event":
		if entry["hover"]:
			row.draw_rect(Rect2(Vector2.ZERO, Vector2(row.size.x, row.size.y - 1)), FEED_HOVER)
		# A round button with a plus (show more) or a minus (show fewer).
		row.draw_circle(middle, 7.0, Color(TEAL, 0.14))
		row.draw_arc(middle, 7.0, 0.0, TAU, 20, Color(TEAL, 0.7), 1.2, true)
		row.draw_line(middle + Vector2(-3.5, 0), middle + Vector2(3.5, 0), TEAL, 1.6)
		if item["kind"] == "more":
			row.draw_line(middle + Vector2(0, -3.5), middle + Vector2(0, 3.5), TEAL, 1.6)
		return
	if entry["hover"]:
		row.draw_rect(Rect2(Vector2.ZERO, Vector2(row.size.x, row.size.y - 1)), FEED_HOVER)
		var text: RichTextLabel = entry["text"]
		var right: float = minf(text.position.x + float(text.get_content_width()), row.size.x - 28.0)
		row.draw_line(Vector2(text.position.x, row.size.y - 2.5), Vector2(right, row.size.y - 2.5), Color(TEAL, 0.55), 1.0)
		# A small "find it" target at the end of the line.
		var at: Vector2 = Vector2(row.size.x - 12.0, row.size.y / 2.0)
		row.draw_arc(at, 5.0, 0.0, TAU, 16, TEAL, 1.5, true)
		row.draw_circle(at, 1.6, TEAL)
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			row.draw_line(at + direction * 6.0, at + direction * 8.5, TEAL, 1.5)
	HudArt.event_icon(row, middle, entry["kind"], 8.0)


## A click on a feed line (0 is the top one): an event line finds where it
## happened; a "more" or "fewer" line opens or closes its group.
func click_feed_line(slot: int) -> void:
	if slot < 0 or slot >= _feed_rows.size():
		return
	var item: Dictionary = _feed_rows[slot]["item"]
	if item.is_empty():
		return
	if item["kind"] == "event":
		focus_feed_line(slot)
		return
	if item["kind"] == "more":
		_feed_expanded[item["group"]] = true
	else:
		_feed_expanded.erase(item["group"])
	_feed_cache_key = ""


## Asks main.gd to show where the feed's line (0 is the top one) happened.
## Returns false if there is no such line or nothing to show.
func focus_feed_line(slot: int) -> bool:
	if slot < 0 or slot >= _feed_rows.size():
		return false
	var item: Dictionary = _feed_rows[slot]["item"]
	if item.is_empty() or item["kind"] != "event":
		return false
	var target: Array = event_target(item["event"])
	if target.is_empty():
		return false
	focus_requested.emit(target[0], target[1])
	return true


## Whether an event belongs in the feed under the filter chosen.
func _feed_matches(event: Dictionary) -> bool:
	match _feed_filter:
		"household":
			return _involves_household(event)
		"money":
			return MONEY_EVENTS.has(event["type"])
		"neighbors":
			if event["type"] != "conversation":
				return false
			return not (_player_ids.has(event["a"]) and _player_ids.has(event["b"]))
	return true


func _involves_household(event: Dictionary) -> bool:
	if event["type"] == "conversation":
		return _player_ids.has(event["a"]) or _player_ids.has(event["b"])
	if event.has("household_id"):
		return simulation.state.households[event["household_id"]]["player_controlled"]
	return _player_ids.has(event.get("person_id", ""))


## Which events may be folded together: those of the same key. News for the
## player's own household is never folded away.
func _collapse_key(event: Dictionary) -> String:
	if _involves_household(event):
		return ""
	if FEED_NOUNS.has(event["type"]):
		return event["type"]
	return ""


static func _event_minute(event: Dictionary) -> int:
	return int(event["day"]) * 1440 + int(event["minute"])


## The feed's lines, top first: events, and for a run of similar events close
## together, the newest with a "N more" line standing for the rest (or, once
## opened, all of them and a "show fewer" line). Groups are named by their
## oldest event, which stays the same as newer ones join.
func _feed_items() -> Array[Dictionary]:
	var log: Array = simulation.state.event_log
	var items: Array[Dictionary] = []
	var index: int = log.size() - 1
	while index >= 0 and items.size() < _feed_slots:
		var event: Dictionary = log[index]
		index -= 1
		if not _feed_matches(event):
			continue
		items.append({"kind": "event", "event": event, "key": "e%d" % event["id"]})
		var key: String = _collapse_key(event)
		if key == "":
			continue
		var group: Array[Dictionary] = []
		var last: int = _event_minute(event)
		var scan: int = index
		while scan >= 0:
			var other: Dictionary = log[scan]
			if not _feed_matches(other):
				scan -= 1
				continue
			if _collapse_key(other) != key or last - _event_minute(other) > FEED_GROUP_MINUTES:
				break
			group.append(other)
			last = _event_minute(other)
			scan -= 1
		if group.size() < FEED_COLLAPSE_AT:
			continue
		index = scan
		var group_id: String = "g%d" % group[group.size() - 1]["id"]
		if _feed_expanded.has(group_id):
			items[items.size() - 1]["member"] = true
			for other: Dictionary in group:
				if items.size() >= _feed_slots:
					break
				items.append({"kind": "event", "event": other, "key": "e%d" % other["id"], "member": true})
			if items.size() < _feed_slots:
				items.append({"kind": "less", "group": group_id, "key": "l" + group_id, "member": true})
		else:
			var noun: Array = FEED_NOUNS[key]
			items.append({"kind": "more", "group": group_id, "key": "m%s_%d" % [group_id, group.size()],
					"text": "%d more %s close together" % [group.size(), noun[0] if group.size() == 1 else noun[1]]})
	return items


## What to show on the street for an event: ["person", id] or
## ["building", id], or [] if there is nothing to show. A conversation shows
## the player's own household member if one took part; money news shows the
## household's home, and shopping the store.
func event_target(event: Dictionary) -> Array:
	match event["type"]:
		"conversation":
			var who: String = event["b"] if _player_ids.has(event["b"]) and not _player_ids.has(event["a"]) else event["a"]
			return ["person", who]
		"birthday", "missed_work":
			return ["person", event["person_id"]]
		"order_failed":
			if event.get("reason", "") == "closed" and event.has("place_id"):
				return ["building", event["place_id"]]
			return ["person", event["person_id"]]
		"shopping":
			var store: String = simulation.area.institution_of_kind("store")
			return ["building", store] if store != "" else ["person", event["person_id"]]
		"payday", "rent_paid", "empty_pantry", "household_short_of_money":
			return ["building", simulation.state.households[event["household_id"]]["home_id"]]
	if event.has("person_id"):
		return ["person", event["person_id"]]
	return []


## A small card under the home cutaway listing this week's things to try.
## Rows are drawn by hand so seven fit in the space; each has the goal's hint
## as its tooltip.
func _build_goals() -> void:
	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = "GoalsCard"
	card.position = GOALS_RECT.position
	card.custom_minimum_size = GOALS_RECT.size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var heading: Label = _caption("THINGS TO TRY THIS WEEK")
	heading.add_theme_color_override("font_color", TEAL)
	column.add_child(heading)
	for index: int in GOAL_ROWS:
		var row: Control = Control.new()
		row.custom_minimum_size = Vector2(0, GOAL_ROW_HEIGHT)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.draw.connect(func() -> void: _draw_goal(row, index))
		column.add_child(row)
		_goal_rows.append(row)


## Takes the goals for the week being played (worked out in main.gd). A goal
## that turns done while shown gets a short shine.
func show_goals(goals: Array) -> void:
	if goals == _goals:
		return
	var same_week: bool = _goals.size() == goals.size()
	for index: int in mini(_goals.size(), goals.size()):
		same_week = same_week and _goals[index]["id"] == goals[index]["id"]
	if not same_week:
		_goal_seen.clear()
		_goal_shine.clear()
	var now: int = Time.get_ticks_msec()
	for goal: Dictionary in goals:
		var before: String = _goal_seen.get(goal["id"], "")
		if before != "" and before != "done" and goal["status"] == "done":
			_goal_shine[goal["id"]] = now
		_goal_seen[goal["id"]] = goal["status"]
	_goals = goals
	for index: int in _goal_rows.size():
		var row: Control = _goal_rows[index]
		row.visible = index < goals.size()
		row.tooltip_text = goals[index]["hint"] if index < goals.size() else ""
		row.queue_redraw()


## Draws one line of text, ending in an ellipsis if it is wider than width.
static func _draw_fitted(canvas: CanvasItem, font: Font, baseline_at: Vector2, text: String, width: float, font_size: int, color: Color) -> void:
	var line: TextLine = TextLine.new()
	line.add_string(text, font, font_size)
	line.width = maxf(width, 1.0)
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.draw(canvas.get_canvas_item(), baseline_at - Vector2(0, line.get_line_ascent()), color)


func _draw_goal(row: Control, index: int) -> void:
	if index >= _goals.size():
		return
	var goal: Dictionary = _goals[index]
	var status: String = goal["status"]
	var font: Font = row.get_theme_default_font()
	var middle: float = row.size.y / 2.0 - 1.0
	var shine: float = -1.0
	if _goal_shine.has(goal["id"]):
		shine = float(Time.get_ticks_msec() - int(_goal_shine[goal["id"]])) / float(GOAL_SHINE_MS)
	if shine >= 0.0 and shine < 1.0:
		row.draw_rect(Rect2(Vector2(-4, 0), Vector2(row.size.x + 8, row.size.y)), Color(MUSTARD, 0.35 * (1.0 - shine)))
	var box: Rect2 = Rect2(1, middle - 5, 10, 10)
	HudArt.goal_box(row, box, status)
	var color: Color = INK
	if status == "done":
		color = INK_SOFT
	elif status == "missed":
		color = CHERRY
	var baseline: float = middle + GOAL_FONT_SIZE * 0.35
	var multi: bool = int(goal["target"]) > 1
	var title_width: float = row.size.x - 17.0 - (GOAL_METER_WIDTH + GOAL_COUNT_WIDTH + 8.0 if multi else 2.0)
	_draw_fitted(row, font, Vector2(17, baseline), goal["title"], title_width, GOAL_FONT_SIZE, color)
	if multi:
		# A small rounded bar with the count beside it: "3/5".
		var count: String = "%d/%d" % [goal["progress"], goal["target"]]
		row.draw_string(font, Vector2(row.size.x - GOAL_COUNT_WIDTH, baseline), count, HORIZONTAL_ALIGNMENT_RIGHT,
				GOAL_COUNT_WIDTH, GOAL_FONT_SIZE - 1, INK_SOFT if status == "done" else TEAL)
		var track: Rect2 = Rect2(row.size.x - GOAL_COUNT_WIDTH - GOAL_METER_WIDTH - 4.0, middle - 2.5, GOAL_METER_WIDTH, 6.0)
		var share: float = clampf(float(goal["progress"]) / float(goal["target"]), 0.0, 1.0)
		row.draw_style_box(_goal_track, track)
		if share > 0.0:
			var filled: Rect2 = Rect2(track.position, Vector2(maxf(track.size.x * share, track.size.y), track.size.y))
			row.draw_style_box(_goal_fill_done if status == "done" else _goal_fill, filled)
	if shine >= 0.0 and shine < 1.0:
		# A bright band sweeps across the row, and a small star by the box.
		var x: float = lerpf(-30.0, row.size.x + 30.0, shine)
		row.draw_colored_polygon(PackedVector2Array([
			Vector2(x - 8, row.size.y), Vector2(x + 4, 0), Vector2(x + 16, 0), Vector2(x + 4, row.size.y),
		]), Color(1, 1, 1, 0.55 * (1.0 - shine)))
		var grow: float = sin(shine * PI)
		row.draw_colored_polygon(HudArt.star(box.get_center() + Vector2(-1, 0), 9.0 * grow, 3.5 * grow), Color(MUSTARD, 0.8 * (1.0 - shine)))
		HudArt.goal_box(row, box, status)


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
	_sheet_dim = dim

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
	# Holds a drawn page in place of the text, such as the week's paper.
	_sheet_content = VBoxContainer.new()
	_sheet_content.visible = false
	column.add_child(_sheet_content)
	_sheet_buttons = HBoxContainer.new()
	_sheet_buttons.alignment = BoxContainer.ALIGNMENT_END
	_sheet_buttons.add_theme_constant_override("separation", 10)
	column.add_child(_sheet_buttons)


## Shows the sheet. actions is a list of [label, Callable] or
## [label, Callable, tooltip] for extra buttons;
## a button to close the sheet is always added.
## content, if given, is shown in place of the text.
func show_sheet(title: String, text: String, actions: Array = [], close_label: String = "Continue", content: Control = null) -> void:
	_sheet_title.text = title
	_sheet_text.text = text
	for child: Node in _sheet_content.get_children():
		_sheet_content.remove_child(child)
		child.queue_free()
	if content != null:
		_sheet_content.add_child(content)
		if _large_text:
			TextSize.scale_overrides(content, TextSize.factor(true))
	_sheet_content.visible = content != null
	_sheet_text.visible = content == null
	for child: Node in _sheet_buttons.get_children():
		_sheet_buttons.remove_child(child)
		child.queue_free()
	for action: Array in actions:
		var action_button: Button = _button(action[0], action[1])
		if action.size() > 2:
			action_button.tooltip_text = action[2]
		_sheet_buttons.add_child(action_button)
	var close: Button = _button(close_label, close_sheet)
	close.tooltip_text = "Esc"
	_sheet_buttons.add_child(close)
	_fit_sheet()
	if not _sheet_open:
		_animate_sheet(true)
	_sheet_open = true


func close_sheet() -> void:
	if _sheet_open:
		_sheet_open = false
		_animate_sheet(false)
		sheet_closed.emit()


func sheet_is_open() -> bool:
	return _sheet_open


## Sizes the sheet to its text, up to a limit past which the text scrolls,
## and centres it on the screen, so a short note is not a tall empty card.
func _fit_sheet() -> void:
	# The text's width is fixed by the sheet's width less its side margins.
	_sheet_text.size.x = _sheet.custom_minimum_size.x - SHEET_SIDE_MARGINS
	var height: int = _sheet_text.get_content_height()
	_sheet_text.custom_minimum_size.y = clampi(height + 6, SHEET_TEXT_MIN_HEIGHT, SHEET_TEXT_MAX_HEIGHT)
	_sheet.reset_size()
	_sheet.position.y = roundf((SCREEN_HEIGHT - _sheet.size.y) / 2.0)
	_sheet.pivot_offset = _sheet.size / 2.0


## Sheets open with a short grow-and-fade and close with a fade. While one
## fades out it no longer blocks clicks.
func _animate_sheet(opening: bool) -> void:
	if _sheet_tween != null:
		_sheet_tween.kill()
	_sheet_layer.visible = true
	_sheet_dim.mouse_filter = Control.MOUSE_FILTER_STOP if opening else Control.MOUSE_FILTER_IGNORE
	_sheet.pivot_offset = _sheet.size / 2.0
	_sheet_tween = create_tween().set_parallel(true)
	if opening:
		_sheet_layer.modulate.a = 0.0
		_sheet.scale = Vector2(0.94, 0.94)
		_sheet_tween.tween_property(_sheet_layer, "modulate:a", 1.0, SHEET_OPEN_SECONDS)
		_sheet_tween.tween_property(_sheet, "scale", Vector2.ONE, SHEET_OPEN_SECONDS) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_sheet_tween.tween_property(_sheet_layer, "modulate:a", 0.0, SHEET_CLOSE_SECONDS)
		_sheet_tween.chain().tween_callback(func() -> void: _sheet_layer.visible = false)


func _button(text: String, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(on_press)
	return button


func _toggle(text: String, on_change: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_pressed = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
	_refresh_speed(speed_index)
	_show_paused(speed_index == 0)
	_music_button.set_pressed_no_signal(music_on)
	_music_button.text = "Music on" if music_on else "Music off"
	_sound_button.set_pressed_no_signal(sound_on)
	_sound_button.text = "Sounds on" if sound_on else "Sounds off"
	_refresh_tabs(selected_id)
	tips.set_blocked(_sheet_open)

	_refresh_person(selected_id)
	_refresh_money()
	_refresh_neighbors(selected_id)
	_refresh_talk_buttons(selected_id)
	_refresh_neighbor_hover()
	_fit_neighbor_list()
	_refresh_feed()
	_refresh_goal_shine()


## Seconds of real time since the last refresh, for the small animations.
func _tick_seconds() -> float:
	var now: int = Time.get_ticks_msec()
	var seconds: float = 0.0 if _last_tick_ms < 0 else float(now - _last_tick_ms) / 1000.0
	_last_tick_ms = now
	return minf(seconds, 0.25)


func _refresh_person(selected_id: String) -> void:
	var person: Dictionary = simulation.state.people[selected_id]
	var age: int = SimDate.age_on(person["birth_day"], simulation.clock.day_index)
	var traits: String = ", ".join(person["traits"]) if not person["traits"].is_empty() else "no marked traits"
	_selected_label.text = "[b]%s %s[/b]\n[color=%s]age %d, %s[/color]" % [
		person["given_name"], person["family_name"], _hex(INK_SOFT), age, traits,
	]
	var mood: Dictionary = Describe.mood(person)
	_mood_label.text = mood["word"]
	_mood_label.add_theme_color_override("font_color", CHERRY if mood["face"] == "low" else INK)
	_activity_label.text = Describe.activity(simulation, person)
	if selected_id != _shown_person or mood["face"] != _shown_face:
		_shown_person = selected_id
		_shown_face = mood["face"]
		_portrait.queue_redraw()
		_mood_face.queue_redraw()

	# Bars glide toward the person's levels rather than jumping; the very
	# first refresh shows the levels as they are.
	var seconds: float = _tick_seconds()
	var blend: float = 1.0 if _need_shown.is_empty() else 1.0 - exp(-NEED_GLIDE_RATE * seconds)
	for need_name: String in Records.NEED_NAMES:
		var level: int = person["needs"][need_name]
		var shown: float = lerpf(float(_need_shown.get(need_name, level)), float(level), blend)
		if absf(shown - float(level)) < 50.0:
			shown = float(level)
		_need_shown[need_name] = shown
		@warning_ignore("integer_division")
		var percent: int = level * 100 / Records.NEED_MAX
		var bar: ProgressBar = _need_bars[need_name]
		bar.value = shown
		var fill: StyleBoxFlat = _need_fills[0]
		if percent < NEED_LOW_PERCENT:
			fill = _need_fills[2]
		elif percent <= NEED_GOOD_PERCENT:
			fill = _need_fills[1]
		bar.add_theme_stylebox_override("fill", fill)
		(_need_values[need_name] as Label).text = "%d%%" % percent
		var warn: Control = _need_warnings[need_name]
		var low: bool = percent < NEED_LOW_PERCENT
		if bool(warn.get_meta("low")) != low:
			warn.set_meta("low", low)
			warn.queue_redraw()


## A little warning triangle with an exclamation mark, drawn when low.
func _draw_need_warning(warn: Control) -> void:
	if not bool(warn.get_meta("low")):
		return
	var w: float = warn.size.x
	var h: float = warn.size.y
	var points: PackedVector2Array = PackedVector2Array([Vector2(w / 2.0, 0.5), Vector2(w - 0.5, h - 0.5), Vector2(0.5, h - 0.5)])
	warn.draw_colored_polygon(points, CHERRY)
	warn.draw_line(Vector2(w / 2.0, 4.0), Vector2(w / 2.0, h - 4.5), PAPER, 1.6)
	warn.draw_circle(Vector2(w / 2.0, h - 2.6), 0.9, PAPER)


func _draw_portrait() -> void:
	if _shown_person == "":
		return
	var person: Dictionary = simulation.state.people[_shown_person]
	var players: bool = simulation.state.households[person["household_id"]]["player_controlled"]
	var child: bool = SimDate.age_on(person["birth_day"], simulation.clock.day_index) < WorldView.CHILD_AGE
	HudArt.portrait(_portrait, Rect2(Vector2.ZERO, _portrait.size), _shown_person, players, child, _shown_face)


## Words and meters for how the viewer stands with each neighbor; met
## neighbors first, warmest first, then those not yet met.
func _refresh_neighbors(selected_id: String) -> void:
	var viewer: String = selected_id if _player_ids.has(selected_id) else _player_ids[0]
	var viewer_name: String = simulation.state.people[viewer]["given_name"]
	var warmth: Dictionary = {}
	var now: int = Time.get_ticks_msec()
	var week_talks_by_pair: Dictionary = {}
	for pair: Dictionary in _week_summary.get("neighbors", []):
		week_talks_by_pair[str(pair["member_id"]) + "|" + str(pair["other_id"])] = int(pair["talks"])
	for other_id: String in _neighbor_rows:
		var entry: Dictionary = _neighbor_rows[other_id]
		var other: Dictionary = simulation.state.people[other_id]
		var key: String = Records.relationship_key(viewer, other_id)
		var met: bool = simulation.state.relationships.has(key)
		var mine: int = simulation.state.regard(viewer, other_id) if met else 0
		var theirs: int = simulation.state.regard(other_id, viewer) if met else 0
		var talks: int = int(simulation.state.relationships[key]["familiarity"]) if met else 0
		warmth[other_id] = mine + theirs
		var week_talks: int = week_talks_by_pair.get(viewer + "|" + other_id, 0)
		if entry["change"] != 0 and now - int(entry["change_ms"]) > METER_CHANGE_MS:
			entry["change"] = 0
			(entry["meter"] as Control).queue_redraw()
		if entry["viewer"] != viewer:
			# Another person selected: their regard is not a change.
			entry["viewer"] = viewer
			entry["change"] = 0
		elif met and entry["met"] and mine != entry["mine"]:
			entry["change"] = signi(mine - int(entry["mine"]))
			entry["change_ms"] = now
		if met == entry["met"] and mine == entry["mine"] and theirs == entry["theirs"] and talks == entry["talks"] and week_talks == entry["week_talks"]:
			continue
		entry["week_talks"] = week_talks
		entry["met"] = met
		entry["mine"] = mine
		entry["theirs"] = theirs
		entry["talks"] = talks
		var word: String = Describe.relationship_word(met, mine, theirs)
		var word_label: Label = entry["word"]
		word_label.text = word
		word_label.add_theme_color_override("font_color", WORD_COLORS[word])
		(entry["name"] as Label).add_theme_color_override("font_color", INK if met else INK_SOFT)
		var panel: PanelContainer = entry["panel"]
		if met:
			panel.tooltip_text = "%s and %s: %s.\n%s thinks %+d of %s; %s thinks %+d of %s.\n%d %s this week, %d in all." % [
				viewer_name, other["given_name"], word.to_lower() + ("s" if word == "Friend" or word == "Acquaintance" or word == "Stranger" else ""),
				viewer_name, mine, other["given_name"], other["given_name"], theirs, viewer_name,
				week_talks, "talk" if week_talks == 1 else "talks", talks,
			]
		else:
			panel.tooltip_text = "%s has not met %s yet.\nSend someone over with Talk to say hello." % [viewer_name, other["given_name"]]
		(entry["meter"] as Control).queue_redraw()
	var order: Array = _neighbor_rows.keys()
	order.sort_custom(func(a: String, b: String) -> bool:
		var met_a: bool = _neighbor_rows[a]["met"]
		var met_b: bool = _neighbor_rows[b]["met"]
		if met_a != met_b:
			return met_a
		if warmth[a] != warmth[b]:
			return warmth[a] > warmth[b]
		return a < b)
	if order != _neighbor_order:
		_neighbor_order = order
		for index: int in order.size():
			_neighbor_list.move_child(_neighbor_rows[order[index]]["panel"], index)
		_restripe_neighbors()


func _refresh_money() -> void:
	var household_id: String = simulation.state.player_household_id()
	var household: Dictionary = simulation.state.households[household_id]
	var owed: String = ""
	if household["rent_owed_cents"] != 0:
		owed = "  [color=%s][b]%s owed[/b][/color]" % [_hex(CHERRY), Describe.money(household["rent_owed_cents"])]
	_money_label.text = "In hand [b]%s[/b]     Pantry [b]%d meals[/b]\nRent [b]%s[/b] Mondays%s     Wages due Friday [b]%s[/b]" % [
		Describe.money(household["funds_cents"]), household["pantry_meals"],
		Describe.money(household["weekly_rent_cents"]), owed, Describe.money(household["wages_due_cents"]),
	]
	# The week's summary is counted again only when something new is logged.
	var first_day: int = WeekSummary.week_start(simulation.clock.day_index)
	var key: String = "%d/%d" % [first_day, simulation.state.event_log.size()]
	if key != _week_summary_key:
		_week_summary_key = key
		_week_summary = WeekSummary.summarize(simulation.state, household_id, first_day, first_day + 6)
		_ledger.queue_redraw()


## "This week": wages in, rent and groceries out, as small bars.
func _draw_ledger() -> void:
	if _week_summary.is_empty():
		return
	var font: Font = _ledger.get_theme_default_font()
	var w: float = _ledger.size.x
	var income: int = _week_summary["wages_cents"] + _week_summary["other_income_cents"]
	var rows: Array = [
		["Wages in", income, LEAF], ["Rent", _week_summary["rent_paid_cents"], CHERRY],
		["Groceries", _week_summary["groceries_cents"], MUSTARD],
	]
	var net: int = _week_summary["net_cents"]
	_ledger.draw_string(font, Vector2(0, 10), "THIS WEEK", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK_SOFT)
	var any_money: bool = false
	for row: Array in rows:
		any_money = any_money or int(row[1]) != 0
	if not any_money and net == 0:
		# Nothing yet: a quiet note in a dashed box rather than three empty bars.
		var box: Rect2 = Rect2(0, 17, w, _ledger.size.y - 19)
		var dash: Color = Color(INK_SOFT, 0.45)
		_ledger.draw_dashed_line(box.position, Vector2(box.end.x, box.position.y), dash, 1.0, 4.0)
		_ledger.draw_dashed_line(Vector2(box.position.x, box.end.y), box.end, dash, 1.0, 4.0)
		_ledger.draw_dashed_line(box.position, Vector2(box.position.x, box.end.y), dash, 1.0, 4.0)
		_ledger.draw_dashed_line(Vector2(box.end.x, box.position.y), box.end, dash, 1.0, 4.0)
		_ledger.draw_string(font, Vector2(0, box.get_center().y + 4), "No money in or out yet this week",
				HORIZONTAL_ALIGNMENT_CENTER, w, 12, INK_SOFT)
		return
	_ledger.draw_string(font, Vector2(w - 160, 10), "%s %s so far" % ["up" if net >= 0 else "down", Describe.money(absi(net))],
			HORIZONTAL_ALIGNMENT_RIGHT, 160, 11, LEAF.darkened(0.2) if net >= 0 else CHERRY)
	var largest: int = 1
	for row: Array in rows:
		largest = maxi(largest, row[1])
	var bar_left: float = 70.0
	var bar_right: float = w - 62.0
	for index: int in rows.size():
		var row: Array = rows[index]
		var y: float = 16.0 + 13.0 * index
		_ledger.draw_string(font, Vector2(0, y + 9), row[0], HORIZONTAL_ALIGNMENT_LEFT, bar_left - 4, 11, INK)
		_ledger.draw_rect(Rect2(bar_left, y + 2, bar_right - bar_left, 8), Color(PAPER_DARK, 0.7))
		var length: float = (bar_right - bar_left) * float(row[1]) / float(largest)
		if row[1] > 0:
			_ledger.draw_rect(Rect2(bar_left, y + 2, maxf(length, 2.0), 8), row[2])
		_ledger.draw_string(font, Vector2(bar_right, y + 9), Describe.money(row[1]), HORIZONTAL_ALIGNMENT_RIGHT, w - bar_right, 11, INK)


## The feed's lines under the filter chosen, each event with an icon; a new
## line slides in from the left and is lit for a few seconds. The lines are
## worked out again only when the log, the filter or an opened group changes.
func _refresh_feed() -> void:
	var log: Array = simulation.state.event_log
	var now: int = Time.get_ticks_msec()
	var cache_key: String = "%d|%s|%d|%s" % [log.size(), _feed_filter, _feed_slots, ",".join(PackedStringArray(_feed_expanded.keys()))]
	if cache_key != _feed_cache_key:
		_feed_cache_key = cache_key
		_feed_shown = _feed_items()
		_feed_empty.visible = _feed_shown.is_empty()
	for slot: int in _feed_rows.size():
		var entry: Dictionary = _feed_rows[slot]
		var row: Control = entry["row"]
		if slot >= _feed_shown.size():
			entry["item"] = {}
			entry["key"] = ""
			row.visible = false
			continue
		row.visible = true
		var item: Dictionary = _feed_shown[slot]
		var text: RichTextLabel = entry["text"]
		var indent: float = 8.0 if item.get("member", false) else 0.0
		if entry["key"] != item["key"]:
			entry["key"] = item["key"]
			entry["item"] = item
			if item["kind"] == "event":
				var event: Dictionary = item["event"]
				entry["kind"] = Describe.event_icon(event)
				_set_feed_text(text, "[b][color=%s]%s[/color][/b]   %s" % [
					_hex(TEAL), Describe.event_time(event), Describe.event_rich(simulation, event, _player_ids, true),
				])
				var plain: String = "%s   %s" % [Describe.event_time(event), Describe.event(simulation, event)]
				var clipped: bool = get_theme_default_font().get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x > row.size.x - 34.0
				row.tooltip_text = (plain + "\n\n" if clipped else "") + "Click to see where this happened on the street"
			elif item["kind"] == "more":
				entry["kind"] = ""
				_set_feed_text(text, "[i][color=%s]%s[/color][/i]" % [_hex(INK_SOFT), item["text"]])
				row.tooltip_text = "Click to show them"
			else:
				entry["kind"] = ""
				_set_feed_text(text, "[i][color=%s]Show fewer[/color][/i]" % _hex(INK_SOFT))
				row.tooltip_text = "Click to fold these lines together again"
			row.queue_redraw()
		# Only events slide in and glow when new; "more" lines just appear.
		var t: float = 1.0
		var glow: float = 0.0
		if item["kind"] == "event":
			var event_id: int = item["event"]["id"]
			if not _first_shown.has(event_id):
				_first_shown[event_id] = now
			var age: int = now - int(_first_shown[event_id])
			t = clampf(float(age) / float(FEED_SLIDE_MS), 0.0, 1.0)
			glow = clampf(1.0 - float(age) / float(FEED_FRESH_MS), 0.0, 1.0)
		var ease_in: float = 1.0 - pow(1.0 - t, 3.0)
		var slide: float = -28.0 * (1.0 - ease_in) + indent
		if slide != entry["slide"] or glow != entry["glow"] or text.position.x != 26.0 + slide:
			entry["slide"] = slide
			entry["glow"] = glow
			text.position.x = 26.0 + slide
			text.size.x = row.size.x - 26.0 - slide
			row.modulate.a = ease_in
			row.queue_redraw()
	# Forget lines long gone from the feed.
	if _first_shown.size() > 200:
		var keep: Dictionary = {}
		for item: Dictionary in _feed_shown:
			if item["kind"] == "event" and _first_shown.has(item["event"]["id"]):
				keep[item["event"]["id"]] = _first_shown[item["event"]["id"]]
		_first_shown = keep


## Sets a feed line's text, putting a small drawn arrow where Describe marked
## a regard change going up or down.
func _set_feed_text(label: RichTextLabel, bbcode: String) -> void:
	label.clear()
	var rest: String = bbcode
	while true:
		var up: int = rest.find(Describe.CHEVRON_UP)
		var down: int = rest.find(Describe.CHEVRON_DOWN)
		var at: int = up if down < 0 or (up >= 0 and up < down) else down
		if at < 0:
			label.append_text(rest)
			return
		label.append_text(rest.left(at))
		label.add_image(_chevron_up if at == up else _chevron_down, 9, 9, Color.WHITE, INLINE_ALIGNMENT_CENTER)
		label.append_text(" ")
		rest = rest.substr(at + 1)


func _refresh_goal_shine() -> void:
	if _goal_shine.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	for index: int in mini(_goals.size(), _goal_rows.size()):
		var id: String = _goals[index]["id"]
		if _goal_shine.has(id):
			_goal_rows[index].queue_redraw()
			if now - int(_goal_shine[id]) > GOAL_SHINE_MS:
				_goal_shine.erase(id)


## Normal or Large text (a setting). Large raises the font sizes of the side
## panel, the feed and the sheets (view/text_size.gd); the top bar, the goals
## card and the drawn pages keep theirs, since they are laid out to fit.
func set_large_text(large: bool) -> void:
	if large == _large_text:
		return
	_large_text = large
	var by: float = TextSize.factor(large)
	var scaled: Theme = TextSize.scaled_theme(theme, by) if large else null
	for part: Control in [_side_panel, _feed_panel, _sheet_layer]:
		part.theme = scaled
		TextSize.scale_overrides(part, by)
	_apply_feed_size()
	# The neighbors list is fitted again to whole rows of the new height.
	_refit_neighbors()
	if _sheet_open:
		_fit_sheet()


## Lets the neighbors list fill the room left for it, then, once laid out,
## fits it again to a whole number of rows.
func _refit_neighbors() -> void:
	_neighbor_rows_fitted = false
	_neighbor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_neighbor_scroll.custom_minimum_size.y = 0
	_refit_wait = 2


func is_large_text() -> bool:
	return _large_text


## What is known about a building as a drawn page, for show_sheet's content.
## info comes from sim/reports/building_info.gd.
func building_page(info: Dictionary, viewer_id: String) -> Control:
	var page: Control = BuildingPage.new()
	page.setup(simulation, info, viewer_id)
	return page


## The week's summary as a page of a small paper, for show_sheet's content.
## A lead, if given, is a short line above the paper (the end of the first
## week invites the player to carry on).
func week_paper(summary: Dictionary, goals: Array, lead: String = "") -> Control:
	var paper: Control = WeekPaper.new()
	paper.setup(simulation, summary, goals)
	if lead == "":
		return paper
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	page.add_child(line)
	var mark: Control = Control.new()
	mark.custom_minimum_size = Vector2(16, 16)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.draw.connect(func() -> void:
		mark.draw_colored_polygon(HudArt.star(mark.size / 2.0, 7.5, 3.2), MUSTARD))
	line.add_child(mark)
	var words: Label = Label.new()
	words.text = lead
	words.add_theme_font_size_override("font_size", 15)
	words.add_theme_color_override("font_color", PAPER)
	line.add_child(words)
	page.add_child(paper)
	return page
