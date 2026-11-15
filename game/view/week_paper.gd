extends Control
## The week's summary laid out as a small local paper, drawn in code
## (D-058). Everything on it comes from sim/reports/week_summary.gd and
## sim/reports/week_goals.gd; only the phrasing is the view's. The masthead
## names the area's street and, for a placeholder area, says it is made up
## (D-035). Presentation only.

const Describe := preload("res://view/describe.gd")
const HudArt := preload("res://view/hud_art.gd")
const SimDate := preload("res://sim/clock/sim_date.gd")

const PAPER: Color = Color("#F6EEDB")
const RULE: Color = Color("#3B2F2A")
const INK: Color = HudArt.INK
const INK_SOFT: Color = HudArt.INK_SOFT
const MONTH_NAMES: Array[String] = [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
]
const PAGE_SIZE: Vector2 = Vector2(576, 444)
const MARGIN: float = 16.0
const GUTTER: float = 14.0
const COLUMN_TOP: float = 150.0
const COLUMN_BOTTOM: float = 412.0
const CLOSEST_SHOWN: int = 3

var _sim: RefCounted
var _summary: Dictionary
var _goals: Array
var _bold: FontVariation
var _italic: FontVariation


func setup(sim: RefCounted, summary: Dictionary, goals: Array) -> void:
	_sim = sim
	_summary = summary
	_goals = goals
	custom_minimum_size = PAGE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var base: Font = get_theme_default_font()
	_bold = FontVariation.new()
	_bold.base_font = base
	_bold.variation_embolden = 0.9
	_italic = FontVariation.new()
	_italic.base_font = base
	_italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)


func _street_name() -> String:
	var ids: Array = _sim.area.streets.keys()
	ids.sort()
	return str(_sim.area.streets[ids[0]]["name"]) if not ids.is_empty() else "Street"


func _date(day_index: int) -> String:
	var date: Dictionary = SimDate.from_day_index(day_index)
	return "%s %d %s %d" % [SimDate.weekday_name(day_index), date["day"], MONTH_NAMES[int(date["month"]) - 1], date["year"]]


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var width: float = size.x
	# The page, with a faint second sheet behind it.
	draw_rect(Rect2(Vector2(4, 4), size - Vector2(2, 2)), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(Vector2.ZERO, size - Vector2(2, 2)), PAPER)
	draw_rect(Rect2(Vector2(5, 5), size - Vector2(12, 12)), Color(RULE, 0.25), false, 1.0)

	# Masthead.
	var title: String = "The %s Weekly" % _street_name()
	draw_string(_bold, Vector2(0, 42), title, HORIZONTAL_ALIGNMENT_CENTER, width, 30, INK)
	draw_line(Vector2(MARGIN, 52), Vector2(width - MARGIN, 52), RULE, 2.0)
	draw_line(Vector2(MARGIN, 55), Vector2(width - MARGIN, 55), RULE, 0.8)
	var dateline: String = "Week of %s to %s" % [_date(_summary["first_day"]), _date(_summary["last_day"])]
	draw_string(font, Vector2(MARGIN, 70), dateline, HORIZONTAL_ALIGNMENT_LEFT, width * 0.6, 11, INK_SOFT)
	if _sim.area.placeholder:
		draw_string(_italic, Vector2(width * 0.5, 70), "A made-up street for testing; not a real place",
				HORIZONTAL_ALIGNMENT_RIGHT, width * 0.5 - MARGIN, 11, HudArt.CHERRY)
	draw_line(Vector2(MARGIN, 77), Vector2(width - MARGIN, 77), RULE, 0.8)

	# Headline and a factual line under it.
	var headline: String = Describe.week_headline(_sim, _summary, _goals)
	draw_string(_bold, Vector2(MARGIN, 106), headline, HORIZONTAL_ALIGNMENT_CENTER, width - 2 * MARGIN, 24, INK)
	var meetings: int = (_summary["first_meetings"] as Array).size()
	var dek: String = "%d %s with neighbors, %d minutes in all; %d first %s. The %s." % [
		_summary["conversations"], "talk" if _summary["conversations"] == 1 else "talks", _summary["minutes_talking"],
		meetings, "meeting" if meetings == 1 else "meetings",
		_sim.state.households[_summary["household_id"]]["name"],
	]
	draw_string(_italic, Vector2(MARGIN, 128), dek, HORIZONTAL_ALIGNMENT_CENTER, width - 2 * MARGIN, 12, INK_SOFT)
	draw_line(Vector2(MARGIN, 138), Vector2(width - MARGIN, 138), RULE, 1.4)

	var column_w: float = (width - 2 * MARGIN - 2 * GUTTER) / 3.0
	var columns: Array[float] = [MARGIN, MARGIN + column_w + GUTTER, MARGIN + 2 * (column_w + GUTTER)]
	for index: int in [1, 2]:
		var x: float = columns[index] - GUTTER / 2.0
		draw_line(Vector2(x, COLUMN_TOP), Vector2(x, COLUMN_BOTTOM), Color(RULE, 0.4), 1.0)
	_draw_money(font, columns[0], column_w)
	_draw_neighbors(font, columns[1], column_w)
	_draw_tried(font, columns[2], column_w)

	# Birthdays, along the foot of the page.
	draw_line(Vector2(MARGIN, COLUMN_BOTTOM + 4), Vector2(width - MARGIN, COLUMN_BOTTOM + 4), RULE, 0.8)
	var births: PackedStringArray = []
	for birthday: Dictionary in _summary["birthdays"]:
		births.append("%s turned %d" % [Describe.given_name(_sim, birthday["person_id"]), birthday["age"]])
	var foot: String = "Birthdays: " + (", ".join(births) + "." if not births.is_empty() else "none in the household this week.")
	if not births.is_empty():
		HudArt.event_icon(self, Vector2(MARGIN + 7, COLUMN_BOTTOM + 18), "cake", 7.0)
	draw_string(font, Vector2(MARGIN + (18 if not births.is_empty() else 0), COLUMN_BOTTOM + 22), foot,
			HORIZONTAL_ALIGNMENT_LEFT, width - 2 * MARGIN - 18, 12, INK)


func _column_head(x: float, w: float, text: String) -> float:
	draw_string(_bold, Vector2(x, COLUMN_TOP + 12), text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w, 13, HudArt.TEAL)
	draw_line(Vector2(x, COLUMN_TOP + 17), Vector2(x + w, COLUMN_TOP + 17), Color(HudArt.TEAL, 0.6), 1.0)
	return COLUMN_TOP + 34.0


## Draws wrapped text and returns the y below it.
func _para(font: Font, x: float, y: float, w: float, text: String, font_size: int, color: Color, max_lines: int = -1) -> float:
	draw_multiline_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, w, font_size, max_lines, color)
	var lines: int = roundi(font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, font_size).y / font.get_height(font_size))
	if max_lines > 0:
		lines = mini(lines, max_lines)
	return y + float(maxi(lines, 1)) * font.get_height(font_size) + 3.0


func _draw_money(font: Font, x: float, w: float) -> void:
	var y: float = _column_head(x, w, "Money")
	var income: int = _summary["wages_cents"] + _summary["other_income_cents"]
	var bars: Array = [
		["In", income, HudArt.LEAF], ["Rent", _summary["rent_paid_cents"], HudArt.CHERRY],
		["Food", _summary["groceries_cents"], HudArt.MUSTARD],
	]
	var largest: int = 1
	for bar: Array in bars:
		largest = maxi(largest, bar[1])
	var chart_h: float = 62.0
	var base: float = y + chart_h
	var slot: float = w / 3.0
	draw_line(Vector2(x, base), Vector2(x + w, base), INK_SOFT, 1.0)
	for index: int in bars.size():
		var bar: Array = bars[index]
		var h: float = chart_h * float(bar[1]) / float(largest)
		var bx: float = x + slot * index + slot * 0.22
		var bw: float = slot * 0.56
		draw_rect(Rect2(bx, base - h, bw, h), bar[2])
		draw_rect(Rect2(bx, base - h, bw, h), Color(bar[2] as Color).darkened(0.35), false, 1.0)
		draw_string(font, Vector2(x + slot * index, base - h - 4), Describe.money(bar[1]), HORIZONTAL_ALIGNMENT_CENTER, slot, 10, INK)
		draw_string(font, Vector2(x + slot * index, base + 13), bar[0], HORIZONTAL_ALIGNMENT_CENTER, slot, 11, INK_SOFT)
	y = base + 32.0
	var net: int = _summary["net_cents"]
	var net_color: Color = HudArt.LEAF.darkened(0.2) if net >= 0 else HudArt.CHERRY
	draw_string(_bold, Vector2(x, y), "%s %s over the week" % ["Up" if net >= 0 else "Down", Describe.money(absi(net))],
			HORIZONTAL_ALIGNMENT_LEFT, w, 12, net_color)
	y += 6.0
	var notes: Array[String] = []
	notes.append("%d meals bought in %d %s." % [_summary["meals_bought"], _summary["shopping_trips"], "trip" if _summary["shopping_trips"] == 1 else "trips"])
	if _summary["rent_short_cents"] > 0:
		notes.append("Rent still owed: %s." % Describe.money(_summary["rent_short_cents"]))
	if _summary["days_missed"] > 0:
		notes.append("%d %s of work missed (%s lost)." % [_summary["days_missed"], "day" if _summary["days_missed"] == 1 else "days", Describe.money(_summary["wages_lost_cents"])])
	if _summary["thin_meal_days"] > 0:
		notes.append("%d %s with an empty pantry." % [_summary["thin_meal_days"], "day" if _summary["thin_meal_days"] == 1 else "days"])
	if _summary["times_short"] > 0:
		notes.append("Short of money %d %s." % [_summary["times_short"], "time" if _summary["times_short"] == 1 else "times"])
	for note: String in notes:
		y = _para(font, x, y + 10.0, w, note, 11, INK) - 10.0
		if y > COLUMN_BOTTOM - 14.0:
			break


func _draw_neighbors(font: Font, x: float, w: float) -> void:
	var y: float = _column_head(x, w, "Neighbors")
	var first: PackedStringArray = []
	for pair: Array in _summary["first_meetings"]:
		var name: String = Describe.given_name(_sim, pair[1])
		if not first.has(name):
			first.append(name)
	if first.is_empty():
		y = _para(font, x, y, w, "No new faces this week.", 11, INK)
	else:
		y = _para(font, x, y, w, "Met for the first time: " + ", ".join(first) + ".", 11, INK, 3)
	y += 8.0
	draw_string(_bold, Vector2(x, y), "Closest this week", HORIZONTAL_ALIGNMENT_LEFT, w, 12, INK)
	y += 6.0
	var ranked: Array = (_summary["neighbors"] as Array).duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var warm_a: int = a["member_change"] + a["other_change"]
		var warm_b: int = b["member_change"] + b["other_change"]
		return warm_a > warm_b if warm_a != warm_b else (a["member_id"] + a["other_id"]) < (b["member_id"] + b["other_id"]))
	if ranked.is_empty():
		draw_string(font, Vector2(x, y + 14), "Nobody talked with the neighbors.", HORIZONTAL_ALIGNMENT_LEFT, w, 11, INK_SOFT)
		return
	for index: int in mini(CLOSEST_SHOWN, ranked.size()):
		var pair: Dictionary = ranked[index]
		y += 16.0
		var names: String = "%s & %s" % [Describe.given_name(_sim, pair["member_id"]), Describe.given_name(_sim, pair["other_id"])]
		draw_string(font, Vector2(x, y), names, HORIZONTAL_ALIGNMENT_LEFT, w - 50, 12, INK)
		draw_string(font, Vector2(x + w - 50, y), "%d %s" % [pair["talks"], "talk" if pair["talks"] == 1 else "talks"],
				HORIZONTAL_ALIGNMENT_RIGHT, 50, 10, INK_SOFT)
		y += 5.0
		HudArt.regard_meter(self, Rect2(x, y, w * 0.55, 7), pair["member_change"], pair["other_change"], true, 40)
		draw_string(font, Vector2(x + w * 0.55 + 6, y + 7), "%+d / %+d" % [pair["member_change"], pair["other_change"]],
				HORIZONTAL_ALIGNMENT_LEFT, w * 0.45 - 6, 10, INK_SOFT)
		y += 8.0


func _draw_tried(font: Font, x: float, w: float) -> void:
	var y: float = _column_head(x, w, "Things you tried")
	if _goals.is_empty():
		draw_string(font, Vector2(x, y), "Nothing this week.", HORIZONTAL_ALIGNMENT_LEFT, w, 11, INK_SOFT)
		return
	var done: int = 0
	for goal: Dictionary in _goals:
		if goal["status"] == "done":
			done += 1
	draw_string(_bold, Vector2(x, y - 2), "%d of %d done" % [done, _goals.size()], HORIZONTAL_ALIGNMENT_LEFT, w, 12, INK)
	y += 8.0
	for goal: Dictionary in _goals:
		HudArt.goal_box(self, Rect2(x + 1, y + 1, 10, 10), goal["status"])
		var color: Color = INK if goal["status"] != "missed" else HudArt.CHERRY
		var text: String = goal["title"]
		if int(goal["target"]) > 1 and goal["status"] != "done":
			text += " (%d/%d)" % [goal["progress"], goal["target"]]
		y = _para(font, x + 16, y + 10, w - 16, text, 11, color, 2) - 6.0
		if y > COLUMN_BOTTOM - 12.0:
			break
