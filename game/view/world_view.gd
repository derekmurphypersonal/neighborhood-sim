extends Node2D
## Draws the area and the people in it in an isometric projection: lawns,
## sidewalks, gabled houses with windows, trees, street lamps and small
## figures, lit by a day-and-night cycle; plus activity bubbles, floating
## notices and the cutaway of the player's home.
##
## Presentation only: reads simulation state, changes nothing. Decorations
## (trees, shrubs, parked cars, lamps, paint colors, a cat and a dog) are
## invented, chosen deterministically from IDs, and never stored in
## simulation state (D-058).
##
## It also answers the player: a dashed path and a marker where the selected
## person has been sent, a ripple where the map is clicked, doors that swing
## as people go in and out, a wave when a conversation starts, and a card
## about the person under the pointer. These are worked out by comparing
## the simulation's state with what was drawn the frame before.

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
const RIPPLE_MS: int = 480
const DOOR_SWING_MS: int = 1000
const WAVE_MS: int = 1000
const ORDER_FADE_IN_MS: int = 180
const ORDER_FADE_OUT_MS: int = 600
const FOLLOW_EASE: float = 3.0

## Game minutes (of the day) when kitchen stoves and furnaces send smoke up
## the chimney: early morning, midday and supper. Invented, for atmosphere.
const SMOKE_TIMES: Array[Vector2i] = [Vector2i(360, 510), Vector2i(690, 810), Vector2i(1020, 1170)]
const FLOWER_COLORS: Array[Color] = [
	Color(0.86, 0.22, 0.20), Color(0.97, 0.82, 0.25), Color(0.98, 0.97, 0.93), Color(0.95, 0.58, 0.70),
]
const WASHING: Array[Color] = [
	Color(0.98, 0.97, 0.93), Color(0.70, 0.82, 0.92), Color(0.95, 0.70, 0.72), Color(0.96, 0.90, 0.62), Color(0.80, 0.88, 0.76),
]

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
## Shutters are dark so they stand out against the pale siding.
const SHUTTERS: Array[Color] = [
	Color(0.18, 0.32, 0.25), Color(0.20, 0.25, 0.34), Color(0.46, 0.20, 0.18), Color(0.17, 0.17, 0.18), Color(0.28, 0.38, 0.40),
]
const CURTAINS: Array[Color] = [
	Color(0.98, 0.96, 0.90), Color(0.97, 0.84, 0.84), Color(0.98, 0.92, 0.70), Color(0.84, 0.92, 0.88),
]
const HATS: Array[Color] = [
	Color(0.36, 0.28, 0.22), Color(0.40, 0.40, 0.43), Color(0.22, 0.25, 0.34), Color(0.86, 0.78, 0.56), Color(0.58, 0.26, 0.28),
]
const BLOSSOMS: Array[Color] = [Color(0.97, 0.76, 0.84), Color(0.99, 0.95, 0.95)]
const TULIPS: Array[Color] = [
	Color(0.88, 0.16, 0.20), Color(0.99, 0.80, 0.18), Color(0.96, 0.46, 0.62), Color(0.99, 0.97, 0.93),
]
const BIKE_PAINT: Array[Color] = [Color(0.72, 0.18, 0.16), Color(0.20, 0.38, 0.64), Color(0.20, 0.46, 0.30)]
const COLOR_HAZE: Color = Color(0.77, 0.82, 0.74)
const COLOR_CONCRETE: Color = Color(0.74, 0.72, 0.67)
const COLOR_WIRE: Color = Color(0.16, 0.15, 0.14)
const PORCH_DEPTH: float = 7.0 * FOOT
const POLE_HEIGHT: float = 25.0 * FOOT

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
var _flowers: Array = []    # {"x", "y", "dots": [[dx, dy, Color], ...]}
var _mailboxes: Array = []  # {"x", "y", "along" (Vector2, world), "paint"}
var _clotheslines: Array = []  # {"a", "b" (world Vector2), "items": [[t, width, drop, Color], ...]}
## building_id -> Vector3(x, y, z) of the top of its chimney (houses only)
var _chimneys: Dictionary = {}
var _clouds: Array = []     # {"x", "y", "blobs": [[dx, dy, radius], ...]}
## The area cloud shadows drift across, wrapping round at the edges.
var _world_bounds: Rect2 = Rect2()
## All lots together; the world fades into haze beyond them.
var _lot_bounds: Rect2 = Rect2()
## building_id -> {"out", "along_x", "shutter", "curtain", "cafe", "porch",
## "dormer", "bay", "bay_wall", "bay_u", "awning_wall", "flicker"}
var _styles: Dictionary = {}
var _patches: Array = []    # {"x", "y", "r", "color"}: soft blotches in the grass
var _stripes: Array = []    # [Vector2 corner, Vector2 opposite corner]: mowing stripes
var _poles: Array = []      # {"x", "y", "across", "transformer"}
var _wires: Array = []      # {"a", "b" (world Vector2), "across", "t0", "t1"}: pieces of a span
var _hydrants: Array = []   # {"x", "y"}
var _drains: Array = []     # {"x", "y", "along", "inward"}
var _cans: Array = []       # {"x", "y"}
var _bicycles: Array = []   # {"x", "y", "along", "lean", "paint"}
var _wagons: Array = []     # {"x", "y", "along"}
var _tulips: Array = []     # {"a", "b", "colors"}
var _glints: Array = []     # {"x", "y", "phase"}: lamplight catching the street at night
# Kinds of thing that stand up from the ground, for the drawing order.
enum {KIND_BUILDING, KIND_TREE, KIND_SHRUB, KIND_LAMP, KIND_CAR, KIND_FENCE, KIND_FLOWERS, KIND_MAILBOX, KIND_CLOTHESLINE,
		KIND_POLE, KIND_WIRE, KIND_HYDRANT, KIND_CAN, KIND_BICYCLE, KIND_WAGON, KIND_TULIPS, KIND_PERSON, KIND_CAT, KIND_DOG}
## Everything that stands still, sorted once from the back of the view to
## the front (the order does not change with zoom or panning). Each:
## [order, bias (pixels), kind, item, x, y (world), radius, height (inches)].
var _statics: Array = []
## Building IDs in order, and each building's footprint as a rectangle.
var _building_ids: Array = []
var _rects: Dictionary = {}
## building_id -> [people inside, of whom asleep], counted once a frame
var _inside: Dictionary = {}
## Screen geometry that depends only on the zoom and pan, kept until either
## changes: grass tufts, fence pickets, wires and mowing stripes.
var _view_key: Vector3 = Vector3.ZERO
var _tuft_lines: Array[PackedVector2Array] = []
var _fence_lines: Array = []
var _wire_lines: Array = []
var _stripe_shapes: Array[PackedVector2Array] = []
var _sign_box: StyleBoxFlat
var _tag_box: StyleBoxFlat
var _one_color: PackedColorArray = PackedColorArray([Color.WHITE])
## A white disc in three faint steps, made in code: one soft blotch of grass.
var _blotch: ImageTexture
var _no_uvs: PackedVector2Array = PackedVector2Array()

## A cat and a dog, invented like the rest of the decoration. The cat:
## {"route" (Array of Vector3: world x, y and height, from its step to its
## place on a fence), "coat", "offset" (seconds), "face"}. The dog: {"a", "b"
## (world Vector2, the ends of its run), "coat", "ear", "offset"}. Empty if
## there is no good place for one.
var _cat: Dictionary = {}
var _dog: Dictionary = {}
## Where each is this frame: {"at" (Vector3), "pose", "face" (1 right, -1 left), "step"}
var _cat_now: Dictionary = {}
var _dog_now: Dictionary = {}
var _golden: float = 0.0
var _spring: bool = false
var _selected_seen: String = ""
var _selected_since: int = -100000

# Follow camera: the view keeps the selected person near the middle of the map.
var _following: bool = false

# Feedback and small animations. All of it is presentation, kept here and
# worked out by comparing the simulation's state with what was seen last frame.
## Each: {"iso" (unscaled isometric point), "since", "good"}
var _ripples: Array = []
## person_id -> [at, place_id] as last drawn
var _seen_at: Dictionary = {}
## person_id -> whether they were talking when last drawn
var _seen_talking: Dictionary = {}
## building_id -> when (ms) its door last swung open
var _door_swings: Dictionary = {}
## person_id -> when (ms) they started waving
var _waves: Dictionary = {}
## person_id -> building they are about to be seen stepping into
var _doors_due: Dictionary = {}
## person_id -> true: will wave once seen to arrive
var _waves_due: Dictionary = {}
## Where the selected person has been sent: {"person_id", "points" (world
## Vector2s, from them to the place), "flag" (a building's door), "born",
## "seen" (ms it last held good)}; empty when there is nothing to show.
var _order_mark: Dictionary = {}


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
	_sign_box = _box(Color.WHITE, CHERRY, 2, 4)
	_tag_box = _box(Color.WHITE, Color(1, 1, 1, 0.7), 1, 4)
	_building_ids = area.sorted_building_ids()
	_blotch = _make_blotch()
	_fit_to_screen()
	_plan_decoration()
	_plan_drawing_order()


## Three discs laid one on another, each letting 5% through: the same
## look as drawing them one by one, as a single small picture.
func _make_blotch() -> ImageTexture:
	var size: int = 96
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y: int in size:
		for x: int in size:
			var r: float = Vector2(float(x) + 0.5 - float(size) / 2.0, float(y) + 0.5 - float(size) / 2.0).length() / (float(size) / 2.0)
			var alpha: float = 0.0
			if r <= 0.4:
				alpha = 1.0 - 0.95 * 0.95 * 0.95
			elif r <= 0.7:
				alpha = 1.0 - 0.95 * 0.95
			elif r <= 1.0:
				alpha = 0.05
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)


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
	if _following:
		_follow_step(delta)


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


## Starts or stops keeping the selected person in the middle of the map.
func toggle_follow() -> void:
	_following = not _following and selected_id != ""


func is_following() -> bool:
	return _following


## Where the selected person is on screen: their figure outdoors, the door of
## the building they are in, or nowhere (Vector2.INF) when off the map.
func _follow_target() -> Vector2:
	if simulation == null or not simulation.state.people.has(selected_id):
		return Vector2.INF
	var person: Dictionary = simulation.state.people[selected_id]
	if person["at"] == Records.AT_OUTSIDE or _is_walking(selected_id):
		return _animated_position(person)
	if person["at"] == Records.AT_INSIDE:
		return to_screen(area.buildings[person["place_id"]]["door"])
	return Vector2.INF


func _follow_step(delta: float) -> void:
	var target: Vector2 = _follow_target()
	if target == Vector2.INF:
		return
	var gap: Vector2 = MAP_RECT.get_center() - target
	if gap.length() < 0.5:
		return
	_pan += gap * clampf(delta * FOLLOW_EASE, 0.0, 1.0)
	_apply_view()


func _draw_follow_pill() -> void:
	if not _following or not simulation.state.people.has(selected_id):
		return
	var person: Dictionary = simulation.state.people[selected_id]
	var away: bool = person["at"] != Records.AT_OUTSIDE and person["at"] != Records.AT_INSIDE
	var text: String = "Following %s%s  (F to stop)" % [person["given_name"], ", who is away" if away else ""]
	var size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12) + Vector2(26, 8)
	# Top left of the map, where it is least likely to cover the person followed.
	var at: Vector2 = MAP_RECT.position + Vector2(6, 6)
	draw_style_box(_home_pill, Rect2(at, size))
	draw_circle(at + Vector2(11, size.y / 2.0), 3.5, MUSTARD)
	draw_string(_font, at + Vector2(19, size.y - 8.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PAPER)


func reset_view() -> void:
	_following = false
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


## A building's footprint as a rectangle, worked out once.
func _building_rect(building: Dictionary) -> Rect2:
	var id: String = building["id"]
	if not _rects.has(id):
		_rects[id] = _rect_of(building["footprint"])
	return _rects[id]


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
	_lot_bounds = everything
	_world_bounds = everything.grow(70.0 * FOOT)
	var near: Rect2 = everything.grow(40.0 * FOOT)
	everything = everything.grow(200.0 * FOOT)

	# Soft, large blotches of lighter and darker grass, and mowing stripes on the lawns.
	var patch_rng: RandomNumberGenerator = _rng_for("grass patches")
	var patch_colors: Array[Color] = [Color(0.72, 0.80, 0.52), Color(0.34, 0.47, 0.29), Color(0.70, 0.70, 0.44)]
	for index: int in 46:
		_patches.append({
			"x": patch_rng.randf_range(near.position.x, near.end.x),
			"y": patch_rng.randf_range(near.position.y, near.end.y),
			"r": patch_rng.randf_range(10.0, 30.0) * FOOT,
			"color": patch_colors[patch_rng.randi_range(0, patch_colors.size() - 1)],
		})
	for lot_id: String in area.lots:
		var lawn: Rect2 = _rect_of(area.lots[lot_id]["boundary"])
		var width: float = 5.0 * FOOT
		var count: int = int(lawn.size.x / width)
		for index: int in range(0, count, 2):
			var x: float = lawn.position.x + float(index) * width
			_stripes.append([Vector2(x, lawn.position.y), Vector2(minf(x + width, lawn.end.x), lawn.end.y)])

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

	var wash_spots: Array = []
	var fronts: Array = []  # [building_id, curb, toward, beside, door, reach] for front gardens
	for building_id: String in area.sorted_building_ids():
		var building: Dictionary = area.buildings[building_id]
		var door: Vector2 = Vector2(building["door"][0], building["door"][1])
		var street: Dictionary = _nearest_street_point(door)
		var store: bool = _is_store(building)
		var deco_rng: RandomNumberGenerator = _rng_for(building_id + ":garden")
		var rect: Rect2 = _rect_of(building["footprint"])
		var along_x: bool = absf(door.y - rect.position.y) < 1.0 or absf(door.y - rect.end.y) < 1.0
		var outward: Vector2 = Vector2(0, -1 if absf(door.y - rect.position.y) < 1.0 else 1) if along_x \
				else Vector2(-1 if absf(door.x - rect.position.x) < 1.0 else 1, 0)
		var style: Dictionary = _plan_style(building, outward, along_x)
		var porch: bool = style["porch"]
		if not street.is_empty():
			var toward: Vector2 = (street["point"] as Vector2 - door).normalized()
			var reach: float = maxf(float(street["distance"]) - float(street["half"]), 0.0)
			var curb: Vector2 = door + toward * reach
			_walks.append([door, curb])
			if not store:
				# A mailbox post on the lawn side of the sidewalk, beside the walk.
				var beside: Vector2 = toward.orthogonal() * (1.0 if deco_rng.randf() < 0.5 else -1.0)
				var post: Vector2 = curb - toward * 6.5 * FOOT + beside * 3.0 * FOOT
				_mailboxes.append({"x": post.x, "y": post.y, "along": toward,
						"paint": [Color(0.22, 0.30, 0.42), Color(0.30, 0.30, 0.32), Color(0.20, 0.36, 0.26)][deco_rng.randi_range(0, 2)]})
				fronts.append([building_id, curb, toward, beside, door, reach])
				# Flower beds along both sides of some front walks.
				if deco_rng.randf() < 0.6 and reach > 16.0 * FOOT:
					for t: float in [0.3, 0.55]:
						if porch and reach * t < PORCH_DEPTH + 3.0 * FOOT:
							continue
						for side: float in [1.0, -1.0]:
							var at: Vector2 = door + toward * reach * t + toward.orthogonal() * side * 3.0 * FOOT
							_flowers.append(_flower_cluster(at, toward, deco_rng))
		# Galvanized garbage cans by the back corner of the east wall.
		if not store and absi((building_id + ":cans").hash()) % 5 != 0:
			var rear: Vector2 = -outward
			var cans: int = 1 + absi((building_id + ":cans").hash()) % 2
			for index: int in cans:
				var spot: Vector2
				if along_x:
					var rear_y: float = rect.end.y if rear.y > 0.0 else rect.position.y
					spot = Vector2(rect.end.x + 2.0 * FOOT, rear_y - rear.y * (3.0 + 2.1 * float(index)) * FOOT)
				else:
					var rear_x: float = rect.end.x if rear.x > 0.0 else rect.position.x
					spot = Vector2(rear_x - rear.x * (3.0 + 2.1 * float(index)) * FOOT, rect.position.y - 2.0 * FOOT)
				_cans.append({"x": spot.x, "y": spot.y})
		# Shrubs along the wall the door is on, leaving the door clear.
		var shrub_rng: RandomNumberGenerator = _rng_for(building_id + ":shrubs")
		var length: float = rect.size.x if along_x else rect.size.y
		var count: int = int(length / (7.0 * FOOT))
		for index: int in count:
			var u: float = (float(index) + 0.5) / float(count)
			var at: Vector2 = Vector2(rect.position.x + rect.size.x * u, door.y) if along_x \
					else Vector2(door.x, rect.position.y + rect.size.y * u)
			if at.distance_to(door) < (6.0 if porch else 5.0) * FOOT:
				continue
			at += outward * ((PORCH_DEPTH + 2.2 * FOOT) if porch else 2.5 * FOOT)
			_shrubs.append({"x": at.x, "y": at.y, "size": shrub_rng.randf_range(2.2, 3.2) * FOOT, "shade": shrub_rng.randf()})
			if not store and deco_rng.randf() < 0.55:
				var wall: Vector2 = Vector2(1, 0) if along_x else Vector2(0, 1)
				_flowers.append(_flower_cluster(at + outward * 2.2 * FOOT, wall, deco_rng))
		if not store:
			var top: Vector3 = _chimney_top(building)
			_chimneys[building_id] = top
			var back: Vector2 = -outward
			var depth: float = rect.size.y if along_x else rect.size.x
			if back.x - back.y > 0.0:  # a back yard on the viewer's side, where washing can be seen
				wash_spots.append([building_id, rect.get_center() + back * (depth / 2.0 + 11.0 * FOOT), Vector2(back.y, back.x)])

	for spot: Array in wash_spots:
		_plan_clothesline(spot[0], spot[1], spot[2], false)
	for spot: Array in wash_spots:
		if not _clotheslines.is_empty() or _plan_clothesline(spot[0], spot[1], spot[2], true):
			break

	# Rows of tulips along the front of two gardens, on the side away from the mailbox.
	fronts.sort_custom(func(a: Array, b: Array) -> bool:
		return absi((String(a[0]) + ":tulips").hash()) < absi((String(b[0]) + ":tulips").hash()))
	for front: Array in fronts.slice(0, 2):
		var curb: Vector2 = front[1]
		var toward: Vector2 = front[2]
		var away: Vector2 = -(front[3] as Vector2)
		var base: Vector2 = curb - toward * 7.5 * FOOT
		var tulip_rng: RandomNumberGenerator = _rng_for(String(front[0]) + ":tulips")
		var colors: Array = []
		var first_color: int = tulip_rng.randi_range(0, TULIPS.size() - 1)
		for index: int in 12:
			colors.append(TULIPS[(first_color + (index % 2 if tulip_rng.randf() < 0.5 else 0)) % TULIPS.size()])
		_tulips.append({"a": base + away * 4.5 * FOOT, "b": base + away * 15.0 * FOOT, "colors": colors})

	for lot_id: String in area.lots:
		var boundary: Array = area.lots[lot_id]["boundary"]
		var lot_rect: Rect2 = _rect_of(boundary)
		# A picket fence on every side but the one nearest the street.
		var front: int = -1
		var front_distance: float = INF
		for index: int in boundary.size():
			var a: Vector2 = Vector2(boundary[index][0], boundary[index][1])
			var b: Vector2 = Vector2(boundary[(index + 1) % boundary.size()][0], boundary[(index + 1) % boundary.size()][1])
			var edge_near: Dictionary = _nearest_street_point((a + b) / 2.0)
			if not edge_near.is_empty() and float(edge_near["distance"]) < front_distance:
				front_distance = edge_near["distance"]
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
			for line: Dictionary in _clotheslines:
				if Geometry2D.get_closest_point_to_segment(spot, line["a"], line["b"]).distance_to(spot) < 10.0 * FOOT:
					clear = false
			for row: Dictionary in _tulips:
				if Geometry2D.get_closest_point_to_segment(spot, row["a"], row["b"]).distance_to(spot) < 7.0 * FOOT:
					clear = false
			for can: Dictionary in _cans:
				if Vector2(can["x"], can["y"]).distance_to(spot) < 6.0 * FOOT:
					clear = false
			var street_gap: Dictionary = _nearest_street_point(spot)
			if not street_gap.is_empty() and float(street_gap["distance"]) < float(street_gap["half"]) + 9.0 * FOOT:
				clear = false
			for tree: Dictionary in _trees:
				if Vector2(tree["x"], tree["y"]).distance_to(spot) < 14.0 * FOOT:
					clear = false
			if not clear:
				continue
			var evergreen: bool = tree_rng.randf() < 0.25
			var specks: Array = []
			for speck: int in 14:
				specks.append(Vector2(tree_rng.randf_range(-1.1, 1.1), tree_rng.randf_range(-1.0, 0.8)))
			_trees.append({
				"x": spot.x, "y": spot.y, "size": tree_rng.randf_range(7.0, 11.0) * FOOT,
				"shade": tree_rng.randf(), "evergreen": evergreen,
				# Some flowering trees, in blossom in spring.
				"blossom": -1 if evergreen or tree_rng.randf() < 0.55 else tree_rng.randi_range(0, BLOSSOMS.size() - 1),
				"specks": specks,
			})
			wanted -= 1

	_plan_yard_things(fronts)

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
					var glint_rng: RandomNumberGenerator = _rng_for("glints %d %d" % [roundi(spot.x), roundi(spot.y)])
					for glint: int in 7:
						var on: Vector2 = spot - across * side * glint_rng.randf_range(3.0, 13.0) * FOOT + along * glint_rng.randf_range(-10.0, 10.0) * FOOT
						_glints.append({"x": on.x, "y": on.y, "phase": glint_rng.randf() * TAU})
				side = -side
				at += 90.0 * FOOT
			var car_rng: RandomNumberGenerator = _rng_for(street_id + ":cars")
			for car: int in 2:
				var place: float = length * (0.33 + 0.4 * float(car)) + car_rng.randf_range(-6.0, 6.0) * FOOT
				var car_side: float = 1.0 if car == 0 else -1.0
				var spot: Vector2 = a + along * place + across * car_side * (half - 4.5 * FOOT)
				_cars.append({"x": spot.x, "y": spot.y, "along_x": absf(along.x) >= absf(along.y),
						"paint": CAR_PAINT[car_rng.randi_range(0, CAR_PAINT.size() - 1)]})

	_plan_street_furniture()
	_plan_animals()

	# Large, soft cloud shadows that drift over the street by day.
	var cloud_rng: RandomNumberGenerator = _rng_for("clouds")
	for cloud: int in 3:
		var blobs: Array = []
		for blob: int in 4:
			blobs.append([cloud_rng.randf_range(-40.0, 40.0) * FOOT, cloud_rng.randf_range(-24.0, 24.0) * FOOT,
					cloud_rng.randf_range(36.0, 60.0) * FOOT])
		_clouds.append({
			"x": cloud_rng.randf_range(_world_bounds.position.x, _world_bounds.end.x),
			"y": cloud_rng.randf_range(_world_bounds.position.y, _world_bounds.end.y),
			"blobs": blobs,
		})


## A small cluster of flowers around a point, spread along a direction.
func _flower_cluster(at: Vector2, along: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var dots: Array = []
	var mixed: bool = rng.randf() < 0.4
	var base: Color = FLOWER_COLORS[rng.randi_range(0, FLOWER_COLORS.size() - 1)]
	var spread: Vector2 = along.normalized()
	for index: int in rng.randi_range(4, 7):
		var offset: Vector2 = spread * rng.randf_range(-2.4, 2.4) * FOOT + spread.orthogonal() * rng.randf_range(-0.8, 0.8) * FOOT
		var color: Color = FLOWER_COLORS[rng.randi_range(0, FLOWER_COLORS.size() - 1)] if mixed else base
		dots.append([offset.x, offset.y, color])
	return {"x": at.x, "y": at.y, "dots": dots}


## A clothesline in one or two back yards, chosen from the building's ID.
## Returns whether one was put up.
func _plan_clothesline(building_id: String, middle: Vector2, along: Vector2, force: bool) -> bool:
	if _clotheslines.size() >= 2 or (not force and absi((building_id + ":washday").hash()) % 3 != 0):
		return false
	var a: Vector2 = middle - along * 7.0 * FOOT
	var b: Vector2 = middle + along * 7.0 * FOOT
	var inside: bool = false
	for lot_id: String in area.lots:
		var lot: PackedVector2Array = PackedVector2Array()
		for point: Array in area.lots[lot_id]["boundary"]:
			lot.append(Vector2(point[0], point[1]))
		if Geometry2D.is_point_in_polygon(a, lot) and Geometry2D.is_point_in_polygon(b, lot):
			inside = true
	if not inside:
		return false
	var rng: RandomNumberGenerator = _rng_for(building_id + ":washing")
	var items: Array = []
	var t: float = 0.12
	while t < 0.85:
		var width: float = rng.randf_range(1.4, 2.6) * FOOT
		items.append([t, width, rng.randf_range(1.4, 2.8) * FOOT, WASHING[rng.randi_range(0, WASHING.size() - 1)]])
		t += width / (14.0 * FOOT) + rng.randf_range(0.06, 0.14)
	_clotheslines.append({"a": a, "b": b, "items": items})
	return true


## How a building is dressed: shutters, curtains, a porch, a dormer or a bay
## window, a store awning. Invented, chosen from the building's ID (P-023).
func _plan_style(building: Dictionary, outward: Vector2, along_x: bool) -> Dictionary:
	var id: String = building["id"]
	var rng: RandomNumberGenerator = _rng_for(id + ":style")
	var store: bool = _is_store(building)
	var rect: Rect2 = _rect_of(building["footprint"])
	var porch: bool = not store and String(building.get("building_type", "")) == "two-family"
	var style: Dictionary = {
		"out": outward, "along_x": along_x,
		"shutter": SHUTTERS[rng.randi_range(0, SHUTTERS.size() - 1)],
		"curtain": CURTAINS[rng.randi_range(0, CURTAINS.size() - 1)],
		"cafe": rng.randf() < 0.4,
		"porch": porch, "dormer": false, "bay": false,
		"flicker": rng.randf() * TAU,
	}
	# The walls the viewer sees: south and east. Each is [from, to, outward].
	var south: Array = [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(0, -1)]
	var east: Array = [Vector2(rect.end.x, rect.position.y), rect.end, Vector2(1, 0)]
	if store:
		style["awning_wall"] = south if outward == Vector2(0, -1) else east
	elif not porch:
		var character: int = absi((id + ":character").hash()) % 3
		style["dormer"] = character == 0
		style["bay"] = character == 1
		var wall: Array = south if outward == Vector2(1, 0) else east
		var length: float = (wall[0] as Vector2).distance_to(wall[1])
		var count: int = maxi(1, int(length / (11.0 * FOOT)))
		style["bay_wall"] = wall
		style["bay_u"] = (float(count / 2) + 0.5) / float(count) * length
	_styles[id] = style
	return style


## True if nothing planned so far stands within the gap of a yard spot.
func _yard_spot_clear(spot: Vector2, gap: float) -> bool:
	for building_id: String in area.buildings:
		if _rect_of(area.buildings[building_id]["footprint"]).grow(gap).has_point(spot):
			return false
	for tree: Dictionary in _trees:
		if Vector2(tree["x"], tree["y"]).distance_to(spot) < gap + 2.0 * FOOT:
			return false
	for walk: Array in _walks:
		if Geometry2D.get_closest_point_to_segment(spot, walk[0], walk[1]).distance_to(spot) < gap:
			return false
	for row: Dictionary in _tulips:
		if Geometry2D.get_closest_point_to_segment(spot, row["a"], row["b"]).distance_to(spot) < gap:
			return false
	for things: Array in [_flowers, _mailboxes, _cans, _shrubs]:
		for thing: Dictionary in things:
			if Vector2(thing["x"], thing["y"]).distance_to(spot) < gap:
				return false
	for line: Dictionary in _clotheslines:
		if Geometry2D.get_closest_point_to_segment(spot, line["a"], line["b"]).distance_to(spot) < gap:
			return false
	return true


## A child's wagon left in one front yard, and a bicycle leaning on one fence.
func _plan_yard_things(fronts: Array) -> void:
	var order: Array = fronts.duplicate()
	order.sort_custom(func(a: Array, b: Array) -> bool:
		return absi((String(a[0]) + ":wagon").hash()) < absi((String(b[0]) + ":wagon").hash()))
	for front: Array in order:
		if not _wagons.is_empty():
			break
		var door: Vector2 = front[4]
		var toward: Vector2 = front[2]
		for t: float in [0.45, 0.65]:
			for side: float in [1.0, -1.0]:
				var spot: Vector2 = door + toward * float(front[5]) * t + toward.orthogonal() * side * 8.0 * FOOT
				if _wagons.is_empty() and _yard_spot_clear(spot, 4.5 * FOOT):
					_wagons.append({"x": spot.x, "y": spot.y, "along": toward.orthogonal().rotated(0.45 * side)})
	var lots: Array = area.lots.keys()
	lots.sort_custom(func(a: String, b: String) -> bool:
		return absi((a + ":bicycle").hash()) < absi((b + ":bicycle").hash()))
	for lot_id: String in lots:
		var rect: Rect2 = _rect_of(area.lots[lot_id]["boundary"])
		var street: Dictionary = _nearest_street_point(rect.get_center())
		# Only lots with the street to the south, so the west fence is in plain view.
		if street.is_empty() or (street["point"] as Vector2).y > rect.get_center().y:
			continue
		for depth: float in [0.32, 0.5, 0.7]:
			var spot: Vector2 = Vector2(rect.position.x + 1.3 * FOOT, rect.position.y + rect.size.y * depth)
			if _yard_spot_clear(spot, 4.0 * FOOT):
				_bicycles.append({"x": spot.x, "y": spot.y, "along": Vector2(0, 1), "lean": Vector2(-1, 0),
						"paint": BIKE_PAINT[absi((lot_id + ":bicycle").hash()) % BIKE_PAINT.size()]})
				return


## Puts everything that stands still into one list, in the order it is
## drawn: from the back of the view to the front. That order depends only on
## where things are in the world, so it is worked out once.
func _plan_drawing_order() -> void:
	_statics.clear()
	for building_id: String in _building_ids:
		var building: Dictionary = area.buildings[building_id]
		var rect: Rect2 = _building_rect(building)
		_add_static(KIND_BUILDING, building_id, rect.get_center(), 0.0, rect.size.length() / 2.0 + 12.0 * FOOT,
				_wall_height(building) + _roof_rise(building) + 10.0 * FOOT)
	for tree: Dictionary in _trees:
		_add_static(KIND_TREE, tree, Vector2(tree["x"], tree["y"]), 0.0, float(tree["size"]) * 1.4, float(tree["size"]) * 2.6)
	for shrub: Dictionary in _shrubs:
		_add_static(KIND_SHRUB, shrub, Vector2(shrub["x"], shrub["y"]), 0.0, float(shrub["size"]) * 1.2, float(shrub["size"]) * 2.0)
	for lamp: Dictionary in _lamps:
		_add_static(KIND_LAMP, lamp, Vector2(lamp["x"], lamp["y"]), 0.0, 4.0 * FOOT, 14.0 * FOOT)
	for car: Dictionary in _cars:
		_add_static(KIND_CAR, car, Vector2(car["x"], car["y"]), 0.0, 10.0 * FOOT, 6.0 * FOOT)
	for bed: Dictionary in _flowers:
		_add_static(KIND_FLOWERS, bed, Vector2(bed["x"], bed["y"]), -1.0, 4.0 * FOOT, 2.0 * FOOT)
	for mailbox: Dictionary in _mailboxes:
		_add_static(KIND_MAILBOX, mailbox, Vector2(mailbox["x"], mailbox["y"]), 0.0, 2.0 * FOOT, 6.0 * FOOT)
	for line: Dictionary in _clotheslines:
		var a: Vector2 = line["a"]
		var b: Vector2 = line["b"]
		_add_static(KIND_CLOTHESLINE, line, (a + b) / 2.0, 0.0, a.distance_to(b) / 2.0 + FOOT, 7.0 * FOOT)
	for index: int in _fences.size():
		var a: Vector2 = _fences[index][0]
		var b: Vector2 = _fences[index][1]
		_add_static(KIND_FENCE, index, (a + b) / 2.0, -2.0, a.distance_to(b) / 2.0 + FOOT, 4.0 * FOOT)
	for pole: Dictionary in _poles:
		_add_static(KIND_POLE, pole, Vector2(pole["x"], pole["y"]), 0.0, 4.0 * FOOT, POLE_HEIGHT + FOOT)
	for index: int in _wires.size():
		var wire: Dictionary = _wires[index]
		var a: Vector2 = (wire["a"] as Vector2).lerp(wire["b"], wire["t0"])
		var b: Vector2 = (wire["a"] as Vector2).lerp(wire["b"], wire["t1"])
		_add_static(KIND_WIRE, index, (a + b) / 2.0, 0.2, a.distance_to(b) / 2.0 + 3.0 * FOOT, POLE_HEIGHT)
	for hydrant: Dictionary in _hydrants:
		_add_static(KIND_HYDRANT, hydrant, Vector2(hydrant["x"], hydrant["y"]), 0.0, 2.0 * FOOT, 3.0 * FOOT)
	for can: Dictionary in _cans:
		_add_static(KIND_CAN, can, Vector2(can["x"], can["y"]), 0.0, 2.0 * FOOT, 3.0 * FOOT)
	for bike: Dictionary in _bicycles:
		_add_static(KIND_BICYCLE, bike, Vector2(bike["x"], bike["y"]), 0.0, 4.0 * FOOT, 4.0 * FOOT)
	for wagon: Dictionary in _wagons:
		_add_static(KIND_WAGON, wagon, Vector2(wagon["x"], wagon["y"]), 0.0, 5.0 * FOOT, 2.0 * FOOT)
	for row: Dictionary in _tulips:
		var a: Vector2 = row["a"]
		var b: Vector2 = row["b"]
		_add_static(KIND_TULIPS, row, (a + b) / 2.0, -1.0, a.distance_to(b) / 2.0 + FOOT, 2.0 * FOOT)
	_statics.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


## "bias" is in screen pixels: it settles which of two things at the same
## depth is drawn first. It is applied at the unzoomed scale for the order.
func _add_static(kind: int, item: Variant, at: Vector2, bias: float, radius: float, height: float) -> void:
	_statics.append([(at.x - at.y) * 0.5 * _base_scale + bias, bias, kind, item, at.x, at.y, radius, height])


func _in_one_lot(points: Array[Vector2]) -> bool:
	for lot_id: String in area.lots:
		var lot: PackedVector2Array = PackedVector2Array()
		for corner: Array in area.lots[lot_id]["boundary"]:
			lot.append(Vector2(corner[0], corner[1]))
		var inside: bool = true
		for point: Vector2 in points:
			if not Geometry2D.is_point_in_polygon(point, lot):
				inside = false
		if inside:
			return true
	return false


## A cat with a favourite front step and a favourite stretch of fence, and a
## dog with the run of one back yard. Invented, placed from building IDs
## (P-023); they are not in the simulation and nothing there knows of them.
func _plan_animals() -> void:
	var houses: Array = []
	for building_id: String in area.sorted_building_ids():
		if not _is_store(area.buildings[building_id]) and _styles.has(building_id):
			houses.append(building_id)
	houses.sort_custom(func(a: String, b: String) -> bool: return absi((a + ":cat").hash()) < absi((b + ":cat").hash()))
	var cat_home: String = ""
	for building_id: String in houses:
		var style: Dictionary = _styles[building_id]
		var out: Vector2 = style["out"]
		if not _faces_viewer(out):
			continue
		var door: Vector2 = _world_point(area.buildings[building_id]["door"])
		var along: Vector2 = out.orthogonal()
		var porch: bool = style["porch"]
		var seat: Vector2 = door + along * (3.4 if porch else 1.3) * FOOT + out * (4.0 if porch else 1.2) * FOOT
		var seat_z: float = (1.6 if porch else 1.0) * FOOT
		var ground: Vector2 = door + along * 1.3 * FOOT + out * ((PORCH_DEPTH + 3.6 * FOOT) if porch else 5.0 * FOOT)
		# The nearest fence that runs alongside, to walk the top of.
		var best: Array = []
		var best_distance: float = 60.0 * FOOT
		for fence: Array in _fences:
			var a: Vector2 = fence[0]
			var b: Vector2 = fence[1]
			var on: Vector2 = Geometry2D.get_closest_point_to_segment(ground, a, b)
			var room: float = maxf(on.distance_to(a), on.distance_to(b))
			if on.distance_to(ground) < best_distance and on.distance_to(ground) > 4.0 * FOOT and room > 12.0 * FOOT:
				best_distance = on.distance_to(ground)
				var toward: Vector2 = a if on.distance_to(a) > on.distance_to(b) else b
				best = [on, on + (toward - on).normalized() * minf(15.0 * FOOT, room - 2.0 * FOOT)]
		if best.is_empty():
			continue
		var top: float = 3.1 * FOOT
		var hop: Vector2 = best[0]
		var perch: Vector2 = best[1]
		_cat = {
			"route": [Vector3(seat.x, seat.y, seat_z), Vector3(ground.x, ground.y, 0.0), Vector3(hop.x, hop.y, 0.0),
					Vector3(hop.x, hop.y, top), Vector3(perch.x, perch.y, top)],
			"coat": [Color(0.86, 0.56, 0.26), Color(0.52, 0.52, 0.55), Color(0.17, 0.16, 0.16), Color(0.93, 0.90, 0.84)][absi((building_id + ":coat").hash()) % 4],
			"offset": float(absi((building_id + ":cat").hash()) % 64),
			"face": 1.0 if out.x + out.y >= 0.0 else -1.0,
		}
		cat_home = building_id
		break
	houses.sort_custom(func(a: String, b: String) -> bool: return absi((a + ":dog").hash()) < absi((b + ":dog").hash()))
	# First choice: a back yard on the viewer's side of its house, with
	# plenty of open grass; then whatever there is.
	for attempt: Array in [[true, 7.0], [true, 5.0], [true, 3.5], [false, 5.0], [false, 3.5]]:
		var in_view: bool = attempt[0]
		var gap: float = float(attempt[1]) * FOOT
		for building_id: String in houses:
			if not _dog.is_empty() or building_id == cat_home:
				continue
			var style: Dictionary = _styles[building_id]
			var back: Vector2 = -(style["out"] as Vector2)
			if in_view and not _faces_viewer(back):
				continue
			var rect: Rect2 = _rect_of(area.buildings[building_id]["footprint"])
			var depth: float = rect.size.y if style["along_x"] else rect.size.x
			var wall: Vector2 = Vector2(1, 0) if style["along_x"] else Vector2(0, 1)
			# Each: how far behind the house, how far along it, and half the length of the run (feet).
			for run: Array in [[11.0, 0.0, 9.0], [14.0, 0.0, 9.0], [11.0, 7.0, 8.0], [11.0, -7.0, 8.0], [15.0, 7.0, 7.0], [15.0, -7.0, 7.0], [8.0, 0.0, 7.0]]:
				var middle: Vector2 = rect.get_center() + back * (depth / 2.0 + float(run[0]) * FOOT) + wall * float(run[1]) * FOOT
				var spots: Array[Vector2] = []
				for t: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
					spots.append(middle + wall * t * float(run[2]) * FOOT)
				var clear: bool = _in_one_lot(spots)
				for spot: Vector2 in spots:
					if not _yard_spot_clear(spot, gap):
						clear = false
				if clear and _dog.is_empty():
					var coat: int = absi((building_id + ":coat").hash()) % 3
					_dog = {
						"a": spots[0], "b": spots[4],
						"coat": [Color(0.78, 0.60, 0.38), Color(0.47, 0.32, 0.22), Color(0.94, 0.92, 0.87)][coat],
						"ear": [Color(0.50, 0.35, 0.22), Color(0.28, 0.19, 0.14), Color(0.36, 0.26, 0.20)][coat],
						"offset": float(absi((building_id + ":dog").hash()) % 22),
					}


func _near_furniture(spot: Vector2, gap: float) -> bool:
	for walk: Array in _walks:
		if Geometry2D.get_closest_point_to_segment(spot, walk[0], walk[1]).distance_to(spot) < gap:
			return true
	for things: Array in [_lamps, _poles, _hydrants]:
		for thing: Dictionary in things:
			if Vector2(thing["x"], thing["y"]).distance_to(spot) < gap:
				return true
	return false


## Utility poles with sagging wires along the far side of each street, fire
## hydrants at the curb and storm drain grates in the gutters.
func _plan_street_furniture() -> void:
	for street_id: String in area.streets:
		var street: Dictionary = area.streets[street_id]
		var line: Array = street["centerline"]
		var half: float = float(street["width"]) / 2.0
		var rng: RandomNumberGenerator = _rng_for(street_id + ":furniture")
		var previous: Dictionary = {}
		for index: int in line.size() - 1:
			var a: Vector2 = Vector2(line[index][0], line[index][1])
			var b: Vector2 = Vector2(line[index + 1][0], line[index + 1][1])
			var along: Vector2 = (b - a).normalized()
			var across: Vector2 = along.orthogonal()
			var length: float = a.distance_to(b)
			# The far side of the street, so the wires never cross in front of it.
			var far: float = -1.0 if _faces_viewer(across) else 1.0
			var at: float = 10.0 * FOOT
			while at < length:
				var spot: Vector2 = a + along * at + across * far * (half + 0.9 * FOOT)
				var tries: int = 0
				while _near_furniture(spot, 9.0 * FOOT) and tries < 4:
					spot -= along * 7.0 * FOOT
					tries += 1
				var pole: Dictionary = {"x": spot.x, "y": spot.y, "across": across, "transformer": rng.randf() < 0.35}
				if not previous.is_empty():
					var from: Vector2 = Vector2(previous["x"], previous["y"])
					for piece: int in 6:
						_wires.append({"a": from, "b": spot, "across": across, "t0": float(piece) / 6.0, "t1": float(piece + 1) / 6.0})
				_poles.append(pole)
				previous = pole
				at += 100.0 * FOOT
			for side: float in [1.0, -1.0]:
				var hydrant_at: Vector2 = a + along * length * (0.24 if side > 0.0 else 0.66) + across * side * (half + 1.3 * FOOT)
				var tries: int = 0
				while _near_furniture(hydrant_at, 7.0 * FOOT) and tries < 6:
					hydrant_at += along * 6.0 * FOOT
					tries += 1
				_hydrants.append({"x": hydrant_at.x, "y": hydrant_at.y})
				for drain: int in 2:
					var u: float = length * (0.12 + 0.5 * float(drain)) + rng.randf_range(0.0, 0.25) * length
					var spot: Vector2 = a + along * u + across * side * (half - 0.8 * FOOT)
					_drains.append({"x": spot.x, "y": spot.y, "along": along, "inward": -across * side})


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
	_golden = clampf(golden, 0.0, 1.0)
	var warm: Color = Color(1.0, 0.85, 0.68)
	# Moonlight: blue, but light enough that the street stays readable.
	var dark: Color = Color(0.27, 0.33, 0.60)
	_ambient = Color.WHITE.lerp(warm, _golden * 0.75).lerp(dark, _night)
	var month: int = int(SimDate.from_day_index(simulation.clock.day_index)["month"])
	_spring = month == 4 or month == 5


func _tint(color: Color) -> Color:
	return Color(color.r * _ambient.r, color.g * _ambient.g, color.b * _ambient.b, color.a)


## Where shadows fall, per inch of height: west in the morning, east in the
## evening, always a little north.
func _shadow_lean() -> Vector2:
	var minute: float = float(simulation.clock.minute_of_day)
	var t: float = clampf((minute - 750.0) / 420.0, -1.0, 1.0)
	# Long shadows when the sun is low.
	return Vector2(t * 0.9, 0.55) * (1.0 + 0.8 * _golden)


# --- Noticing what changed since the last frame ---------------------------------

## Compares where people are and whether they are talking with what was drawn
## last, to start the door swings and waves. Reads the simulation only.
func _notice_changes() -> void:
	var now: int = Time.get_ticks_msec()
	var first_look: bool = _seen_at.is_empty()
	_inside.clear()
	for person_id: String in simulation.state.people:
		var person: Dictionary = simulation.state.people[person_id]
		var at: String = person["at"]
		var place: String = person["place_id"]
		if at == Records.AT_INSIDE:
			# Who is in each building, and how many of them are asleep.
			if not _inside.has(place):
				_inside[place] = [0, 0]
			_inside[place][0] += 1
			var doing: Dictionary = person["action"]
			if not doing.is_empty() and doing["started"] and doing["kind"] == "sleep":
				_inside[place][1] += 1
		if not first_look and _seen_at.has(person_id):
			var before: Array = _seen_at[person_id]
			if before[0] != at or before[1] != place:
				if before[0] == Records.AT_INSIDE and area.buildings.has(before[1]):
					_door_swings[before[1]] = now
				if at == Records.AT_INSIDE and area.buildings.has(place):
					_doors_due[person_id] = place
		_seen_at[person_id] = [at, place]
		var action: Dictionary = person["action"]
		var talking: bool = not action.is_empty() and action["kind"] == "talk"
		if talking and not first_look and not bool(_seen_talking.get(person_id, false)) and at == Records.AT_OUTSIDE:
			_waves_due[person_id] = true
		elif not talking:
			_waves_due.erase(person_id)
		_seen_talking[person_id] = talking
	# The figure follows up to a minute behind the simulation, so the door
	# opens as it reaches the step and the wave waits until it has stopped.
	for person_id: String in _doors_due.keys():
		if not _is_walking(person_id) or minute_fraction > 0.8:
			_door_swings[_doors_due[person_id]] = now
			_doors_due.erase(person_id)
	for person_id: String in _waves_due.keys():
		if not _is_walking(person_id):
			_waves[person_id] = now
			_waves_due.erase(person_id)


## How far open a building's door is right now, 0 to 1.
func _door_open(building_id: String) -> float:
	if not _door_swings.has(building_id):
		return 0.0
	var age: int = Time.get_ticks_msec() - int(_door_swings[building_id])
	if age >= DOOR_SWING_MS:
		_door_swings.erase(building_id)
		return 0.0
	return clampf(float(age) / 180.0, 0.0, 1.0) * clampf(float(DOOR_SWING_MS - age) / 320.0, 0.0, 1.0)


# --- Where the selected person has been sent -------------------------------------

func _world_point(point: Array) -> Vector2:
	return Vector2(float(point[0]), float(point[1]))


## Where an order or a journey of this person ends: {"point" (world Vector2),
## "flag" (building ID whose door gets a flag, or "")}; empty if there is
## nowhere to show. Reads the person's waiting orders and current action.
func _order_destination(person: Dictionary) -> Dictionary:
	var orders: Array = person["orders"]
	if not orders.is_empty():
		var order: Dictionary = orders[0]
		var home: String = simulation.state.households[person["household_id"]]["home_id"]
		match String(order.get("kind", "")):
			"go_home", "use_room":
				return _door_destination(person, home)
			"go_to", "enter":
				return _door_destination(person, String(order.get("place_id", "")))
			"talk_to":
				var other_id: String = order.get("other_id", "")
				if not simulation.state.people.has(other_id):
					return {}
				var other: Dictionary = simulation.state.people[other_id]
				if other["at"] == Records.AT_OUTSIDE:
					return {"point": Vector2(float(other["x"]), float(other["y"])), "flag": ""}
				if other["at"] == Records.AT_INSIDE:
					return _door_destination(person, other["place_id"])
		return {}
	var action: Dictionary = person["action"]
	if action.is_empty() or bool(action["started"]):
		return {}
	var kind: String = action["kind"]
	var place: String = action["place_id"]
	if action["where"] == Records.AT_OUTSIDE and (kind == "go_to" or kind == "visit" or kind == "call_on"):
		var path: Array = action["path"]
		var end: Vector2 = Vector2(float(action["tx"]), float(action["ty"])) if path.is_empty() else _world_point(path[path.size() - 1])
		return {"point": end, "flag": place if area.buildings.has(place) else ""}
	if action["where"] == Records.AT_INSIDE and action["source"] == "player":
		return _door_destination(person, place)
	return {}


func _door_destination(person: Dictionary, building_id: String) -> Dictionary:
	if not area.buildings.has(building_id):
		return {}
	if person["at"] == Records.AT_INSIDE and person["place_id"] == building_id:
		return {}
	return {"point": _world_point(area.buildings[building_id]["door"]), "flag": building_id}


## The rest of the walk a figure is shown making this minute, as screen points.
## The simulation moves a person a minute at a time and the figure follows
## along behind, so someone who has "arrived" may still be seen walking.
func _trail_ahead(person: Dictionary) -> Array[Vector2]:
	var ahead: Array[Vector2] = []
	var trail: Array = _trails.get(person["id"], [])
	if trail.size() < 2 or minute_fraction >= 1.0:
		return ahead
	var total: float = 0.0
	for index: int in trail.size() - 1:
		total += to_screen(trail[index]).distance_to(to_screen(trail[index + 1]))
	var remaining: float = total * minute_fraction
	for index: int in trail.size() - 1:
		var length: float = to_screen(trail[index]).distance_to(to_screen(trail[index + 1]))
		if remaining <= length and length > 0.0:
			for later: int in range(index + 1, trail.size()):
				ahead.append(to_screen(trail[later]))
			return ahead
		remaining -= length
	return ahead


## Works out the mark for the selected person, if they are one of the
## player's household, and keeps the last one a moment so it can fade out.
## Points are kept as unscaled isometric points so they stay put on the ground.
func _update_order_mark() -> void:
	var now: int = Time.get_ticks_msec()
	if not _order_mark.is_empty() and _order_mark["person_id"] != selected_id:
		_order_mark = {}
	var destination: Dictionary = {}
	var person: Dictionary = simulation.state.people.get(selected_id, {})
	var walking: bool = false
	if not person.is_empty() and simulation.state.households[person["household_id"]]["player_controlled"]:
		walking = _is_walking(selected_id)
		if person["at"] != Records.AT_OFFMAP:
			destination = _order_destination(person)
	# Still good while the figure walks the last of the way there.
	var finishing: bool = destination.is_empty() and walking and not _order_mark.is_empty() and bool(_order_mark["live"])
	if destination.is_empty() and not finishing:
		if not _order_mark.is_empty():
			_order_mark["live"] = false
			if now - int(_order_mark["seen"]) > ORDER_FADE_OUT_MS:
				_order_mark = {}
		return
	var line: Array[Vector2] = []
	if _screen_positions.has(selected_id):
		line.append(_screen_positions[selected_id])
		line.append_array(_trail_ahead(person))
	elif person["at"] == Records.AT_INSIDE:
		line.append(to_screen(area.buildings[person["place_id"]]["door"]))
	else:
		line.append(to_screen([person["x"], person["y"]]))
	var flag: String = _order_mark["flag"] if finishing else destination["flag"]
	if not finishing:
		var action: Dictionary = person["action"]
		if person["orders"].is_empty() and not action.is_empty():
			for waypoint: Array in action["path"]:
				line.append(to_screen(waypoint))
		var end: Vector2 = _iso((destination["point"] as Vector2).x, (destination["point"] as Vector2).y)
		if line[line.size() - 1].distance_to(end) > 2.0:
			line.append(end)
	var points: Array[Vector2] = []
	for point: Vector2 in line:
		points.append(_iso_of_screen(point))
	var born: int = now
	if not _order_mark.is_empty() and bool(_order_mark["live"]):
		born = _order_mark["born"]
	_order_mark = {"person_id": selected_id, "points": points, "flag": flag, "born": born, "seen": now, "live": true}


## 0 to 1: fades in when the order is given and out once the person arrives.
func _order_mark_alpha() -> float:
	if _order_mark.is_empty():
		return 0.0
	var now: int = Time.get_ticks_msec()
	var fade_in: float = clampf(float(now - int(_order_mark["born"])) / float(ORDER_FADE_IN_MS), 0.0, 1.0)
	var fade_out: float = 1.0 - clampf(float(now - int(_order_mark["seen"])) / float(ORDER_FADE_OUT_MS), 0.0, 1.0)
	return fade_in * fade_out


## On the ground: a soft dashed line from the person to where they are going,
## the dashes drifting that way, and a pulsing ring at the end of it.
func _draw_order_path() -> void:
	var alpha: float = _order_mark_alpha()
	if alpha <= 0.01:
		return
	var line: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in _order_mark["points"]:
		line.append(point * _scale + _offset)
	var total: float = 0.0
	for index: int in line.size() - 1:
		total += line[index].distance_to(line[index + 1])
	var end: Vector2 = line[line.size() - 1]
	var now: float = float(Time.get_ticks_msec())
	var size: float = clampf(sqrt(_zoom), 0.9, 1.7)
	_draw_order_ring(end, alpha)
	var skip: float = 9.0 * size
	if line.size() < 2 or total < skip * 2.0 + 4.0:
		return
	var dash: float = 6.0 * size
	var period: float = 12.0 * size
	var dashes: PackedVector2Array = PackedVector2Array()
	var segment: int = 0
	var before: float = 0.0
	var d: float = skip + fmod(now / 1000.0 * 16.0 * size, period) - period
	while d < total - skip:
		var ends: Array[Vector2] = []
		for s: float in [maxf(d, skip), minf(d + dash, total - skip)]:
			while segment < line.size() - 2 and s > before + line[segment].distance_to(line[segment + 1]):
				before += line[segment].distance_to(line[segment + 1])
				segment += 1
			var length: float = line[segment].distance_to(line[segment + 1])
			ends.append(line[segment].lerp(line[segment + 1], clampf((s - before) / maxf(length, 0.001), 0.0, 1.0)))
		if ends[0].distance_to(ends[1]) > 1.0:
			dashes.append(ends[0])
			dashes.append(ends[1])
		d += period
	if dashes.size() >= 2:
		draw_multiline(dashes, Color(TEAL_DARK, 0.30 * alpha), 4.0 * size, true)
		draw_multiline(dashes, Color(1.0, 0.93, 0.70, 0.92 * alpha), 2.0 * size, true)


## The pulsing ring on the ground where the selected person is headed.
func _draw_order_ring(at: Vector2, alpha: float) -> void:
	var now: float = float(Time.get_ticks_msec())
	var size: float = clampf(sqrt(_zoom), 0.9, 1.7)
	var pulse: float = 0.5 + 0.5 * sin(now / 260.0)
	draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, (9.0 + 2.5 * pulse) * size, Color(MUSTARD, 0.22 * alpha))
	draw_arc(Vector2.ZERO, (9.0 + 2.5 * pulse) * size, 0.0, TAU, 28, Color(1, 1, 1, 0.55 * alpha), 3.6, true)
	draw_arc(Vector2.ZERO, (9.0 + 2.5 * pulse) * size, 0.0, TAU, 28, Color(MUSTARD, 0.95 * alpha), 2.0, true)
	var spread: float = fmod(now / 1100.0, 1.0)
	draw_arc(Vector2.ZERO, (9.0 + 12.0 * spread) * size, 0.0, TAU, 28, Color(MUSTARD, 0.5 * (1.0 - spread) * alpha), 1.4, true)
	draw_circle(Vector2.ZERO, 2.2 * size, Color(MUSTARD, 0.9 * alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Over everything: a small flag above the door of the building they were
## sent to; or, with no building, the ring again, faintly, so that it shows
## through a tree or a house standing in front of it.
func _draw_order_flag() -> void:
	var alpha: float = _order_mark_alpha()
	if alpha <= 0.01:
		return
	if String(_order_mark["flag"]) == "":
		var points: Array[Vector2] = _order_mark["points"]
		_draw_order_ring(points[points.size() - 1] * _scale + _offset, alpha * 0.3)
		return
	var building: Dictionary = area.buildings[_order_mark["flag"]]
	var door: Vector2 = _world_point(building["door"])
	var now: float = float(Time.get_ticks_msec())
	var size: float = clampf(sqrt(_zoom), 0.9, 1.6)
	var foot: Vector2 = _pv(door, 9.6 * FOOT) - Vector2(0, 2.0 + 1.5 * sin(now / 300.0))
	var top: Vector2 = foot - Vector2(0, 17.0 * size)
	var flutter: float = sin(now / 170.0) * 1.6 * size
	draw_line(foot + Vector2(1, 1), top + Vector2(1, 1), Color(0, 0, 0, 0.25 * alpha), 2.0)
	draw_line(foot, top, Color(INK, alpha), 2.0)
	var pennant: PackedVector2Array = PackedVector2Array([top, top + Vector2(11.0 * size, 3.5 * size + flutter), top + Vector2(0, 8.0 * size)])
	_fill(pennant, Color(MUSTARD, alpha))
	_outline(pennant, Color(INK, alpha))
	draw_circle(top, 1.6 * size, Color(CHERRY, alpha))
	draw_circle(foot, 2.0 * size, Color(MUSTARD, alpha))
	draw_arc(foot, 2.0 * size, 0.0, TAU, 12, Color(INK, alpha), 1.0, true)


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	if simulation == null:
		return
	_update_light()
	_notice_changes()
	_check_view_caches()
	_building_shapes.clear()
	if selected_id != _selected_seen:
		_selected_seen = selected_id
		_selected_since = Time.get_ticks_msec()
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), _tint(COLOR_GRASS))
	_draw_tufts()
	for lot_id: String in area.lots:
		var lot: PackedVector2Array = _polygon(area.lots[lot_id]["boundary"])
		_fill(lot, _tint(COLOR_LAWN))
	_draw_lawn_texture()
	for street_id: String in area.streets:
		_draw_street(area.streets[street_id])
	for drain: Dictionary in _drains:
		_draw_drain(drain)
	var worn: Color = _tint(Color(0.52, 0.45, 0.32, 0.22))
	for walk: Array in _walks:
		# Grass worn thin beside the walk, where feet stray off it.
		_draw_strip(walk[0], walk[1], 5.6 * FOOT, worn)
		_ellipse(_iso((walk[1] as Vector2).x, (walk[1] as Vector2).y), 4.0 * FOOT * _scale * 1.4, 0.5, worn)
		_draw_strip(walk[0], walk[1], 3.5 * FOOT, _tint(COLOR_PATH))
		_draw_strip(walk[0], walk[1], 3.5 * FOOT * 0.18, _tint(Color(COLOR_PATH.lightened(0.12), 0.6)))
	_draw_shadows()
	_draw_cloud_shadows()
	_draw_lamp_pools()
	_draw_glints()
	_draw_haze()
	_layout_people()
	_update_order_mark()
	_draw_order_path()

	# Everything that stands up, from the back of the view to the front: the
	# things that stand still are already in order, and the few that move
	# (people, the cat, the dog) are slipped in where they belong.
	var home_id: String = _player_home()
	var moving: Array = []  # [depth on screen, kind, person ID]
	for person_id: String in _screen_positions:
		moving.append([(_screen_positions[person_id] as Vector2).y + 0.5, KIND_PERSON, person_id])
	_place_animals()
	if not _cat_now.is_empty():
		moving.append([_iso((_cat_now["at"] as Vector3).x, (_cat_now["at"] as Vector3).y).y + 0.3, KIND_CAT, ""])
	if not _dog_now.is_empty():
		moving.append([_iso((_dog_now["at"] as Vector3).x, (_dog_now["at"] as Vector3).y).y + 0.3, KIND_DOG, ""])
	moving.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

	_draw_talk_lines()
	var hovered: Dictionary = _hovered()
	var hovered_person: String = hovered.get("person", "")
	var hovered_building: String = hovered.get("building", "")
	var next: int = 0
	var half: float = 0.5 * _scale
	for entry: Array in _statics:
		var x: float = entry[4]
		var y: float = entry[5]
		var depth: float = (x - y) * half + _offset.y
		while next < moving.size() and float(moving[next][0]) < depth + float(entry[1]):
			_draw_moving(moving[next], hovered_person)
			next += 1
		# Skip what is wholly off the screen.
		var reach: float = float(entry[6]) * _scale
		var across: float = (x + y) * _scale + _offset.x
		if across + reach * 1.5 + 40.0 < 0.0 or across - reach * 1.5 - 40.0 > VIEW_SIZE.x \
				or depth + reach * 0.75 + 40.0 < 0.0 or depth - reach * 0.75 - float(entry[7]) * _scale - 40.0 > VIEW_SIZE.y:
			continue
		match int(entry[2]):
			KIND_BUILDING:
				_draw_building(area.buildings[entry[3]], entry[3] == home_id, hovered_building == entry[3])
			KIND_TREE:
				_draw_tree(entry[3])
			KIND_SHRUB:
				_draw_shrub(entry[3])
			KIND_LAMP:
				_draw_lamp(entry[3])
			KIND_CAR:
				_draw_car(entry[3])
			KIND_FENCE:
				_draw_fence(entry[3])
			KIND_FLOWERS:
				_draw_flowers(entry[3])
			KIND_MAILBOX:
				_draw_mailbox(entry[3])
			KIND_CLOTHESLINE:
				_draw_clothesline(entry[3])
			KIND_POLE:
				_draw_pole(entry[3])
			KIND_WIRE:
				_draw_wire(entry[3])
			KIND_HYDRANT:
				_draw_hydrant(entry[3])
			KIND_CAN:
				_draw_can(entry[3])
			KIND_BICYCLE:
				_draw_bicycle(entry[3])
			KIND_WAGON:
				_draw_wagon(entry[3])
			KIND_TULIPS:
				if _spring:
					_draw_tulips(entry[3])
	while next < moving.size():
		_draw_moving(moving[next], hovered_person)
		next += 1

	_draw_smoke()
	_draw_birds()
	_draw_golden_light()
	_draw_vignette()
	_draw_street_names()
	_draw_building_badges(home_id)
	_draw_order_flag()
	_draw_ripples()
	_draw_bubbles()
	_draw_hover_label(hovered)
	_draw_interior()
	_draw_house_notes()
	_draw_floats()
	_draw_toasts()
	_draw_follow_pill()


func _draw_moving(entry: Array, hovered_person: String) -> void:
	match int(entry[1]):
		KIND_PERSON:
			_draw_person(simulation.state.people[entry[2]], hovered_person == entry[2])
		KIND_CAT:
			_draw_cat()
		KIND_DOG:
			_draw_dog()


## Forgets the screen geometry that was worked out for another zoom or pan.
func _check_view_caches() -> void:
	var key: Vector3 = Vector3(_scale, _offset.x, _offset.y)
	if key == _view_key:
		return
	_view_key = key
	_tuft_lines.clear()
	_stripe_shapes.clear()
	_fence_lines.clear()
	_fence_lines.resize(_fences.size())
	_wire_lines.clear()
	_wire_lines.resize(_wires.size())


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
	_fill(points, fill)
	if edge.a > 0.0:
		_outline(points, edge)


## A filled shape in one colour. Triangles and four-sided shapes (which must
## bulge outward everywhere, as walls, panes and roofs do) go to the renderer
## as they are, which is many times cheaper than handing it a polygon to cut up.
func _fill(points: PackedVector2Array, color: Color) -> void:
	if points.size() <= 4:
		_one_color[0] = color
		draw_primitive(points, _one_color, _no_uvs)
	else:
		draw_colored_polygon(points, color)


## A small round dot. One too small to look round is drawn as a square,
## which costs the renderer far less than a circle.
func _dot(at: Vector2, radius: float, color: Color) -> void:
	if radius < 1.8:
		draw_rect(Rect2(at.x - radius, at.y - radius, radius * 2.0, radius * 2.0), color)
	else:
		draw_circle(at, radius, color)


## A thin smooth line around a shape.
func _outline(points: PackedVector2Array, color: Color) -> void:
	var count: int = points.size()
	for index: int in count:
		draw_line(points[index], points[(index + 1) % count], color, 1.0, true)


func _ellipse(centre: Vector2, radius: float, flat: float, color: Color) -> void:
	draw_set_transform(centre, 0.0, Vector2(1.0, flat))
	draw_circle(Vector2.ZERO, radius, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A flat strip on the ground between two world points.
func _draw_strip(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	if a.distance_to(b) < 1.0:
		return
	var side: Vector2 = (b - a).normalized().orthogonal() * width / 2.0
	_fill(PackedVector2Array([
		_iso(a.x + side.x, a.y + side.y), _iso(b.x + side.x, b.y + side.y),
		_iso(b.x - side.x, b.y - side.y), _iso(a.x - side.x, a.y - side.y)]), color)


func _draw_tufts() -> void:
	if _tuft_lines.is_empty():
		# One batch of little strokes for the light tufts and one for the dark.
		var length: float = clampf(2.0 * _zoom, 1.5, 4.0)
		var stroke: Vector2 = Vector2(0.6, -length)
		var light_lines: PackedVector2Array = PackedVector2Array()
		var dark_lines: PackedVector2Array = PackedVector2Array()
		for tuft: Dictionary in _tufts:
			var at: Vector2 = _iso(tuft["x"], tuft["y"])
			if at.x < -5.0 or at.y < -5.0 or at.x > VIEW_SIZE.x + 5.0 or at.y > VIEW_SIZE.y + 5.0:
				continue
			if tuft["light"]:
				light_lines.append(at)
				light_lines.append(at + stroke)
			else:
				dark_lines.append(at)
				dark_lines.append(at + stroke)
		_tuft_lines = [light_lines, dark_lines]
	if _tuft_lines[0].size() >= 2:
		draw_multiline(_tuft_lines[0], _tint(COLOR_GRASS_LIGHT), 1.0)
	if _tuft_lines[1].size() >= 2:
		draw_multiline(_tuft_lines[1], _tint(COLOR_GRASS_DARK), 1.0)


func _draw_street(street: Dictionary) -> void:
	var line: Array = street["centerline"]
	var half: float = float(street["width"]) / 2.0
	var walk: float = 5.0 * FOOT
	for index: int in line.size() - 1:
		var a: Vector2 = Vector2(line[index][0], line[index][1])
		var b: Vector2 = Vector2(line[index + 1][0], line[index + 1][1])
		var along: Vector2 = (b - a).normalized()
		var across: Vector2 = along.orthogonal()
		# The street runs on past the ends of the area and fades into the haze.
		if index == 0:
			a -= along * 160.0 * FOOT
		if index == line.size() - 2:
			b += along * 160.0 * FOOT
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
		# Worn, lighter wheel tracks and a darker gutter along each curb.
		for side: float in [1.0, -1.0]:
			_draw_strip(a + across * side * half * 0.45, b + across * side * half * 0.45, 3.0 * FOOT, _tint(Color(COLOR_ASPHALT.lightened(0.10), 0.35)))
			_draw_strip(a + across * side * (half - 0.7 * FOOT), b + across * side * (half - 0.7 * FOOT), 1.4 * FOOT, _tint(Color(0.30, 0.30, 0.31, 0.45)))
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
	for building_id: String in _building_ids:
		var building: Dictionary = area.buildings[building_id]
		var reach: Vector2 = lean * (_wall_height(building) + _roof_rise(building) * 0.5)
		var points: PackedVector2Array = PackedVector2Array()
		for point: Array in building["footprint"]:
			points.append(_iso(float(point[0]), float(point[1])))
			points.append(_iso(float(point[0]) + reach.x, float(point[1]) + reach.y))
		var hull: PackedVector2Array = Geometry2D.convex_hull(points)
		if hull.size() >= 3:
			_fill(hull, shade)
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
	var rect: Rect2 = _building_rect(building)
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
	var counts: Array = _inside.get(building_id, [0, 0])
	return int(counts[0]) > int(counts[1])


func _draw_building(building: Dictionary, is_home: bool, hovered: bool) -> void:
	var id: String = building["id"]
	var rect: Rect2 = _building_rect(building)
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
	var style: Dictionary = _styles.get(id, {})
	var porch: bool = style.get("porch", false)
	var door_seen: bool = _faces_viewer(style.get("out", Vector2(0, 1)))
	# A porch on a wall the viewer cannot see stands behind the house.
	if porch and not door_seen:
		_draw_porch(building, style, roof)

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
		# Corner boards.
		var corner: float = maxf(1.0, 0.5 * FOOT * _scale)
		draw_line(_p3(x1, y0, 0), _p3(x1, y0, h), _tint(COLOR_TRIM), corner)
		draw_line(_p3(x0, y0, 0), _p3(x0, y0, h), _tint(COLOR_TRIM), corner)
	_draw_foundation(Vector2(x0, y0), Vector2(x1, y0), store)
	_draw_foundation(Vector2(x1, y0), Vector2(x1, y1), store)
	_draw_wall_openings(building, Vector2(x0, y0), Vector2(x1, y0), lit, store)
	_draw_wall_openings(building, Vector2(x1, y0), Vector2(x1, y1), lit, store)

	if store:
		_draw_awning(building, style)
		var top: PackedVector2Array = PackedVector2Array([_p3(x0, y0, h), _p3(x1, y0, h), _p3(x1, y1, h), _p3(x0, y1, h)])
		_face(top, _tint(roof), edge)
		var lip: float = _roof_rise(building)
		_face(PackedVector2Array([_p3(x0, y0, h), _p3(x1, y0, h), _p3(x1, y0, h + lip), _p3(x0, y0, h + lip)]), _tint(siding.darkened(0.05)), edge)
		_face(PackedVector2Array([_p3(x1, y0, h), _p3(x1, y1, h), _p3(x1, y1, h + lip), _p3(x1, y0, h + lip)]), _tint(siding.darkened(0.2)), edge)
		# A coping of light stone along the top of the parapet.
		draw_polyline(PackedVector2Array([_p3(x0, y0, h + lip), _p3(x1, y0, h + lip), _p3(x1, y1, h + lip)]), _tint(Color(0.90, 0.86, 0.78)), maxf(1.5, 0.4 * FOOT * _scale))
		shapes.append(top)
		_draw_store_sign(building, h + lip)
	else:
		if porch and door_seen:
			_draw_porch(building, style, roof)
		elif door_seen:
			_draw_stoop(building, style)
		if style.get("bay", false):
			_draw_bay(id, style, siding, roof, lit)
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
	var style: Dictionary = _styles.get(building["id"], {})
	var glass: Color = _window_glass(building["id"], lit)
	var frame: Color = _tint(COLOR_TRIM)
	var skip_u: float = -1.0
	if style.get("bay", false) and (style["bay_wall"][0] as Vector2).is_equal_approx(a) and (style["bay_wall"][1] as Vector2).is_equal_approx(b):
		skip_u = style["bay_u"]
	var shutter: Color = _tint(_wall_shade(style.get("shutter", SHUTTERS[0]), along.orthogonal()))
	var detailed: bool = _scale * FOOT >= 1.6
	for story: int in int(building["stories"]):
		var base: float = float(story) * STORY_HEIGHT_INCHES
		for index: int in count:
			var u: float = (float(index) + 0.5) / float(count) * length
			if story == 0 and on_wall and absf(u - a.distance_to(door)) < 5.0 * FOOT:
				continue
			if story == 0 and skip_u >= 0.0 and absf(u - skip_u) < FOOT:
				continue
			var half: float = (3.5 if store and story == 0 else 1.6) * FOOT
			var low: float = base + (2.0 if store and story == 0 else 3.2) * FOOT
			var high: float = base + 7.0 * FOOT
			var p: Vector2 = a + along * (u - half)
			var q: Vector2 = a + along * (u + half)
			if not store:
				for side: Array in [[p - along * 0.95 * FOOT, p - along * 0.15 * FOOT], [q + along * 0.15 * FOOT, q + along * 0.95 * FOOT]]:
					var s0: Vector2 = side[0]
					var s1: Vector2 = side[1]
					_fill(PackedVector2Array([_p3(s0.x, s0.y, low - 0.2 * FOOT), _p3(s1.x, s1.y, low - 0.2 * FOOT),
							_p3(s1.x, s1.y, high + 0.2 * FOOT), _p3(s0.x, s0.y, high + 0.2 * FOOT)]), shutter)
			var pane: PackedVector2Array = PackedVector2Array([_p3(p.x, p.y, low), _p3(q.x, q.y, low), _p3(q.x, q.y, high), _p3(p.x, p.y, high)])
			_fill(pane, glass)
			if not lit and detailed:
				# A pale streak of reflected sky.
				draw_line(_p3(p.x, p.y, low + (high - low) * 0.35).lerp(_p3(q.x, q.y, low), 0.1),
						_p3(p.x, p.y, high).lerp(_p3(q.x, q.y, high), 0.55), Color(1, 1, 1, 0.22 * (1.0 - _night)), 1.0)
			if not store and detailed:
				_draw_curtains(p, q, low, high, style, lit)
			if store and story == 0 and detailed:
				_draw_shop_window(p, q, low, high)
			_outline(pane, frame)
			var mid: Vector2 = (p + q) / 2.0
			draw_line(_p3(mid.x, mid.y, low), _p3(mid.x, mid.y, high), frame, 1.0)
			# Sill.
			draw_line(_p3(p.x, p.y, low) - along.orthogonal() * 0.0, _p3(q.x, q.y, low), frame, maxf(1.0, 0.3 * FOOT * _scale))
			if lit:
				var centre: Vector2 = (pane[0] + pane[2]) / 2.0
				draw_circle(centre, 6.0 * _zoom, Color(1.0, 0.85, 0.45, 0.12))
	if on_wall:
		var at: float = a.distance_to(door)
		var p: Vector2 = a + along * (at - 1.8 * FOOT)
		var q: Vector2 = a + along * (at + 1.8 * FOOT)
		var color: Color = _tint(_pick(DOORS, building["id"] + "door"))
		var leaf: PackedVector2Array = PackedVector2Array([_p3(p.x, p.y, 0), _p3(q.x, q.y, 0), _p3(q.x, q.y, 7.0 * FOOT), _p3(p.x, p.y, 7.0 * FOOT)])
		var open: float = _door_open(building["id"])
		if open > 0.0:
			# Someone is going in or out: a dark doorway (warm if the lights
			# are on) and the door swung out on its hinges, seen edge-on.
			_fill(leaf, Color(0.62, 0.45, 0.22) if lit else _tint(Color(0.13, 0.10, 0.09)))
			_outline(leaf, frame)
			var angle: float = open * 1.4
			var tip: Vector2 = p + (along * cos(angle) + along.orthogonal() * sin(angle)) * 3.6 * FOOT
			var swung: PackedVector2Array = PackedVector2Array([_p3(p.x, p.y, 0), _p3(tip.x, tip.y, 0), _p3(tip.x, tip.y, 7.0 * FOOT), _p3(p.x, p.y, 7.0 * FOOT)])
			_fill(swung, color.darkened(0.12))
			_outline(swung, frame)
		else:
			_fill(leaf, color)
			_outline(leaf, frame)
		if open <= 0.0 and _scale * FOOT >= 1.6:
			# A small window in the door and a brass knob.
			var w0: Vector2 = p.lerp(q, 0.28)
			var w1: Vector2 = p.lerp(q, 0.72)
			_fill(PackedVector2Array([_p3(w0.x, w0.y, 4.6 * FOOT), _p3(w1.x, w1.y, 4.6 * FOOT),
					_p3(w1.x, w1.y, 6.2 * FOOT), _p3(w0.x, w0.y, 6.2 * FOOT)]), glass)
			var knob: Vector2 = p.lerp(q, 0.82)
			draw_circle(_p3(knob.x, knob.y, 3.4 * FOOT), maxf(1.0, 0.22 * FOOT * _scale), _tint(Color(0.85, 0.70, 0.30)))
		if not store and not bool(style.get("porch", false)):
			# A little roof over the step, standing out from the wall.
			var out: Vector2 = along.orthogonal() * 1.9 * FOOT
			var hp: Vector2 = p - along * 0.8 * FOOT
			var hq: Vector2 = q + along * 0.8 * FOOT
			var hood: PackedVector2Array = PackedVector2Array([
				_p3(hp.x, hp.y, 9.2 * FOOT), _p3(hq.x, hq.y, 9.2 * FOOT),
				_p3(hq.x + out.x, hq.y + out.y, 8.3 * FOOT), _p3(hp.x + out.x, hp.y + out.y, 8.3 * FOOT)])
			_fill(hood, _tint(_pick(ROOFS, building["id"] + "roof").lightened(0.1)))
			draw_line(hood[3], hood[2], frame, maxf(1.0, 0.3 * FOOT * _scale))
			for end: Vector2 in [hp, hq]:
				draw_line(_p3(end.x + out.x, end.y + out.y, 8.3 * FOOT), _p3(end.x, end.y, 7.4 * FOOT), frame, 1.0)
		if lit:
			# A porch light by the door while someone is up after dark.
			var strength: float = clampf((_night - 0.2) / 0.5, 0.0, 1.0)
			var bulb: Vector2 = _p3(door.x, door.y, 7.6 * FOOT) + (_p3(q.x, q.y, 0) - _p3(p.x, p.y, 0)) * 0.75
			_ellipse(_iso(door.x, door.y), 7.0 * FOOT * _scale, 0.5, Color(1.0, 0.82, 0.45, 0.14 * strength))
			for ring: int in 3:
				draw_circle(bulb, (7.0 - 2.0 * ring) * sqrt(_zoom), Color(1.0, 0.85, 0.45, 0.13 * strength))
			draw_circle(bulb, maxf(1.3, 0.9 * sqrt(_zoom)), Color(1.0, 0.95, 0.70, strength))


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
		_face(front, _tint(roof.lightened(0.08)), roof_edge)
		_draw_shingles(front, roof)
		_draw_roof_trim(front, [front[0], front[3]], [back[0], back[3]], roof)
		# This chimney stands on the front slope, so it is drawn over it.
		_draw_chimney(_chimneys.get(building["id"], Vector3.ZERO), h + rise * 0.6)
		if _styles.get(building["id"], {}).get("dormer", false):
			_draw_dormer(building, rect, h, rise, siding, roof)
		faces.append_array([gable, back, front])
	else:
		var ym: float = (y0 + y1) / 2.0
		var gable: PackedVector2Array = PackedVector2Array([_p3(x1, y0, h), _p3(x1, y1, h), _p3(x1, ym, h + rise)])
		_face(gable, _tint(siding.darkened(0.16)), edge)
		_draw_gable_window(Vector2(x1, y0), Vector2(x1, y1), h, rise)
		var back: PackedVector2Array = PackedVector2Array([_p3(x0 - o, y1 + o, h - o * 0.4), _p3(x1 + o, y1 + o, h - o * 0.4), _p3(x1 + o, ym, h + rise), _p3(x0 - o, ym, h + rise)])
		var front: PackedVector2Array = PackedVector2Array([_p3(x0 - o, y0 - o, h - o * 0.4), _p3(x1 + o, y0 - o, h - o * 0.4), _p3(x1 + o, ym, h + rise), _p3(x0 - o, ym, h + rise)])
		_face(back, _tint(roof.darkened(0.12)), roof_edge)
		_draw_chimney(_chimneys.get(building["id"], Vector3.ZERO), h)
		_face(front, _tint(roof.lightened(0.08)), roof_edge)
		_draw_shingles(front, roof)
		_draw_roof_trim(front, [front[1], front[2]], [back[1], back[2]], roof)
		if _styles.get(building["id"], {}).get("dormer", false):
			_draw_dormer(building, rect, h, rise, siding, roof)
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
	_fill(pane, _tint(COLOR_GLASS.darkened(0.2)))
	_outline(pane, _tint(COLOR_TRIM))


## Faint rows of shingles across a roof face (corners 0 and 1 are the eave).
func _draw_shingles(face: PackedVector2Array, roof: Color) -> void:
	if _zoom < 1.2:
		return
	var color: Color = _tint(roof.darkened(0.2))
	for row: int in range(1, 6):
		var t: float = float(row) / 6.0
		draw_line(face[0].lerp(face[3], t), face[1].lerp(face[2], t), Color(color, 0.5), 1.0)


## Where a house's chimney stands (x, y) and how high its top is (z), in
## world inches. It sits on the back slope of the gable roof.
func _chimney_top(building: Dictionary) -> Vector3:
	var rect: Rect2 = _building_rect(building)
	var top: float = _wall_height(building) + _roof_rise(building) + 2.0 * FOOT
	if rect.size.y >= rect.size.x:
		return Vector3(rect.get_center().x + rect.size.x * 0.18, rect.position.y + rect.size.y * 0.65, top)
	return Vector3(rect.position.x + rect.size.x * 0.3, rect.get_center().y + rect.size.y * 0.18, top)


func _draw_chimney(spot: Vector3, base: float) -> void:
	if spot == Vector3.ZERO:
		return
	var at: Vector2 = Vector2(spot.x, spot.y)
	var size: float = 1.4 * FOOT
	var top: float = spot.z
	var brick: Color = Color(0.58, 0.30, 0.24)
	var x0: float = at.x - size
	var x1: float = at.x + size
	var y0: float = at.y - size
	var y1: float = at.y + size
	_face(PackedVector2Array([_p3(x0, y0, base), _p3(x1, y0, base), _p3(x1, y0, top), _p3(x0, y0, top)]), _tint(brick), _tint(brick.darkened(0.4)))
	_face(PackedVector2Array([_p3(x1, y0, base), _p3(x1, y1, base), _p3(x1, y1, top), _p3(x1, y0, top)]), _tint(brick.darkened(0.2)), _tint(brick.darkened(0.4)))
	_face(PackedVector2Array([_p3(x0, y0, top), _p3(x1, y0, top), _p3(x1, y1, top), _p3(x0, y1, top)]), _tint(brick.darkened(0.45)))


func _draw_store_sign(building: Dictionary, top: float) -> void:
	var rect: Rect2 = _building_rect(building)
	var open: bool = area.is_open(building["id"], simulation.clock.weekday(), simulation.clock.minute_of_day)
	var name: String = area.institutions[building["id"]]["name"]
	var at: Vector2 = _p3(rect.get_center().x, rect.get_center().y, top) - Vector2(0, 14.0 * sqrt(_zoom))
	var size: int = clampi(int(11.0 * sqrt(_zoom)), 10, 18)
	var width: float = _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 14.0
	var board: Rect2 = Rect2(at - Vector2(width / 2.0, size + 6.0), Vector2(width, size + 8.0))
	draw_line(board.end - Vector2(6, 0), board.end - Vector2(6, -10), _tint(COLOR_OUTLINE), 2.0)
	draw_line(Vector2(board.position.x + 6, board.end.y), Vector2(board.position.x + 6, board.end.y + 10), _tint(COLOR_OUTLINE), 2.0)
	_sign_box.bg_color = _tint(Color(0.96, 0.92, 0.80))
	_sign_box.border_color = _tint(CHERRY)
	draw_style_box(_sign_box, board)
	draw_string(_font, board.position + Vector2(7, size + 1.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _tint(CHERRY.darkened(0.2)))
	var tag: String = "OPEN" if open else "CLOSED"
	var tag_size: int = size - 2
	var tag_width: float = _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x + 10.0
	var tag_rect: Rect2 = Rect2(Vector2(board.end.x + 4.0, board.position.y + 1.5), Vector2(tag_width, tag_size + 5.0))
	var tag_fill: Color = Color(0.25, 0.60, 0.30) if open else Color(0.45, 0.42, 0.40)
	if open and _night > 0.2:
		draw_circle(tag_rect.get_center(), tag_width * 0.8, Color(0.4, 1.0, 0.5, 0.10))
	_tag_box.bg_color = tag_fill
	draw_style_box(_tag_box, tag_rect)
	draw_string(_font, tag_rect.position + Vector2(5, tag_size + 1.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size, Color.WHITE)


## Small pills over houses: how many are inside, and which house is yours.
func _draw_building_badges(home_id: String) -> void:
	for building_id: String in _building_ids:
		var building: Dictionary = area.buildings[building_id]
		var rect: Rect2 = _building_rect(building)
		var top: Vector2 = _p3(rect.get_center().x, rect.get_center().y, _wall_height(building) + _roof_rise(building))
		var lines: Array[String] = []
		var counts: Array = _inside.get(building_id, [0, 0])
		var inside: int = counts[0]
		var asleep: int = counts[1]
		if inside > 0:
			if asleep == inside:
				lines.append("%d asleep" % asleep)
			elif asleep > 0:
				lines.append("%d in, %d asleep" % [inside, asleep])
			else:
				lines.append("%d inside" % inside)
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


# --- Building details ----------------------------------------------------------

## A world point (inches) at a height above the ground.
func _pv(point: Vector2, z: float) -> Vector2:
	return _p3(point.x, point.y, z)


## Whether an upright face with this outward direction (world) faces the viewer.
func _faces_viewer(normal: Vector2) -> bool:
	return normal.x - normal.y > 0.01


## Walls facing south get full light, walls facing east a little less.
func _wall_shade(color: Color, normal: Vector2) -> Color:
	return color.darkened(0.16 * clampf(normal.normalized().x, 0.0, 1.0))


## An upright prism over a convex world polygon, from z0 to z1. Only the sides
## facing the viewer are drawn, so they never overlap; then the top, if given.
func _draw_prism(base: Array, z0: float, z1: float, color: Color, top: Color = Color(0, 0, 0, 0)) -> void:
	var centre: Vector2 = Vector2.ZERO
	for point: Vector2 in base:
		centre += point
	centre /= float(base.size())
	var edge: Color = _tint(color.darkened(0.42))
	for index: int in base.size():
		var a: Vector2 = base[index]
		var b: Vector2 = base[(index + 1) % base.size()]
		var normal: Vector2 = (b - a).orthogonal().normalized()
		if normal.dot((a + b) / 2.0 - centre) < 0.0:
			normal = -normal
		if not _faces_viewer(normal):
			continue
		_face(PackedVector2Array([_pv(a, z0), _pv(b, z0), _pv(b, z1), _pv(a, z1)]), _tint(_wall_shade(color, normal)), edge)
	if top.a > 0.0:
		var lid: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in base:
			lid.append(_pv(point, z1))
		_face(lid, _tint(top), edge)


## Window glass: sky-tinted by day; warm and very faintly flickering when lit.
func _window_glass(building_id: String, lit: bool) -> Color:
	if not lit:
		return _tint(COLOR_GLASS)
	var phase: float = float(_styles.get(building_id, {}).get("flicker", 0.0))
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	var f: float = 0.965 + 0.025 * sin(now * 1.7 + phase) + 0.012 * sin(now * 5.3 + phase * 2.0)
	return Color(COLOR_LIT.r * f, COLOR_LIT.g * f, COLOR_LIT.b * f)


## Tie-back curtains or a cafe curtain across the lower half of a window.
func _draw_curtains(p: Vector2, q: Vector2, low: float, high: float, style: Dictionary, lit: bool) -> void:
	var cloth: Color = style.get("curtain", CURTAINS[0])
	cloth = cloth.lerp(Color(1.0, 0.74, 0.42), 0.4) if lit else _tint(cloth)
	cloth.a = 0.9
	var span: float = high - low
	if style.get("cafe", false):
		_fill(PackedVector2Array([_pv(p, low), _pv(q, low), _pv(q, low + span * 0.48), _pv(p, low + span * 0.48)]), cloth)
		draw_line(_pv(p, low + span * 0.48), _pv(q, low + span * 0.48), Color(cloth.darkened(0.2), 0.9), 1.0)
	else:
		for side: Array in [[p, q], [q, p]]:
			var edge: Vector2 = side[0]
			var other: Vector2 = side[1]
			# Gathered at the waist: drawn as an upper and a lower piece.
			var waist: Vector2 = _pv(edge.lerp(other, 0.1), low + span * 0.45)
			var hem: Vector2 = _pv(edge, low + span * 0.45)
			_fill(PackedVector2Array([_pv(edge, high), _pv(edge.lerp(other, 0.3), high), waist, hem]), cloth)
			_fill(PackedVector2Array([hem, waist, _pv(edge.lerp(other, 0.16), low), _pv(edge, low)]), cloth)
	_fill(PackedVector2Array([_pv(p, high), _pv(q, high), _pv(q, high - span * 0.14), _pv(p, high - span * 0.14)]), cloth.darkened(0.06))


## Goods on shelves behind the store window.
func _draw_shop_window(p: Vector2, q: Vector2, low: float, high: float) -> void:
	var goods: Array[Color] = [Color(0.86, 0.36, 0.26), Color(0.95, 0.82, 0.40), Color(0.45, 0.62, 0.42), Color(0.92, 0.90, 0.84)]
	for shelf: int in 2:
		var z: float = low + (high - low) * (0.08 + 0.4 * float(shelf))
		draw_line(_pv(p, z), _pv(q, z), _tint(Color(0.45, 0.34, 0.26, 0.8)), 1.0)
		for item: int in 6:
			var t0: float = (float(item) + 0.15) / 6.0
			var t1: float = (float(item) + 0.8) / 6.0
			var tall: float = (high - low) * (0.14 + 0.08 * float((item + shelf) % 3))
			_fill(PackedVector2Array([_pv(p.lerp(q, t0), z), _pv(p.lerp(q, t1), z), _pv(p.lerp(q, t1), z + tall), _pv(p.lerp(q, t0), z + tall)]),
					_tint(Color(goods[(item + shelf * 2) % goods.size()], 0.85)))


func _draw_foundation(a: Vector2, b: Vector2, store: bool) -> void:
	var color: Color = Color(0.44, 0.38, 0.35) if store else Color(0.66, 0.64, 0.60)
	var top: float = (1.0 if store else 1.3) * FOOT
	var normal: Vector2 = (b - a).normalized().orthogonal()
	_fill(PackedVector2Array([_pv(a, 0.0), _pv(b, 0.0), _pv(b, top), _pv(a, top)]), _tint(_wall_shade(color, normal)))
	draw_line(_pv(a, top), _pv(b, top), _tint(color.darkened(0.3)), 1.0)


## The two ends of the wall the door is on.
func _door_wall(building: Dictionary, style: Dictionary) -> Array:
	var rect: Rect2 = _building_rect(building)
	var out: Vector2 = style["out"]
	if style["along_x"]:
		var y: float = rect.position.y if out.y < 0.0 else rect.end.y
		return [Vector2(rect.position.x, y), Vector2(rect.end.x, y)]
	var x: float = rect.position.x if out.x < 0.0 else rect.end.x
	return [Vector2(x, rect.position.y), Vector2(x, rect.end.y)]


## A full-width front porch with posts, railings, steps and a shed roof.
func _draw_porch(building: Dictionary, style: Dictionary, roof: Color) -> void:
	var wall: Array = _door_wall(building, style)
	var out: Vector2 = style["out"]
	var a: Vector2 = wall[0]
	var b: Vector2 = wall[1]
	var along: Vector2 = (b - a).normalized()
	var p: Vector2 = a + along * 0.4 * FOOT
	var q: Vector2 = b - along * 0.4 * FOOT
	var deck: float = 1.6 * FOOT
	var door: Vector2 = Vector2(building["door"][0], building["door"][1])
	var door_u: float = (door - p).dot(along)
	var front: Vector2 = out * PORCH_DEPTH
	_draw_prism([p, q, q + front, p + front], 0.0, deck, Color(0.88, 0.86, 0.80), Color(0.60, 0.54, 0.47))
	var wood: Color = Color(0.66, 0.60, 0.53)
	var s0: Vector2 = door - along * 2.4 * FOOT + front
	var s1: Vector2 = door + along * 2.4 * FOOT + front
	_draw_prism([s0, s1, s1 + out * 1.2 * FOOT, s0 + out * 1.2 * FOOT], 0.0, deck * 0.66, wood, wood.lightened(0.12))
	_draw_prism([s0 + out * 1.2 * FOOT, s1 + out * 1.2 * FOOT, s1 + out * 2.4 * FOOT, s0 + out * 2.4 * FOOT], 0.0, deck * 0.33, wood, wood.lightened(0.12))
	var fp: Vector2 = p + out * (PORCH_DEPTH - 0.4 * FOOT)
	var fq: Vector2 = q + out * (PORCH_DEPTH - 0.4 * FOOT)
	var span: float = fp.distance_to(fq)
	var bays: int = maxi(2, roundi(span / (9.0 * FOOT)))
	_draw_rail(p + out * 0.2 * FOOT, fp, deck)
	_draw_rail(q + out * 0.2 * FOOT, fq, deck)
	for index: int in bays:
		var u0: float = span * float(index) / float(bays)
		var u1: float = span * float(index + 1) / float(bays)
		if door_u > u0 and door_u < u1:
			if door_u - 2.6 * FOOT > u0:
				_draw_rail(fp + along * u0, fp + along * (door_u - 2.6 * FOOT), deck)
			if door_u + 2.6 * FOOT < u1:
				_draw_rail(fp + along * (door_u + 2.6 * FOOT), fp + along * u1, deck)
		else:
			_draw_rail(fp + along * u0, fp + along * u1, deck)
	var trim: Color = _tint(COLOR_TRIM)
	var post: float = maxf(1.5, 0.5 * FOOT * _scale)
	for index: int in bays + 1:
		var at: Vector2 = fp + along * span * float(index) / float(bays)
		draw_line(_pv(at, deck), _pv(at, 9.2 * FOOT), trim, post)
	var rp: Vector2 = a - along * 0.3 * FOOT
	var rq: Vector2 = b + along * 0.3 * FOOT
	var reach: Vector2 = out * (PORCH_DEPTH + 0.7 * FOOT)
	var top: PackedVector2Array = PackedVector2Array([_pv(rp, 10.4 * FOOT), _pv(rq, 10.4 * FOOT), _pv(rq + reach, 9.2 * FOOT), _pv(rp + reach, 9.2 * FOOT)])
	_face(top, _tint(roof.lightened(0.12)), _tint(roof.darkened(0.35)))
	if _faces_viewer(out):
		_face(PackedVector2Array([_pv(rp + reach, 9.2 * FOOT), _pv(rq + reach, 9.2 * FOOT), _pv(rq + reach, 8.5 * FOOT), _pv(rp + reach, 8.5 * FOOT)]), trim, _tint(COLOR_TRIM.darkened(0.3)))


## A porch railing: top and bottom rails with balusters when close enough to see.
func _draw_rail(from: Vector2, to: Vector2, base: float) -> void:
	var color: Color = _tint(COLOR_TRIM.darkened(0.04))
	var top: float = base + 2.4 * FOOT
	if _scale * FOOT >= 1.6:
		var length: float = from.distance_to(to)
		var at: float = 0.6 * FOOT
		while at < length:
			var point: Vector2 = from.lerp(to, at / length)
			draw_line(_pv(point, base), _pv(point, top), Color(color, 0.85), 1.0)
			at += 0.8 * FOOT
	draw_line(_pv(from, top), _pv(to, top), color, maxf(1.0, 0.28 * FOOT * _scale))
	draw_line(_pv(from, base + 0.3 * FOOT), _pv(to, base + 0.3 * FOOT), color, 1.0)


## Two concrete steps up to the front door.
func _draw_stoop(building: Dictionary, style: Dictionary) -> void:
	var out: Vector2 = style["out"]
	var door: Vector2 = Vector2(building["door"][0], building["door"][1])
	var along: Vector2 = out.orthogonal()
	var w: Vector2 = along * 2.4 * FOOT
	_draw_prism([door - w, door + w, door + w + out * 2.4 * FOOT, door - w + out * 2.4 * FOOT], 0.0, 1.0 * FOOT, COLOR_CONCRETE, COLOR_CONCRETE.lightened(0.12))
	_draw_prism([door - w + out * 2.4 * FOOT, door + w + out * 2.4 * FOOT, door + w + out * 3.7 * FOOT, door - w + out * 3.7 * FOOT],
			0.0, 0.5 * FOOT, COLOR_CONCRETE, COLOR_CONCRETE.lightened(0.12))


## A three-sided bay window standing out from the ground floor.
func _draw_bay(id: String, style: Dictionary, siding: Color, roof: Color, lit: bool) -> void:
	var wall: Array = style["bay_wall"]
	var a: Vector2 = wall[0]
	var b: Vector2 = wall[1]
	var n: Vector2 = wall[2]
	var along: Vector2 = (b - a).normalized()
	var c: Vector2 = a + along * float(style["bay_u"])
	var bl: Vector2 = c - along * 3.6 * FOOT
	var br: Vector2 = c + along * 3.6 * FOOT
	var fl: Vector2 = c - along * 2.3 * FOOT + n * 2.2 * FOOT
	var fr: Vector2 = c + along * 2.3 * FOOT + n * 2.2 * FOOT
	var base: Array = [bl, fl, fr, br]
	_draw_prism(base, 0.0, 1.3 * FOOT, Color(0.66, 0.64, 0.60))
	_draw_prism(base, 1.3 * FOOT, 8.4 * FOOT, siding)
	var glass: Color = _window_glass(id, lit)
	var frame: Color = _tint(COLOR_TRIM)
	for pair: Array in [[bl, fl], [fl, fr], [fr, br]]:
		var p: Vector2 = pair[0]
		var q: Vector2 = pair[1]
		var normal: Vector2 = (q - p).orthogonal().normalized()
		if normal.dot((p + q) / 2.0 - c) < 0.0:
			normal = -normal
		if not _faces_viewer(normal):
			continue
		var p2: Vector2 = p.lerp(q, 0.16)
		var q2: Vector2 = p.lerp(q, 0.84)
		var pane: PackedVector2Array = PackedVector2Array([_pv(p2, 3.0 * FOOT), _pv(q2, 3.0 * FOOT), _pv(q2, 7.2 * FOOT), _pv(p2, 7.2 * FOOT)])
		_fill(pane, glass)
		if _scale * FOOT >= 1.6:
			_draw_curtains(p2, q2, 3.0 * FOOT, 7.2 * FOOT, style, lit)
		_outline(pane, frame)
		if lit:
			draw_circle((pane[0] + pane[2]) / 2.0, 5.0 * _zoom, Color(1.0, 0.85, 0.45, 0.12))
	var hood: PackedVector2Array = PackedVector2Array([
		_pv(bl - along * 0.3 * FOOT, 9.8 * FOOT), _pv(fl + n * 0.4 * FOOT - along * 0.3 * FOOT, 8.4 * FOOT),
		_pv(fr + n * 0.4 * FOOT + along * 0.3 * FOOT, 8.4 * FOOT), _pv(br + along * 0.3 * FOOT, 9.8 * FOOT)])
	_face(hood, _tint(roof.lightened(0.08)), _tint(roof.darkened(0.35)))
	draw_line(hood[1], hood[2], frame, maxf(1.0, 0.25 * FOOT * _scale))


## A light fascia along the eave, light rakes on the gable end and a lit ridge.
func _draw_roof_trim(front: PackedVector2Array, front_rake: Array, back_rake: Array, roof: Color) -> void:
	var trim: Color = _tint(COLOR_TRIM)
	var width: float = maxf(1.0, 0.32 * FOOT * _scale)
	draw_line(front[0], front[1], trim, width)
	draw_line(back_rake[0], back_rake[1], trim, width)
	draw_line(front_rake[0], front_rake[1], trim, width)
	draw_line(front[2], front[3], _tint(roof.lightened(0.4)), maxf(1.0, 0.25 * FOOT * _scale))


## A point on the front slope of a roof: u along the eave, d in from the wall.
func _on_slope(frame: Array, u: float, d: float, z: float) -> Vector2:
	return _pv((frame[0] as Vector2) + (frame[1] as Vector2) * u - (frame[2] as Vector2) * d, z)


## A small gabled dormer on the front slope of the roof.
func _draw_dormer(building: Dictionary, rect: Rect2, h: float, rise: float, siding: Color, roof: Color) -> void:
	var frame: Array
	var half_depth: float
	var u: float
	if rect.size.y >= rect.size.x:
		frame = [Vector2(rect.end.x, rect.position.y), Vector2(0, 1), Vector2(1, 0)]
		half_depth = rect.size.x / 2.0
		u = rect.size.y * 0.3
	else:
		frame = [rect.position, Vector2(1, 0), Vector2(0, -1)]
		half_depth = rect.size.y / 2.0
		u = rect.size.x * 0.55
	var along: Vector2 = frame[1]
	var out: Vector2 = frame[2]
	var w: float = 2.6 * FOOT
	var o: float = 0.5 * FOOT
	var peak: float = 1.6 * FOOT
	var d_f: float = half_depth * 0.3
	var zs: float = h + rise * d_f / half_depth
	var zt: float = minf(zs + 3.4 * FOOT, h + rise - peak - 0.4 * FOOT)
	var d_t: float = (zt - h) / rise * half_depth
	var d_e: float = (zt - 0.3 * FOOT - h) / rise * half_depth
	var d_p: float = minf(half_depth, (zt + peak - h) / rise * half_depth)
	var side: float = -1.0 if _faces_viewer(-along) else 1.0
	var edge: Color = _tint(roof.darkened(0.35))
	var lit: bool = _night > 0.2 and _anyone_awake(building["id"])
	_face(PackedVector2Array([_on_slope(frame, u - side * (w + o), d_f - o, zt - 0.3 * FOOT), _on_slope(frame, u, d_f - o, zt + peak),
			_on_slope(frame, u, d_p, zt + peak), _on_slope(frame, u - side * (w + o), d_e, zt - 0.3 * FOOT)]), _tint(roof.darkened(0.1)), edge)
	_face(PackedVector2Array([_on_slope(frame, u + side * w, d_f, zs), _on_slope(frame, u + side * w, d_f, zt), _on_slope(frame, u + side * w, d_t, zt)]),
			_tint(_wall_shade(siding, along * side).darkened(0.06)))
	_face(PackedVector2Array([_on_slope(frame, u - w, d_f, zs), _on_slope(frame, u + w, d_f, zs), _on_slope(frame, u + w, d_f, zt), _on_slope(frame, u - w, d_f, zt)]),
			_tint(_wall_shade(siding, out)))
	var pane: PackedVector2Array = PackedVector2Array([_on_slope(frame, u - 1.3 * FOOT, d_f, zs + 0.5 * FOOT), _on_slope(frame, u + 1.3 * FOOT, d_f, zs + 0.5 * FOOT),
			_on_slope(frame, u + 1.3 * FOOT, d_f, zt - 0.4 * FOOT), _on_slope(frame, u - 1.3 * FOOT, d_f, zt - 0.4 * FOOT)])
	_fill(pane, _window_glass(building["id"], lit) if lit else _tint(COLOR_GLASS.darkened(0.1)))
	_outline(pane, _tint(COLOR_TRIM))
	_face(PackedVector2Array([_on_slope(frame, u - w, d_f, zt), _on_slope(frame, u + w, d_f, zt), _on_slope(frame, u, d_f, zt + peak)]), _tint(_wall_shade(siding, out)))
	_face(PackedVector2Array([_on_slope(frame, u + side * (w + o), d_f - o, zt - 0.3 * FOOT), _on_slope(frame, u, d_f - o, zt + peak),
			_on_slope(frame, u, d_p, zt + peak), _on_slope(frame, u + side * (w + o), d_e, zt - 0.3 * FOOT)]), _tint(roof.lightened(0.1)), edge)
	draw_polyline(PackedVector2Array([_on_slope(frame, u - w - o, d_f - o, zt - 0.3 * FOOT), _on_slope(frame, u, d_f - o, zt + peak),
			_on_slope(frame, u + w + o, d_f - o, zt - 0.3 * FOOT)]), _tint(COLOR_TRIM), maxf(1.0, 0.28 * FOOT * _scale), true)


## A striped awning over the store's front, a bench under it and a round sign.
func _draw_awning(building: Dictionary, style: Dictionary) -> void:
	if not style.has("awning_wall"):
		return
	var wall: Array = style["awning_wall"]
	var a: Vector2 = wall[0]
	var b: Vector2 = wall[1]
	var n: Vector2 = wall[2]
	var along: Vector2 = (b - a).normalized()
	var length: float = a.distance_to(b)
	var u0: float = 1.2 * FOOT
	var u1: float = length - 1.2 * FOOT
	var top: float = 9.6 * FOOT
	var low: float = 8.0 * FOOT
	var reach: Vector2 = n * 4.2 * FOOT
	var drop: float = 0.9 * FOOT
	_fill(PackedVector2Array([_pv(a + along * u0, top), _pv(a + along * u1, top), _pv(a + along * u1, 6.8 * FOOT), _pv(a + along * u0, 6.8 * FOOT)]),
			Color(0, 0, 0, 0.12 * (1.0 - _night)))
	var count: int = maxi(6, int((u1 - u0) / (1.7 * FOOT)))
	var cream: Color = Color(0.97, 0.94, 0.86)
	for index: int in count:
		var wa: Vector2 = a + along * lerpf(u0, u1, float(index) / float(count))
		var wb: Vector2 = a + along * lerpf(u0, u1, float(index + 1) / float(count))
		var color: Color = CHERRY if index % 2 == 0 else cream
		_fill(PackedVector2Array([_pv(wa, top), _pv(wb, top), _pv(wb + reach, low), _pv(wa + reach, low)]), _tint(color))
		var middle: Vector2 = (wa + wb) / 2.0 + reach
		_fill(PackedVector2Array([_pv(wa + reach, low), _pv(wb + reach, low), _pv(wb + reach, low - drop * 0.55),
				_pv(middle, low - drop), _pv(wa + reach, low - drop * 0.55)]), _tint(color.darkened(0.14)))
	var seam: Color = _tint(CHERRY.darkened(0.4))
	draw_line(_pv(a + along * u0, top), _pv(a + along * u1, top), seam, 1.0)
	draw_line(_pv(a + along * u0 + reach, low), _pv(a + along * u1 + reach, low), seam, 1.0)
	for end: Array in [[u0, -along], [u1, along]]:
		if _faces_viewer(end[1]):
			var w: Vector2 = a + along * float(end[0])
			_face(PackedVector2Array([_pv(w, top), _pv(w + reach, low), _pv(w + reach, low - drop * 0.55), _pv(w, low - drop * 0.55)]), _tint(CHERRY.darkened(0.15)), seam)
	_draw_bench(a + along * length * 0.62 + n * 5.4 * FOOT, along, n)
	var sign_at: Vector2 = a + along * (length * 0.18)
	draw_line(_pv(sign_at, 13.4 * FOOT), _pv(sign_at + n * 1.0 * FOOT, 13.4 * FOOT), _tint(COLOR_OUTLINE), maxf(1.0, 0.2 * FOOT * _scale))
	_draw_round_sign(sign_at + n * 2.4 * FOOT, 12.4 * FOOT, n, 1.5 * FOOT)


## A round enamel-style sign (no lettering) standing out from a wall, drawn
## in the upright plane through the direction it stands out in.
func _draw_round_sign(centre: Vector2, z: float, n: Vector2, radius: float) -> void:
	var x_axis: Vector2 = _iso(centre.x + n.x, centre.y + n.y) - _iso(centre.x, centre.y)
	draw_set_transform_matrix(Transform2D(x_axis, Vector2(0, _scale), _pv(centre, z)))
	var cream: Color = _tint(Color(0.97, 0.95, 0.90))
	draw_circle(Vector2.ZERO, radius, cream)
	draw_circle(Vector2.ZERO, radius * 0.8, _tint(CHERRY))
	draw_rect(Rect2(-radius * 0.92, -radius * 0.22, radius * 1.84, radius * 0.44), cream)
	draw_rect(Rect2(-radius * 0.6, -radius * 0.06, radius * 1.2, radius * 0.12), _tint(Color(0.22, 0.30, 0.42)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A park-style bench: iron legs, a slatted seat and back.
func _draw_bench(c: Vector2, along: Vector2, n: Vector2) -> void:
	var half: float = 2.8 * FOOT
	var depth: float = 0.7 * FOOT
	var wood: Color = Color(0.32, 0.48, 0.36)
	var iron: Color = _tint(Color(0.18, 0.18, 0.19))
	var back: Vector2 = c - n * depth
	_ellipse(_iso(c.x, c.y), half * _scale * 1.1, 0.4, Color(0, 0, 0, 0.12 * (1.0 - _night)))
	for side: float in [-1.0, 1.0]:
		draw_line(_pv(back + along * side * half * 0.85, 0.0), _pv(back + along * side * half * 0.85, 3.1 * FOOT), iron, 1.0)
	for z: float in [2.2 * FOOT, 2.8 * FOOT]:
		_fill(PackedVector2Array([_pv(back - along * half, z - 0.22 * FOOT), _pv(back + along * half, z - 0.22 * FOOT),
				_pv(back + along * half, z + 0.15 * FOOT), _pv(back - along * half, z + 0.15 * FOOT)]), _tint(wood.darkened(0.1)))
	_draw_prism([c - along * half - n * depth, c + along * half - n * depth, c + along * half + n * depth, c - along * half + n * depth],
			1.35 * FOOT, 1.6 * FOOT, wood, wood.lightened(0.12))
	for side: float in [-1.0, 1.0]:
		var leg: Vector2 = c + n * depth * 0.8 + along * side * half * 0.85
		draw_line(_pv(leg, 0.0), _pv(leg, 1.35 * FOOT), iron, 1.0)


# --- Street furniture and yard things -------------------------------------------

func _draw_pole(pole: Dictionary) -> void:
	var at: Vector2 = Vector2(pole["x"], pole["y"])
	var across: Vector2 = pole["across"]
	var wood: Color = _tint(Color(0.42, 0.33, 0.25))
	var width: float = maxf(1.6, 0.75 * FOOT * _scale)
	draw_line(_pv(at, 0.0), _pv(at, POLE_HEIGHT), wood, width)
	draw_line(_pv(at, 0.0) + Vector2(width * 0.25, 0), _pv(at, POLE_HEIGHT) + Vector2(width * 0.25, 0), _tint(Color(0.30, 0.23, 0.18)), width * 0.4)
	var arm: float = 23.6 * FOOT
	draw_line(_pv(at - across * 3.2 * FOOT, arm), _pv(at + across * 3.2 * FOOT, arm), wood, maxf(1.2, 0.4 * FOOT * _scale))
	for offset: float in [-2.7, 0.0, 2.7]:
		draw_circle(_pv(at + across * offset * FOOT, arm + 0.4 * FOOT), maxf(0.9, 0.28 * FOOT * _scale), _tint(Color(0.55, 0.72, 0.66)))
	if pole["transformer"]:
		var top: Vector2 = _pv(at, 21.5 * FOOT) + Vector2(width * 0.5, 0)
		var size: Vector2 = Vector2(maxf(3.0, 1.5 * FOOT * _scale), maxf(4.0, 2.6 * FOOT * _scale))
		var grey: Color = _tint(Color(0.56, 0.58, 0.60))
		draw_rect(Rect2(top, size), grey)
		draw_rect(Rect2(top + Vector2(size.x * 0.6, 0), Vector2(size.x * 0.4, size.y)), grey.darkened(0.15))
		_ellipse(top + Vector2(size.x / 2.0, 0), size.x / 2.0, 0.45, grey.lightened(0.15))


## One piece of the wires between two poles: three power lines on the
## crossarm and a telephone line lower down, each sagging between the poles.
func _draw_wire(index: int) -> void:
	if _wire_lines[index] == null:
		var wire: Dictionary = _wires[index]
		var a: Vector2 = wire["a"]
		var b: Vector2 = wire["b"]
		var across: Vector2 = wire["across"]
		var t0: float = wire["t0"]
		var t1: float = wire["t1"]
		var runs: Array[PackedVector2Array] = []
		for spec: Array in [[-2.7, 24.0, 1.8], [0.0, 24.0, 1.8], [2.7, 24.0, 1.8], [0.0, 19.6, 2.4]]:
			var off: Vector2 = across * float(spec[0]) * FOOT
			var points: PackedVector2Array = PackedVector2Array()
			for step: int in 4:
				var t: float = lerpf(t0, t1, float(step) / 3.0)
				points.append(_pv(a.lerp(b, t) + off, (float(spec[1]) - float(spec[2]) * sin(t * PI)) * FOOT))
			runs.append(points)
		_wire_lines[index] = runs
	var color: Color = Color(_tint(COLOR_WIRE), 0.5)
	for points: PackedVector2Array in _wire_lines[index]:
		for step: int in points.size() - 1:
			draw_line(points[step], points[step + 1], color, 1.0, true)


func _draw_hydrant(hydrant: Dictionary) -> void:
	var at: Vector2 = Vector2(hydrant["x"], hydrant["y"])
	var red: Color = _tint(Color(0.80, 0.20, 0.16))
	var base: Vector2 = _iso(at.x, at.y)
	var top: Vector2 = _pv(at, 2.3 * FOOT)
	var w: float = maxf(1.6, 0.5 * FOOT * _scale)
	_ellipse(base + Vector2(w * 0.6, 0), w * 2.0, 0.4, Color(0, 0, 0, 0.18 * (1.0 - _night)))
	draw_rect(Rect2(base.x - w * 1.3, base.y - w * 0.7, w * 2.6, w * 0.7), red.darkened(0.25))
	draw_rect(Rect2(top.x - w, top.y, w * 2.0, base.y - top.y), red)
	draw_rect(Rect2(top.x + w * 0.25, top.y, w * 0.75, base.y - top.y), red.darkened(0.18))
	var nozzle: Vector2 = _pv(at, 1.5 * FOOT)
	draw_circle(nozzle - Vector2(w * 1.2, 0), w * 0.45, red.darkened(0.1))
	draw_circle(nozzle + Vector2(w * 1.2, 0), w * 0.45, red.darkened(0.25))
	draw_circle(top, w * 1.05, red.lightened(0.12))
	draw_circle(top - Vector2(0, w * 0.75), w * 0.4, _tint(Color(0.80, 0.78, 0.72)))


func _draw_drain(drain: Dictionary) -> void:
	var c: Vector2 = Vector2(drain["x"], drain["y"])
	var along: Vector2 = drain["along"]
	var inward: Vector2 = drain["inward"]
	var l: Vector2 = along * 1.5 * FOOT
	var w: Vector2 = inward * 0.7 * FOOT
	var grate: PackedVector2Array = PackedVector2Array([_iso(c.x - l.x - w.x, c.y - l.y - w.y), _iso(c.x + l.x - w.x, c.y + l.y - w.y),
			_iso(c.x + l.x + w.x, c.y + l.y + w.y), _iso(c.x - l.x + w.x, c.y - l.y + w.y)])
	_fill(grate, _tint(Color(0.21, 0.21, 0.22)))
	var bar: Color = _tint(Color(0.48, 0.48, 0.49))
	for index: int in 5:
		var u: Vector2 = along * (float(index) - 2.0) * 0.55 * FOOT
		draw_line(_iso(c.x + u.x - w.x, c.y + u.y - w.y), _iso(c.x + u.x + w.x, c.y + u.y + w.y), bar, 1.0)
	_outline(grate, bar)


func _draw_can(can: Dictionary) -> void:
	var at: Vector2 = Vector2(can["x"], can["y"])
	var base: Vector2 = _iso(at.x, at.y)
	var top: Vector2 = _pv(at, 2.6 * FOOT)
	var r: float = maxf(2.0, 1.0 * FOOT * _scale * 1.3)
	var metal: Color = Color(0.64, 0.66, 0.68)
	_ellipse(base + Vector2(r * 0.6, 0), r * 1.4, 0.45, Color(0, 0, 0, 0.15 * (1.0 - _night)))
	_ellipse(base, r, 0.45, _tint(metal.darkened(0.1)))
	draw_rect(Rect2(top.x - r, top.y, r * 2.0, base.y - top.y), _tint(metal))
	draw_rect(Rect2(top.x + r * 0.3, top.y, r * 0.7, base.y - top.y), _tint(metal.darkened(0.15)))
	for f: float in [0.35, 0.7]:
		var y: float = lerpf(top.y, base.y, f)
		draw_line(Vector2(top.x - r, y), Vector2(top.x + r, y), _tint(metal.darkened(0.28)), 1.0)
	_ellipse(top, r * 1.12, 0.45, _tint(metal.lightened(0.14)))
	draw_line(top + Vector2(-r * 0.35, -r * 0.2), top + Vector2(r * 0.35, -r * 0.2), _tint(metal.darkened(0.4)), 1.0)


func _draw_bicycle(bike: Dictionary) -> void:
	var c: Vector2 = Vector2(bike["x"], bike["y"])
	var dir: Vector2 = bike["along"]
	var lean: Vector2 = bike["lean"]
	var paint: Color = _tint(bike["paint"])
	var tire: Color = _tint(Color(0.13, 0.13, 0.13))
	var r: float = 1.15 * FOOT
	var line: float = maxf(1.0, 0.15 * FOOT * _scale)
	var tilt: Vector2 = lean * 0.12
	var hubs: Array[Vector2] = [c - dir * 1.75 * FOOT, c + dir * 1.75 * FOOT]
	for hub: Vector2 in hubs:
		var rim: PackedVector2Array = PackedVector2Array()
		for step: int in 17:
			var angle: float = TAU * float(step) / 16.0
			var z: float = r + sin(angle) * r
			rim.append(_pv(hub + dir * cos(angle) * r + tilt * z, z))
		draw_polyline(rim, tire, maxf(1.0, 0.2 * FOOT * _scale), true)
	var crank: Vector2 = _pv(c - dir * 0.15 * FOOT + tilt * FOOT, FOOT)
	var seat: Vector2 = _pv(c - dir * 0.55 * FOOT + tilt * 3.0 * FOOT, 3.0 * FOOT)
	var head: Vector2 = _pv(c + dir * 1.1 * FOOT + tilt * 3.1 * FOOT, 3.1 * FOOT)
	var rear: Vector2 = _pv(hubs[0] + tilt * r, r)
	var front: Vector2 = _pv(hubs[1] + tilt * r, r)
	draw_polyline(PackedVector2Array([rear, crank, seat, rear]), paint, line, true)
	draw_polyline(PackedVector2Array([crank, head, seat]), paint, line, true)
	draw_line(head, front, paint, line)
	draw_line(seat + Vector2(-2.0, -1.0), seat + Vector2(2.5, -1.0), tire, maxf(1.5, line * 1.4))
	var bar: Vector2 = dir.orthogonal() * 0.8 * FOOT
	var grip: float = 3.5 * FOOT
	draw_line(_pv(c + dir * 1.1 * FOOT + tilt * grip - bar, grip), _pv(c + dir * 1.1 * FOOT + tilt * grip + bar, grip), tire, line)


func _draw_wagon(wagon: Dictionary) -> void:
	var c: Vector2 = Vector2(wagon["x"], wagon["y"])
	var dir: Vector2 = (wagon["along"] as Vector2).normalized()
	var side: Vector2 = dir.orthogonal()
	var red: Color = Color(0.78, 0.20, 0.16)
	var wheel: Color = _tint(Color(0.15, 0.15, 0.15))
	_ellipse(_iso(c.x, c.y), 2.2 * FOOT * _scale * 1.3, 0.45, Color(0, 0, 0, 0.14 * (1.0 - _night)))
	for u: float in [-1.1, 1.1]:
		for v: float in [-0.95, 0.95]:
			draw_circle(_pv(c + dir * u * FOOT + side * v * FOOT, 0.35 * FOOT), maxf(1.2, 0.36 * FOOT * _scale), wheel)
	var hl: Vector2 = dir * 1.6 * FOOT
	var hw: Vector2 = side * 0.85 * FOOT
	_draw_prism([c - hl - hw, c + hl - hw, c + hl + hw, c - hl + hw], 0.5 * FOOT, 1.2 * FOOT, red, red.darkened(0.4))
	var handle: Vector2 = c + hl + dir * 2.4 * FOOT
	draw_line(_pv(c + hl, 0.8 * FOOT), _pv(handle, 0.3 * FOOT), wheel, 1.0)
	draw_line(_pv(handle - side * 0.4 * FOOT, 0.3 * FOOT), _pv(handle + side * 0.4 * FOOT, 0.3 * FOOT), wheel, 1.0)


func _draw_tulips(row: Dictionary) -> void:
	var a: Vector2 = row["a"]
	var b: Vector2 = row["b"]
	_draw_strip(a, b, 1.5 * FOOT, _tint(Color(0.45, 0.34, 0.25)))
	var colors: Array = row["colors"]
	var r: float = clampf(0.42 * FOOT * _scale, 1.1, 3.4)
	var stem: Color = _tint(Color(0.30, 0.52, 0.26))
	for index: int in colors.size():
		var p: Vector2 = a.lerp(b, (float(index) + 0.5) / float(colors.size()))
		var base: Vector2 = _iso(p.x, p.y)
		var top: Vector2 = _pv(p, 1.3 * FOOT)
		draw_line(base, top, stem, maxf(1.0, r * 0.35))
		draw_line(base, base + Vector2(-r * 0.9, -r * 1.3), stem, maxf(1.0, r * 0.45))
		_fill(PackedVector2Array([top + Vector2(-r, -r * 0.9), top + Vector2(-r * 0.35, -r * 0.4), top + Vector2(0, -r * 1.1),
				top + Vector2(r * 0.35, -r * 0.4), top + Vector2(r, -r * 0.9), top + Vector2(r * 0.8, r * 0.3), top + Vector2(0, r * 0.6),
				top + Vector2(-r * 0.8, r * 0.3)]), _tint(colors[index]))


# --- Ground, haze and light over everything -------------------------------------

func _draw_lawn_texture() -> void:
	var stripe: Color = _tint(Color(0.86, 0.95, 0.66, 0.08))
	if _stripe_shapes.is_empty():
		for band: Array in _stripes:
			var p: Vector2 = band[0]
			var q: Vector2 = band[1]
			_stripe_shapes.append(PackedVector2Array([_iso(p.x, p.y), _iso(q.x, p.y), _iso(q.x, q.y), _iso(p.x, q.y)]))
	for shape: PackedVector2Array in _stripe_shapes:
		_fill(shape, stripe)
	for patch: Dictionary in _patches:
		var at: Vector2 = _iso(patch["x"], patch["y"])
		var radius: float = float(patch["r"]) * _scale * 1.4
		if at.x < -radius or at.x > VIEW_SIZE.x + radius or at.y < -radius or at.y > VIEW_SIZE.y + radius:
			continue
		draw_texture_rect(_blotch, Rect2(at.x - radius, at.y - radius * 0.5, radius * 2.0, radius), false, _tint(Color(patch["color"], 1.0)))


## Lamplight catching the wet-looking street at night: a few faint twinkles.
func _draw_glints() -> void:
	if _night < 0.4:
		return
	var strength: float = (_night - 0.4) / 0.6
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	for glint: Dictionary in _glints:
		var twinkle: float = 0.5 + 0.5 * sin(now * 2.1 + float(glint["phase"]))
		twinkle = twinkle * twinkle * twinkle
		var at: Vector2 = _iso(glint["x"], glint["y"])
		var r: float = (1.2 + 2.0 * twinkle) * sqrt(_zoom)
		var color: Color = Color(1.0, 0.93, 0.74, 0.7 * twinkle * strength)
		draw_line(at - Vector2(r, 0), at + Vector2(r, 0), color, 1.0)
		draw_line(at - Vector2(0, r * 0.6), at + Vector2(0, r * 0.6), color, 1.0)


func _rect_corners(rect: Rect2) -> Array[Vector2]:
	return [_iso(rect.position.x, rect.position.y), _iso(rect.end.x, rect.position.y), _iso(rect.end.x, rect.end.y), _iso(rect.position.x, rect.end.y)]


## Beyond the lots the ground fades into a soft, hazy distance, so the world
## does not stop at a hard edge.
func _draw_haze() -> void:
	var haze: Color = _tint(COLOR_HAZE)
	var rings: Array = [
		[_rect_corners(_lot_bounds.grow(24.0 * FOOT)), Color(haze, 0.0)],
		[_rect_corners(_lot_bounds.grow(70.0 * FOOT)), Color(haze, 0.32)],
		[_rect_corners(_lot_bounds.grow(130.0 * FOOT)), Color(haze, 0.88)],
		[_rect_corners(_lot_bounds.grow(6000.0 * FOOT)), Color(haze, 0.88)],
	]
	for ring: int in rings.size() - 1:
		var inner: Array[Vector2] = rings[ring][0]
		var outer: Array[Vector2] = rings[ring + 1][0]
		var c0: Color = rings[ring][1]
		var c1: Color = rings[ring + 1][1]
		for i: int in 4:
			var j: int = (i + 1) % 4
			draw_polygon(PackedVector2Array([inner[i], inner[j], outer[j], outer[i]]), PackedColorArray([c0, c0, c1, c1]))


## Low warm sunlight washing in from the sun's side at the start and end of the day.
func _draw_golden_light() -> void:
	var strength: float = _golden * (1.0 - _night)
	if strength < 0.02:
		return
	var sun: Vector2 = Vector2(-1.0, -0.5).normalized() if simulation.clock.minute_of_day > 750 else Vector2(1.0, 0.5).normalized()
	var centre: Vector2 = MAP_RECT.get_center()
	var corners: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(VIEW_SIZE.x, 0), VIEW_SIZE, Vector2(0, VIEW_SIZE.y)])
	var colors: PackedColorArray = PackedColorArray()
	for corner: Vector2 in corners:
		var t: float = clampf((corner - centre).normalized().dot(sun) * 0.5 + 0.5, 0.0, 1.0)
		colors.append(Color(1.0, 0.70, 0.36, strength * (0.03 + 0.22 * t * t)))
	draw_polygon(corners, colors)


## A soft darkening toward the edges of the map, like an old photograph.
func _draw_vignette() -> void:
	var outer: Rect2 = MAP_RECT.grow(22.0)
	var inner: Rect2 = MAP_RECT.grow(-70.0)
	var edge: Color = Color(0.06, 0.08, 0.10, 0.22 + 0.10 * _night)
	var none: Color = Color(edge, 0.0)
	var o: Array[Vector2] = [outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)]
	var n: Array[Vector2] = [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]
	for i: int in 4:
		var j: int = (i + 1) % 4
		draw_polygon(PackedVector2Array([n[i], n[j], o[j], o[i]]), PackedColorArray([none, none, edge, edge]))
	draw_rect(Rect2(0, 0, VIEW_SIZE.x, outer.position.y), edge)
	draw_rect(Rect2(0, outer.end.y, VIEW_SIZE.x, VIEW_SIZE.y - outer.end.y), edge)
	draw_rect(Rect2(0, outer.position.y, outer.position.x, outer.size.y), edge)
	draw_rect(Rect2(outer.end.x, outer.position.y, VIEW_SIZE.x - outer.end.x, outer.size.y), edge)


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
			_fill(PackedVector2Array([at - Vector2(width, base), at - Vector2(-width, base), at - Vector2(0, base + size * 0.95)]),
				dark.lightened(0.08 * float(layer)))
		return
	var centre: Vector2 = at - Vector2(0, size * 1.45)
	var blossom: int = tree.get("blossom", -1)
	if _spring and blossom >= 0:
		# A flowering tree in bloom: a soft pink or white crown scattered with petals.
		var bloom: Color = BLOSSOMS[blossom]
		draw_circle(centre + Vector2(size * 0.15, size * 0.12), size, _tint(bloom.darkened(0.22)))
		draw_circle(centre - Vector2(size * 0.35, size * 0.05), size * 0.72, _tint(bloom.darkened(0.10)))
		draw_circle(centre + Vector2(size * 0.32, -size * 0.18), size * 0.68, _tint(bloom))
		draw_circle(centre - Vector2(size * 0.08, size * 0.42), size * 0.55, _tint(bloom.lightened(0.10)))
		var light_petal: Color = _tint(bloom.lightened(0.35))
		var dark_petal: Color = _tint(bloom.darkened(0.3))
		var fallen: Color = _tint(Color(bloom, 0.8))
		for speck: Vector2 in tree["specks"]:
			_dot(centre + speck * size * 0.8, maxf(0.8, size * 0.07), light_petal if speck.y < 0.0 else dark_petal)
		# A few petals fallen on the grass beneath.
		for speck: Vector2 in tree["specks"]:
			_dot(at + Vector2(speck.x * size * 1.1, speck.y * size * 0.35 + size * 0.1), maxf(0.7, size * 0.04), fallen)
		return
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


func _draw_fence(index: int) -> void:
	var fence: Array = _fences[index]
	var a: Vector2 = fence[0]
	var b: Vector2 = fence[1]
	var height: float = 3.0 * FOOT
	if _fence_lines[index] == null:
		# The pickets, as one batch of lines.
		var pickets: PackedVector2Array = PackedVector2Array()
		var step: float = 2.0 * FOOT if _zoom >= 1.4 else 4.0 * FOOT
		var length: float = a.distance_to(b)
		var at: float = 0.0
		while at <= length:
			var p: Vector2 = a.lerp(b, at / length)
			pickets.append(_p3(p.x, p.y, 0.0))
			pickets.append(_p3(p.x, p.y, height))
			at += step
		_fence_lines[index] = pickets
	draw_line(_p3(a.x, a.y, height * 0.7), _p3(b.x, b.y, height * 0.7), _tint(COLOR_FENCE.darkened(0.25)), 1.0)
	var lines: PackedVector2Array = _fence_lines[index]
	if lines.size() >= 2:
		draw_multiline(lines, _tint(COLOR_FENCE), 1.0)


func _draw_flowers(bed: Dictionary) -> void:
	var x: float = bed["x"]
	var y: float = bed["y"]
	var radius: float = clampf(0.6 * FOOT * _scale, 1.4, 3.6)
	var lift: Vector2 = Vector2(0, 0.6 * FOOT * _scale)
	var leaf: Color = _tint(Color(0.26, 0.44, 0.22))
	for dot: Array in bed["dots"]:
		var at: Vector2 = _iso(x + float(dot[0]), y + float(dot[1]))
		_dot(at, radius * 1.2, leaf)
		_dot(at - lift, radius, _tint(dot[2]))


func _draw_mailbox(mailbox: Dictionary) -> void:
	var x: float = mailbox["x"]
	var y: float = mailbox["y"]
	var along: Vector2 = mailbox["along"]
	var post: Color = _tint(Color(0.45, 0.35, 0.25))
	draw_line(_p3(x, y, 0.0), _p3(x, y, 3.4 * FOOT), post, maxf(1.5, 0.35 * FOOT * _scale))
	var hx: float = 0.5 * FOOT if absf(along.x) < absf(along.y) else 0.9 * FOOT
	var hy: float = 0.9 * FOOT if absf(along.x) < absf(along.y) else 0.5 * FOOT
	_draw_box(x - hx, y - hy, x + hx, y + hy, 3.4 * FOOT, 4.4 * FOOT, mailbox["paint"])
	# The little red flag.
	var flag: Vector2 = _p3(x + hx, y - hy, 4.4 * FOOT)
	var flag_size: float = maxf(2.0, 0.7 * FOOT * _scale)
	draw_line(flag, flag - Vector2(0, flag_size * 1.4), _tint(CHERRY), maxf(1.0, flag_size * 0.4))
	draw_rect(Rect2(flag - Vector2(0, flag_size * 1.4), Vector2(flag_size, flag_size * 0.6)), _tint(CHERRY))


func _draw_clothesline(line: Dictionary) -> void:
	var a: Vector2 = line["a"]
	var b: Vector2 = line["b"]
	var high: float = 6.0 * FOOT
	var sag: float = 0.7 * FOOT
	var post: Color = _tint(Color(0.55, 0.52, 0.48))
	var width: float = maxf(1.2, 0.3 * FOOT * _scale)
	draw_line(_p3(a.x, a.y, 0.0), _p3(a.x, a.y, high), post, width)
	draw_line(_p3(b.x, b.y, 0.0), _p3(b.x, b.y, high), post, width)
	var rope: PackedVector2Array = PackedVector2Array()
	for step: int in 9:
		var t: float = float(step) / 8.0
		var p: Vector2 = a.lerp(b, t)
		rope.append(_p3(p.x, p.y, high - sag * sin(t * PI)))
	draw_polyline(rope, _tint(Color(0.85, 0.83, 0.78)), 1.0, true)
	var sway: float = sin(float(Time.get_ticks_msec()) / 900.0)
	var dir: Vector2 = (b - a).normalized()
	for item: Array in line["items"]:
		var t: float = item[0]
		var p: Vector2 = a.lerp(b, t)
		var q: Vector2 = p + dir * float(item[1])
		var tq: float = t + float(item[1]) / a.distance_to(b)
		var top_p: float = high - sag * sin(t * PI)
		var top_q: float = high - sag * sin(tq * PI)
		var drop: float = item[2]
		var swing: Vector2 = Vector2(sway * 1.2 * _scale * FOOT * 0.3, 0)
		var cloth: PackedVector2Array = PackedVector2Array([
			_p3(p.x, p.y, top_p), _p3(q.x, q.y, top_q),
			_p3(q.x, q.y, top_q - drop) + swing, _p3(p.x, p.y, top_p - drop) + swing])
		var color: Color = item[3]
		_face(cloth, _tint(color), _tint(color.darkened(0.3)))


## Soft grey puffs from the chimneys of houses where someone is up around
## breakfast, dinner and supper, or the furnace is going in the early morning.
func _draw_smoke() -> void:
	var minute: int = simulation.clock.minute_of_day
	var cooking: bool = false
	for window: Vector2i in SMOKE_TIMES:
		if minute >= window.x and minute <= window.y:
			cooking = true
	if not cooking:
		return
	var now: float = float(Time.get_ticks_msec())
	var grey: Color = Color(0.86, 0.86, 0.85).lerp(_ambient, 0.35)
	for building_id: String in _chimneys:
		if not _anyone_awake(building_id):
			continue
		var top: Vector3 = _chimneys[building_id]
		var mouth: Vector2 = _p3(top.x, top.y, top.z)
		var offset: float = float(absi(building_id.hash()) % 1000) / 1000.0
		for puff: int in 6:
			var phase: float = fmod(now / 3200.0 + offset + float(puff) / 6.0, 1.0)
			var rise: float = phase * 46.0 * sqrt(_zoom)
			var drift: Vector2 = Vector2(phase * phase * 22.0 * sqrt(_zoom) + sin(now / 700.0 + float(puff)) * 2.0, -rise)
			var radius: float = (2.5 + phase * 7.5) * sqrt(_zoom)
			var alpha: float = 0.5 * (1.0 - phase) * clampf(phase * 6.0, 0.0, 1.0)
			draw_circle(mouth + drift, radius, Color(grey, alpha))


## Large, faint cloud shadows sliding across the ground by day.
func _draw_cloud_shadows() -> void:
	var minute: float = float(simulation.clock.minute_of_day)
	var day: float = clampf((minute - 420.0) / 60.0, 0.0, 1.0) * clampf((1080.0 - minute) / 60.0, 0.0, 1.0)
	if day <= 0.01:
		return
	var seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var travel: Vector2 = Vector2(1.0, -0.45).normalized() * 3.0 * FOOT * seconds
	var span: Vector2 = _world_bounds.size
	var shade: Color = Color(0.08, 0.12, 0.10, 0.06 * day)
	for cloud: Dictionary in _clouds:
		var x: float = _world_bounds.position.x + fposmod(float(cloud["x"]) + travel.x - _world_bounds.position.x, span.x)
		var y: float = _world_bounds.position.y + fposmod(float(cloud["y"]) + travel.y - _world_bounds.position.y, span.y)
		for blob: Array in cloud["blobs"]:
			_ellipse(_iso(x + float(blob[0]), y + float(blob[1])), float(blob[2]) * _scale, 0.5, shade)


## Now and then a few small birds cross the sky by day.
func _draw_birds() -> void:
	if _night > 0.3:
		return
	var now: int = Time.get_ticks_msec()
	var cycle: int = now / 26000
	var age: float = float(now % 26000) / 11000.0
	if age > 1.0 or absi(str(cycle).hash()) % 3 == 0:
		return
	var key: int = absi(("birds" + str(cycle)).hash())
	var leftward: bool = key % 2 == 0
	var y: float = MAP_RECT.position.y + 30.0 + float(key % 110)
	var x: float = lerpf(MAP_RECT.position.x - 20.0, MAP_RECT.end.x + 20.0, 1.0 - age if leftward else age)
	var ink: Color = Color(INK, 0.75 * (1.0 - _night))
	for bird: int in 1 + key % 3:
		var at: Vector2 = Vector2(x + float(bird) * (14.0 if leftward else -14.0), y + float(bird) * 7.0 + sin(age * 9.0 + float(bird)) * 3.0)
		var flap: float = sin(float(now) / 120.0 + float(bird) * 1.7) * 2.5
		draw_polyline(PackedVector2Array([at + Vector2(-5, -2 - flap), at, at + Vector2(5, -2 - flap)]), ink, 1.3, true)


# --- A cat and a dog ---------------------------------------------------------------

## Where the cat and the dog are this frame. They keep wall-clock time, not
## the game's, so they go about their business while the game is paused;
## after dark both are curled up asleep.
func _place_animals() -> void:
	var seconds: float = float(Time.get_ticks_msec()) / 1000.0
	var asleep: bool = _night > 0.6
	_cat_now = {}
	_dog_now = {}
	if not _cat.is_empty():
		var route: Array = _cat["route"]
		var face: float = _cat["face"]
		# A minute or so: on the step, over to the fence and along it, a
		# while up there, and back again.
		var t: float = fmod(seconds + float(_cat["offset"]), 64.0)
		var along: float = 0.0   # 0 on the step, 1 on the fence
		var pose: String = "sit"
		if asleep:
			pose = "sleep"
		elif t >= 22.0 and t < 31.0:
			along = (t - 22.0) / 9.0
			pose = "walk"
		elif t >= 31.0 and t < 52.0:
			along = 1.0
		elif t >= 52.0 and t < 61.0:
			along = 1.0 - (t - 52.0) / 9.0
			pose = "walk"
		var total: float = 0.0
		for index: int in route.size() - 1:
			total += (route[index] as Vector3).distance_to(route[index + 1])
		var remaining: float = total * along
		var at: Vector3 = route[0]
		for index: int in route.size() - 1:
			var from: Vector3 = route[index]
			var to: Vector3 = route[index + 1]
			var length: float = from.distance_to(to)
			if remaining <= length:
				at = from.lerp(to, remaining / maxf(length, 0.001))
				if pose == "walk" and absf(to.x + to.y - from.x - from.y) > 1.0:
					face = signf(to.x + to.y - from.x - from.y) * (1.0 if t < 40.0 else -1.0)
				break
			remaining -= length
			at = to
		if along >= 1.0:
			var last: Vector3 = route[route.size() - 1]
			var previous: Vector3 = route[route.size() - 2]
			face = -signf(last.x + last.y - previous.x - previous.y)
		_cat_now = {"at": at, "pose": pose, "face": face if face != 0.0 else 1.0, "step": seconds * 9.0}
	if not _dog.is_empty():
		var a: Vector2 = _dog["a"]
		var b: Vector2 = _dog["b"]
		var t: float = fmod(seconds + float(_dog["offset"]), 22.0)
		var along: float = 0.0
		var pose: String = "sit"
		var face: float = signf(b.x + b.y - a.x - a.y)
		if asleep:
			pose = "sleep"
		elif t < 5.0:
			along = t / 5.0
			pose = "trot"
		elif t < 9.0:
			along = 1.0
			pose = "stand"
		elif t < 14.0:
			along = 1.0 - (t - 9.0) / 5.0
			pose = "trot"
			face = -face
		var spot: Vector2 = a.lerp(b, along)
		_dog_now = {"at": Vector3(spot.x, spot.y, 0.0), "pose": pose, "face": face if face != 0.0 else 1.0, "step": seconds * 11.0}


func _animal_light(color: Color) -> Color:
	return _lit_by(Color.WHITE.lerp(_ambient, 0.7), color)


func _draw_zzz(at: Vector2, k: float) -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	for index: int in 2:
		var t: float = fmod(now * 0.45 + 0.5 * float(index), 1.0)
		draw_string(_font, at + Vector2(3.0 * k + 5.0 * t * k, -4.0 * k - 9.0 * t * k), "z", HORIZONTAL_ALIGNMENT_LEFT, -1,
				clampi(int((6.0 + 3.0 * t) * k), 7, 16), Color(0.95, 0.95, 1.0, 0.75 * sin(t * PI)))


func _draw_cat() -> void:
	var at: Vector3 = _cat_now["at"]
	var feet: Vector2 = _p3(at.x, at.y, at.z)
	var k: float = clampf(1.1 * sqrt(_zoom), 0.9, 1.9)
	var f: float = _cat_now["face"]
	var coat: Color = _animal_light(_cat["coat"])
	var dark: Color = _animal_light((_cat["coat"] as Color).darkened(0.35))
	var pose: String = _cat_now["pose"]
	if at.z < 1.0:
		_ellipse(feet, 3.6 * k, 0.4, Color(0.10, 0.12, 0.08, 0.16 * (1.0 - _night)))
	var head: Vector2
	if pose == "sleep":
		_ellipse(feet - Vector2(0, 1.5 * k), 3.3 * k, 0.6, coat)
		head = feet + Vector2(2.0 * f * k, -1.7 * k)
		draw_arc(feet - Vector2(0, 1.2 * k), 3.2 * k, 0.15 * PI, 0.85 * PI, 8, dark, maxf(1.0, 0.9 * k))
		_draw_zzz(feet, k)
	elif pose == "walk":
		var swing: float = sin(float(_cat_now["step"])) * 1.3 * k
		for leg: Array in [[-2.4, 1.0], [-1.6, -1.0], [1.8, -1.0], [2.6, 1.0]]:
			draw_line(feet + Vector2(float(leg[0]) * f * k, -2.6 * k), feet + Vector2(float(leg[0]) * f * k + swing * float(leg[1]), 0), dark, maxf(1.0, 0.8 * k))
		draw_set_transform(feet - Vector2(0, 3.3 * k), 0.0, Vector2(1.0, 0.48))
		draw_circle(Vector2.ZERO, 3.5 * k, coat)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		head = feet + Vector2(3.9 * f * k, -4.6 * k)
		var sway: float = sin(float(_cat_now["step"]) * 0.35) * 1.2 * k
		draw_polyline(PackedVector2Array([feet + Vector2(-3.2 * f * k, -3.6 * k), feet + Vector2(-4.6 * f * k, -5.6 * k),
				feet + Vector2(-4.4 * f * k + sway, -8.2 * k)]), coat, maxf(1.0, 0.9 * k), true)
	else:
		var flick: float = sin(float(Time.get_ticks_msec()) / 500.0) * 0.8 * k
		draw_polyline(PackedVector2Array([feet + Vector2(-1.6 * f * k, -0.8 * k), feet + Vector2(-3.6 * f * k, -0.4 * k),
				feet + Vector2(-4.4 * f * k, -1.8 * k + flick)]), dark, maxf(1.0, 0.9 * k), true)
		draw_set_transform(feet - Vector2(0.4 * f * k, 2.6 * k), 0.0, Vector2(0.78, 1.0))
		draw_circle(Vector2.ZERO, 2.8 * k, coat)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(feet + Vector2(0.9 * f * k, -1.5 * k), 1.5 * k, _animal_light((_cat["coat"] as Color).lightened(0.25)))
		head = feet + Vector2(0.9 * f * k, -5.9 * k)
	draw_circle(head, 1.9 * k, coat)
	for ear: float in [-1.0, 1.0]:
		_fill(PackedVector2Array([head + Vector2((ear * 1.7 - 0.5) * k, -0.9 * k), head + Vector2((ear * 1.7 + 0.5) * k, -1.3 * k),
				head + Vector2(ear * 1.5 * k, -3.0 * k)]), coat if pose == "sleep" else dark)


func _draw_dog() -> void:
	var at: Vector3 = _dog_now["at"]
	var feet: Vector2 = _p3(at.x, at.y, 0.0)
	var k: float = clampf(1.3 * sqrt(_zoom), 1.1, 2.3)
	var f: float = _dog_now["face"]
	var coat: Color = _animal_light(_dog["coat"])
	var ear: Color = _animal_light(_dog["ear"])
	var pose: String = _dog_now["pose"]
	var now: float = float(Time.get_ticks_msec())
	_ellipse(feet, 5.0 * k, 0.4, Color(0.10, 0.12, 0.08, 0.16 * (1.0 - _night)))
	if pose == "sleep":
		_ellipse(feet - Vector2(0, 1.8 * k), 4.6 * k, 0.5, coat)
		draw_circle(feet + Vector2(3.6 * f * k, -1.5 * k), 2.0 * k, coat)
		_fill(PackedVector2Array([feet + Vector2(2.6 * f * k, -3.0 * k), feet + Vector2(4.2 * f * k, -2.6 * k), feet + Vector2(2.8 * f * k, -0.6 * k)]), ear)
		draw_arc(feet - Vector2(0, 1.4 * k), 4.4 * k, 0.2 * PI, 0.8 * PI, 8, ear, maxf(1.0, 0.9 * k))
		_draw_zzz(feet + Vector2(2.0 * f * k, 0), k)
		return
	var trot: bool = pose == "trot"
	var sitting: bool = pose == "sit"
	var stride: float = sin(float(_dog_now["step"])) * 1.9 * k if trot else 0.0
	var bounce: float = absf(sin(float(_dog_now["step"]))) * 0.7 * k if trot else 0.0
	var body: Vector2 = feet - Vector2(0, 4.6 * k + bounce)
	var legs: Color = _animal_light((_dog["coat"] as Color).darkened(0.22))
	var rump: float = 2.0 * k if sitting else 0.0
	for leg: Array in [[-3.0, 1.0], [-2.1, -1.0], [2.3, -1.0], [3.2, 1.0]]:
		var top: Vector2 = body + Vector2(float(leg[0]) * f * k, 1.2 * k + (rump if float(leg[0]) < 0.0 else 0.0))
		draw_line(top, feet + Vector2(float(leg[0]) * f * k + stride * float(leg[1]), 0), legs, maxf(1.2, 1.1 * k))
	# The tail wags, faster when standing about.
	var wag: float = sin(now / (90.0 if not trot else 150.0)) * 1.8 * k
	draw_line(body + Vector2(-3.8 * f * k, -0.4 * k + rump), body + Vector2(-5.6 * f * k + wag * 0.4, -3.6 * k + rump + absf(wag) * 0.3), coat, maxf(1.2, 1.1 * k))
	draw_set_transform(body + Vector2(0, rump * 0.5), -0.35 * f if sitting else 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 4.2 * k, coat)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var head: Vector2 = body + Vector2(4.6 * f * k, -2.6 * k)
	draw_circle(head, 2.2 * k, coat)
	draw_circle(head + Vector2(2.1 * f * k, 0.7 * k), 1.2 * k, coat)
	draw_circle(head + Vector2(3.1 * f * k, 0.5 * k), maxf(0.7, 0.5 * k), _animal_light(Color(0.14, 0.12, 0.12)))
	_fill(PackedVector2Array([head + Vector2(-1.9 * f * k, -1.6 * k), head + Vector2(0.2 * f * k, -1.9 * k), head + Vector2(-1.5 * f * k, 1.9 * k)]), ear)


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
	_fill(torso, _lit_by(person_light, body))
	_outline(torso, _lit_by(person_light, body.darkened(0.45)))
	var sleeve: Color = _lit_by(person_light, body.darkened(0.15))
	# A short wave hello when a conversation starts: the arm on the side of
	# the other person goes up and wags.
	var wave_side: float = 0.0
	if _waves.has(id):
		var wave_age: int = int(now) - int(_waves[id])
		if wave_age >= WAVE_MS:
			_waves.erase(id)
		else:
			var other_id: String = person["action"].get("other_id", "") if talking else ""
			wave_side = -1.0 if _screen_positions.has(other_id) and (_screen_positions[other_id] as Vector2).x < feet.x else 1.0
			var raise: float = clampf(float(wave_age) / 140.0, 0.0, 1.0) * clampf(float(WAVE_MS - wave_age) / 200.0, 0.0, 1.0)
			var wag: float = sin(float(wave_age) / 70.0) * 1.6 * k
			var shoulder: Vector2 = shoulders + Vector2(3.0 * k * wave_side, 0.5)
			var rest: Vector2 = hip + Vector2(3.8 * k * wave_side, -1.0)
			var hand: Vector2 = rest.lerp(shoulders + Vector2(6.2 * k * wave_side + wag, -6.5 * k), raise)
			draw_line(shoulder, hand, sleeve, 1.6 * k)
			draw_circle(hand, 1.3 * k, _lit_by(person_light, COLOR_SKIN))
	if wave_side >= 0.0:
		draw_line(shoulders + Vector2(-3.0 * k, 0.5), hip + Vector2(-3.8 * k, -1.0 - swing * 0.4), sleeve, 1.6 * k)
	if wave_side <= 0.0:
		draw_line(shoulders + Vector2(3.0 * k, 0.5), hip + Vector2(3.8 * k, -1.0 + swing * 0.4), sleeve, 1.6 * k)
	var head: Vector2 = shoulders - Vector2(0, 3.4 * k)
	draw_circle(head, 3.2 * k, _lit_by(person_light, COLOR_SKIN))
	draw_arc(head, 3.2 * k, PI * 1.05, PI * 1.95, 10, _lit_by(person_light, _pick(HAIR, id + "hair")), 2.2 * k)
	draw_arc(head, 3.2 * k, 0.0, TAU, 16, _lit_by(person_light, COLOR_SKIN.darkened(0.4)), 1.0)
	if id == selected_id:
		var bounce: float = sin(now / 220.0) * 2.0
		var tip: Vector2 = head - Vector2(0, 9.0 * k + bounce)
		_fill(PackedVector2Array([tip, tip + Vector2(-4.5, -6), tip + Vector2(4.5, -6)]), MUSTARD)
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
		_fill(PackedVector2Array([
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


## A small paper card about the person under the pointer: who they are, whose
## household, what they are doing and, for a neighbor while one of the
## player's household is selected, how the two regard each other. Read only:
## a pair who have never met has no record, and none is made here.
func _draw_person_card(person_id: String) -> void:
	var person: Dictionary = simulation.state.people[person_id]
	var household: Dictionary = simulation.state.households[person["household_id"]]
	var players: bool = household["player_controlled"]
	var title: String = "%s %s" % [person["given_name"], person["family_name"]]
	var home_line: String = "%s%s" % [household["name"], "  (your household)" if players else ""]
	var doing: String = _bubbles.get(person_id, {}).get("text", "")
	# Each row: [text, size, color].
	var rows: Array = [[home_line, 11, Color(0.45, 0.38, 0.32)]]
	if doing != "":
		rows.append([doing, 12, INK])
	var regard: Array = []  # [text, color] pieces of the regard line
	var viewer: Dictionary = simulation.state.people.get(selected_id, {})
	if not players and not viewer.is_empty() and selected_id != person_id \
			and simulation.state.households[viewer["household_id"]]["player_controlled"]:
		if simulation.state.relationships.has(Records.relationship_key(selected_id, person_id)):
			var mine: int = simulation.state.regard(selected_id, person_id)
			var theirs: int = simulation.state.regard(person_id, selected_id)
			regard = [
				["Regard:  %s → %s " % [viewer["given_name"], person["given_name"]], INK], ["%+d" % mine, _regard_color(mine)],
				["   %s → %s " % [person["given_name"], viewer["given_name"]], INK], ["%+d" % theirs, _regard_color(theirs)]]
		else:
			regard = [["%s has not met %s yet" % [viewer["given_name"], person["given_name"]], Color(0.45, 0.38, 0.32)]]
	var width: float = _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 30.0
	for row: Array in rows:
		width = maxf(width, _font.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, row[1]).x)
	var regard_width: float = 0.0
	for piece: Array in regard:
		regard_width += _font.get_string_size(piece[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	width = maxf(width, regard_width) + 22.0
	var height: float = 26.0 + 8.0 + 16.0 * float(rows.size()) + (22.0 if not regard.is_empty() else 0.0) + 4.0
	var at: Vector2 = _hover + Vector2(16, 20)
	if at.x + width > VIEW_SIZE.x - 6.0:
		at.x = _hover.x - 16.0 - width
	if at.y + height > VIEW_SIZE.y - 6.0:
		at.y = _hover.y - 12.0 - height
	at = Vector2(maxf(at.x, 6.0), maxf(at.y, 6.0)).round()
	draw_style_box(_card_box, Rect2(at, Vector2(width, height)))
	draw_style_box(_card_head, Rect2(at, Vector2(width, 26)))
	draw_circle(at + Vector2(14, 13), 5.5, PAPER)
	draw_circle(at + Vector2(14, 13), 4.2, _pick(PLAYER_CLOTHES, person_id) if players else _pick(CLOTHES, person_id))
	draw_string(_font, at + Vector2(25, 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PAPER)
	var y: float = at.y + 26.0 + 17.0
	for row: Array in rows:
		draw_string(_font, Vector2(at.x + 11.0, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, row[1], row[2])
		y += 16.0
	if not regard.is_empty():
		draw_line(Vector2(at.x + 10.0, y - 9.0), Vector2(at.x + width - 10.0, y - 9.0), Color(MUSTARD, 0.7), 1.0)
		y += 6.0
		var x: float = at.x + 11.0
		for piece: Array in regard:
			draw_string(_font, Vector2(x, y), piece[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, piece[1])
			x += _font.get_string_size(piece[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x


func _regard_color(value: int) -> Color:
	if value > 0:
		return TEAL
	return CHERRY if value < 0 else INK


func _draw_hover_label(hovered: Dictionary) -> void:
	var text: String = ""
	if hovered.has("person"):
		_draw_person_card(hovered["person"])
		return
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
	var hovered_label: Array = []
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
		var here: Array = occupants.get(room_id, [])
		if here.is_empty():
			continue
		# As many rows as fit below the room's name; further people start a
		# new column. Labels shorten to fit; hovering a dot shows it all.
		var rows: int = maxi(1, int((rect.size.y - 24.0) / 15.0))
		var columns: int = ceili(float(here.size()) / float(rows))
		var column_width: float = (rect.size.x - 6.0) / float(columns)
		var spacing: float = minf(15.0, (rect.size.y - 30.0) / float(mini(rows, here.size()) - 1)) if mini(rows, here.size()) > 1 else 15.0
		for index: int in here.size():
			var person: Dictionary = here[index]
			var at: Vector2 = rect.position + Vector2(13.0 + float(index / rows) * column_width, 30.0 + float(index % rows) * spacing)
			var players: bool = simulation.state.households[person["household_id"]]["player_controlled"]
			if person["id"] == selected_id:
				draw_circle(at, 7.5, MUSTARD)
			draw_circle(at, 5.5, _pick(PLAYER_CLOTHES, person["id"]) if players else _pick(CLOTHES, person["id"]))
			draw_circle(at - Vector2(0, 1.5), 2.6, COLOR_SKIN)
			var full: String = _interior_label(person)
			if at.distance_to(_hover) < 8.0:
				hovered_label = [at, full]
			var room_for_text: float = column_width - 26.0
			var text: String = _fit_text(full, room_for_text, 10)
			if text == "":
				text = _fit_text(person["given_name"], room_for_text, 10)
			if text == "":
				continue
			var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			draw_rect(Rect2(at + Vector2(8, -7), Vector2(width + 6, 13)), Color(PAPER, 0.8))
			draw_string(_font, at + Vector2(11, 3.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)
	draw_string(_font, Vector2(INTERIOR_RECT.position.x + 12, INTERIOR_RECT.end.y - 9), "Click a room to send someone there", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.48, 0.40, 0.34))
	if not hovered_label.is_empty():
		var label_text: String = hovered_label[1]
		var size: Vector2 = _font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12) + Vector2(14, 8)
		var spot: Vector2 = (hovered_label[0] as Vector2) + Vector2(10, -size.y - 8)
		spot.x = clampf(spot.x, 4.0, VIEW_SIZE.x - size.x - 4.0)
		draw_style_box(_pill_box, Rect2(spot, size))
		draw_string(_font, spot + Vector2(7, size.y - 8.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


## "Name: what they are doing" for the cutaway.
func _interior_label(person: Dictionary) -> String:
	var doing: String = (_bubbles.get(person["id"], {}).get("text", "") as String).to_lower()
	return person["given_name"] if doing == "" else "%s: %s" % [person["given_name"], doing]


## The text if it fits the width; otherwise "" (the caller tries something shorter).
func _fit_text(text: String, width: float, size: int) -> String:
	return text if _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width else ""


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
				_following = false
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
				_following = false
			KEY_RIGHT, KEY_D:
				_pan.x -= step
				_following = false
			KEY_UP, KEY_W:
				_pan.y += step
				_following = false
			KEY_DOWN, KEY_S:
				_pan.y -= step
				_following = false
			KEY_F:
				toggle_follow()
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
			_add_ripple(point, true)
			room_clicked.emit(room_id)
			return
	if INTERIOR_RECT.has_point(point) and not rects.is_empty():
		return
	var person_id: String = _person_at(point)
	if person_id != "":
		_add_ripple(point, true)
		person_clicked.emit(person_id)
		return
	var clicked: String = _building_at(point)
	_add_ripple(point, clicked != "")
	if clicked != "":
		building_clicked.emit(clicked)


## A ring that spreads from where the player clicked: mustard on something
## that can be clicked, grey on open ground. It stays put if the view moves.
func _add_ripple(point: Vector2, good: bool) -> void:
	_ripples.append({"iso": _iso_of_screen(point), "since": Time.get_ticks_msec(), "good": good})
	while _ripples.size() > 6:
		_ripples.pop_front()


func _draw_ripples() -> void:
	var now: int = Time.get_ticks_msec()
	var kept: Array = []
	for ripple: Dictionary in _ripples:
		var age: int = now - int(ripple["since"])
		if age > RIPPLE_MS:
			continue
		kept.append(ripple)
		var t: float = float(age) / float(RIPPLE_MS)
		var eased: float = 1.0 - (1.0 - t) * (1.0 - t)
		var good: bool = ripple["good"]
		var color: Color = MUSTARD if good else Color(0.80, 0.79, 0.76)
		var at: Vector2 = (ripple["iso"] as Vector2) * _scale + _offset
		draw_set_transform(at, 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, 3.0 + 4.0 * eased, Color(color, 0.30 * (1.0 - t)))
		draw_arc(Vector2.ZERO, 4.0 + (20.0 if good else 14.0) * eased, 0.0, TAU, 28, Color(1, 1, 1, 0.55 * (1.0 - t)), 4.0, true)
		draw_arc(Vector2.ZERO, 4.0 + (20.0 if good else 14.0) * eased, 0.0, TAU, 28, Color(color, 1.0 - t * t), 2.2, true)
		if good and t > 0.25:
			var late: float = (t - 0.25) / 0.75
			draw_arc(Vector2.ZERO, 3.0 + 13.0 * late, 0.0, TAU, 24, Color(color, 0.6 * (1.0 - late)), 1.5, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_ripples = kept


## The building drawn at a point on the screen ("" if none). The frontmost
## building wins where two overlap.
func _building_at(point: Vector2) -> String:
	if INTERIOR_RECT.has_point(point) and _interior_home() != "":
		return ""
	var found: String = ""
	var found_depth: float = -INF
	for building_id: String in _building_ids:
		var shapes: Array = _building_shapes.get(building_id, [])
		if shapes.is_empty():
			var building: Dictionary = area.buildings[building_id]
			shapes = [_polygon(building["footprint"]), _polygon(building["footprint"], (_wall_height(building) + _roof_rise(building)) * _scale)]
		for shape: PackedVector2Array in shapes:
			if Geometry2D.is_point_in_polygon(point, shape):
				var rect: Rect2 = _building_rect(area.buildings[building_id])
				var depth: float = _iso(rect.get_center().x, rect.get_center().y).y
				if depth > found_depth:
					found_depth = depth
					found = building_id
				break
	return found
