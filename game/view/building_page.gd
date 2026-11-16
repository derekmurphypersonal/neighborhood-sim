extends Control
## What is known about a building, laid out as a page drawn in code (D-058).
## Every statement on it comes from sim/reports/building_info.gd, and the
## three kinds of content keep their own labelled panels, as in that report:
## what the record says about the outside, the invented interior (D-032), and
## the fictional people and business of the scenario. For a placeholder area
## the page says the street is made up (D-035).
##
## The front elevation is the game's own sketch and is captioned as one. Its
## colours are chosen from the building's ID exactly as world_view chooses
## them, so the sketch matches the map. The floor plan's shapes are read from
## the area's interior for that building; relationship words and whether the
## business is open now are read from the state. Presentation only.

const Describe := preload("res://view/describe.gd")
const HudArt := preload("res://view/hud_art.gd")
const SimDate := preload("res://sim/clock/sim_date.gd")
const Records := preload("res://sim/state/records.gd")
const WorldView := preload("res://view/world_view.gd")

const PAPER: Color = Color("#F6EEDB")
const PANEL: Color = Color("#FBF6E9")
const RULE: Color = Color("#3B2F2A")
const INK: Color = HudArt.INK
const INK_SOFT: Color = HudArt.INK_SOFT
## The badge colour for invented content, distinct from every research status.
const FICTION: Color = Color("#7B4B6A")
const STATUS_COLORS: Dictionary = {
	"verified": Color("#3E7A33"), "probable": Color("#B07F12"), "hypothesis": Color("#2F5D62"),
}
const WORD_COLORS: Dictionary = {
	"Friend": Color("#3E7A33"), "Friendly": Color("#5E8C4A"), "Acquaintance": Color("#3B2F2A"),
	"Cool": Color("#4F6E8C"), "Unfriendly": Color("#B5442F"), "Stranger": Color("#9A8676"),
}
const PAGE_SIZE: Vector2 = Vector2(576, 456)
const MARGIN: float = 16.0
const LEFT_W: float = 248.0
const GUTTER: float = 12.0
const ROW_ONE: Rect2 = Rect2(0, 66, 0, 186)
const ROW_TWO: Rect2 = Rect2(0, 262, 0, 178)
const PANEL_HEAD: float = 26.0
const PAD: float = 9.0
const PORTRAIT: float = 30.0
const MEMBER_ROW: float = 35.0
const STORE_BRICK: Color = Color(0.68, 0.38, 0.31)
const STORE_ROOF: Color = Color(0.40, 0.38, 0.36)

var _sim: RefCounted
var _info: Dictionary
var _viewer_id: String = ""
var _bold: FontVariation
var _italic: FontVariation
## The elevation's mapping from feet to the page: origin of the wall's
## lower-left corner and pixels per foot.
var _origin: Vector2
var _k: float = 1.0


## info is BuildingInfo.describe()'s result; viewer_id is the person whose
## standing with the residents is shown (one of the player's household).
func setup(sim: RefCounted, info: Dictionary, viewer_id: String) -> void:
	_sim = sim
	_info = info
	var players: Array = sim.state.households[sim.state.player_household_id()]["member_ids"]
	_viewer_id = viewer_id if players.has(viewer_id) else str(players[0])
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
	return str(_sim.area.streets[ids[0]]["name"]) if not ids.is_empty() else "This street"


func _is_store() -> bool:
	return not (_info["institution"] as Dictionary).is_empty()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var width: float = size.x
	draw_rect(Rect2(Vector2(4, 4), size - Vector2(2, 2)), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(Vector2.ZERO, size - Vector2(2, 2)), PAPER)
	draw_rect(Rect2(Vector2(5, 5), size - Vector2(12, 12)), Color(RULE, 0.25), false, 1.0)

	# Heading: the building's label, and for a stand-in area a plain notice.
	draw_string(_bold, Vector2(MARGIN, 38), _info["label"], HORIZONTAL_ALIGNMENT_LEFT, width * 0.55, 26, INK)
	if _info["area_placeholder"]:
		var stamp: Rect2 = Rect2(width - MARGIN - 214, 14, 212, 32)
		draw_style_box(_pill(Color(HudArt.CHERRY, 0.08), HudArt.CHERRY, 4), stamp)
		draw_string(_bold, Vector2(stamp.position.x, stamp.position.y + 14), "FICTIONAL TEST BUILDING",
				HORIZONTAL_ALIGNMENT_CENTER, stamp.size.x, 11, HudArt.CHERRY)
		draw_string(_italic, Vector2(stamp.position.x, stamp.position.y + 27), "a made-up street; not a real place",
				HORIZONTAL_ALIGNMENT_CENTER, stamp.size.x, 10, HudArt.CHERRY)
	draw_line(Vector2(MARGIN, 52), Vector2(width - MARGIN, 52), RULE, 2.0)
	draw_line(Vector2(MARGIN, 55), Vector2(width - MARGIN, 55), RULE, 0.8)

	var right_x: float = MARGIN + LEFT_W + GUTTER
	var right_w: float = width - MARGIN - right_x - 2.0
	_draw_elevation(font, Rect2(MARGIN, ROW_ONE.position.y, LEFT_W, ROW_ONE.size.y))
	_draw_record(font, Rect2(right_x, ROW_ONE.position.y, right_w, ROW_ONE.size.y))
	_draw_inside(font, Rect2(MARGIN, ROW_TWO.position.y, LEFT_W, ROW_TWO.size.y))
	_draw_scenario(font, Rect2(right_x, ROW_TWO.position.y, right_w, ROW_TWO.size.y))


# --- Small parts -------------------------------------------------------------

static func _pill(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


## A filled tag ending at right_x, centred on y. Returns its width.
func _badge(right_x: float, y: float, text: String, color: Color) -> float:
	var text_w: float = _bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var w: float = text_w + 14.0
	var rect: Rect2 = Rect2(right_x - w, y - 7.5, w, 15)
	draw_style_box(_pill(color, color.darkened(0.25), 7), rect)
	draw_string(_bold, Vector2(rect.position.x, y + 3.5), text, HORIZONTAL_ALIGNMENT_CENTER, w, 9, PANEL)
	return w


## A panel with a heading and a tag saying what kind of content it holds.
## Returns the rectangle left for the content.
func _panel(rect: Rect2, title: String, tag: String, tag_color: Color) -> Rect2:
	draw_style_box(_pill(PANEL, Color(RULE, 0.28), 5), rect)
	var badge_w: float = _badge(rect.end.x - 7.0, rect.position.y + 13.0, tag, tag_color)
	draw_string(_bold, Vector2(rect.position.x + PAD, rect.position.y + 17.0), title.to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - PAD - badge_w - 12.0, 11, HudArt.TEAL)
	draw_line(Vector2(rect.position.x + 1, rect.position.y + PANEL_HEAD - 2), Vector2(rect.end.x - 1, rect.position.y + PANEL_HEAD - 2),
			Color(tag_color, 0.55), 1.5)
	return Rect2(rect.position.x + PAD, rect.position.y + PANEL_HEAD + 4.0, rect.size.x - 2.0 * PAD, rect.size.y - PANEL_HEAD - 4.0 - PAD + 2.0)


## Draws wrapped text whose first baseline is at y; returns the next baseline.
func _para(font: Font, x: float, y: float, w: float, text: String, font_size: int, color: Color, max_lines: int = -1) -> float:
	draw_multiline_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, w, font_size, max_lines, color)
	var lines: int = roundi(font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, font_size).y / font.get_height(font_size))
	if max_lines > 0:
		lines = mini(lines, max_lines)
	return y + float(maxi(lines, 1)) * font.get_height(font_size) + 2.0


static func _status_tag(status: String, documented: bool) -> Array:
	if documented:
		return [status.to_upper(), STATUS_COLORS.get(status, HudArt.TEAL)]
	return ["NOT DOCUMENTED", HudArt.CHERRY]


# --- What the record says ----------------------------------------------------

func _draw_record(font: Font, rect: Rect2) -> void:
	var exterior: Dictionary = _info["exterior"]
	var tag: Array = _status_tag(exterior["status"], exterior["documented"])
	var inner: Rect2 = _panel(rect, "What the record says", tag[0], tag[1])
	var x: float = inner.position.x
	var w: float = inner.size.x
	var y: float = inner.position.y + 10.0
	var bottom: float = inner.end.y
	if exterior["documented"]:
		y = _para(font, x, y, w, "Research status: %s. The outside of this building is from the historical record." % exterior["status"], 11, INK, 3) + 3.0
		y = _facts(font, x, y, w, exterior["facts"])
		for source: Dictionary in exterior["sources"]:
			if y > bottom - 10.0:
				break
			var cite: String = "Source %s, %s (finding %s)" % [source.get("source_id", "?"), source.get("locator", "?"), source.get("finding_id", "?")]
			y = _para(_italic, x, y, w, cite, 10, INK_SOFT, 2)
		if exterior["reasoning"] != "" and y < bottom - 10.0:
			var lines_left: int = maxi(1, int((bottom - y) / font.get_height(10)) + 1)
			_para(font, x, y + 2.0, w, "Reasoning: %s" % exterior["reasoning"], 10, INK, lines_left)
		return
	y = _para(_bold, x, y, w, "Nothing is documented about this building.", 12, INK, 2) + 2.0
	if _info["area_placeholder"]:
		y = _para(font, x, y, w, "%s is made up, a stand-in used while the game is built and tested, so there is no record to show." % _street_name(), 11, INK, 4)
	else:
		y = _para(font, x, y, w, "No source has been found for it yet.", 11, INK, 2)
	y += 5.0
	draw_line(Vector2(x, y - 8.0), Vector2(x + w, y - 8.0), Color(RULE, 0.2), 1.0)
	draw_string(_bold, Vector2(x, y + 4.0), "Stand-in exterior", HORIZONTAL_ALIGNMENT_LEFT, w - 70.0, 11, INK)
	_badge(x + w, y, "INVENTED", FICTION)
	_facts(font, x, y + 20.0, w, exterior["facts"])


func _facts(font: Font, x: float, y: float, w: float, facts: Array) -> float:
	for fact: Dictionary in facts:
		var label: String = Describe.FACT_LABELS.get(fact["field"], fact["field"])
		draw_string(font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, w * 0.55, 11, INK_SOFT)
		draw_string(_bold, Vector2(x + w * 0.5, y), str(fact["value"]), HORIZONTAL_ALIGNMENT_RIGHT, w * 0.5, 11, INK)
		draw_line(Vector2(x, y + 4.0), Vector2(x + w, y + 4.0), Color(RULE, 0.12), 1.0)
		y += 16.0
	return y + 2.0


# --- Inside ------------------------------------------------------------------

func _draw_inside(font: Font, rect: Rect2) -> void:
	var inner: Rect2 = _panel(rect, "Inside (invented layout)", "FICTIONAL", FICTION)
	var interior: Dictionary = _info["interior"]
	if interior.is_empty():
		var y: float = _para(font, inner.position.x, inner.position.y + 12.0, inner.size.x, "No interior has been made for this building.", 11, INK, 3)
		_para(_italic, inner.position.x, y + 4.0, inner.size.x, "When one is, it will be invented: interiors are never taken from the historical record.", 10, INK_SOFT, 4)
		return
	var plan: Rect2 = _draw_plan(font, Rect2(inner.position, Vector2(inner.size.x * 0.46, inner.size.y)))
	var x: float = plan.end.x + 10.0
	var w: float = inner.end.x - x
	var y: float = _para(_bold, x, inner.position.y + 11.0, w, str(interior["name"]), 11, INK, 4) + 3.0
	y = _para(font, x, y, w, "%d rooms: %s." % [(interior["rooms"] as Array).size(), ", ".join(PackedStringArray(interior["rooms"])).to_lower()], 10, INK, 4) + 3.0
	_para(_italic, x, y, w, "Interiors are never taken from the historical record.", 10, INK_SOFT, 4)


## A tiny floor plan fitted into rect, north up. Returns the plan's rectangle.
func _draw_plan(font: Font, rect: Rect2) -> Rect2:
	var area: RefCounted = _sim.area
	var building_id: String = _info["building_id"]
	if not area.interiors.has(building_id):
		return Rect2(rect.position, Vector2.ZERO)
	var rooms: Dictionary = area.interiors[building_id]["rooms"]
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for room_id: String in rooms:
		var r: Array = rooms[room_id]["rect"]
		var room_rect: Rect2 = Rect2(r[0], r[1], r[2], r[3])
		bounds = room_rect if first else bounds.merge(room_rect)
		first = false
	if first or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Rect2(rect.position, Vector2.ZERO)
	var fit: float = minf(rect.size.x / bounds.size.x, rect.size.y / bounds.size.y)
	var plan: Rect2 = Rect2(Vector2(rect.position.x, rect.position.y + (rect.size.y - bounds.size.y * fit) / 2.0), bounds.size * fit)
	var wall: Color = Color(RULE, 0.85)
	var ids: Array = rooms.keys()
	ids.sort()
	for room_id: String in ids:
		var room: Dictionary = rooms[room_id]
		var r: Array = room["rect"]
		# The world's y grows northward, the page's downward.
		var shown: Rect2 = Rect2(
			plan.position.x + (float(r[0]) - bounds.position.x) * fit,
			plan.position.y + (bounds.end.y - float(r[1]) - float(r[3])) * fit,
			float(r[2]) * fit, float(r[3]) * fit)
		draw_rect(shown, _floor_color(str(room["name"])))
		draw_rect(shown, wall, false, 1.0)
		var label_h: float = font.get_multiline_string_size(room["name"], HORIZONTAL_ALIGNMENT_CENTER, shown.size.x - 4.0, 9).y
		draw_multiline_string(font, Vector2(shown.position.x + 2.0, shown.get_center().y - label_h / 2.0 + font.get_ascent(9)), room["name"],
				HORIZONTAL_ALIGNMENT_CENTER, shown.size.x - 4.0, 9, 2, INK)
	draw_rect(plan, wall, false, 2.0)
	return plan


## Floor tints as in the home cutaway, by the room's name.
static func _floor_color(room_name: String) -> Color:
	var lower: String = room_name.to_lower()
	if lower.contains("kitchen"):
		return Color(0.95, 0.90, 0.84)
	if lower.contains("bath"):
		return Color(0.86, 0.92, 0.94)
	if lower.contains("bed"):
		return Color(0.90, 0.83, 0.81)
	if lower.contains("living"):
		return Color(0.88, 0.78, 0.63)
	return Color(0.90, 0.87, 0.80)


# --- The scenario: who lives here, and the business --------------------------

func _draw_scenario(font: Font, rect: Rect2) -> void:
	var institution: Dictionary = _info["institution"]
	var households: Array = _info["households"]
	if not institution.is_empty():
		var tag: Array = [str(institution["status"]).to_upper(), STATUS_COLORS.get(institution["status"], HudArt.TEAL)] if institution["documented"] else ["INVENTED", FICTION]
		var inner: Rect2 = _panel(rect, "The business here", tag[0], tag[1])
		var y: float = _draw_business(font, inner, institution)
		if households.is_empty():
			draw_string(_italic, Vector2(inner.position.x, inner.end.y - 2.0), "Nobody lives here in this scenario.", HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, 10, INK_SOFT)
		else:
			_draw_households(font, Rect2(inner.position.x, y, inner.size.x, inner.end.y - y), households)
		return
	var inner: Rect2 = _panel(rect, "Who lives here (fictional)", "FICTIONAL", FICTION)
	if households.is_empty():
		_para(font, inner.position.x, inner.position.y + 12.0, inner.size.x, "Nobody lives or works here in this scenario.", 11, INK, 3)
		return
	_draw_households(font, inner, households)


func _draw_households(font: Font, inner: Rect2, households: Array) -> void:
	var state: RefCounted = _sim.state
	var x: float = inner.position.x
	var w: float = inner.size.x
	var y: float = inner.position.y
	var viewer_name: String = Describe.given_name(_sim, _viewer_id)
	var any_neighbors: bool = false
	for household: Dictionary in households:
		var players: bool = state.households[household["household_id"]]["player_controlled"]
		draw_string(_bold, Vector2(x, y + 10.0), "The %s" % household["name"], HORIZONTAL_ALIGNMENT_LEFT, w - 96.0, 12, INK)
		if players:
			_badge(x + w, y + 6.0, "YOUR HOUSEHOLD", HudArt.TEAL)
		y += 17.0
		var members: Array = household["member_ids"]
		var column_w: float = w / 2.0
		for index: int in members.size():
			var person_id: String = members[index]
			var person: Dictionary = state.people[person_id]
			@warning_ignore("integer_division")
			var cell: Vector2 = Vector2(x + column_w * float(index % 2), y + MEMBER_ROW * float(index / 2))
			if cell.y + PORTRAIT > inner.end.y - 8.0:
				break
			var age: int = SimDate.age_on(person["birth_day"], _sim.clock.day_index)
			var mood: Dictionary = Describe.mood(person)
			HudArt.portrait(self, Rect2(cell, Vector2(PORTRAIT, PORTRAIT)), person_id, players, age < WorldView.CHILD_AGE, mood["face"])
			var tx: float = cell.x + PORTRAIT + 6.0
			var tw: float = column_w - PORTRAIT - 10.0
			draw_string(_bold, Vector2(tx, cell.y + 12.0), person["given_name"], HORIZONTAL_ALIGNMENT_LEFT, tw, 11, INK)
			var age_text: String = "age %d" % age
			draw_string(font, Vector2(tx, cell.y + 25.0), age_text, HORIZONTAL_ALIGNMENT_LEFT, tw, 10, INK_SOFT)
			var after_age: float = font.get_string_size(age_text + "  ", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			if person_id == _viewer_id:
				draw_string(font, Vector2(tx + after_age, cell.y + 25.0), "selected", HORIZONTAL_ALIGNMENT_LEFT, tw - after_age, 10, HudArt.TEAL)
			elif not players:
				any_neighbors = true
				var met: bool = state.relationships.has(Records.relationship_key(_viewer_id, person_id))
				var word: String = Describe.relationship_word(met, state.regard(_viewer_id, person_id) if met else 0, state.regard(person_id, _viewer_id) if met else 0)
				draw_string(_bold, Vector2(tx + after_age, cell.y + 25.0), word, HORIZONTAL_ALIGNMENT_LEFT, tw - after_age, 10, WORD_COLORS[word])
		@warning_ignore("integer_division")
		y += MEMBER_ROW * float((members.size() + 1) / 2) + 2.0
	var foot: String = "How %s stands with each. All are invented." % viewer_name if any_neighbors else "Everyone here is invented."
	draw_string(_italic, Vector2(x, inner.end.y - 2.0), foot, HORIZONTAL_ALIGNMENT_LEFT, w, 10, INK_SOFT)


## The business: its name, whether it is open now, and its hours with today's
## row marked. Returns the y below it.
func _draw_business(font: Font, inner: Rect2, institution: Dictionary) -> float:
	var x: float = inner.position.x
	var w: float = inner.size.x
	var y: float = inner.position.y
	var weekday: int = SimDate.weekday(_sim.clock.day_index)
	var minute: int = _sim.clock.minute_of_day
	var open_now: bool = _sim.area.is_open(_info["building_id"], weekday, minute)
	draw_string(_bold, Vector2(x, y + 13.0), institution["name"], HORIZONTAL_ALIGNMENT_LEFT, w - 92.0, 15, INK)
	_badge(x + w, y + 8.0, "OPEN NOW" if open_now else "CLOSED NOW", Color("#3E7A33") if open_now else INK_SOFT)
	y += 20.0
	var standing: String = "From the historical record (%s)." % institution["status"] if institution["documented"] else "An invented %s, not a documented business." % institution["kind"]
	draw_string(_italic, Vector2(x, y + 9.0), standing, HORIZONTAL_ALIGNMENT_LEFT, w, 10, INK_SOFT)
	y += 18.0
	draw_string(_bold, Vector2(x, y + 9.0), "OPENING HOURS", HORIZONTAL_ALIGNMENT_LEFT, w, 10, HudArt.TEAL)
	y += 14.0
	var today: String = SimDate.day_kind(weekday)
	for entry: Array in Describe.DAY_KIND_LABELS:
		var hours: Variant = institution["hours"].get(entry[0])
		var closed: bool = typeof(hours) != TYPE_ARRAY or (hours as Array).size() != 2
		var text: String = "Closed" if closed else "%s to %s" % [Describe.twelve_hour(int(hours[0])), Describe.twelve_hour(int(hours[1]))]
		var is_today: bool = entry[0] == today
		if is_today:
			draw_style_box(_pill(Color(HudArt.MUSTARD, 0.28), Color(HudArt.MUSTARD, 0.7), 3), Rect2(x - 4.0, y - 1.0, w + 8.0, 16.0))
		draw_string(_bold if is_today else font, Vector2(x, y + 11.0), entry[1], HORIZONTAL_ALIGNMENT_LEFT, 80.0, 11, INK)
		if is_today:
			draw_string(_italic, Vector2(x + 82.0, y + 11.0), "today", HORIZONTAL_ALIGNMENT_LEFT, 40.0, 10, INK_SOFT)
		draw_string(_bold if is_today else font, Vector2(x + w * 0.4, y + 11.0), text, HORIZONTAL_ALIGNMENT_RIGHT, w * 0.6, 11,
				INK_SOFT if closed else INK)
		y += 17.0
	return y + 4.0


# --- The front elevation -----------------------------------------------------

## A point on the front wall: u feet from its left end, z feet above ground.
func _e(u: float, z: float) -> Vector2:
	return _origin + Vector2(u * _k, -z * _k)


func _quad(u0: float, z0: float, u1: float, z1: float, color: Color) -> void:
	var a: Vector2 = _e(u0, z1)
	draw_rect(Rect2(a, _e(u1, z0) - a), color)


func _quad_line(u0: float, z0: float, u1: float, z1: float, color: Color, line: float = 1.0) -> void:
	var a: Vector2 = _e(u0, z1)
	draw_rect(Rect2(a, _e(u1, z0) - a), color, false, line)


## The width of the wall with the door in it and where the door is along it,
## in feet. Read from the footprint, which is in world inches.
func _front() -> Dictionary:
	var building: Dictionary = _sim.area.buildings[_info["building_id"]]
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for point: Array in building["footprint"]:
		var at: Vector2 = Vector2(point[0], point[1])
		bounds = Rect2(at, Vector2.ZERO) if first else bounds.expand(at)
		first = false
	var door: Vector2 = bounds.get_center()
	if building.has("door"):
		door = Vector2(building["door"][0], building["door"][1])
	var on_x_wall: bool = minf(absf(door.y - bounds.position.y), absf(door.y - bounds.end.y)) <= minf(absf(door.x - bounds.position.x), absf(door.x - bounds.end.x))
	var width: float = (bounds.size.x if on_x_wall else bounds.size.y) / 12.0
	var along: float = ((door.x - bounds.position.x) if on_x_wall else (door.y - bounds.position.y)) / 12.0
	return {"width": maxf(width, 12.0), "door": clampf(along, 3.0, maxf(width, 12.0) - 3.0)}


func _draw_elevation(font: Font, rect: Rect2) -> void:
	var id: String = _info["building_id"]
	var store: bool = _is_store()
	var stories: int = maxi(1, int(_sim.area.buildings[id]["stories"]))
	var front: Dictionary = _front()
	var width: float = front["width"]
	var wall_h: float = float(stories) * 10.0
	var rise: float = 2.0 if store else width * 0.38
	var caption_h: float = 16.0
	var picture: Rect2 = Rect2(rect.position, Vector2(rect.size.x, rect.size.y - caption_h))
	var ground_h: float = 24.0
	_k = minf((picture.size.x - 70.0) / (width + 3.0), (picture.size.y - ground_h - 14.0) / (wall_h + rise + (5.0 if store else 3.0)))
	_origin = Vector2(picture.get_center().x - width * _k / 2.0, picture.end.y - ground_h + 6.0)

	# Sky, a far hedge, the lawn and the walk to the door.
	draw_rect(picture, Color("#CFE2E6"))
	draw_rect(Rect2(picture.position, Vector2(picture.size.x, picture.size.y * 0.45)), Color("#BCD7E0"))
	for cloud: Array in [[0.16, 0.16, 15.0], [0.24, 0.19, 11.0], [0.84, 0.26, 12.0], [0.77, 0.29, 9.0]]:
		draw_circle(picture.position + Vector2(picture.size.x * float(cloud[0]), picture.size.y * float(cloud[1])), cloud[2], Color(1, 1, 1, 0.75))
	var ground_y: float = _origin.y
	draw_rect(Rect2(picture.position.x, ground_y - 13.0, picture.size.x, 13.0), WorldView.COLOR_GRASS_DARK.lerp(Color("#CFE2E6"), 0.35))
	draw_rect(Rect2(picture.position.x, ground_y - 2.0, picture.size.x, picture.end.y - ground_y + 2.0), WorldView.COLOR_LAWN)
	var door_x: float = _e(front["door"], 0.0).x
	draw_colored_polygon(PackedVector2Array([
		Vector2(door_x - 2.0 * _k, ground_y), Vector2(door_x + 2.0 * _k, ground_y),
		Vector2(door_x + 3.4 * _k, picture.end.y), Vector2(door_x - 3.4 * _k, picture.end.y),
	]), WorldView.COLOR_SIDEWALK if store else WorldView.COLOR_PATH)
	if store:
		draw_rect(Rect2(picture.position.x, picture.end.y - 9.0, picture.size.x, 9.0), WorldView.COLOR_SIDEWALK)
	else:
		_draw_tree(Vector2(picture.position.x + 22.0, ground_y), 1.0)
		for bush: float in [-2.2, width + 2.2]:
			draw_circle(_e(bush, 1.0), 1.9 * _k, WorldView.COLOR_GRASS_DARK.darkened(0.12))
			draw_circle(_e(bush + 0.6, 1.6), 1.2 * _k, WorldView.COLOR_GRASS_DARK)

	if store:
		_draw_store_front(font, width, wall_h, stories, front["door"])
	else:
		_draw_house_front(id, width, wall_h, rise, stories, front["door"])
	draw_rect(picture, Color(RULE, 0.55), false, 1.0)
	draw_string(_italic, Vector2(rect.position.x, rect.end.y - 3.0), "The game's own sketch; the details are invented.",
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 9, INK_SOFT)


func _draw_tree(foot: Vector2, scale_by: float) -> void:
	draw_rect(Rect2(foot.x - 2.5 * scale_by, foot.y - 34.0 * scale_by, 5.0 * scale_by, 36.0 * scale_by), WorldView.COLOR_TRUNK)
	for blob: Array in [[0.0, -52.0, 19.0], [-12.0, -42.0, 13.0], [12.0, -44.0, 14.0], [2.0, -64.0, 13.0]]:
		draw_circle(foot + Vector2(blob[0], blob[1]) * scale_by, float(blob[2]) * scale_by, WorldView.COLOR_GRASS_DARK.darkened(0.08))
	for blob: Array in [[-5.0, -57.0, 10.0], [8.0, -50.0, 8.0]]:
		draw_circle(foot + Vector2(blob[0], blob[1]) * scale_by, float(blob[2]) * scale_by, WorldView.COLOR_GRASS_LIGHT.darkened(0.1))


## A window between u - half and u + half, from low to high (feet).
func _window(u: float, half: float, low: float, high: float, shutter: Color, curtain: Color, with_shutters: bool) -> void:
	if with_shutters:
		_quad(u - half - 0.95, low - 0.2, u - half - 0.1, high + 0.2, shutter)
		_quad(u + half + 0.1, low - 0.2, u + half + 0.95, high + 0.2, shutter)
	_quad(u - half, low, u + half, high, WorldView.COLOR_GLASS)
	draw_line(_e(u - half + 0.3, low + (high - low) * 0.3), _e(u + half * 0.2, high - 0.2), Color(1, 1, 1, 0.28), 1.0)
	if curtain.a > 0.0:
		var span: float = high - low
		for side: float in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([
				_e(u + side * half, high), _e(u + side * half * 0.4, high), _e(u + side * half * 0.8, low + span * 0.45),
				_e(u + side * half * 0.68, low), _e(u + side * half, low),
			]), curtain)
		_quad(u - half, high - span * 0.14, u + half, high, curtain.darkened(0.06))
	_quad_line(u - half, low, u + half, high, WorldView.COLOR_TRIM, 1.5)
	draw_line(_e(u, low), _e(u, high), WorldView.COLOR_TRIM, 1.0)
	draw_line(_e(u - half, (low + high) / 2.0), _e(u + half, (low + high) / 2.0), WorldView.COLOR_TRIM, 1.0)
	draw_line(_e(u - half - 0.3, low), _e(u + half + 0.3, low), WorldView.COLOR_TRIM, 2.0)


func _door(id: String, at: float, glass_low: float) -> void:
	var color: Color = HudArt.pick(WorldView.DOORS, id + "door")
	_quad(at - 1.8, 0.0, at + 1.8, 7.0, color)
	_quad_line(at - 1.8, 0.0, at + 1.8, 7.0, WorldView.COLOR_TRIM, 1.5)
	_quad(at - 0.9, glass_low, at + 0.9, 6.2, WorldView.COLOR_GLASS)
	if glass_low > 4.0:
		_quad_line(at - 1.1, 0.8, at + 1.1, 3.6, color.darkened(0.25))
	draw_circle(_e(at + 1.25, 3.4), maxf(1.2, 0.24 * _k), Color(0.85, 0.70, 0.30))


func _draw_house_front(id: String, width: float, wall_h: float, rise: float, stories: int, door_at: float) -> void:
	var siding: Color = HudArt.pick(WorldView.SIDING, id)
	var roof: Color = HudArt.pick(WorldView.ROOFS, id + "roof")
	# The same draws, in the same order, as world_view's style for this ID.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (id + ":style").hash()
	var shutter: Color = WorldView.SHUTTERS[rng.randi_range(0, WorldView.SHUTTERS.size() - 1)]
	var curtain: Color = WorldView.CURTAINS[rng.randi_range(0, WorldView.CURTAINS.size() - 1)]
	var porch: bool = str(_sim.area.buildings[id].get("building_type", "")) == "two-family"
	var edge: Color = WorldView.COLOR_OUTLINE.lerp(siding, 0.35)
	var board: Color = siding.darkened(0.10)

	# Chimney behind the roof.
	_quad(width * 0.68, wall_h + rise * 0.3, width * 0.68 + 2.4, wall_h + rise * 0.3 + 6.5, Color(0.62, 0.36, 0.30))
	_quad(width * 0.68 - 0.3, wall_h + rise * 0.3 + 6.0, width * 0.68 + 2.7, wall_h + rise * 0.3 + 6.9, Color(0.50, 0.30, 0.26))
	# Wall and gable in clapboard.
	var shape: PackedVector2Array = PackedVector2Array([_e(0, 0), _e(width, 0), _e(width, wall_h), _e(width / 2.0, wall_h + rise), _e(0, wall_h)])
	draw_colored_polygon(shape, siding)
	var z: float = 1.5
	while z < wall_h + rise - 0.5:
		var inset: float = 0.0 if z <= wall_h else (z - wall_h) / rise * width / 2.0
		draw_line(_e(inset, z), _e(width - inset, z), board, 1.0)
		z += 1.5
	_quad(0.0, 0.0, width, 1.3, Color(0.66, 0.64, 0.60))
	for corner: float in [0.0, width - 0.6]:
		_quad(corner, 1.3, corner + 0.6, wall_h, WorldView.COLOR_TRIM)
	draw_polyline(PackedVector2Array([_e(0, wall_h), _e(0, 0), _e(width, 0), _e(width, wall_h)]), edge, 1.0, true)
	# Roof edges with an overhang, and the trim under them.
	var over: float = 1.8
	var drop: float = over * rise / (width / 2.0)
	var thick: float = 1.5
	for side: float in [-1.0, 1.0]:
		var eave: Vector2 = _e(width / 2.0 + side * (width / 2.0 + over), wall_h - drop)
		var ridge: Vector2 = _e(width / 2.0, wall_h + rise)
		draw_colored_polygon(PackedVector2Array([
			ridge + Vector2(0, -thick * _k), eave + Vector2(side * 0.6 * _k, -thick * _k * 0.5), eave + Vector2(0, 0.5 * _k), ridge + Vector2(0, 0.3 * _k),
		]), roof)
		draw_line(ridge + Vector2(0, 0.3 * _k), eave + Vector2(0, 0.5 * _k), WorldView.COLOR_TRIM, maxf(1.5, 0.35 * _k))
		draw_line(ridge + Vector2(0, -thick * _k), eave + Vector2(side * 0.6 * _k, -thick * _k * 0.5), roof.darkened(0.3), 1.0, true)
	# An attic window in the gable.
	_quad(width / 2.0 - 1.4, wall_h + rise * 0.18, width / 2.0 + 1.4, wall_h + rise * 0.18 + 3.2, WorldView.COLOR_GLASS)
	_quad_line(width / 2.0 - 1.4, wall_h + rise * 0.18, width / 2.0 + 1.4, wall_h + rise * 0.18 + 3.2, WorldView.COLOR_TRIM, 1.5)
	draw_line(_e(width / 2.0, wall_h + rise * 0.18), _e(width / 2.0, wall_h + rise * 0.18 + 3.2), WorldView.COLOR_TRIM, 1.0)

	var count: int = maxi(1, int(width / 11.0))
	for story: int in stories:
		var base: float = float(story) * 10.0
		for index: int in count:
			var u: float = (float(index) + 0.5) / float(count) * width
			if story == 0 and absf(u - door_at) < 5.0:
				continue
			_window(u, 1.6, base + 3.2, base + 7.0, shutter, Color(curtain, 0.9), true)
	_door(id, door_at, 4.6)
	if porch:
		# A porch across the front: a low roof on posts, a rail and steps.
		_quad(-0.6, 8.4, width + 0.6, 9.6, roof.lightened(0.08))
		draw_line(_e(-0.6, 8.4), _e(width + 0.6, 8.4), WorldView.COLOR_TRIM, maxf(1.5, 0.35 * _k))
		for post: float in [0.2, door_at - 3.0, door_at + 3.0, width - 0.2]:
			draw_line(_e(post, 1.3), _e(post, 8.4), WorldView.COLOR_TRIM, maxf(2.0, 0.5 * _k))
		for rail: Array in [[0.2, door_at - 3.0], [door_at + 3.0, width - 0.2]]:
			draw_line(_e(rail[0], 3.6), _e(rail[1], 3.6), WorldView.COLOR_TRIM, 1.5)
			var baluster: float = float(rail[0]) + 0.8
			while baluster < float(rail[1]):
				draw_line(_e(baluster, 1.3), _e(baluster, 3.6), WorldView.COLOR_TRIM, 1.0)
				baluster += 0.8
		_quad(-0.6, 0.7, width + 0.6, 1.3, Color(0.74, 0.72, 0.67))
	else:
		# A little roof over the step.
		draw_colored_polygon(PackedVector2Array([_e(door_at - 2.8, 8.3), _e(door_at + 2.8, 8.3), _e(door_at + 2.3, 9.3), _e(door_at - 2.3, 9.3)]), roof.lightened(0.1))
		draw_line(_e(door_at - 2.8, 8.3), _e(door_at + 2.8, 8.3), WorldView.COLOR_TRIM, maxf(1.5, 0.3 * _k))
		for bracket: float in [-2.3, 2.3]:
			draw_line(_e(door_at + bracket, 8.3), _e(door_at + bracket * 0.85, 7.3), WorldView.COLOR_TRIM, 1.0)
	_quad(door_at - 2.6, 0.0, door_at + 2.6, 0.7, Color(0.74, 0.72, 0.67))


func _draw_store_front(font: Font, width: float, wall_h: float, stories: int, door_at: float) -> void:
	var id: String = _info["building_id"]
	var brick: Color = STORE_BRICK
	var top: float = wall_h + 2.0
	_quad(0.0, 0.0, width, top, brick)
	# Brick courses, staggered.
	var z: float = 1.0
	var row: int = 0
	while z < top:
		draw_line(_e(0, z), _e(width, z), brick.darkened(0.14), 1.0)
		var u: float = 1.5 if row % 2 == 0 else 3.0
		while u < width:
			draw_line(_e(u, z), _e(u, minf(z + 1.0, top)), brick.darkened(0.10), 1.0)
			u += 3.0
		z += 1.0
		row += 1
	_quad(0.0, 0.0, width, 1.0, Color(0.44, 0.38, 0.35))
	_quad_line(0.0, 0.0, width, top, WorldView.COLOR_OUTLINE.lerp(brick, 0.35))
	# Parapet coping and a roof line behind it.
	_quad(-0.4, top - 0.2, width + 0.4, top + 0.6, Color(0.90, 0.86, 0.78))
	draw_line(_e(0, wall_h), _e(width, wall_h), brick.darkened(0.22), 1.0)

	var count: int = maxi(1, int(width / 11.0))
	for story: int in stories:
		var base: float = float(story) * 10.0
		for index: int in count:
			var u: float = (float(index) + 0.5) / float(count) * width
			if story == 0:
				if absf(u - door_at) < 5.0:
					continue
				_window(u, 3.5, 2.0, 7.0, Color.BLACK, Color(0, 0, 0, 0), false)
				_shop_goods(u, 3.5, 2.0, 7.0)
			else:
				_window(u, 1.6, base + 3.2, base + 7.0, Color.BLACK, Color(0.98, 0.96, 0.90, 0.9), false)
	_door(id, door_at, 1.2)
	# The sign board, with the business's name from the report.
	var sign: Rect2 = Rect2(_e(width * 0.12, 12.6), Vector2(width * 0.76 * _k, 2.4 * _k))
	draw_style_box(_pill(Color(0.96, 0.92, 0.80), HudArt.CHERRY, 2), sign)
	var name_size: int = clampi(int(sign.size.y * 0.72), 8, 14)
	draw_string(_bold, Vector2(sign.position.x, sign.get_center().y + name_size * 0.36), str(_info["institution"]["name"]),
			HORIZONTAL_ALIGNMENT_CENTER, sign.size.x, name_size, HudArt.CHERRY.darkened(0.2))
	# The striped awning.
	var stripes: int = maxi(6, int((width - 2.4) / 1.7))
	var cream: Color = Color(0.97, 0.94, 0.86)
	for index: int in stripes:
		var u0: float = lerpf(1.2, width - 1.2, float(index) / float(stripes))
		var u1: float = lerpf(1.2, width - 1.2, float(index + 1) / float(stripes))
		var color: Color = HudArt.CHERRY if index % 2 == 0 else cream
		var flare0: float = lerpf(u0, width / 2.0, -0.05)
		var flare1: float = lerpf(u1, width / 2.0, -0.05)
		draw_colored_polygon(PackedVector2Array([_e(u0, 9.8), _e(u1, 9.8), _e(flare1, 8.0), _e(flare0, 8.0)]), color)
		draw_colored_polygon(PackedVector2Array([
			_e(flare0, 8.0), _e(flare1, 8.0), _e(flare1, 7.5), _e((flare0 + flare1) / 2.0, 7.1), _e(flare0, 7.5),
		]), color.darkened(0.14))
	draw_line(_e(1.2, 9.8), _e(width - 1.2, 9.8), HudArt.CHERRY.darkened(0.4), 1.0)
	_quad(door_at - 2.6, 0.0, door_at + 2.6, 0.5, Color(0.74, 0.72, 0.67))


## Goods on two shelves behind a shop window, as on the street.
func _shop_goods(u: float, half: float, low: float, high: float) -> void:
	var goods: Array[Color] = [Color(0.86, 0.36, 0.26), Color(0.95, 0.82, 0.40), Color(0.45, 0.62, 0.42), Color(0.92, 0.90, 0.84)]
	for shelf: int in 2:
		var z: float = low + (high - low) * (0.08 + 0.4 * float(shelf))
		draw_line(_e(u - half, z), _e(u + half, z), Color(0.45, 0.34, 0.26, 0.8), 1.0)
		for item: int in 6:
			var u0: float = u - half + 2.0 * half * (float(item) + 0.15) / 6.0
			var u1: float = u - half + 2.0 * half * (float(item) + 0.8) / 6.0
			var tall: float = (high - low) * (0.14 + 0.08 * float((item + shelf) % 3))
			_quad(u0, z, u1, z + tall, Color(goods[(item + shelf * 2) % goods.size()], 0.85))
