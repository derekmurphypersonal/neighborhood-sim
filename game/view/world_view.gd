extends Node2D
## Draws the area and the people in it in a plain isometric projection.
## Presentation only: reads simulation state, changes nothing.

signal person_clicked(person_id: String)
signal building_clicked(building_id: String)

const Simulation := preload("res://sim/simulation.gd")
const Area := preload("res://sim/world/area.gd")
const Records := preload("res://sim/state/records.gd")

const VIEW_SIZE: Vector2 = Vector2(1280, 720)
## Screen area left free for the map (the panel is on the right, the feed below).
const MAP_RECT: Rect2 = Rect2(20, 70, 880, 430)
const STORY_HEIGHT_INCHES: float = 120.0
const PERSON_RADIUS: float = 7.0
const CLICK_RADIUS: float = 16.0

const COLOR_GROUND: Color = Color(0.56, 0.66, 0.47)
const COLOR_LOT: Color = Color(0.63, 0.72, 0.52)
const COLOR_STREET: Color = Color(0.72, 0.70, 0.66)
const COLOR_WALL: Color = Color(0.86, 0.82, 0.70)
const COLOR_WALL_SHADE: Color = Color(0.74, 0.70, 0.60)
const COLOR_ROOF: Color = Color(0.58, 0.36, 0.30)
const COLOR_HOME_ROOF: Color = Color(0.30, 0.42, 0.62)
const COLOR_OUTLINE: Color = Color(0.20, 0.20, 0.20)
const COLOR_PLAYER: Color = Color(0.20, 0.38, 0.75)
const COLOR_NEIGHBOR: Color = Color(0.78, 0.42, 0.18)
const COLOR_TALK: Color = Color(1.0, 1.0, 1.0)

var simulation: Simulation
var area: Area
var selected_id: String = ""
var minute_fraction: float = 1.0

var _scale: float = 0.1
var _offset: Vector2 = Vector2.ZERO
var _font: Font
## Where each person was drawn from during the latest minute: id -> [points].
var _trails: Dictionary = {}
var _screen_positions: Dictionary = {}


func setup(sim: Simulation) -> void:
	simulation = sim
	area = sim.area
	_font = ThemeDB.fallback_font
	_fit_to_screen()


func after_ticks() -> void:
	_trails = simulation.trails.duplicate(true)


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

	# Buildings from the back of the view to the front.
	var order: Array = area.sorted_building_ids()
	order.sort_custom(func(a: String, b: String) -> bool:
		return to_screen(area.door_of(a)).y < to_screen(area.door_of(b)).y)
	for building_id: String in order:
		_draw_building(area.buildings[building_id], building_id == home_id)

	_draw_people()


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	return closed


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


func _draw_building(building: Dictionary, is_home: bool) -> void:
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
	draw_colored_polygon(top, COLOR_HOME_ROOF if is_home else COLOR_ROOF)
	draw_polyline(_closed(top), COLOR_OUTLINE, 1.0)

	var inside: int = 0
	for person_id: String in simulation.state.people:
		var person: Dictionary = simulation.state.people[person_id]
		if person["at"] == Records.AT_INSIDE and person["place_id"] == building["id"]:
			inside += 1
	var centre: Vector2 = Vector2.ZERO
	for point: Vector2 in top:
		centre += point
	centre /= float(top.size())
	if inside > 0:
		draw_string(_font, centre + Vector2(-22, 5), "%d inside" % inside, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


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
	var visible: Array = []
	for person_id: String in simulation.state.sorted_person_ids():
		var person: Dictionary = simulation.state.people[person_id]
		# Someone who walked this minute is shown on the way even if now indoors.
		if person["at"] == Records.AT_OUTSIDE or (_trails.has(person_id) and minute_fraction < 1.0):
			if person["at"] == Records.AT_OFFMAP and not _trails.has(person_id):
				continue
			_screen_positions[person_id] = _animated_position(person)
			visible.append(person)
	# People standing on the same spot are fanned out so each can be seen.
	var taken: Dictionary = {}
	for person: Dictionary in visible:
		var spot: Vector2i = Vector2i((_screen_positions[person["id"]] as Vector2).round())
		var count: int = taken.get(spot, 0)
		taken[spot] = count + 1
		if count > 0:
			_screen_positions[person["id"]] += Vector2(0, 20.0 * count)
	# A line between two people talking outdoors.
	for person: Dictionary in visible:
		var action: Dictionary = person["action"]
		if not action.is_empty() and action["kind"] == "talk" and _screen_positions.has(action["other_id"]):
			draw_line(_screen_positions[person["id"]], _screen_positions[action["other_id"]], COLOR_TALK, 2.0)
	for person: Dictionary in visible:
		var position_on_screen: Vector2 = _screen_positions[person["id"]]
		var players: bool = simulation.state.households[person["household_id"]]["player_controlled"]
		if person["id"] == selected_id:
			draw_circle(position_on_screen, PERSON_RADIUS + 4.0, Color.WHITE)
		draw_circle(position_on_screen, PERSON_RADIUS, COLOR_PLAYER if players else COLOR_NEIGHBOR)
		draw_arc(position_on_screen, PERSON_RADIUS, 0.0, TAU, 20, COLOR_OUTLINE, 1.0)
		var talking: bool = not person["action"].is_empty() and person["action"]["kind"] == "talk"
		var label: String = person["given_name"] + (" (talking)" if talking else "")
		draw_string(_font, position_on_screen + Vector2(11, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_OUTLINE)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var click: InputEventMouseButton = event
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
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
	for building_id: String in area.sorted_building_ids():
		var building: Dictionary = area.buildings[building_id]
		var height: float = float(building["stories"]) * STORY_HEIGHT_INCHES * _scale
		if Geometry2D.is_point_in_polygon(click.position, _polygon(building["footprint"], height)) \
				or Geometry2D.is_point_in_polygon(click.position, _polygon(building["footprint"])):
			building_clicked.emit(building_id)
			return
