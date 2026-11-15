extends Control
## Screen-wide touches that sit between the street and the panels: a gentle
## grey-out of the street while the clock is paused, and a ribbon that slides
## across the top of the map when a new day begins.
## Presentation only: it reads nothing from the simulation and keeps no state
## the game depends on.

const SimDate := preload("res://sim/clock/sim_date.gd")
const WorldView := preload("res://view/world_view.gd")

const PAPER: Color = Color("#F3E9D2")
const TEAL: Color = Color("#2F5D62")
const TEAL_DARK: Color = Color("#22474B")
const MUSTARD: Color = Color("#E0A526")
const CHERRY: Color = Color("#B5442F")
const MONTH_NAMES: Array[String] = [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
]
## How long the day ribbon is on screen, and how long it takes to slide in
## and out, in real seconds.
const BANNER_SECONDS: float = 2.6
const BANNER_SLIDE: float = 0.45
const BANNER_SIZE: Vector2 = Vector2(400, 50)
const PAUSE_FADE_SECONDS: float = 0.35

## Reads the screen behind it, takes some colour out and darkens it a touch.
const PAUSE_SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 muted = mix(c, vec3(grey), 0.5 * amount) * (1.0 - 0.10 * amount);
	COLOR = vec4(muted, 1.0);
}
"""

var _pause_rect: ColorRect
var _pause_material: ShaderMaterial
var _pause_amount: float = 0.0
var _paused: bool = false
var _banner_text: String = ""
var _banner_caption: String = ""
## Real seconds since the ribbon appeared; negative when none is showing.
var _banner_age: float = -1.0
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	var shader: Shader = Shader.new()
	shader.code = PAUSE_SHADER
	_pause_material = ShaderMaterial.new()
	_pause_material.shader = shader
	_pause_rect = ColorRect.new()
	_pause_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_rect.material = _pause_material
	_pause_rect.visible = false
	add_child(_pause_rect)
	# The ribbon is drawn on its own child so it sits above the grey-out.
	var ribbon: Control = Control.new()
	ribbon.set_anchors_preset(Control.PRESET_FULL_RECT)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.draw.connect(func() -> void: _draw_banner(ribbon))
	ribbon.name = "Ribbon"
	add_child(ribbon)


func set_paused(paused: bool) -> void:
	_paused = paused


## Starts the ribbon for a new day, e.g. "Tuesday, 4 April 1950".
func show_day(day_index: int, caption: String = "A NEW DAY") -> void:
	var date: Dictionary = SimDate.from_day_index(day_index)
	_banner_text = "%s, %d %s %d" % [SimDate.weekday_name(day_index), date["day"], MONTH_NAMES[int(date["month"]) - 1], date["year"]]
	_banner_caption = caption
	_banner_age = 0.0


func banner_showing() -> bool:
	return _banner_age >= 0.0


func _process(delta: float) -> void:
	var target: float = 1.0 if _paused else 0.0
	if not is_equal_approx(_pause_amount, target):
		_pause_amount = move_toward(_pause_amount, target, delta / PAUSE_FADE_SECONDS)
		_pause_material.set_shader_parameter("amount", _pause_amount)
	_pause_rect.visible = _pause_amount > 0.001
	if _banner_age >= 0.0:
		_banner_age += delta
		if _banner_age > BANNER_SECONDS:
			_banner_age = -1.0
		($Ribbon as Control).queue_redraw()


func _draw_banner(canvas: Control) -> void:
	if _banner_age < 0.0:
		return
	# Slides in from the left with an ease-out, rests, then slides on to the
	# right while fading.
	var slide_in: float = clampf(_banner_age / BANNER_SLIDE, 0.0, 1.0)
	var slide_out: float = clampf((_banner_age - (BANNER_SECONDS - BANNER_SLIDE)) / BANNER_SLIDE, 0.0, 1.0)
	var ease_in: float = 1.0 - pow(1.0 - slide_in, 3.0)
	var ease_out: float = pow(slide_out, 2.0)
	var shift: float = (1.0 - ease_in) * -140.0 + ease_out * 140.0
	var alpha: float = ease_in * (1.0 - slide_out)
	var map: Rect2 = WorldView.MAP_RECT
	var top_left: Vector2 = Vector2(map.get_center().x - BANNER_SIZE.x / 2.0 + shift, map.position.y + 12.0)
	var r: Rect2 = Rect2(top_left, BANNER_SIZE)
	var notch: float = 14.0

	# Soft shadow, then the ribbon's folded tails, then the band itself.
	for spread: int in 3:
		var grow: float = 2.0 + spread * 2.0
		canvas.draw_rect(r.grow(grow).grow_individual(0, -2, 0, 2), Color(0.1, 0.07, 0.05, 0.07 * alpha))
	var tail_drop: float = 8.0
	for side: int in 2:
		var x0: float = r.position.x - 26.0 if side == 0 else r.end.x - 10.0
		var x1: float = x0 + 36.0
		var outer: float = x0 if side == 0 else x1
		var tail: PackedVector2Array = PackedVector2Array([
			Vector2(x0, r.position.y + tail_drop), Vector2(x1, r.position.y + tail_drop),
			Vector2(x1, r.end.y + tail_drop), Vector2(x0, r.end.y + tail_drop),
			Vector2(outer + (notch if side == 0 else -notch), r.get_center().y + tail_drop),
		])
		if side == 1:
			tail = PackedVector2Array([tail[0], tail[1], tail[4], tail[2], tail[3]])
		canvas.draw_colored_polygon(tail, Color(MUSTARD.darkened(0.3), alpha))
	canvas.draw_rect(r, Color(MUSTARD, alpha))
	canvas.draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(MUSTARD.lightened(0.3), alpha))
	canvas.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 3)), Color(MUSTARD.darkened(0.2), alpha))
	canvas.draw_rect(r.grow(-4), Color(TEAL_DARK, 0.5 * alpha), false, 1.0)

	var caption_size: int = 10
	var text_size: int = 21
	var caption_width: float = _font.get_string_size(_banner_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x
	canvas.draw_string(_font, Vector2(r.get_center().x - caption_width / 2.0, r.position.y + 15),
			_banner_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size, Color(CHERRY.darkened(0.1), alpha))
	var width: float = _font.get_string_size(_banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	var at: Vector2 = Vector2(r.get_center().x - width / 2.0, r.position.y + 39)
	canvas.draw_string(_font, at + Vector2(0, 1), _banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(PAPER, 0.6 * alpha))
	canvas.draw_string(_font, at, _banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(TEAL_DARK, alpha))
