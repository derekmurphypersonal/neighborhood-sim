extends Node2D
## Draws the area and the people in it in a plain isometric projection, with
## activity bubbles, floating notices and a day-and-night tint.
## Presentation only: reads simulation state, changes nothing.

signal person_clicked(person_id: String)
signal building_clicked(building_id: String)
signal room_clicked(room_id: String)
signal building_info_requested(building_id: String)

const Simulation := preload("res://sim/simulation.gd")
const Area := preload("res://sim/world/area.gd")
const Records := preload("res://sim/state/records.gd")

const VIEW_SIZE: Vector2 = Vector2(1280, 720)
## Screen area left free for the map (the panel is on the right, the feed below).
const MAP_RECT: Rect2 = Rect2(262, 70, 638, 430)
## Where the cutaway of the player's home is drawn.
const INTERIOR_RECT: Rect2 = Rect2(20, 70, 232, 300)
const STORY_HEIGHT_INCHES: float = 120.0
const PERSON_RADIUS: float = 7.0
const CLICK_RADIUS: float = 18.0
const FAN_SPACING: float = 30.0

## How long things stay on screen, in real milliseconds.
const BUBBLE_FRESH_MS: int = 3500
const BUBBLE_POP_MS: int = 180
const FLOAT_MS: int = 2600
const HOUSE_NOTE_MS: int = 3200
const TOAST_MS: int = 4500
const MAX_FLOATS: int = 14

const COLOR_GROUND: Color = Color(0.56, 0.66, 0.47)
const COLOR_LOT: Color = Color(0.63, 0.72, 0.52)
const COLOR_STREET: Color = Color(0.72, 0.70, 0.66)
const COLOR_WALL: Color = Color(0.86, 0.82, 0.70)
const COLOR_WALL_SHADE: Color = Color(0.74, 0.70, 0.60)
const COLOR_ROOF: Color = Color(0.58, 0.36, 0.30)
const COLOR_HOME_ROOF: Color = Color(0.30, 0.42, 0.62)
const COLOR_INSTITUTION_ROOF: Color = Color(0.36, 0.52, 0.38)
const COLOR_OUTLINE: Color = Color(0.20, 0.20, 0.20)
const COLOR_PLAYER: Color = Color(0.20, 0.38, 0.75)
const COLOR_NEIGHBOR: Color = Color(0.78, 0.42, 0.18)
const COLOR_TALK: Color = Color(1.0, 0.95, 0.45)
const COLOR_NIGHT: Color = Color(0.05, 0.08, 0.25)
const COLOR_GOOD: Color = Color(0.20, 0.55, 0.20)
const COLOR_BAD: Color = Color(0.75, 0.20, 0.15)
const COLOR_NOTE: Color = Color(0.15, 0.15, 0.15)

var simulation: Simulation
var area: Area
var selected_id: String = ""
var minute_fraction: float = 1.0

var _scale: float = 0.1
var _offset: Vector2 = Vector2.ZERO
var _font: Font
var _trails: Dictionary = {}
var _screen_positions: Dictionary = {}
## person_id -> {"text": String, "since": int}
var _bubbles: Dictionary = {}
## Each: {"text", "point" (world [x, y]) , "lift" (pixels), "since", "color"}
var _floats: Array = []
## building_id -> {"text", "since"}
var _house_notes: Dictionary = {}
## Each: {"text", "since"}
var _toasts: Array = []
var _bubble_box: StyleBoxFlat
var _bubble_box_fresh: StyleBoxFlat
var _toast_box: StyleBoxFlat


func setup(sim: Simulation) -> void:
	simulation = sim
	area = sim.area
	_font = ThemeDB.fallback_font
	_bubble_box = _box(Color(1, 1, 1, 0.82), COLOR_OUTLINE, 1)
	_bubble_box_fresh = _box(Color(1.0, 0.98, 0.80), Color(0.85, 0.55, 0.10), 2)
	_toast_box = _box(Color(0.12, 0.14, 0.20, 0.92), Color(1.0, 0.92, 0.55), 2)
	_fit_to_screen()


func _box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(6)
	return box


func after_ticks() -> void:
	_trails = simulation.trails.duplicate(true)


# --- Things the main scene tells the view to show ---------------------------

## Sets the bubble over a person. A changed text makes the bubble pop.
func show_activity(person_id: String, text: String) -> void:
	if not _bubbles.has(person_id) or _bubbles[person_id]["text"] != text:
		_bubbles[person_id] = {"text": text, "since": Time.get_ticks_msec()}


## A short text that rises and fades from a point in the world.
func add_float(point: Array, lift: float, text: String, color: Color) -> void:
	_floats.append({"text": text, "point": point, "lift": lift, "since": Time.get_ticks_msec(), "color": color})
	while _floats.size() > MAX_FLOATS:
		_floats.pop_front()


## A note over a house about someone inside it.
func add_house_note(building_id: String, text: String) -> void:
	_house_notes[building_id] = {"text": text, "since": Time.get_ticks_msec()}


## A notice across the top of the map.
func add_toast(text: String) -> void:
	_toasts.append({"text": text, "since": Time.get_ticks_msec()})
	while _toasts.size() > 3:
		_toasts.pop_front()


## Where a person is on the map: their own spot outdoors, or the roof of the
## building they are in. Returns {"point", "lift"}; empty if off the map.
func anchor_of(person: Dictionary) -> Dictionary:
	if person["at"] == Records.AT_OUTSIDE:
		return {"point": [person["x"], person["y"]], "lift": 26.0}
	if person["at"] == Records.AT_INSIDE:
		return building_anchor(person["place_id"])
	return {}


func building_anchor(building_id: String) -> Dictionary:
	var building: Dictionary = area.buildings[building_id]
	return {"point": building["door"], "lift": float(building["stories"]) * STORY_HEIGHT_INCHES * _scale + 34.0}


# --- Projection --------------------------------------------------------------

## World inches to screen pixels. East runs down-right, north runs up-right.
func to_screen(point: Array) -> Vector2:
	var x: float = float(point[0])
	var y: float = float(point[1])
	return Vector2((x + y) * _scale, (x - y) * _scale * 0.5) + _offset


func _fit_to_screen() -> void:
	var corners: Array[Vector2] = []
	for lot_id: String in area.lots:
		for point: Array in area.lots[lot_id]["boundary"]:
			corners.append(Vector2(float(point[0]) + float(point[1]), (float(point[0]) - float(point[1])) * 0.5))
	for street_id: String in area.streets:
		for point: Array in area.streets[street_id]["centerline"]:
			corners.append(Vector2(float(point[0]) + float(point[1]), (float(point[0]) - float(point[1])) * 0.5))
	if corners.is_empty():
		return
	var bounds: Rect2 = Rect2(corners[0], Vector2.ZERO)
	for corner: Vector2 in corners:
		bounds = bounds.expand(corner)
	_scale = minf(MAP_RECT.size.x / maxf(bounds.size.x, 1.0), MAP_RECT.size.y / maxf(bounds.size.y, 1.0)) * 0.92
	_offset = MAP_RECT.get_center() - bounds.get_center() * _scale


func _polygon(points: Array, lift: float = 0.0) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for point: Array in points:
		result.append(to_screen(point) - Vector2(0, lift))
	return result


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	return closed


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	if simulation == null:
		return
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), COLOR_GROUND)
	for lot_id: String in area.lots:
		var lot: PackedVector2Array = _polygon(area.lots[lot_id]["boundary"])
		draw_colored_polygon(lot, COLOR_LOT)
		draw_polyline(_closed(lot), COLOR_OUTLINE.lerp(COLOR_LOT, 0.6), 1.0)
	for street_id: String in area.streets:
		_draw_street(area.streets[street_id])

	var home_id: String = ""
	if selected_id != "":
		home_id = simulation.state.households[simulation.state.people[selected_id]["household_id"]]["home_id"]
	var night: float = night_amount()

	# Buildings from the back of the view to the front.
	var order: Array = area.sorted_building_ids()
	order.sort_custom(func(a: String, b: String) -> bool:
		return to_screen(area.door_of(a)).y < to_screen(area.door_of(b)).y)
	for building_id: String in order:
		_draw_building(area.buildings[building_id], building_id == home_id, night)

	if night > 0.0:
		draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(COLOR_NIGHT, night * 0.5))
		for building_id: String in order:
			_draw_lit_window(area.buildings[building_id])

	_draw_people()
	_draw_interior()
	_draw_house_notes()
	_draw_floats()
	_draw_toasts()


## 0 in full daylight, 1 in the middle of the night.
func night_amount() -> float:
	var minute: float = float(simulation.clock.minute_of_day)
	if minute >= 420.0 and minute <= 1080.0:      # 07:00 to 18:00
		return 0.0
	if minute > 1080.0:                           # dusk until 21:00
		return clampf((minute - 1080.0) / 180.0, 0.0, 1.0)
	return clampf((420.0 - minute) / 120.0, 0.0, 1.0)  # dawn from 05:00


func _draw_street(street: Dictionary) -> void:
	var line: Array = street["centerline"]
	var half: float = float(street["width"]) / 2.0
	for index: int in line.size() - 1:
		var a: Vector2 = Vector2(line[index][0], line[index][1])
		var b: Vector2 = Vector2(line[index + 1][0], line[index + 1][1])
		var side: Vector2 = (b - a).normalized().orthogonal() * half
		var corners: Array = [
			[a.x + side.x, a.y + side.y], [b.x + side.x, b.y + side.y],
			[b.x - side.x, b.y - side.y], [a.x - side.x, a.y - side.y],
		]
		draw_colored_polygon(_polygon(corners), COLOR_STREET)
	var middle: Vector2 = (to_screen(line[0]) + to_screen(line[line.size() - 1])) / 2.0
	draw_string(_font, middle + Vector2(-60, 4), street["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_OUTLINE)


func _occupants(building_id: String) -> Array:
	var inside: Array = []
	for person_id: String in simulation.state.sorted_person_ids():
		var person: Dictionary = simulation.state.people[person_id]
		if person["at"] == Records.AT_INSIDE and person["place_id"] == building_id:
			inside.append(person)
	return inside


func _draw_building(building: Dictionary, is_home: bool, night: float) -> void:
	var footprint: Array = building["footprint"]
	var height: float = float(building["stories"]) * STORY_HEIGHT_INCHES * _scale
	var base: PackedVector2Array = _polygon(footprint)
	var top: PackedVector2Array = _polygon(footprint, height)
	for index: int in base.size():
		var next: int = (index + 1) % base.size()
		# Only walls that face the viewer are visible.
		if (base[next] - base[index]).x < 0.0:
			continue
		var wall: PackedVector2Array = PackedVector2Array([base[index], base[next], top[next], top[index]])
		draw_colored_polygon(wall, COLOR_WALL if (base[next] - base[index]).y < 0.0 else COLOR_WALL_SHADE)
		draw_polyline(_closed(wall), COLOR_OUTLINE, 1.0)
	var roof: Color = COLOR_HOME_ROOF if is_home else COLOR_ROOF
	if area.is_institution(building["id"]):
		roof = COLOR_INSTITUTION_ROOF
	draw_colored_polygon(top, roof)
	draw_polyline(_closed(top), COLOR_OUTLINE, 1.0)

	var inside: Array = _occupants(building["id"])
	if area.is_institution(building["id"]):
		var open: bool = area.is_open(building["id"], simulation.clock.weekday(), simulation.clock.minute_of_day)
		var sign: String = "%s (%s)" % [area.institutions[building["id"]]["name"], "open" if open else "closed"]
		var sign_at: Vector2 = Vector2.ZERO
		for point: Vector2 in top:
			sign_at += point
		sign_at /= float(top.size())
		draw_string(_font, sign_at + Vector2(-48, -8), sign, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	if not inside.is_empty():
		var asleep: int = 0
		for person: Dictionary in inside:
			if not person["action"].is_empty() and person["action"]["started"] and person["action"]["kind"] == "sleep":
				asleep += 1
		var label: String = "%d inside" % inside.size()
		if asleep == inside.size():
			label = "%d asleep" % asleep
		elif asleep > 0 and night > 0.0:
			label = "%d in, %d asleep" % [inside.size(), asleep]
		var centre: Vector2 = Vector2.ZERO
		for point: Vector2 in top:
			centre += point
		centre /= float(top.size())
		draw_string(_font, centre + Vector2(-30, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


## At night, a house with someone awake inside shows a lit window.
func _draw_lit_window(building: Dictionary) -> void:
	var awake: bool = false
	for person: Dictionary in _occupants(building["id"]):
		var action: Dictionary = person["action"]
		if action.is_empty() or not (action["started"] and action["kind"] == "sleep"):
			awake = true
	if not awake:
		return
	var height: float = float(building["stories"]) * STORY_HEIGHT_INCHES * _scale
	var at: Vector2 = to_screen(building["door"]) - Vector2(0, height * 0.45)
	draw_rect(Rect2(at - Vector2(5, 6), Vector2(10, 12)), Color(1.0, 0.88, 0.45))
	draw_rect(Rect2(at - Vector2(5, 6), Vector2(10, 12)), COLOR_OUTLINE, false, 1.0)


## Where to draw a person this frame: along the path walked in the latest minute.
func _animated_position(person: Dictionary) -> Vector2:
	var trail: Array = _trails.get(person["id"], [])
	if trail.size() < 2 or minute_fraction >= 1.0:
		return to_screen([person["x"], person["y"]])
	var total: float = 0.0
	for index: int in trail.size() - 1:
		total += to_screen(trail[index]).distance_to(to_screen(trail[index + 1]))
	var remaining: float = total * minute_fraction
	for index: int in trail.size() - 1:
		var a: Vector2 = to_screen(trail[index])
		var b: Vector2 = to_screen(trail[index + 1])
		var length: float = a.distance_to(b)
		if remaining <= length and length > 0.0:
			return a.lerp(b, remaining / length)
		remaining -= length
	return to_screen(trail[trail.size() - 1])


func _draw_people() -> void:
	_screen_positions.clear()
	var now: int = Time.get_ticks_msec()
	var visible: Array = []
	for person_id: String in simulation.state.sorted_person_ids():
		var person: Dictionary = simulation.state.people[person_id]
		var walking: bool = _trails.has(person_id) and minute_fraction < 1.0
		if person["at"] == Records.AT_OUTSIDE or walking:
			_screen_positions[person_id] = _animated_position(person)
			visible.append(person)
	# People standing on the same spot are fanned out so each can be seen.
	var taken: Dictionary = {}
	for person: Dictionary in visible:
		var spot: Vector2i = Vector2i((_screen_positions[person["id"]] as Vector2).round())
		var count: int = taken.get(spot, 0)
		taken[spot] = count + 1
		if count > 0:
			_screen_positions[person["id"]] += Vector2(0, FAN_SPACING * count)

	# A bright line between two people talking outdoors.
	for person: Dictionary in visible:
		var action: Dictionary = person["action"]
		if not action.is_empty() and action["kind"] == "talk" and _screen_positions.has(action["other_id"]):
			draw_line(_screen_positions[person["id"]], _screen_positions[action["other_id"]], COLOR_TALK, 3.0)

	var pulse: float = 0.5 + 0.5 * sin(float(now) / 180.0)
	for person: Dictionary in visible:
		var at: Vector2 = _screen_positions[person["id"]]
		var players: bool = simulation.state.households[person["household_id"]]["player_controlled"]
		var talking: bool = not person["action"].is_empty() and person["action"]["kind"] == "talk"
		if talking:
			draw_arc(at, PERSON_RADIUS + 5.0 + 3.0 * pulse, 0.0, TAU, 24, COLOR_TALK, 2.5)
		if person["id"] == selected_id:
			draw_circle(at, PERSON_RADIUS + 4.0, Color.WHITE)
		draw_circle(at, PERSON_RADIUS, COLOR_PLAYER if players else COLOR_NEIGHBOR)
		draw_arc(at, PERSON_RADIUS, 0.0, TAU, 20, COLOR_OUTLINE, 1.0)

	# Bubbles last, so they are never hidden behind another person.
	for person: Dictionary in visible:
		var bubble: Dictionary = _bubbles.get(person["id"], {})
		var text: String = person["given_name"]
		var since: int = 0
		if not bubble.is_empty():
			var activity: String = bubble["text"]
			text = "%s: %s%s" % [person["given_name"], activity.left(1).to_lower(), activity.substr(1)]
			since = bubble["since"]
		# The bubble sits to the right unless that would cover someone else.
		var at: Vector2 = _screen_positions[person["id"]]
		var size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13) + Vector2(12, 7)
		var right: Rect2 = Rect2(at + Vector2(12, -10 - size.y), size).grow(PERSON_RADIUS)
		var covered: bool = false
		for other_id: String in _screen_positions:
			if other_id != person["id"] and right.has_point(_screen_positions[other_id]):
				covered = true
		var anchor: Vector2 = at + (Vector2(-12 - size.x, -10) if covered else Vector2(12, -10))
		_draw_bubble(anchor, text, now - since)


## A rounded label. A new one pops out and is highlighted for a few seconds.
func _draw_bubble(anchor: Vector2, text: String, age_ms: int) -> void:
	var size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13) + Vector2(12, 7)
	var grow: float = 1.0
	if age_ms < BUBBLE_POP_MS:
		grow = 0.5 + 0.65 * float(age_ms) / float(BUBBLE_POP_MS)   # overshoots slightly, then settles
	elif age_ms < BUBBLE_POP_MS * 2:
		grow = 1.15 - 0.15 * float(age_ms - BUBBLE_POP_MS) / float(BUBBLE_POP_MS)
	# Grow from the middle of the bubble so it pops in place.
	var middle: Vector2 = anchor + Vector2(size.x / 2.0, -size.y / 2.0)
	draw_set_transform(middle - Vector2(size.x / 2.0, -size.y / 2.0) * grow, 0.0, Vector2(grow, grow))
	var rect: Rect2 = Rect2(Vector2(0, -size.y), size)
	draw_style_box(_bubble_box_fresh if age_ms < BUBBLE_FRESH_MS else _bubble_box, rect)
	draw_string(_font, Vector2(6, -7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_NOTE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_house_notes() -> void:
	var now: int = Time.get_ticks_msec()
	for building_id: String in _house_notes.keys():
		var note: Dictionary = _house_notes[building_id]
		var age: int = now - int(note["since"])
		if age > HOUSE_NOTE_MS:
			_house_notes.erase(building_id)
			continue
		var anchor: Dictionary = building_anchor(building_id)
		var text: String = note["text"]
		var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 12.0
		_draw_bubble(to_screen(anchor["point"]) - Vector2(width / 2.0, float(anchor["lift"])), text, age)


func _draw_floats() -> void:
	var now: int = Time.get_ticks_msec()
	var kept: Array = []
	for item: Dictionary in _floats:
		var age: int = now - int(item["since"])
		if age > FLOAT_MS:
			continue
		kept.append(item)
		var progress: float = float(age) / float(FLOAT_MS)
		var at: Vector2 = to_screen(item["point"]) - Vector2(0, float(item["lift"]) + 34.0 * progress)
		var color: Color = item["color"]
		var alpha: float = 1.0 - progress * progress
		var text: String = item["text"]
		var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string_outline(_font, at - Vector2(width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(1, 1, 1, alpha))
		draw_string(_font, at - Vector2(width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(color, alpha))
	_floats = kept


func _draw_toasts() -> void:
	var now: int = Time.get_ticks_msec()
	var kept: Array = []
	var row: int = 0
	for index: int in range(_toasts.size() - 1, -1, -1):
		var toast: Dictionary = _toasts[index]
		var age: int = now - int(toast["since"])
		if age > TOAST_MS:
			continue
		kept.push_front(toast)
		var text: String = toast["text"]
		var size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16) + Vector2(24, 12)
		# Stacked upward from the bottom of the map, newest lowest, clear of the houses.
		var top_left: Vector2 = Vector2(MAP_RECT.get_center().x - size.x / 2.0, MAP_RECT.end.y - (row + 1) * (size.y + 6.0))
		var fade: float = clampf(float(TOAST_MS - age) / 600.0, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		modulate_box(_toast_box, fade)
		draw_style_box(_toast_box, Rect2(top_left, size))
		draw_string(_font, top_left + Vector2(12, size.y - 10.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, fade))
		row += 1
	modulate_box(_toast_box, 1.0)
	_toasts = kept


func modulate_box(box: StyleBoxFlat, alpha: float) -> void:
	box.bg_color.a = 0.92 * alpha
	box.border_color.a = alpha


# --- The player's home, seen from above ---------------------------------------

## The home of the player's household, if it has an interior ("" otherwise).
func _interior_home() -> String:
	var household_id: String = simulation.state.player_household_id()
	if household_id == "":
		return ""
	var home: String = simulation.state.households[household_id]["home_id"]
	return home if area.has_interior(home) else ""


## Screen rectangle of each room in the cutaway: {room_id: Rect2}.
func _room_rects() -> Dictionary:
	var result: Dictionary = {}
	var home: String = _interior_home()
	if home == "":
		return result
	var rooms: Dictionary = area.interiors[home]["rooms"]
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for room_id: String in rooms:
		var r: Array = rooms[room_id]["rect"]
		var rect: Rect2 = Rect2(r[0], r[1], r[2], r[3])
		bounds = rect if first else bounds.merge(rect)
		first = false
	var inner: Rect2 = Rect2(INTERIOR_RECT.position + Vector2(10, 44), INTERIOR_RECT.size - Vector2(20, 54))
	var fit: float = minf(inner.size.x / bounds.size.x, inner.size.y / bounds.size.y)
	var origin: Vector2 = inner.get_center() - bounds.size * fit / 2.0
	for room_id: String in rooms:
		var r: Array = rooms[room_id]["rect"]
		# North is up: the world's y grows northward, the screen's downward.
		var x: float = origin.x + (float(r[0]) - bounds.position.x) * fit
		var y: float = origin.y + (bounds.end.y - float(r[1]) - float(r[3])) * fit
		result[room_id] = Rect2(x, y, float(r[2]) * fit, float(r[3]) * fit)
	return result


func _draw_interior() -> void:
	var home: String = _interior_home()
	if home == "":
		return
	draw_style_box(_toast_box, INTERIOR_RECT)
	draw_string(_font, INTERIOR_RECT.position + Vector2(10, 18), "Inside your home", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(_font, INTERIOR_RECT.position + Vector2(10, 34), "FICTIONAL INTERIOR (invented layout)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.92, 0.55))
	var rooms: Dictionary = area.interiors[home]["rooms"]
	var rects: Dictionary = _room_rects()
	var occupants: Dictionary = {}
	for person: Dictionary in _occupants(home):
		var spot: String = person["spot"] if rects.has(person["spot"]) else ""
		if not occupants.has(spot):
			occupants[spot] = []
		occupants[spot].append(person)
	for room_id: String in rects:
		var rect: Rect2 = rects[room_id]
		draw_rect(rect, Color(0.90, 0.86, 0.76))
		draw_rect(rect, COLOR_OUTLINE, false, 2.0)
		draw_string(_font, rect.position + Vector2(5, 14), rooms[room_id]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_NOTE)
		var row: int = 0
		for person: Dictionary in occupants.get(room_id, []):
			var at: Vector2 = rect.position + Vector2(12, 28 + row * 15)
			var players: bool = simulation.state.households[person["household_id"]]["player_controlled"]
			if person["id"] == selected_id:
				draw_circle(at, 7.0, Color.WHITE)
			draw_circle(at, 5.0, COLOR_PLAYER if players else COLOR_NEIGHBOR)
			var bubble: Dictionary = _bubbles.get(person["id"], {})
			var doing: String = (bubble.get("text", "") as String).to_lower()
			draw_string(_font, at + Vector2(9, 4), "%s: %s" % [person["given_name"], doing], HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x) - 24, 10, COLOR_NOTE)
			row += 1
	draw_string(_font, Vector2(INTERIOR_RECT.position.x + 10, INTERIOR_RECT.end.y - 6), "Click a room to send someone there", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.85, 0.85))


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var click: InputEventMouseButton = event
	if click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		var looked_at: String = _building_at(click.position)
		if looked_at != "":
			building_info_requested.emit(looked_at)
		return
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var rects: Dictionary = _room_rects()
	for room_id: String in rects:
		if (rects[room_id] as Rect2).has_point(click.position):
			room_clicked.emit(room_id)
			return
	if INTERIOR_RECT.has_point(click.position) and not rects.is_empty():
		return
	var best_id: String = ""
	var best: float = CLICK_RADIUS
	for person_id: String in _screen_positions:
		var distance: float = (_screen_positions[person_id] as Vector2).distance_to(click.position)
		if distance < best:
			best = distance
			best_id = person_id
	if best_id != "":
		person_clicked.emit(best_id)
		return
	var clicked: String = _building_at(click.position)
	if clicked != "":
		building_clicked.emit(clicked)


## The building drawn at a point on the screen ("" if none).
func _building_at(point: Vector2) -> String:
	for building_id: String in area.sorted_building_ids():
		var building: Dictionary = area.buildings[building_id]
		var height: float = float(building["stories"]) * STORY_HEIGHT_INCHES * _scale
		if Geometry2D.is_point_in_polygon(point, _polygon(building["footprint"], height)) \
				or Geometry2D.is_point_in_polygon(point, _polygon(building["footprint"])):
			return building_id
	return ""
