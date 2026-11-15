extends Node2D
## Draws the area and the people in it in an isometric projection: lawns,
## sidewalks, gabled houses with windows, trees, street lamps and small
## figures, lit by a day-and-night cycle; plus activity bubbles, floating
## notices and the cutaway of the player's home.
##
## Presentation only: reads simulation state, changes nothing. Decorations
## (trees, shrubs, parked cars, lamps, paint colors) are invented, chosen
## deterministically from IDs, and never stored in simulation state (P-023).

signal person_clicked(person_id: String)
signal building_clicked(building_id: String)
signal room_clicked(room_id: String)
signal building_info_requested(building_id: String)

const Simulation := preload("res://sim/simulation.gd")
const Area := preload("res://sim/world/area.gd")
const Records := preload("res://sim/state/records.gd")
const SimDate := preload("res://sim/clock/sim_date.gd")

const VIEW_SIZE: Vector2 = Vector2(1280, 720)
## Screen area left free for the map (the panel is on the right, the feed below).
const MAP_RECT: Rect2 = Rect2(262, 70, 638, 430)
## Where the cutaway of the player's home is drawn.
const INTERIOR_RECT: Rect2 = Rect2(20, 70, 232, 300)
const FOOT: float = 12.0
const STORY_HEIGHT_INCHES: float = 120.0
const CLICK_RADIUS: float = 16.0
const FAN_SPACING: float = 14.0
const CHILD_AGE: int = 13

const ZOOM_MIN: float = 0.8
const ZOOM_MAX: float = 3.2
const ZOOM_STEP: float = 1.15
const DRAG_THRESHOLD: float = 5.0

## How long things stay on screen, in real milliseconds.
const BUBBLE_FRESH_MS: int = 3500
const BUBBLE_POP_MS: int = 180
const FLOAT_MS: int = 2600
const HOUSE_NOTE_MS: int = 3200
const TOAST_MS: int = 4500
const MAX_FLOATS: int = 14

# The interface palette (shared with the HUD).
const PAPER: Color = Color("#F3E9D2")
const TEAL: Color = Color("#2F5D62")
const TEAL_DARK: Color = Color("#22474B")
const MUSTARD: Color = Color("#E0A526")
const CHERRY: Color = Color("#B5442F")
const INK: Color = Color("#3B2F2A")

# The world palette.
const COLOR_GRASS: Color = Color(0.53, 0.65, 0.42)
const COLOR_GRASS_DARK: Color = Color(0.44, 0.56, 0.35)
const COLOR_GRASS_LIGHT: Color = Color(0.62, 0.73, 0.48)
const COLOR_LAWN: Color = Color(0.58, 0.70, 0.45)
const COLOR_ASPHALT: Color = Color(0.40, 0.40, 0.42)
const COLOR_CURB: Color = Color(0.70, 0.69, 0.65)
const COLOR_SIDEWALK: Color = Color(0.83, 0.81, 0.75)
const COLOR_PATH: Color = Color(0.80, 0.76, 0.66)
const COLOR_FENCE: Color = Color(0.95, 0.94, 0.90)
const COLOR_TRUNK: Color = Color(0.40, 0.29, 0.20)
const COLOR_TRIM: Color = Color(0.97, 0.96, 0.92)
const COLOR_GLASS: Color = Color(0.56, 0.67, 0.76)
const COLOR_LIT: Color = Color(1.0, 0.86, 0.48)
const COLOR_SKIN: Color = Color(0.92, 0.79, 0.66)
const COLOR_OUTLINE: Color = Color(0.20, 0.17, 0.15)
const COLOR_PLAYER: Color = Color(0.22, 0.42, 0.78)
const COLOR_NEIGHBOR: Color = Color(0.80, 0.45, 0.20)
const COLOR_TALK: Color = Color(1.0, 0.86, 0.30)
const COLOR_GOOD: Color = Color(0.20, 0.55, 0.20)
const COLOR_BAD: Color = Color(0.75, 0.20, 0.15)
const COLOR_NOTE: Color = Color(0.15, 0.15, 0.15)

const SIDING: Array[Color] = [
	Color(0.94, 0.90, 0.79), Color(0.95, 0.95, 0.92), Color(0.96, 0.88, 0.62),
	Color(0.75, 0.86, 0.76), Color(0.74, 0.83, 0.90), Color(0.93, 0.76, 0.68),
	Color(0.74, 0.77, 0.69),
]
const ROOFS: Array[Color] = [
	Color(0.34, 0.34, 0.37), Color(0.46, 0.34, 0.28), Color(0.34, 0.43, 0.39), Color(0.55, 0.31, 0.26),
]
const DOORS: Array[Color] = [
	Color(0.62, 0.20, 0.17), Color(0.18, 0.36, 0.38), Color(0.16, 0.27, 0.21), Color(0.80, 0.58, 0.16),
]
const CLOTHES: Array[Color] = [
	Color(0.80, 0.45, 0.20), Color(0.70, 0.28, 0.26), Color(0.52, 0.55, 0.25), Color(0.62, 0.42, 0.55),
	Color(0.85, 0.65, 0.25), Color(0.45, 0.36, 0.30), Color(0.35, 0.55, 0.45),
]
const PLAYER_CLOTHES: Array[Color] = [
	Color(0.22, 0.42, 0.78), Color(0.18, 0.34, 0.66), Color(0.30, 0.50, 0.86), Color(0.20, 0.38, 0.70),
]
const HAIR: Array[Color] = [
	Color(0.25, 0.18, 0.12), Color(0.45, 0.30, 0.16), Color(0.15, 0.12, 0.10), Color(0.62, 0.48, 0.28), Color(0.55, 0.55, 0.55),
]
const CAR_PAINT: Array[Color] = [
	Color(0.55, 0.78, 0.74), Color(0.86, 0.52, 0.46), Color(0.92, 0.86, 0.60), Color(0.50, 0.60, 0.78),
]

var simulation: Simulation
var area: Area
var selected_id: String = ""
var minute_fraction: float = 1.0

var _scale: float = 0.1
var _offset: Vector2 = Vector2.ZERO
var _base_scale: float = 0.1
var _base_offset: Vector2 = Vector2.ZERO
var _zoom: float = 1.0
var _zoom_target: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _zoom_anchor: Vector2 = Vector2.ZERO
var _press_at: Vector2 = Vector2.ZERO
var _pressing: bool = false
var _dragging: bool = false
var _hover: Vector2 = Vector2(-1000, -1000)

var _font: Font
var _ambient: Color = Color.WHITE
var _night: float = 0.0
var _trails: Dictionary = {}
var _screen_positions: Dictionary = {}
## person_id -> scale of the figure drawn this frame
var _figure_scales: Dictionary = {}
## building_id -> Array of screen polygons, for clicks
var _building_shapes: Dictionary = {}
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
var _card_box: StyleBoxFlat
var _card_head: StyleBoxFlat
var _pill_box: StyleBoxFlat
var _home_pill: StyleBoxFlat

# Decoration, worked out once from the area (world inches).
var _trees: Array = []      # {"x", "y", "size", "shade", "evergreen"}
var _shrubs: Array = []     # {"x", "y", "size", "shade"}
var _lamps: Array = []      # {"x", "y"}
var _cars: Array = []       # {"x", "y", "along_x", "paint"}
var _tufts: Array = []      # {"x", "y", "light"}
var _fences: Array = []     # [[a, b], ...] world segments
var _walks: Array = []      # [door_point, street_point]


func setup(sim: Simulation) -> void:
	simulation = sim
	area = sim.area
	_font = ThemeDB.fallback_font
	_bubble_box = _box(Color(0.99, 0.97, 0.90, 0.95), TEAL, 1, 8)
	_bubble_box_fresh = _box(Color(1.0, 0.95, 0.74), MUSTARD, 2, 8)
	_toast_box = _box(Color(TEAL_DARK, 0.94), MUSTARD, 2, 10)
	_card_box = _box(PAPER, Color(0.75, 0.66, 0.50), 1, 10)
	_card_box.shadow_color = Color(0.12, 0.08, 0.05, 0.30)
	_card_box.shadow_size = 6
	_card_box.shadow_offset = Vector2(0, 2)
	_card_head = _box(TEAL, TEAL, 0, 10)
	_card_head.corner_radius_bottom_left = 0
	_card_head.corner_radius_bottom_right = 0
	_pill_box = _box(Color(0.15, 0.13, 0.12, 0.72), Color(0, 0, 0, 0), 0, 8)
	_home_pill = _box(TEAL, MUSTARD, 2, 8)
	_fit_to_screen()
	_plan_decoration()


func _box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


func after_ticks() -> void:
	_trails = simulation.trails.duplicate(true)


func _process(delta: float) -> void:
	if absf(_zoom - _zoom_target) > 0.001:
		var before: Vector2 = _iso_of_screen(_zoom_anchor)
		_zoom = lerpf(_zoom, _zoom_target, clampf(delta * 12.0, 0.0, 1.0))
		_apply_view()
		# Keep the point under the cursor where it is while zooming.
		_pan += _zoom_anchor - (before * _scale + _offset)
		_apply_view()


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
		return {"point": [person["x"], person["y"]], "lift": 30.0}
	if person["at"] == Records.AT_INSIDE:
		return building_anchor(person["place_id"])
	return {}


func building_anchor(building_id: String) -> Dictionary:
	var building: Dictionary = area.buildings[building_id]
	var top: float = _wall_height(building) + _roof_rise(building)
	return {"point": building["door"], "lift": top * _scale + 22.0}


# --- Projection and camera ---------------------------------------------------

## World inches to screen pixels. East runs down-right, north runs up-right.
func to_screen(point: Array) -> Vector2:
	return _iso(float(point[0]), float(point[1]))


func _iso(x: float, y: float) -> Vector2:
	return Vector2((x + y) * _scale, (x - y) * _scale * 0.5) + _offset


## A point at a height (inches) above the ground.
func _p3(x: float, y: float, z: float) -> Vector2:
	return _iso(x, y) - Vector2(0, z * _scale)


## Unscaled isometric coordinates of a screen point (inverse of the view).
func _iso_of_screen(point: Vector2) -> Vector2:
	return (point - _offset) / _scale


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
	_base_scale = minf(MAP_RECT.size.x / maxf(bounds.size.x, 1.0), MAP_RECT.size.y / maxf(bounds.size.y, 1.0)) * 1.04
	_base_offset = MAP_RECT.get_center() - bounds.get_center() * _base_scale
	_apply_view()


func _apply_view() -> void:
	var centre: Vector2 = MAP_RECT.get_center()
	_scale = _base_scale * _zoom
	_offset = (_base_offset - centre) * _zoom + centre + _pan
	var limit: Vector2 = Vector2(520, 360) * _zoom
	_pan = _pan.clamp(-limit, limit)
	_offset = (_base_offset - centre) * _zoom + centre + _pan


func reset_view() -> void:
	_zoom = 1.0
	_zoom_target = 1.0
	_pan = Vector2.ZERO
	_apply_view()


## Sets the zoom at once, about the middle of the map.
func set_zoom(zoom: float) -> void:
	_zoom = clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	_zoom_target = _zoom
	_apply_view()


func _zoom_by(factor: float, at: Vector2) -> void:
	_zoom_target = clampf(_zoom_target * factor, ZOOM_MIN, ZOOM_MAX)
	_zoom_anchor = at


# --- Decoration, chosen once and deterministically --------------------------

func _rng_for(key: String) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = key.hash()
	return rng


func _pick(colors: Array[Color], key: String) -> Color:
	return colors[absi(key.hash()) % colors.size()]


func _rect_of(points: Array) -> Rect2:
	var rect: Rect2 = Rect2(Vector2(points[0][0], points[0][1]), Vector2.ZERO)
	for point: Array in points:
		rect = rect.expand(Vector2(point[0], point[1]))
	return rect


func _nearest_street_point(point: Vector2) -> Dictionary:
	var best: Dictionary = {}
	for street_id: String in area.streets:
		var street: Dictionary = area.streets[street_id]
		var line: Array = street["centerline"]
		for index: int in line.size() - 1:
			var a: Vector2 = Vector2(line[index][0], line[index][1])
			var b: Vector2 = Vector2(line[index + 1][0], line[index + 1][1])
			var on: Vector2 = Geometry2D.get_closest_point_to_segment(point, a, b)
			var distance: float = on.distance_to(point)
			if best.is_empty() or distance < float(best["distance"]):
				best = {"point": on, "distance": distance, "half": float(street["width"]) / 2.0}
	return best


func _plan_decoration() -> void:
	var everything: Rect2 = Rect2()
	var first: bool = true
	for lot_id: String in area.lots:
		var lot_rect: Rect2 = _rect_of(area.lots[lot_id]["boundary"])
		everything = lot_rect if first else everything.merge(lot_rect)
		first = false
	everything = everything.grow(200.0 * FOOT)

	var rng: RandomNumberGenerator = _rng_for("grass")
	for index: int in 900:
		_tufts.append({
			"x": rng.randf_range(everything.position.x, everything.end.x),
			"y": rng.randf_range(everything.position.y, everything.end.y),
			"light": rng.randf() < 0.45,
		})

	var footprints: Array[Rect2] = []
	for building_id: String in area.sorted_building_ids():
		footprints.append(_rect_of(area.buildings[building_id]["footprint"]))

	for building_id: String in area.sorted_building_ids():
		var building: Dictionary = area.buildings[building_id]
		var door: Vector2 = Vector2(building["door"][0], building["door"][1])
		var street: Dictionary = _nearest_street_point(door)
		if not street.is_empty():
			var toward: Vector2 = (street["point"] as Vector2 - door).normalized()
			var reach: float = maxf(float(street["distance"]) - float(street["half"]), 0.0)
			_walks.append([door, door + toward * reach])
		# Shrubs along the wall the door is on, leaving the door clear.
		var rect: Rect2 = _rect_of(building["footprint"])
		var shrub_rng: RandomNumberGenerator = _rng_for(building_id + ":shrubs")
		var along_x: bool = absf(door.y - rect.position.y) < 1.0 or absf(door.y - rect.end.y) < 1.0
		var outward: Vector2 = Vector2(0, -1 if absf(door.y - rect.position.y) < 1.0 else 1) if along_x \
				else Vector2(-1 if absf(door.x - rect.position.x) < 1.0 else 1, 0)
		var length: float = rect.size.x if along_x else rect.size.y
		var count: int = int(length / (7.0 * FOOT))
		for index: int in count:
			var u: float = (float(index) + 0.5) / float(count)
			var at: Vector2 = Vector2(rect.position.x + rect.size.x * u, door.y) if along_x \
					else Vector2(door.x, rect.position.y + rect.size.y * u)
			if at.distance_to(door) < 5.0 * FOOT:
				continue
			at += outward * 2.5 * FOOT
			_shrubs.append({"x": at.x, "y": at.y, "size": shrub_rng.randf_range(2.2, 3.2) * FOOT, "shade": shrub_rng.randf()})

	for lot_id: String in area.lots:
		var boundary: Array = area.lots[lot_id]["boundary"]
		var lot_rect: Rect2 = _rect_of(boundary)
		# A picket fence on every side but the one nearest the street.
		var front: int = -1
		var front_distance: float = INF
		for index: int in boundary.size():
			var a: Vector2 = Vector2(boundary[index][0], boundary[index][1])
			var b: Vector2 = Vector2(boundary[(index + 1) % boundary.size()][0], boundary[(index + 1) % boundary.size()][1])
			var near: Dictionary = _nearest_street_point((a + b) / 2.0)
			if not near.is_empty() and float(near["distance"]) < front_distance:
				front_distance = near["distance"]
				front = index
		for index: int in boundary.size():
			if index == front:
				continue
			var a: Vector2 = Vector2(boundary[index][0], boundary[index][1])
			var b: Vector2 = Vector2(boundary[(index + 1) % boundary.size()][0], boundary[(index + 1) % boundary.size()][1])
			_fences.append([a, b])
		# Two or three trees, clear of houses and front walks.
		var tree_rng: RandomNumberGenerator = _rng_for(lot_id + ":trees")
		var wanted: int = tree_rng.randi_range(2, 3)
		var tries: int = 0
		while wanted > 0 and tries < 60:
			tries += 1
			var spot: Vector2 = Vector2(
				tree_rng.randf_range(lot_rect.position.x + 6.0 * FOOT, lot_rect.end.x - 6.0 * FOOT),
				tree_rng.randf_range(lot_rect.position.y + 6.0 * FOOT, lot_rect.end.y - 6.0 * FOOT))
			var clear: bool = true
			for footprint: Rect2 in footprints:
				if footprint.grow(9.0 * FOOT).has_point(spot):
					clear = false
			for walk: Array in _walks:
				if Geometry2D.get_closest_point_to_segment(spot, walk[0], walk[1]).distance_to(spot) < 9.0 * FOOT:
					clear = false
			var street_gap: Dictionary = _nearest_street_point(spot)
			if not street_gap.is_empty() and float(street_gap["distance"]) < float(street_gap["half"]) + 9.0 * FOOT:
				clear = false
			for tree: Dictionary in _trees:
				if Vector2(tree["x"], tree["y"]).distance_to(spot) < 14.0 * FOOT:
					clear = false
			if not clear:
				continue
			_trees.append({
				"x": spot.x, "y": spot.y, "size": tree_rng.randf_range(7.0, 11.0) * FOOT,
				"shade": tree_rng.randf(), "evergreen": tree_rng.randf() < 0.25,
			})
			wanted -= 1

	# Street lamps, alternating sides, and a couple of cars at the curb.
	for street_id: String in area.streets:
		var street: Dictionary = area.streets[street_id]
		var line: Array = street["centerline"]
		var half: float = float(street["width"]) / 2.0
		var side: float = 1.0
		for index: int in line.size() - 1:
			var a: Vector2 = Vector2(line[index][0], line[index][1])
			var b: Vector2 = Vector2(line[index + 1][0], line[index + 1][1])
			var along: Vector2 = (b - a).normalized()
			var across: Vector2 = along.orthogonal()
			var length: float = a.distance_to(b)
			var at: float = 30.0 * FOOT
			while at < length:
				var spot: Vector2 = a + along * at + across * side * (half + 1.5 * FOOT)
				var clear: bool = true
				for walk: Array in _walks:
					if (walk[1] as Vector2).distance_to(spot) < 6.0 * FOOT:
						clear = false
				if clear:
					_lamps.append({"x": spot.x, "y": spot.y})
				side = -side
				at += 90.0 * FOOT
			var car_rng: RandomNumberGenerator = _rng_for(street_id + ":cars")
			for car: int in 2:
				var place: float = length * (0.33 + 0.4 * float(car)) + car_rng.randf_range(-6.0, 6.0) * FOOT
				var car_side: float = 1.0 if car == 0 else -1.0
				var spot: Vector2 = a + along * place + across * car_side * (half - 4.5 * FOOT)
				_cars.append({"x": spot.x, "y": spot.y, "along_x": absf(along.x) >= absf(along.y),
						"paint": CAR_PAINT[car_rng.randi_range(0, CAR_PAINT.size() - 1)]})


# --- Light -----------------------------------------------------------------

## 0 in full daylight, 1 in the middle of the night.
func night_amount() -> float:
	var minute: float = float(simulation.clock.minute_of_day)
	if minute >= 420.0 and minute <= 1080.0:      # 07:00 to 18:00
		return 0.0
	if minute > 1080.0:                           # dusk until 21:00
		return clampf((minute - 1080.0) / 180.0, 0.0, 1.0)
	return clampf((420.0 - minute) / 120.0, 0.0, 1.0)  # dawn from 05:00


func _update_light() -> void:
	var minute: float = float(simulation.clock.minute_of_day) + minute_fraction
	_night = night_amount()
	var golden: float = maxf(0.0, 1.0 - absf(minute - 1100.0) / 80.0) + maxf(0.0, 1.0 - absf(minute - 380.0) / 60.0)
	var warm: Color = Color(1.0, 0.85, 0.68)
	var dark: Color = Color(0.28, 0.33, 0.55)
	_ambient = Color.WHITE.lerp(warm, clampf(golden, 0.0, 1.0) * 0.75).lerp(dark, _night)


func _tint(color: Color) -> Color:
	return Color(color.r * _ambient.r, color.g * _ambient.g, color.b * _ambient.b, color.a)


## Where shadows fall, per inch of height: west in the morning, east in the
## evening, always a little north.
func _shadow_lean() -> Vector2:
	var minute: float = float(simulation.clock.minute_of_day)
	var t: float = clampf((minute - 750.0) / 420.0, -1.0, 1.0)
	return Vector2(t * 0.9, 0.55)


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	if simulation == null:
		return
	_update_light()
	_building_shapes.clear()
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), _tint(COLOR_GRASS))
	_draw_tufts()
	for lot_id: String in area.lots:
		var lot: PackedVector2Array = _polygon(area.lots[lot_id]["boundary"])
		draw_colored_polygon(lot, _tint(COLOR_LAWN))
	for street_id: String in area.streets:
		_draw_street(area.streets[street_id])
	for walk: Array in _walks:
		_draw_strip(walk[0], walk[1], 3.5 * FOOT, _tint(COLOR_PATH))
	_draw_shadows()
	_draw_lamp_pools()
	_layout_people()

	# Everything that stands up, from the back of the view to the front.
	var drawables: Array = []
	var home_id: String = _player_home()
	for building_id: String in area.sorted_building_ids():
		var rect: Rect2 = _rect_of(area.buildings[building_id]["footprint"])
		drawables.append({"key": _iso(rect.get_center().x, rect.get_center().y).y, "kind": "building", "id": building_id})
	for tree: Dictionary in _trees:
		drawables.append({"key": _iso(tree["x"], tree["y"]).y, "kind": "tree", "item": tree})
	for shrub: Dictionary in _shrubs:
		drawables.append({"key": _iso(shrub["x"], shrub["y"]).y, "kind": "shrub", "item": shrub})
	for lamp: Dictionary in _lamps:
		drawables.append({"key": _iso(lamp["x"], lamp["y"]).y, "kind": "lamp", "item": lamp})
	for car: Dictionary in _cars:
		drawables.append({"key": _iso(car["x"], car["y"]).y, "kind": "car", "item": car})
	for fence: Array in _fences:
		var middle: Vector2 = ((fence[0] as Vector2) + (fence[1] as Vector2)) / 2.0
		drawables.append({"key": _iso(middle.x, middle.y).y - 2.0, "kind": "fence", "item": fence})
	for person_id: String in _screen_positions:
		drawables.append({"key": (_screen_positions[person_id] as Vector2).y + 0.5, "kind": "person", "id": person_id})
	drawables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["key"]) < float(b["key"]))

	_draw_talk_lines()
	var hovered: Dictionary = _hovered()
	for item: Dictionary in drawables:
		match item["kind"]:
			"building":
				_draw_building(area.buildings[item["id"]], item["id"] == home_id, hovered.get("building", "") == item["id"])
			"tree":
				_draw_tree(item["item"])
			"shrub":
				_draw_shrub(item["item"])
			"lamp":
				_draw_lamp(item["item"])
			"car":
				_draw_car(item["item"])
			"fence":
				_draw_fence(item["item"])
			"person":
				_draw_person(simulation.state.people[item["id"]], hovered.get("person", "") == item["id"])

	_draw_street_names()
	_draw_building_badges(home_id)
	_draw_bubbles()
	_draw_hover_label(hovered)
	_draw_interior()
	_draw_house_notes()
	_draw_floats()
	_draw_toasts()


func _polygon(points: Array, lift: float = 0.0) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for point: Array in points:
		result.append(to_screen(point) - Vector2(0, lift))
	return result


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	return closed


func _face(points: PackedVector2Array, fill: Color, edge: Color = Color(0, 0, 0, 0)) -> void:
	draw_colored_polygon(points, fill)
	if edge.a > 0.0:
		draw_polyline(_closed(points), edge, 1.0, true)


func _ellipse(centre: Vector2, radius: float, flat: float, color: Color) -> void:
	draw_set_transform(centre, 0.0, Vector2(1.0, flat))
	draw_circle(Vector2.ZERO, radius, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A flat strip on the ground between two world points.
func _draw_strip(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	if a.distance_to(b) < 1.0:
		return
	var side: Vector2 = (b - a).normalized().orthogonal() * width / 2.0
	draw_colored_polygon(PackedVector2Array([
		_iso(a.x + side.x, a.y + side.y), _iso(b.x + side.x, b.y + side.y),
		_iso(b.x - side.x, b.y - side.y), _iso(a.x - side.x, a.y - side.y)]), color)


func _draw_tufts() -> void:
	var dark: Color = _tint(COLOR_GRASS_DARK)
	var light: Color = _tint(COLOR_GRASS_LIGHT)
	var length: float = clampf(2.0 * _zoom, 1.5, 4.0)
	for tuft: Dictionary in _tufts:
		var at: Vector2 = _iso(tuft["x"], tuft["y"])
		if at.x < -5.0 or at.y < -5.0 or at.x > VIEW_SIZE.x + 5.0 or at.y > VIEW_SIZE.y + 5.0:
			continue
		draw_line(at, at + Vector2(0.6, -length), light if tuft["light"] else dark, 1.0)


func _draw_street(street: Dictionary) -> void:
	var line: Array = street["centerline"]
	var half: float = float(street["width"]) / 2.0
	var walk: float = 5.0 * FOOT
	for index: int in line.size() - 1:
		var a: Vector2 = Vector2(line[index][0], line[index][1])
		var b: Vector2 = Vector2(line[index + 1][0], line[index + 1][1])
		var along: Vector2 = (b - a).normalized()
		var across: Vector2 = along.orthogonal()
		for side: float in [1.0, -1.0]:
			var middle: Vector2 = across * side * (half + walk / 2.0)
			_draw_strip(a + middle, b + middle, walk, _tint(COLOR_SIDEWALK))
			# Joints in the sidewalk every five feet.
			var at: float = 0.0
			var joint: Color = _tint(COLOR_SIDEWALK.darkened(0.12))
			while at <= a.distance_to(b):
				var p: Vector2 = a + along * at + across * side * half
				var q: Vector2 = p + across * side * walk
				draw_line(_iso(p.x, p.y), _iso(q.x, q.y), joint, 1.0)
				at += 5.0 * FOOT
		_draw_strip(a, b, half * 2.0, _tint(COLOR_ASPHALT))
		for side: float in [1.0, -1.0]:
			var edge: Vector2 = across * side * half
			draw_line(_iso(a.x + edge.x, a.y + edge.y), _iso(b.x + edge.x, b.y + edge.y), _tint(COLOR_CURB), clampf(1.5 * _zoom, 1.0, 3.0))


func _draw_street_names() -> void:
	for street_id: String in area.streets:
		var street: Dictionary = area.streets[street_id]
		var line: Array = street["centerline"]
		var a: Vector2 = to_screen(line[0])
		var b: Vector2 = to_screen(line[line.size() - 1])
		var size: int = clampi(int(14.0 * sqrt(_zoom)), 12, 24)
		var text: String = (street["name"] as String).to_upper()
		var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var middle: Vector2 = a.lerp(b, 0.28)
		draw_set_transform(middle, (b - a).angle(), Vector2.ONE)
		draw_string(_font, Vector2(-width / 2.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _tint(Color(0.92, 0.90, 0.82, 0.55)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_shadows() -> void:
	var strength: float = 0.20 * (1.0 - _night)
	if strength <= 0.01:
		return
	var shade: Color = Color(0.10, 0.12, 0.08, strength)
	var lean: Vector2 = _shadow_lean()
	for building_id: String in area.sorted_building_ids():
		var building: Dictionary = area.buildings[building_id]
		var reach: Vector2 = lean * (_wall_height(building) + _roof_rise(building) * 0.5)
		var points: PackedVector2Array = PackedVector2Array()
		for point: Array in building["footprint"]:
			points.append(_iso(float(point[0]), float(point[1])))
			points.append(_iso(float(point[0]) + reach.x, float(point[1]) + reach.y))
		var hull: PackedVector2Array = Geometry2D.convex_hull(points)
		if hull.size() >= 3:
			draw_colored_polygon(hull, shade)
	for tree: Dictionary in _trees:
		var reach: Vector2 = lean * float(tree["size"]) * 1.6
		var at: Vector2 = _iso(float(tree["x"]) + reach.x, float(tree["y"]) + reach.y)
		_ellipse(at, float(tree["size"]) * _scale * 1.0, 0.5, shade)
	for person_id: String in _screen_positions:
		_ellipse(_screen_positions[person_id], 5.0 * float(_figure_scales.get(person_id, 1.0)), 0.4, shade)


func _draw_lamp_pools() -> void:
	if _night < 0.25:
		return
	var strength: float = (_night - 0.25) / 0.75
	for lamp: Dictionary in _lamps:
		var at: Vector2 = _iso(lamp["x"], lamp["y"])
		for ring: int in 4:
			_ellipse(at, (16.0 - 3.0 * ring) * FOOT * _scale, 0.5, Color(1.0, 0.85, 0.50, 0.07 * strength))


# --- Buildings ---------------------------------------------------------------

func _wall_height(building: Dictionary) -> float:
	return float(building["stories"]) * STORY_HEIGHT_INCHES


func _is_store(building: Dictionary) -> bool:
	return area.is_institution(building["id"])


func _roof_rise(building: Dictionary) -> float:
	if _is_store(building):
		return 2.0 * FOOT
	var rect: Rect2 = _rect_of(building["footprint"])
	return minf(rect.size.x, rect.size.y) * 0.38


func _player_home() -> String:
	var household_id: String = simulation.state.player_household_id()
	if household_id == "":
		return ""
	return simulation.state.households[household_id]["home_id"]


func _occupants(building_id: String) -> Array:
	var inside: Array = []
	for person_id: String in simulation.state.sorted_person_ids():
		var person: Dictionary = simulation.state.people[person_id]
		if person["at"] == Records.AT_INSIDE and person["place_id"] == building_id:
			inside.append(person)
	return inside


func _anyone_awake(building_id: String) -> bool:
	for person: Dictionary in _occupants(building_id):
		var action: Dictionary = person["action"]
		if action.is_empty() or not (action["started"] and action["kind"] == "sleep"):
			return true
	return false


func _draw_building(building: Dictionary, is_home: bool, hovered: bool) -> void:
	var id: String = building["id"]
	var rect: Rect2 = _rect_of(building["footprint"])
	var x0: float = rect.position.x
	var x1: float = rect.end.x
	var y0: float = rect.position.y
	var y1: float = rect.end.y
	var h: float = _wall_height(building)
	var store: bool = _is_store(building)
	var siding: Color = Color(0.68, 0.38, 0.31) if store else _pick(SIDING, id)
	var roof: Color = Color(0.40, 0.38, 0.36) if store else _pick(ROOFS, id + "roof")
	var edge: Color = _tint(COLOR_OUTLINE.lerp(siding, 0.35))
	var lit: bool = _night > 0.2 and _anyone_awake(id)
	var shapes: Array = []

	# Walls that face the viewer: south (y0) and east (x1).
	var south: PackedVector2Array = PackedVector2Array([_p3(x0, y0, 0), _p3(x1, y0, 0), _p3(x1, y0, h), _p3(x0, y0, h)])
	var east: PackedVector2Array = PackedVector2Array([_p3(x1, y0, 0), _p3(x1, y1, 0), _p3(x1, y1, h), _p3(x1, y0, h)])
	_face(south, _tint(siding), edge)
	_face(east, _tint(siding.darkened(0.16)), edge)
	shapes.append(south)
	shapes.append(east)
	if not store:
		_draw_clapboard(Vector2(x0, y0), Vector2(x1, y0), h, _tint(siding.darkened(0.10)))
		_draw_clapboard(Vector2(x1, y0), Vector2(x1, y1), h, _tint(siding.darkened(0.24)))
	_draw_wall_openings(building, Vector2(x0, y0), Vector2(x1, y0), lit, store)
	_draw_wall_openings(building, Vector2(x1, y0), Vector2(x1, y1), lit, store)

	if store:
		var top: PackedVector2Array = PackedVector2Array([_p3(x0, y0, h), _p3(x1, y0, h), _p3(x1, y1, h), _p3(x0, y1, h)])
		_face(top, _tint(roof), edge)
		var lip: float = _roof_rise(building)
		_face(PackedVector2Array([_p3(x0, y0, h), _p3(x1, y0, h), _p3(x1, y0, h + lip), _p3(x0, y0, h + lip)]), _tint(siding.darkened(0.05)), edge)
		_face(PackedVector2Array([_p3(x1, y0, h), _p3(x1, y1, h), _p3(x1, y1, h + lip), _p3(x1, y0, h + lip)]), _tint(siding.darkened(0.2)), edge)
		shapes.append(top)
		_draw_store_sign(building, h + lip)
	else:
		shapes.append_array(_draw_gable_roof(building, rect, h, siding, roof, edge))

	if is_home or hovered:
		var outline: Color = MUSTARD if is_home else Color(1, 1, 1, 0.9)
		for shape: PackedVector2Array in shapes:
			draw_polyline(_closed(shape), Color(outline, 0.9), 2.0 if hovered else 1.5, true)
	_building_shapes[id] = shapes


func _draw_clapboard(a: Vector2, b: Vector2, h: float, color: Color) -> void:
	if _scale * 2.0 * FOOT < 3.0:
		return
	var z: float = 1.5 * FOOT
	while z < h:
		draw_line(_p3(a.x, a.y, z), _p3(b.x, b.y, z), color, 1.0)
		z += 1.5 * FOOT


## Windows and, where the door is on this wall, the door.
func _draw_wall_openings(building: Dictionary, a: Vector2, b: Vector2, lit: bool, store: bool) -> void:
	var door: Vector2 = Vector2(building["door"][0], building["door"][1])
	var on_wall: bool = Geometry2D.get_closest_point_to_segment(door, a, b).distance_to(door) < 1.0
	var length: float = a.distance_to(b)
	var along: Vector2 = (b - a) / length
	var count: int = maxi(1, int(length / (11.0 * FOOT)))
	var glass: Color = COLOR_LIT if lit else _tint(COLOR_GLASS)
	var frame: Color = _tint(COLOR_TRIM)
	for story: int in int(building["stories"]):
		var base: float = float(story) * STORY_HEIGHT_INCHES
		for index: int in count:
			var u: float = (float(index) + 0.5) / float(count) * length
			if story == 0 and on_wall and absf(u - a.distance_to(door)) < 5.0 * FOOT:
				continue
			var half: float = (3.5 if store and story == 0 else 1.6) * FOOT
			var low: float = base + (2.0 if store and story == 0 else 3.2) * FOOT
			var high: float = base + 7.0 * FOOT
			var p: Vector2 = a + along * (u - half)
			var q: Vector2 = a + along * (u + half)
			var pane: PackedVector2Array = PackedVector2Array([_p3(p.x, p.y, low), _p3(q.x, q.y, low), _p3(q.x, q.y, high), _p3(p.x, p.y, high)])
			draw_colored_polygon(pane, glass)
			draw_polyline(_closed(pane), frame, 1.0, true)
			var mid: Vector2 = (p + q) / 2.0
			draw_line(_p3(mid.x, mid.y, low), _p3(mid.x, mid.y, high), frame, 1.0)
			if lit:
				var centre: Vector2 = (pane[0] + pane[2]) / 2.0
				draw_circle(centre, 6.0 * _zoom, Color(1.0, 0.85, 0.45, 0.12))
	if on_wall:
		var at: float = a.distance_to(door)
		var p: Vector2 = a + along * (at - 1.8 * FOOT)
		var q: Vector2 = a + along * (at + 1.8 * FOOT)
		var color: Color = _tint(_pick(DOORS, building["id"] + "door"))
		var leaf: PackedVector2Array = PackedVector2Array([_p3(p.x, p.y, 0), _p3(q.x, q.y, 0), _p3(q.x, q.y, 7.0 * FOOT), _p3(p.x, p.y, 7.0 * FOOT)])
		draw_colored_polygon(leaf, color)
		draw_polyline(_closed(leaf), frame, 1.0, true)
		# A little roof over the step.
		var hood: PackedVector2Array = PackedVector2Array([
			_p3(p.x - along.x * FOOT, p.y - along.y * FOOT, 8.0 * FOOT), _p3(q.x + along.x * FOOT, q.y + along.y * FOOT, 8.0 * FOOT),
			_p3(q.x + along.x * FOOT, q.y + along.y * FOOT, 9.0 * FOOT), _p3(p.x - along.x * FOOT, p.y - along.y * FOOT, 9.0 * FOOT)])
		draw_colored_polygon(hood, frame)


## A gabled roof, ridge along the longer side. Returns the roof faces drawn.
func _draw_gable_roof(building: Dictionary, rect: Rect2, h: float, siding: Color, roof: Color, edge: Color) -> Array:
	var o: float = 1.5 * FOOT
	var rise: float = _roof_rise(building)
	var x0: float = rect.position.x
	var x1: float = rect.end.x
	var y0: float = rect.position.y
	var y1: float = rect.end.y
	var faces: Array = []
	var roof_edge: Color = _tint(roof.darkened(0.35))
	if rect.size.y >= rect.size.x:
		var xm: float = (x0 + x1) / 2.0
		var gable: PackedVector2Array = PackedVector2Array([_p3(x0, y0, h), _p3(x1, y0, h), _p3(xm, y0, h + rise)])
		_face(gable, _tint(siding), edge)
		_draw_gable_window(Vector2(x0, y0), Vector2(x1, y0), h, rise)
		var back: PackedVector2Array = PackedVector2Array([_p3(x0 - o, y0 - o, h - o * 0.4), _p3(x0 - o, y1 + o, h - o * 0.4), _p3(xm, y1 + o, h + rise), _p3(xm, y0 - o, h + rise)])
		var front: PackedVector2Array = PackedVector2Array([_p3(x1 + o, y0 - o, h - o * 0.4), _p3(x1 + o, y1 + o, h - o * 0.4), _p3(xm, y1 + o, h + rise), _p3(xm, y0 - o, h + rise)])
		_face(back, _tint(roof.darkened(0.12)), roof_edge)
		_draw_chimney(Vector2(xm + rect.size.x * 0.18, y0 + rect.size.y * 0.65), h, rise)
		_face(front, _tint(roof.lightened(0.08)), roof_edge)
		_draw_shingles(front, roof)
		faces.append_array([gable, back, front])
	else:
		var ym: float = (y0 + y1) / 2.0
		var gable: PackedVector2Array = PackedVector2Array([_p3(x1, y0, h), _p3(x1, y1, h), _p3(x1, ym, h + rise)])
		_face(gable, _tint(siding.darkened(0.16)), edge)
		_draw_gable_window(Vector2(x1, y0), Vector2(x1, y1), h, rise)
		var back: PackedVector2Array = PackedVector2Array([_p3(x0 - o, y1 + o, h - o * 0.4), _p3(x1 + o, y1 + o, h - o * 0.4), _p3(x1 + o, ym, h + rise), _p3(x0 - o, ym, h + rise)])
		var front: PackedVector2Array = PackedVector2Array([_p3(x0 - o, y0 - o, h - o * 0.4), _p3(x1 + o, y0 - o, h - o * 0.4), _p3(x1 + o, ym, h + rise), _p3(x0 - o, ym, h + rise)])
		_face(back, _tint(roof.darkened(0.12)), roof_edge)
		_draw_chimney(Vector2(x0 + rect.size.x * 0.3, ym + rect.size.y * 0.18), h, rise)
		_face(front, _tint(roof.lightened(0.08)), roof_edge)
		_draw_shingles(front, roof)
		faces.append_array([gable, back, front])
	return faces


func _draw_gable_window(a: Vector2, b: Vector2, h: float, rise: float) -> void:
	var mid: Vector2 = (a + b) / 2.0
	var along: Vector2 = (b - a).normalized()
	var p: Vector2 = mid - along * 1.2 * FOOT
	var q: Vector2 = mid + along * 1.2 * FOOT
	var low: float = h + rise * 0.2
	var high: float = h + rise * 0.55
	var pane: PackedVector2Array = PackedVector2Array([_p3(p.x, p.y, low), _p3(q.x, q.y, low), _p3(q.x, q.y, high), _p3(p.x, p.y, high)])
	draw_colored_polygon(pane, _tint(COLOR_GLASS.darkened(0.2)))
	draw_polyline(_closed(pane), _tint(COLOR_TRIM), 1.0, true)


## Faint rows of shingles across a roof face (corners 0 and 1 are the eave).
func _draw_shingles(face: PackedVector2Array, roof: Color) -> void:
	if _zoom < 1.2:
		return
	var color: Color = _tint(roof.darkened(0.2))
	for row: int in range(1, 6):
		var t: float = float(row) / 6.0
		draw_line(face[0].lerp(face[3], t), face[1].lerp(face[2], t), Color(color, 0.5), 1.0)


func _draw_chimney(at: Vector2, h: float, rise: float) -> void:
	var size: float = 1.4 * FOOT
	# Height of the roof surface under the chimney, plus a little.
	var base: float = h
	var top: float = h + rise + 2.0 * FOOT
	var brick: Color = Color(0.58, 0.30, 0.24)
	var x0: float = at.x - size
	var x1: float = at.x + size
	var y0: float = at.y - size
	var y1: float = at.y + size
	_face(PackedVector2Array([_p3(x0, y0, base), _p3(x1, y0, base), _p3(x1, y0, top), _p3(x0, y0, top)]), _tint(brick), _tint(brick.darkened(0.4)))
	_face(PackedVector2Array([_p3(x1, y0, base), _p3(x1, y1, base), _p3(x1, y1, top), _p3(x1, y0, top)]), _tint(brick.darkened(0.2)), _tint(brick.darkened(0.4)))
	_face(PackedVector2Array([_p3(x0, y0, top), _p3(x1, y0, top), _p3(x1, y1, top), _p3(x0, y1, top)]), _tint(brick.darkened(0.45)))


func _draw_store_sign(building: Dictionary, top: float) -> void:
	var rect: Rect2 = _rect_of(building["footprint"])
	var open: bool = area.is_open(building["id"], simulation.clock.weekday(), simulation.clock.minute_of_day)
	var name: String = area.institutions[building["id"]]["name"]
	var at: Vector2 = _p3(rect.get_center().x, rect.get_center().y, top) - Vector2(0, 14.0 * sqrt(_zoom))
	var size: int = clampi(int(11.0 * sqrt(_zoom)), 10, 18)
	var width: float = _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 14.0
	var board: Rect2 = Rect2(at - Vector2(width / 2.0, size + 6.0), Vector2(width, size + 8.0))
	draw_line(board.end - Vector2(6, 0), board.end - Vector2(6, -10), _tint(COLOR_OUTLINE), 2.0)
	draw_line(Vector2(board.position.x + 6, board.end.y), Vector2(board.position.x + 6, board.end.y + 10), _tint(COLOR_OUTLINE), 2.0)
	var sign: StyleBoxFlat = _box(_tint(Color(0.96, 0.92, 0.80)), _tint(CHERRY), 2, 4)
	draw_style_box(sign, board)
	draw_string(_font, board.position + Vector2(7, size + 1.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _tint(CHERRY.darkened(0.2)))
	var tag: String = "OPEN" if open else "CLOSED"
	var tag_size: int = size - 2
	var tag_width: float = _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x + 10.0
	var tag_rect: Rect2 = Rect2(Vector2(board.end.x + 4.0, board.position.y + 1.5), Vector2(tag_width, tag_size + 5.0))
	var tag_fill: Color = Color(0.25, 0.60, 0.30) if open else Color(0.45, 0.42, 0.40)
	if open and _night > 0.2:
		draw_circle(tag_rect.get_center(), tag_width * 0.8, Color(0.4, 1.0, 0.5, 0.10))
	draw_style_box(_box(tag_fill, Color(1, 1, 1, 0.7), 1, 4), tag_rect)
	draw_string(_font, tag_rect.position + Vector2(5, tag_size + 1.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size, Color.WHITE)


## Small pills over houses: how many are inside, and which house is yours.
func _draw_building_badges(home_id: String) -> void:
	for building_id: String in area.sorted_building_ids():
		var building: Dictionary = area.buildings[building_id]
		var rect: Rect2 = _rect_of(building["footprint"])
		var top: Vector2 = _p3(rect.get_center().x, rect.get_center().y, _wall_height(building) + _roof_rise(building))
		var lines: Array[String] = []
		var inside: Array = _occupants(building_id)
		if not inside.is_empty():
			var asleep: int = 0
			for person: Dictionary in inside:
				if not person["action"].is_empty() and person["action"]["started"] and person["action"]["kind"] == "sleep":
					asleep += 1
			if asleep == inside.size():
				lines.append("%d asleep" % asleep)
			elif asleep > 0:
				lines.append("%d in, %d asleep" % [inside.size(), asleep])
			else:
				lines.append("%d inside" % inside.size())
		var lift: float = 38.0 * sqrt(_zoom) if _is_store(building) else 10.0
		if building_id == home_id:
			var text: String = "Your home"
			var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0
			var pill: Rect2 = Rect2(top - Vector2(width / 2.0, lift + 22.0), Vector2(width, 18))
			draw_style_box(_home_pill, pill)
			draw_string(_font, pill.position + Vector2(7, 13), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PAPER)
			lift += 22.0
		for text: String in lines:
			var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12.0
			var pill: Rect2 = Rect2(top - Vector2(width / 2.0, lift + 18.0), Vector2(width, 16))
			draw_style_box(_pill_box, pill)
			draw_string(_font, pill.position + Vector2(6, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.95))


# --- Trees, shrubs, lamps, cars, fences ----------------------------------------

func _draw_tree(tree: Dictionary) -> void:
	var at: Vector2 = _iso(tree["x"], tree["y"])
	var size: float = float(tree["size"]) * _scale
	var shade: float = float(tree["shade"])
	var leaf: Color = Color(0.30, 0.50, 0.26).lerp(Color(0.42, 0.58, 0.28), shade)
	draw_line(at, at - Vector2(0, size * 1.1), _tint(COLOR_TRUNK), maxf(2.0, size * 0.18))
	if tree["evergreen"]:
		var dark: Color = _tint(Color(0.20, 0.38, 0.26))
		for layer: int in 3:
			var base: float = size * (0.5 + 0.55 * float(layer))
			var width: float = size * (0.85 - 0.22 * float(layer))
			draw_colored_polygon(PackedVector2Array([at - Vector2(width, base), at - Vector2(-width, base), at - Vector2(0, base + size * 0.95)]),
				dark.lightened(0.08 * float(layer)))
		return
	var centre: Vector2 = at - Vector2(0, size * 1.45)
	draw_circle(centre + Vector2(size * 0.15, size * 0.12), size, _tint(leaf.darkened(0.25)))
	draw_circle(centre - Vector2(size * 0.35, size * 0.05), size * 0.72, _tint(leaf.darkened(0.08)))
	draw_circle(centre + Vector2(size * 0.32, -size * 0.18), size * 0.68, _tint(leaf))
	draw_circle(centre - Vector2(size * 0.08, size * 0.42), size * 0.55, _tint(leaf.lightened(0.12)))


func _draw_shrub(shrub: Dictionary) -> void:
	var at: Vector2 = _iso(shrub["x"], shrub["y"])
	var size: float = float(shrub["size"]) * _scale
	var leaf: Color = Color(0.28, 0.46, 0.25).lerp(Color(0.38, 0.52, 0.27), float(shrub["shade"]))
	draw_circle(at - Vector2(0, size * 0.7), size, _tint(leaf))
	draw_circle(at - Vector2(size * 0.3, size * 1.0), size * 0.55, _tint(leaf.lightened(0.10)))


func _draw_lamp(lamp: Dictionary) -> void:
	var at: Vector2 = _iso(lamp["x"], lamp["y"])
	var height: float = 13.0 * FOOT * _scale
	var head: Vector2 = at - Vector2(0, height)
	draw_line(at, head, _tint(Color(0.22, 0.22, 0.24)), maxf(1.5, 1.2 * _zoom))
	draw_line(head, head + Vector2(3.0 * _zoom, 1.0), _tint(Color(0.22, 0.22, 0.24)), maxf(1.5, 1.2 * _zoom))
	var lit: bool = _night > 0.25
	var bulb: Color = Color(1.0, 0.92, 0.62) if lit else _tint(Color(0.85, 0.85, 0.80))
	if lit:
		for ring: int in 3:
			draw_circle(head + Vector2(3.0 * _zoom, 3.0), (9.0 - 2.5 * ring) * _zoom, Color(1.0, 0.85, 0.45, 0.10))
	draw_circle(head + Vector2(3.0 * _zoom, 2.5), maxf(2.0, 1.8 * _zoom), bulb)


## A boxy parked car. Its width and height are drawn from three visible faces.
func _draw_box(x0: float, y0: float, x1: float, y1: float, z0: float, z1: float, color: Color) -> void:
	var edge: Color = _tint(color.darkened(0.45))
	_face(PackedVector2Array([_p3(x0, y0, z0), _p3(x1, y0, z0), _p3(x1, y0, z1), _p3(x0, y0, z1)]), _tint(color), edge)
	_face(PackedVector2Array([_p3(x1, y0, z0), _p3(x1, y1, z0), _p3(x1, y1, z1), _p3(x1, y0, z1)]), _tint(color.darkened(0.18)), edge)
	_face(PackedVector2Array([_p3(x0, y0, z1), _p3(x1, y0, z1), _p3(x1, y1, z1), _p3(x0, y1, z1)]), _tint(color.lightened(0.15)), edge)


func _draw_car(car: Dictionary) -> void:
	var half_long: float = 8.0 * FOOT
	var half_wide: float = 3.2 * FOOT
	var x: float = car["x"]
	var y: float = car["y"]
	var paint: Color = car["paint"]
	var hx: float = half_long if car["along_x"] else half_wide
	var hy: float = half_wide if car["along_x"] else half_long
	_ellipse(_iso(x, y), maxf(hx, hy) * _scale * 1.2, 0.45, Color(0, 0, 0, 0.18 * (1.0 - _night * 0.5)))
	_draw_box(x - hx, y - hy, x + hx, y + hy, 1.0 * FOOT, 3.4 * FOOT, paint)
	var cx: float = hx * 0.5 if car["along_x"] else hx * 0.9
	var cy: float = hy * 0.9 if car["along_x"] else hy * 0.5
	_draw_box(x - cx - (FOOT if car["along_x"] else 0.0), y - cy, x + cx - (FOOT if car["along_x"] else 0.0), y + cy, 3.4 * FOOT, 5.0 * FOOT, Color(0.96, 0.95, 0.90))
	# Wheels.
	for along: float in [-0.6, 0.6]:
		var wx: float = x + (hx * along if car["along_x"] else hx)
		var wy: float = y - (hy if car["along_x"] else -hy * along)
		draw_circle(_p3(wx, wy, 1.0 * FOOT), maxf(1.5, 1.1 * FOOT * _scale), _tint(Color(0.12, 0.12, 0.12)))


func _draw_fence(fence: Array) -> void:
	var a: Vector2 = fence[0]
	var b: Vector2 = fence[1]
	var height: float = 3.0 * FOOT
	var color: Color = _tint(COLOR_FENCE)
	var low: Color = _tint(COLOR_FENCE.darkened(0.25))
	draw_line(_p3(a.x, a.y, height * 0.7), _p3(b.x, b.y, height * 0.7), low, 1.0)
	var step: float = 2.0 * FOOT if _zoom >= 1.4 else 4.0 * FOOT
	var length: float = a.distance_to(b)
	var at: float = 0.0
	while at <= length:
		var p: Vector2 = a.lerp(b, at / length)
		draw_line(_p3(p.x, p.y, 0.0), _p3(p.x, p.y, height), color, 1.0)
		at += step


# --- People ------------------------------------------------------------------

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


func _is_walking(person_id: String) -> bool:
	var trail: Array = _trails.get(person_id, [])
	return trail.size() >= 2 and minute_fraction < 1.0


func _is_child(person: Dictionary) -> bool:
	return SimDate.age_on(person["birth_day"], simulation.clock.day_index) < CHILD_AGE


func _layout_people() -> void:
	_screen_positions.clear()
	_figure_scales.clear()
	var visible: Array = []
	var base: float = clampf(1.2 * sqrt(_zoom), 1.0, 2.0)
	for person_id: String in simulation.state.sorted_person_ids():
		var person: Dictionary = simulation.state.people[person_id]
		if person["at"] == Records.AT_OUTSIDE or _is_walking(person_id):
			_screen_positions[person_id] = _animated_position(person)
			_figure_scales[person_id] = base * (0.72 if _is_child(person) else 1.0)
			visible.append(person)
	# People standing on the same spot are spread out so each can be seen.
	var taken: Dictionary = {}
	for person: Dictionary in visible:
		var spot: Vector2i = Vector2i((_screen_positions[person["id"]] as Vector2).round())
		var count: int = taken.get(spot, 0)
		taken[spot] = count + 1
		if count > 0:
			var side: float = 1.0 if count % 2 == 1 else -1.0
			_screen_positions[person["id"]] += Vector2(FAN_SPACING * side * float((count + 1) / 2), 2.0 * float(count))


## Where a figure's chest is, for lines and clicks.
func _chest(person_id: String) -> Vector2:
	return (_screen_positions[person_id] as Vector2) - Vector2(0, 11.0 * float(_figure_scales[person_id]))


func _draw_talk_lines() -> void:
	for person_id: String in _screen_positions:
		var action: Dictionary = simulation.state.people[person_id]["action"]
		if not action.is_empty() and action["kind"] == "talk" and _screen_positions.has(action["other_id"]) and person_id < String(action["other_id"]):
			var a: Vector2 = _chest(person_id)
			var b: Vector2 = _chest(action["other_id"])
			var length: float = a.distance_to(b)
			var dots: int = maxi(2, int(length / 7.0))
			var phase: float = fmod(float(Time.get_ticks_msec()) / 400.0, 1.0)
			for index: int in dots:
				var t: float = (float(index) + phase) / float(dots)
				draw_circle(a.lerp(b, t) - Vector2(0, sin(t * PI) * 6.0), 1.6, Color(COLOR_TALK, 0.9))


func _draw_person(person: Dictionary, hovered: bool) -> void:
	var id: String = person["id"]
	var feet: Vector2 = _screen_positions[id]
	var k: float = _figure_scales[id]
	var players: bool = simulation.state.households[person["household_id"]]["player_controlled"]
	var now: float = float(Time.get_ticks_msec())
	var talking: bool = not person["action"].is_empty() and person["action"]["kind"] == "talk"
	var walking: bool = _is_walking(id)
	var body: Color = _pick(PLAYER_CLOTHES, id) if players else _pick(CLOTHES, id)
	var person_light: Color = Color.WHITE.lerp(_ambient, 0.6)

	if id == selected_id:
		_ellipse(feet, 9.0 * k, 0.45, Color(1, 1, 1, 0.95))
		_ellipse(feet, 7.0 * k, 0.45, Color(MUSTARD, 0.9))
	elif hovered:
		_ellipse(feet, 8.0 * k, 0.45, Color(1, 1, 1, 0.7))
	if talking:
		var pulse: float = 0.5 + 0.5 * sin(now / 180.0)
		draw_arc(feet - Vector2(0, 1), (9.0 + 2.0 * pulse) * k, 0.0, TAU, 24, Color(COLOR_TALK, 0.9), 2.0)

	var swing: float = sin(now / 85.0) * 2.4 * k if walking else 0.0
	var bob: float = absf(sin(now / 85.0)) * 1.0 * k if walking else 0.0
	var hip: Vector2 = feet - Vector2(0, 6.5 * k + bob)
	var legs: Color = _lit_by(person_light, Color(0.25, 0.22, 0.22))
	draw_line(hip + Vector2(-1.2 * k, 0), feet + Vector2(-1.5 * k + swing, 0), legs, 2.0 * k)
	draw_line(hip + Vector2(1.2 * k, 0), feet + Vector2(1.5 * k - swing, 0), legs, 2.0 * k)
	var shoulders: Vector2 = hip - Vector2(0, 7.5 * k)
	var torso: PackedVector2Array = PackedVector2Array([
		hip + Vector2(-3.4 * k, 0.5), hip + Vector2(3.4 * k, 0.5),
		shoulders + Vector2(3.0 * k, 0), shoulders + Vector2(-3.0 * k, 0)])
	draw_colored_polygon(torso, _lit_by(person_light, body))
	draw_polyline(_closed(torso), _lit_by(person_light, body.darkened(0.45)), 1.0, true)
	draw_line(shoulders + Vector2(-3.0 * k, 0.5), hip + Vector2(-3.8 * k, -1.0 - swing * 0.4), _lit_by(person_light, body.darkened(0.15)), 1.6 * k)
	draw_line(shoulders + Vector2(3.0 * k, 0.5), hip + Vector2(3.8 * k, -1.0 + swing * 0.4), _lit_by(person_light, body.darkened(0.15)), 1.6 * k)
	var head: Vector2 = shoulders - Vector2(0, 3.4 * k)
	draw_circle(head, 3.2 * k, _lit_by(person_light, COLOR_SKIN))
	draw_arc(head, 3.2 * k, PI * 1.05, PI * 1.95, 10, _lit_by(person_light, _pick(HAIR, id + "hair")), 2.2 * k)
	draw_arc(head, 3.2 * k, 0.0, TAU, 16, _lit_by(person_light, COLOR_SKIN.darkened(0.4)), 1.0)
	if id == selected_id:
		var bounce: float = sin(now / 220.0) * 2.0
		var tip: Vector2 = head - Vector2(0, 9.0 * k + bounce)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-4.5, -6), tip + Vector2(4.5, -6)]), MUSTARD)
		draw_polyline(PackedVector2Array([tip, tip + Vector2(-4.5, -6), tip + Vector2(4.5, -6), tip]), INK, 1.0, true)


func _lit_by(light: Color, color: Color) -> Color:
	return Color(color.r * light.r, color.g * light.g, color.b * light.b, color.a)


func _draw_bubbles() -> void:
	var now: int = Time.get_ticks_msec()
	var placed: Array[Rect2] = []
	for person_id: String in _screen_positions:
		var person: Dictionary = simulation.state.people[person_id]
		var bubble: Dictionary = _bubbles.get(person_id, {})
		var text: String = person["given_name"]
		var since: int = 0
		if not bubble.is_empty():
			var activity: String = bubble["text"]
			text = "%s: %s%s" % [person["given_name"], activity.left(1).to_lower(), activity.substr(1)]
			since = bubble["since"]
		var k: float = _figure_scales[person_id]
		var head_top: Vector2 = (_screen_positions[person_id] as Vector2) - Vector2(0, 21.0 * k)
		# The bubble sits to the right unless that would cover someone else.
		var size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12) + Vector2(14, 8)
		var right: Rect2 = Rect2(head_top + Vector2(6, -size.y), size).grow(4.0)
		var covered: bool = false
		for other_id: String in _screen_positions:
			if other_id != person_id and right.has_point(_chest(other_id)):
				covered = true
		var anchor: Vector2 = head_top + (Vector2(-6 - size.x, 0) if covered else Vector2(6, 0))
		# Stack upward past bubbles already drawn rather than cover them.
		var moved: bool = true
		while moved:
			moved = false
			var box: Rect2 = Rect2(anchor - Vector2(0, size.y), size).grow(1.0)
			for other: Rect2 in placed:
				if other.intersects(box):
					anchor.y = other.position.y - 1.0
					moved = true
		var natural: Vector2 = head_top + (Vector2(-6 - size.x, 0) if covered else Vector2(6, 0))
		placed.append(Rect2(anchor - Vector2(0, size.y), size))
		_draw_bubble(anchor, text, now - since, head_top if anchor == natural else Vector2.INF)


## A rounded label with a little tail. A new one pops out and is highlighted
## for a few seconds.
func _draw_bubble(anchor: Vector2, text: String, age_ms: int, tail_to: Vector2 = Vector2.INF) -> void:
	var size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12) + Vector2(14, 8)
	var grow: float = 1.0
	if age_ms < BUBBLE_POP_MS:
		grow = 0.5 + 0.65 * float(age_ms) / float(BUBBLE_POP_MS)   # overshoots slightly, then settles
	elif age_ms < BUBBLE_POP_MS * 2:
		grow = 1.15 - 0.15 * float(age_ms - BUBBLE_POP_MS) / float(BUBBLE_POP_MS)
	var fresh: bool = age_ms < BUBBLE_FRESH_MS
	var box: StyleBoxFlat = _bubble_box_fresh if fresh else _bubble_box
	if tail_to != Vector2.INF:
		var base_x: float = clampf(tail_to.x, anchor.x + 8.0, anchor.x + size.x - 8.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(base_x - 4.0, anchor.y - 2.0), Vector2(base_x + 4.0, anchor.y - 2.0), tail_to + Vector2(0, -1)]), box.border_color)
	# Grow from the middle of the bubble so it pops in place.
	var middle: Vector2 = anchor + Vector2(size.x / 2.0, -size.y / 2.0)
	draw_set_transform(middle - Vector2(size.x / 2.0, -size.y / 2.0) * grow, 0.0, Vector2(grow, grow))
	var rect: Rect2 = Rect2(Vector2(0, -size.y), size)
	draw_style_box(box, rect)
	draw_string(_font, Vector2(7, -8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Hover -------------------------------------------------------------------

func _person_at(point: Vector2) -> String:
	var best_id: String = ""
	var best: float = CLICK_RADIUS
	for person_id: String in _screen_positions:
		var distance: float = minf(_chest(person_id).distance_to(point), (_screen_positions[person_id] as Vector2).distance_to(point))
		if distance < best:
			best = distance
			best_id = person_id
	return best_id


func _hovered() -> Dictionary:
	if _dragging or INTERIOR_RECT.has_point(_hover) or not Rect2(Vector2.ZERO, VIEW_SIZE).has_point(_hover):
		return {}
	var person_id: String = _person_at(_hover)
	if person_id != "":
		return {"person": person_id}
	var building_id: String = _building_at(_hover)
	if building_id != "":
		return {"building": building_id}
	return {}


func _draw_hover_label(hovered: Dictionary) -> void:
	var text: String = ""
	if hovered.has("person"):
		var person: Dictionary = simulation.state.people[hovered["person"]]
		text = "%s %s" % [person["given_name"], person["family_name"]]
	elif hovered.has("building"):
		var building: Dictionary = area.buildings[hovered["building"]]
		text = "%s  (right-click for details)" % building["label"]
	if text == "":
		return
	var size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12) + Vector2(14, 8)
	var at: Vector2 = _hover + Vector2(14, 22)
	draw_style_box(_pill_box, Rect2(at, size))
	draw_string(_font, at + Vector2(7, size.y - 8.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


# --- Notes, floats and toasts ------------------------------------------------

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
		var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14.0
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
		draw_string_outline(_font, at - Vector2(width / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(1, 0.98, 0.92, alpha))
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
		var size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15) + Vector2(28, 14)
		# Stacked upward from the bottom of the map, newest lowest; slides in.
		var slide: float = clampf(float(age) / 220.0, 0.0, 1.0)
		var top_left: Vector2 = Vector2(MAP_RECT.get_center().x - size.x / 2.0,
				MAP_RECT.end.y - (row + 1) * (size.y + 6.0) + (1.0 - slide) * 16.0)
		var fade: float = clampf(float(TOAST_MS - age) / 600.0, 0.0, 1.0) * slide
		modulate_box(_toast_box, fade)
		draw_style_box(_toast_box, Rect2(top_left, size))
		draw_string(_font, top_left + Vector2(14, size.y - 10.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(PAPER, fade))
		row += 1
	modulate_box(_toast_box, 1.0)
	_toasts = kept


func modulate_box(box: StyleBoxFlat, alpha: float) -> void:
	box.bg_color.a = 0.94 * alpha
	box.border_color.a = alpha


# --- The player's home, seen from above ---------------------------------------

## The home of the player's household, if it has an interior ("" otherwise).
func _interior_home() -> String:
	var home: String = _player_home()
	return home if home != "" and area.has_interior(home) else ""


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
	var inner: Rect2 = Rect2(INTERIOR_RECT.position + Vector2(12, 50), INTERIOR_RECT.size - Vector2(24, 72))
	var fit: float = minf(inner.size.x / bounds.size.x, inner.size.y / bounds.size.y)
	var origin: Vector2 = inner.get_center() - bounds.size * fit / 2.0
	for room_id: String in rooms:
		var r: Array = rooms[room_id]["rect"]
		# North is up: the world's y grows northward, the screen's downward.
		var x: float = origin.x + (float(r[0]) - bounds.position.x) * fit
		var y: float = origin.y + (bounds.end.y - float(r[1]) - float(r[3])) * fit
		result[room_id] = Rect2(x, y, float(r[2]) * fit, float(r[3]) * fit)
	return result


func _draw_floor(rect: Rect2, name: String) -> void:
	var lower: String = name.to_lower()
	if lower.contains("kitchen") or lower.contains("bath"):
		var light: Color = Color(0.95, 0.94, 0.90) if lower.contains("kitchen") else Color(0.86, 0.92, 0.94)
		var dark: Color = Color(0.80, 0.30, 0.26, 0.55) if lower.contains("kitchen") else Color(0.55, 0.70, 0.75, 0.6)
		draw_rect(rect, light)
		var tile: float = 9.0
		var row: int = 0
		var y: float = rect.position.y
		while y < rect.end.y:
			var column: int = row % 2
			var x: float = rect.position.x + float(column) * tile
			while x < rect.end.x:
				draw_rect(Rect2(Vector2(x, y), Vector2(tile, tile)).intersection(rect), dark)
				x += tile * 2.0
			y += tile
			row += 1
	elif lower.contains("bed"):
		draw_rect(rect, Color(0.88, 0.80, 0.78))
		var bed: Rect2 = Rect2(rect.end - Vector2(34, 30), Vector2(26, 22))
		draw_rect(bed, Color(0.96, 0.95, 0.92))
		draw_rect(Rect2(bed.position, Vector2(bed.size.x, 7)), Color(0.55, 0.62, 0.78))
		draw_rect(bed, Color(0.45, 0.36, 0.30), false, 1.0)
	elif lower.contains("living"):
		draw_rect(rect, Color(0.84, 0.72, 0.56))
		var plank: float = rect.position.y + 7.0
		while plank < rect.end.y:
			draw_line(Vector2(rect.position.x, plank), Vector2(rect.end.x, plank), Color(0.72, 0.60, 0.45, 0.6), 1.0)
			plank += 7.0
		var rug: Rect2 = Rect2(rect.get_center() + Vector2(10, -6), Vector2(minf(60.0, rect.size.x * 0.45), 24))
		draw_rect(rug, Color(0.62, 0.30, 0.28, 0.75))
		var sofa: Rect2 = Rect2(Vector2(rect.end.x - 50, rect.end.y - 14), Vector2(42, 9))
		draw_rect(sofa, Color(0.30, 0.48, 0.48))
	else:
		draw_rect(rect, Color(0.90, 0.86, 0.76))


func _draw_interior() -> void:
	var home: String = _interior_home()
	if home == "":
		return
	draw_style_box(_card_box, INTERIOR_RECT)
	draw_style_box(_card_head, Rect2(INTERIOR_RECT.position, Vector2(INTERIOR_RECT.size.x, 42)))
	draw_string(_font, INTERIOR_RECT.position + Vector2(12, 19), "Inside your home", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, PAPER)
	draw_string(_font, INTERIOR_RECT.position + Vector2(12, 35), "FICTIONAL INTERIOR (invented layout)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUSTARD)
	var rooms: Dictionary = area.interiors[home]["rooms"]
	var rects: Dictionary = _room_rects()
	var occupants: Dictionary = {}
	for person: Dictionary in _occupants(home):
		var spot: String = person["spot"] if rects.has(person["spot"]) else ""
		if not occupants.has(spot):
			occupants[spot] = []
		occupants[spot].append(person)
	var hovered_room: String = ""
	for room_id: String in rects:
		if (rects[room_id] as Rect2).has_point(_hover):
			hovered_room = room_id
	for room_id: String in rects:
		var rect: Rect2 = rects[room_id]
		_draw_floor(rect, rooms[room_id]["name"])
		if room_id == hovered_room:
			draw_rect(rect, Color(1.0, 0.95, 0.70, 0.35))
	for room_id: String in rects:
		var rect: Rect2 = rects[room_id]
		draw_rect(rect, Color(0.32, 0.25, 0.21), false, 3.0)
		var label: String = rooms[room_id]["name"]
		var label_width: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2(label_width + 8, 15)), Color(PAPER, 0.85))
		draw_string(_font, rect.position + Vector2(7, 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
		var row: int = 0
		var here: Array = occupants.get(room_id, [])
		var spacing: float = minf(15.0, (rect.size.y - 30.0) / maxf(float(here.size()), 1.0))
		for person: Dictionary in here:
			var at: Vector2 = rect.position + Vector2(13, 30.0 + float(row) * spacing)
			var players: bool = simulation.state.households[person["household_id"]]["player_controlled"]
			if person["id"] == selected_id:
				draw_circle(at, 7.5, MUSTARD)
			draw_circle(at, 5.5, _pick(PLAYER_CLOTHES, person["id"]) if players else _pick(CLOTHES, person["id"]))
			draw_circle(at - Vector2(0, 1.5), 2.6, COLOR_SKIN)
			var bubble: Dictionary = _bubbles.get(person["id"], {})
			var doing: String = (bubble.get("text", "") as String).to_lower()
			var text: String = "%s: %s" % [person["given_name"], doing]
			var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x) - 24, 10).x
			draw_rect(Rect2(at + Vector2(8, -7), Vector2(width + 6, 13)), Color(PAPER, 0.8))
			draw_string(_font, at + Vector2(11, 3.5), text, HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x) - 24, 10, INK)
			row += 1
	draw_string(_font, Vector2(INTERIOR_RECT.position.x + 12, INTERIOR_RECT.end.y - 9), "Click a room to send someone there", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.48, 0.40, 0.34))


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		_hover = motion.position
		if _pressing and (motion.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE)) != 0:
			if not _dragging and motion.position.distance_to(_press_at) > DRAG_THRESHOLD:
				_dragging = true
			if _dragging:
				_pan += motion.relative
				_apply_view()
		Input.set_default_cursor_shape(Input.CURSOR_DRAG if _dragging else (Input.CURSOR_POINTING_HAND if not _hovered().is_empty() else Input.CURSOR_ARROW))
		return
	if event is InputEventKey:
		var key: InputEventKey = event
		if not key.pressed:
			return
		var step: float = 40.0
		match key.keycode:
			KEY_LEFT, KEY_A:
				_pan.x += step
			KEY_RIGHT, KEY_D:
				_pan.x -= step
			KEY_UP, KEY_W:
				_pan.y += step
			KEY_DOWN, KEY_S:
				_pan.y -= step
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				_zoom_by(ZOOM_STEP, MAP_RECT.get_center())
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom_by(1.0 / ZOOM_STEP, MAP_RECT.get_center())
			KEY_HOME, KEY_R:
				reset_view()
			_:
				return
		_apply_view()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton):
		return
	var click: InputEventMouseButton = event
	if click.pressed and (click.button_index == MOUSE_BUTTON_WHEEL_UP or click.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_zoom_by(ZOOM_STEP if click.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP, click.position)
		return
	if click.button_index == MOUSE_BUTTON_MIDDLE:
		_pressing = click.pressed
		_dragging = false
		_press_at = click.position
		return
	if click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		var looked_at: String = _building_at(click.position)
		if looked_at != "":
			building_info_requested.emit(looked_at)
		return
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	if click.pressed:
		_pressing = true
		_dragging = false
		_press_at = click.position
		return
	# Released: a click unless the mouse was dragged to look around.
	var was_drag: bool = _dragging
	_pressing = false
	_dragging = false
	if was_drag:
		return
	_click(click.position)


func _click(point: Vector2) -> void:
	var rects: Dictionary = _room_rects()
	for room_id: String in rects:
		if (rects[room_id] as Rect2).has_point(point):
			room_clicked.emit(room_id)
			return
	if INTERIOR_RECT.has_point(point) and not rects.is_empty():
		return
	var person_id: String = _person_at(point)
	if person_id != "":
		person_clicked.emit(person_id)
		return
	var clicked: String = _building_at(point)
	if clicked != "":
		building_clicked.emit(clicked)


## The building drawn at a point on the screen ("" if none). The frontmost
## building wins where two overlap.
func _building_at(point: Vector2) -> String:
	if INTERIOR_RECT.has_point(point) and _interior_home() != "":
		return ""
	var found: String = ""
	var found_depth: float = -INF
	for building_id: String in area.sorted_building_ids():
		var shapes: Array = _building_shapes.get(building_id, [])
		if shapes.is_empty():
			var building: Dictionary = area.buildings[building_id]
			shapes = [_polygon(building["footprint"]), _polygon(building["footprint"], (_wall_height(building) + _roof_rise(building)) * _scale)]
		for shape: PackedVector2Array in shapes:
			if Geometry2D.is_point_in_polygon(point, shape):
				var rect: Rect2 = _rect_of(area.buildings[building_id]["footprint"])
				var depth: float = _iso(rect.get_center().x, rect.get_center().y).y
				if depth > found_depth:
					found_depth = depth
					found = building_id
				break
	return found
