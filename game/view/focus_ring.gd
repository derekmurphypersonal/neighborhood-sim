extends Control
## A brief highlight on the street: rings that spread out from a person or a
## building's door and a small marker bobbing above, used when the player jumps
## to something from the feed, the neighbors list or the household tabs.
## Drawn over the map but under the panels. It asks a Callable where the
## target is each frame, so it stays on it while the camera glides.
## Presentation only.

const MUSTARD: Color = Color("#E0A526")
const PAPER: Color = Color("#F3E9D2")
const INK: Color = Color("#3B2F2A")
## How long the highlight lasts, in real milliseconds.
const SHOW_MS: int = 2200
const RING_PERIOD_MS: int = 900

## Returns {"point": Vector2 on screen, "lift": float} or {} when off the map.
var _where: Callable
var _since: int = -1


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_at(where: Callable) -> void:
	_where = where
	_since = Time.get_ticks_msec()
	queue_redraw()


func is_showing() -> bool:
	return _since >= 0


func _process(_delta: float) -> void:
	if _since < 0:
		return
	if Time.get_ticks_msec() - _since > SHOW_MS:
		_since = -1
	queue_redraw()


func _draw() -> void:
	if _since < 0 or not _where.is_valid():
		return
	var target: Dictionary = _where.call()
	if target.is_empty():
		return
	var age: int = Time.get_ticks_msec() - _since
	var fade: float = clampf(float(SHOW_MS - age) / 500.0, 0.0, 1.0) * clampf(float(age) / 120.0, 0.0, 1.0)
	var point: Vector2 = target["point"]
	# Two rings spreading out on the ground, flattened like the street.
	for offset: int in [0, RING_PERIOD_MS / 2]:
		var phase: float = float((age + offset) % RING_PERIOD_MS) / float(RING_PERIOD_MS)
		var radius: float = lerpf(8.0, 34.0, phase)
		var alpha: float = (1.0 - phase) * fade
		_ellipse(point, radius, Color(MUSTARD, 0.9 * alpha), 2.5)
	_ellipse(point, 9.0, Color(PAPER, 0.8 * fade), 2.0)
	# A small marker bobbing above.
	var bob: float = sin(float(age) / 1000.0 * TAU * 1.6) * 3.0
	var tip: Vector2 = point - Vector2(0, float(target["lift"]) + 6.0 + bob)
	var marker: PackedVector2Array = PackedVector2Array([tip, tip + Vector2(-8, -11), tip + Vector2(8, -11)])
	draw_colored_polygon(marker, Color(MUSTARD, fade))
	marker.append(tip)
	draw_polyline(marker, Color(INK, 0.7 * fade), 1.5, true)


func _ellipse(centre: Vector2, radius: float, color: Color, width: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in 33:
		var angle: float = TAU * step / 32.0
		points.append(centre + Vector2(cos(angle) * radius, sin(angle) * radius * 0.5))
	draw_polyline(points, color, width, true)
