extends Control
## The title screen: a dusk view of a row of houses painted in code, the
## working title, and the way into the game.
## Presentation only. The street in the backdrop is invented decoration, not a
## picture of any real place, and nothing here touches the simulation.

signal new_game_requested
signal continue_requested
signal settings_requested
signal quit_requested

const Hud := preload("res://view/hud.gd")

const VIEW_SIZE: Vector2 = Vector2(1280, 720)
const PAPER: Color = Color("#F3E9D2")
const PAPER_DARK: Color = Color("#E4D3AE")
const TEAL: Color = Color("#2F5D62")
const TEAL_DARK: Color = Color("#22474B")
const MUSTARD: Color = Color("#E0A526")
const CHERRY: Color = Color("#B5442F")
const INK: Color = Color("#3B2F2A")

## The sky from the top down to the horizon.
const SKY: Array[Color] = [Color("#141F38"), Color("#24395A"), Color("#4A5B7E"), Color("#9A7A8E"), Color("#E3A27A"), Color("#F2C48A")]
const SKY_STOPS: Array[float] = [0.0, 0.22, 0.42, 0.62, 0.80, 0.90]
const HORIZON_Y: float = 560.0
const GROUND_Y: float = 590.0
const SIDING: Array[Color] = [Color("#7E8AA6"), Color("#9C8C9A"), Color("#6F8C93"), Color("#A49A8C"), Color("#8693A0"), Color("#9A8473")]
const ROOFS: Array[Color] = [Color("#3B3550"), Color("#4A3A44"), Color("#323E4C"), Color("#463B38")]
const LIT: Color = Color(1.0, 0.82, 0.48)
const STAR_COUNT: int = 70
const FIREFLY_COUNT: int = 14
const BUILD_LINE: String = "M1-P preview build"
const INTRO_TITLE_SECONDS: float = 1.5
const INTRO_PART_SECONDS: float = 0.7
## How far each layer moves with the slow sway, as a share of the houses'
## movement: distant things less, near things more.
const FAR_PARALLAX: float = 0.35
const CLOUD_PARALLAX: float = 0.2
## Each house: x of its left wall, width, wall height, and whether it has two
## storeys (presentation only; the shapes are invented).
const HOUSES: Array[Vector4] = [
	Vector4(445, 140, 110, 1), Vector4(625, 118, 90, 0), Vector4(785, 165, 128, 1),
	Vector4(995, 128, 98, 0), Vector4(1160, 160, 122, 1),
]

var _time: float = 0.0
var _stars: Array[Vector4] = []      # x, y, size, phase
var _fireflies: Array[Vector4] = []  # x, y, phase, speed
var _continue_button: Button
var _continue_note: Label
var _message: Label
var _column: VBoxContainer
var _buttons: Array[Button] = []
var _intro: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = _title_theme()
	# Decoration is placed by its own generator, never the simulation's.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1950
	for i: int in STAR_COUNT:
		_stars.append(Vector4(rng.randf_range(0, VIEW_SIZE.x), rng.randf_range(0, HORIZON_Y * 0.55), rng.randf_range(0.6, 1.8), rng.randf_range(0, TAU)))
	for i: int in FIREFLY_COUNT:
		_fireflies.append(Vector4(rng.randf_range(300, VIEW_SIZE.x), rng.randf_range(GROUND_Y - 36, GROUND_Y + 12), rng.randf_range(0, TAU), rng.randf_range(0.3, 0.8)))
	_build_ui()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Enables Continue when there is a saved game; detail says when it is from.
func set_can_continue(can: bool, detail: String) -> void:
	_continue_button.disabled = not can
	_continue_note.text = detail
	_continue_note.visible = detail != ""


## A line under the buttons, for example when a saved game cannot be read.
func show_note(text: String) -> void:
	_message.text = text
	_message.visible = text != ""


## Fades the title in gently, then the buttons one after another.
func play_intro() -> void:
	if _intro != null:
		_intro.kill()
	_intro = create_tween().set_parallel(true)
	var parts: Array[Control] = []
	for child: Node in _column.get_children():
		parts.append(child as Control)
	for index: int in parts.size():
		var part: Control = parts[index]
		part.modulate.a = 0.0
		# The title words (the first four parts) come up slowly; the rest follow.
		var seconds: float = INTRO_TITLE_SECONDS if index < 4 else INTRO_PART_SECONDS
		_intro.tween_property(part, "modulate:a", 1.0, seconds).set_delay(0.2 + index * 0.09) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func button_count() -> int:
	return _buttons.size()


# --- Layout ------------------------------------------------------------------

func _title_theme() -> Theme:
	var t: Theme = Hud.make_theme()
	var styles: Dictionary = {
		"normal": [Color(PAPER, 0.93), Color(PAPER_DARK.darkened(0.3), 0.9), 0],
		"hover": [PAPER.lightened(0.4), MUSTARD, 0],
		"pressed": [MUSTARD, MUSTARD.darkened(0.35), 1],
		"hover_pressed": [MUSTARD.lightened(0.1), MUSTARD.darkened(0.35), 1],
		"disabled": [Color(PAPER, 0.35), Color(PAPER, 0.2), 0],
	}
	t.set_type_variation("TitleButton", "Button")
	for state: String in styles:
		var spec: Array = styles[state]
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = spec[0]
		box.border_color = spec[1]
		box.set_border_width_all(2)
		box.border_width_bottom = 2 if int(spec[2]) == 1 else 4
		box.set_corner_radius_all(10)
		box.content_margin_left = 22
		box.content_margin_right = 22
		box.content_margin_top = 8 + int(spec[2])
		box.content_margin_bottom = 8 - int(spec[2])
		if state != "disabled":
			box.shadow_color = Color(0.05, 0.04, 0.08, 0.35)
			box.shadow_size = 6 if state.begins_with("hover") else 4
			box.shadow_offset = Vector2(0, 2)
		t.set_stylebox(state, "TitleButton", box)
	t.set_stylebox("focus", "TitleButton", StyleBoxEmpty.new())
	t.set_font_size("font_size", "TitleButton", 20)
	t.set_color("font_disabled_color", "TitleButton", Color(PAPER, 0.5))
	return t


func _build_ui() -> void:
	_column = VBoxContainer.new()
	_column.position = Vector2(92, 92)
	_column.custom_minimum_size = Vector2(440, 0)
	_column.add_theme_constant_override("separation", 0)
	add_child(_column)

	var kicker: Label = Label.new()
	kicker.text = "WORKING TITLE"
	kicker.add_theme_font_size_override("font_size", 12)
	kicker.add_theme_color_override("font_color", Color(MUSTARD, 0.9))
	kicker.add_theme_constant_override("outline_size", 0)
	_column.add_child(kicker)

	var title: Label = Label.new()
	title.text = "The Neighborhood"
	var bold: FontVariation = FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.9
	bold.spacing_glyph = 1
	title.add_theme_font_override("font", bold)
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_color_override("font_color", PAPER)
	title.add_theme_color_override("font_shadow_color", Color(0.05, 0.04, 0.10, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.add_theme_constant_override("shadow_outline_size", 8)
	_column.add_child(title)

	var rule: ColorRect = ColorRect.new()
	rule.color = MUSTARD
	rule.custom_minimum_size = Vector2(120, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_column.add_child(_spaced(rule, 6, 12))

	var subtitle: Label = Label.new()
	subtitle.text = "A week on Fixture Street, spring 1950"
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color("#F6D9A8"))
	subtitle.add_theme_color_override("font_shadow_color", Color(0.05, 0.04, 0.10, 0.5))
	subtitle.add_theme_constant_override("shadow_offset_x", 1)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	_column.add_child(subtitle)
	_column.add_child(_gap(42))

	var new_game: Button = _menu_button("New game", func() -> void: new_game_requested.emit())
	new_game.tooltip_text = "Start a fresh week with the household"
	_column.add_child(new_game)
	_column.add_child(_gap(12))
	_continue_button = _menu_button("Continue", func() -> void: continue_requested.emit())
	_continue_button.tooltip_text = "Carry on from the saved game"
	_column.add_child(_continue_button)
	_continue_note = Label.new()
	_continue_note.add_theme_font_size_override("font_size", 12)
	_continue_note.add_theme_color_override("font_color", Color(PAPER, 0.75))
	_continue_note.visible = false
	_column.add_child(_spaced(_continue_note, 3, 0))
	_column.add_child(_gap(12))
	_column.add_child(_menu_button("Settings", func() -> void: settings_requested.emit()))
	_column.add_child(_gap(12))
	_column.add_child(_menu_button("Quit", func() -> void: quit_requested.emit()))
	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 13)
	_message.add_theme_color_override("font_color", Color("#FFD9A0"))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD
	_message.custom_minimum_size = Vector2(300, 0)
	_message.visible = false
	_column.add_child(_spaced(_message, 10, 0))

	# Required on screen by the project rules (D-035): this street is made up.
	var note: PanelContainer = PanelContainer.new()
	note.theme_type_variation = "Badge"
	note.position = Vector2(92, 664)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(note)
	var note_text: Label = Label.new()
	note_text.text = "Fixture Street is a made-up test street, not a real place."
	note_text.add_theme_font_size_override("font_size", 13)
	note_text.add_theme_color_override("font_color", PAPER)
	note.add_child(note_text)

	var build: Label = Label.new()
	build.text = "%s  ·  F11 full screen" % BUILD_LINE
	build.add_theme_font_size_override("font_size", 12)
	build.add_theme_color_override("font_color", Color(PAPER, 0.7))
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Placed in the fixed 1280x720 layout, like everything else on this screen.
	build.position = Vector2(VIEW_SIZE.x - 364, VIEW_SIZE.y - 46)
	build.size = Vector2(340, 20)
	add_child(build)


func _menu_button(text: String, on_press: Callable) -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = "TitleButton"
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(270, 50)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_press)
	_buttons.append(button)
	return button


func _gap(height: int) -> Control:
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	return gap


func _spaced(child: Control, above: int, below: int) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", above)
	margin.add_theme_constant_override("margin_bottom", below)
	margin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(child)
	return margin


# --- The painted backdrop ----------------------------------------------------

func _draw() -> void:
	_draw_sky()
	_draw_stars()
	_draw_moon(Vector2(1060, 118))
	# A very slow sway of the whole street, like a camera breathing. Nearer
	# layers move further than distant ones.
	var drift: float = sin(_time * 0.07) * 10.0 + sin(_time * 0.031 + 1.3) * 4.0
	_draw_clouds(drift * CLOUD_PARALLAX)
	_draw_far_trees(drift * FAR_PARALLAX)
	_draw_ground(drift)
	for index: int in HOUSES.size():
		_draw_house(HOUSES[index], index, drift)
	_draw_front_trees(drift)
	_draw_fence(drift)
	_draw_lamp(Vector2(905 + drift * 1.2, GROUND_Y + 34), 0)
	_draw_lamp(Vector2(1240 + drift * 1.2, GROUND_Y + 34), 1)
	_draw_fireflies(drift)
	_draw_vignette()


func _gradient(top: float, bottom: float, from: Color, to: Color, left: float = 0.0, right: float = VIEW_SIZE.x) -> void:
	draw_polygon(
		PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right, bottom), Vector2(left, bottom)]),
		PackedColorArray([from, from, to, to]))


func _draw_sky() -> void:
	for index: int in SKY.size() - 1:
		_gradient(SKY_STOPS[index] * HORIZON_Y / 0.9, SKY_STOPS[index + 1] * HORIZON_Y / 0.9, SKY[index], SKY[index + 1])
	# A warm glow low in the west where the sun has gone down.
	for ring: int in 6:
		var radius: Vector2 = Vector2(520 - ring * 60, 120 - ring * 14)
		draw_colored_polygon(_ellipse(Vector2(980, HORIZON_Y + 10), radius), Color(1.0, 0.72, 0.45, 0.05))


func _draw_stars() -> void:
	for star: Vector4 in _stars:
		var depth: float = clampf(1.0 - star.y / (HORIZON_Y * 0.55), 0.0, 1.0)
		# A slow twinkle, each star at its own pace (a cycle of 8 to 20 seconds).
		var twinkle: float = 0.6 + 0.4 * sin(_time * (0.3 + star.z * 0.25) + star.w)
		var color: Color = Color(1.0, 0.97, 0.88, twinkle * (0.25 + 0.75 * depth))
		draw_circle(Vector2(star.x, star.y), star.z * 0.8, color)
		if star.z > 1.5:
			draw_circle(Vector2(star.x, star.y), star.z * 2.4, Color(color, color.a * 0.15))


func _draw_moon(at: Vector2) -> void:
	for ring: int in 5:
		draw_circle(at, 22.0 + ring * 11.0, Color(1.0, 0.95, 0.80, 0.045))
	draw_circle(at, 21.0, Color("#F7EBCB"))
	# Soft grey patches, and a faint shade on the side away from the sunset.
	draw_circle(at + Vector2(-6, -5), 5.0, Color("#E3D6B6"))
	draw_circle(at + Vector2(5, 6), 7.0, Color("#E6DABB"))
	draw_circle(at + Vector2(8, -8), 3.0, Color("#E3D6B6"))
	draw_arc(at, 19.0, PI * 0.6, PI * 1.4, 16, Color(0.6, 0.6, 0.75, 0.25), 4.0)


func _draw_clouds(shift: float) -> void:
	for index: int in 4:
		var width: float = VIEW_SIZE.x + 400.0
		var x: float = fposmod(index * 377.0 + _time * (5.0 + index * 1.5) + shift * (1.0 + index * 0.5), width) - 200.0
		var y: float = 300.0 + index * 46.0
		var tint: Color = Color(0.98, 0.70, 0.62, 0.10 + 0.03 * index)
		for blob: int in 4:
			draw_colored_polygon(_ellipse(Vector2(x + blob * 46.0, y + sin(blob * 1.7) * 5.0), Vector2(70.0 - blob * 6.0, 9.0 + (blob % 2) * 3.0)), tint)


func _draw_far_trees(shift: float) -> void:
	var points: PackedVector2Array = PackedVector2Array([Vector2(0, HORIZON_Y + 40)])
	for step: int in 65:
		var x: float = step * 20.0
		# The skyline is read a little to one side as the view sways.
		var along: float = x - shift
		var bump: float = 16.0 * sin(along * 0.021) + 11.0 * sin(along * 0.053 + 1.0) + 7.0 * sin(along * 0.11)
		points.append(Vector2(x, HORIZON_Y - 22.0 - bump))
	points.append(Vector2(VIEW_SIZE.x, HORIZON_Y + 40))
	draw_colored_polygon(points, Color("#2E3A52"))


func _draw_ground(drift: float) -> void:
	_gradient(HORIZON_Y - 4, GROUND_Y + 30, Color("#36465A"), Color("#2C3B44"))
	# Sidewalk, curb, and the street in front.
	_gradient(GROUND_Y + 28, GROUND_Y + 50, Color("#6F6E78"), Color("#5E5D68"))
	draw_rect(Rect2(0, GROUND_Y + 50, VIEW_SIZE.x, 5), Color("#8A8790"))
	_gradient(GROUND_Y + 55, VIEW_SIZE.y, Color("#2A2B35"), Color("#1D1E27"))
	for dash: int in 14:
		var x: float = fposmod(dash * 110.0 + drift * 1.4, VIEW_SIZE.x + 110.0) - 60.0
		draw_rect(Rect2(x, GROUND_Y + 96, 56, 3), Color(0.85, 0.80, 0.60, 0.25))


func _draw_house(house: Vector4, index: int, drift: float) -> void:
	var left: float = house.x + drift
	var width: float = house.y
	var height: float = house.z
	var base: float = GROUND_Y + 8.0
	var top: float = base - height
	var siding: Color = SIDING[index % SIDING.size()]
	var roof: Color = ROOFS[index % ROOFS.size()]
	var peak: Vector2 = Vector2(left + width / 2.0, top - width * 0.42)
	# Chimney behind the roof.
	var chimney_x: float = left + width * (0.68 if index % 2 == 0 else 0.24)
	draw_rect(Rect2(chimney_x, peak.y + 14, 13, top - peak.y), Color("#5C3D3A").darkened(0.2))
	# Walls with a soft darker band at the foot.
	_gradient(top, base, siding, siding.darkened(0.25), left, left + width)
	for clap: int in int(height / 9.0):
		draw_line(Vector2(left, top + clap * 9.0 + 8), Vector2(left + width, top + clap * 9.0 + 8), Color(siding.darkened(0.15), 0.35), 1.0)
	# Roof with overhang and a highlight along the left slope.
	draw_colored_polygon(PackedVector2Array([Vector2(left - 10, top + 2), peak + Vector2(0, -3), Vector2(left + width + 10, top + 2)]), roof)
	draw_line(Vector2(left - 10, top + 2), peak + Vector2(0, -3), roof.lightened(0.25), 2.0)
	# Windows: some lit, changing slowly as the evening goes on.
	var rows: int = 2 if house.w > 0.5 else 1
	for row: int in rows:
		var y: float = top + 16.0 + row * 48.0
		for column: int in 2:
			var x: float = left + width * (0.18 if column == 0 else 0.62)
			var key: int = index * 7 + row * 3 + column
			_draw_window(Rect2(x, y, width * 0.2, 26), _window_light(key))
	# Gable window.
	_draw_window(Rect2(peak.x - 8, peak.y + width * 0.2, 16, 14), 1.0 if index % 3 == 0 else 0.0)
	# Door and step.
	var door: Rect2 = Rect2(left + width * 0.44, base - 34, width * 0.13, 34)
	draw_rect(door, Color("#3F2F33"))
	draw_rect(Rect2(door.position.x - 4, base - 2, door.size.x + 8, 4), Color("#5A5560"))
	if index % 2 == 1:
		# A porch light by the door.
		var bulb: Vector2 = Vector2(door.end.x + 6, door.position.y + 6)
		for ring: int in 4:
			draw_circle(bulb, 4.0 + ring * 5.0, Color(LIT, 0.08))
		draw_circle(bulb, 2.5, LIT)


## How brightly a window is lit, from 0 (dark) to 1. Each window keeps its own
## slow rhythm (a cycle of one and a half to four minutes, lit for most of it),
## so now and then one switches on or off; the change takes about a second.
func _window_light(key: int) -> float:
	var period: float = 90.0 + float((key * 37) % 150)
	var wave: float = sin(_time * TAU / period + key * 1.9)
	return smoothstep(-0.37, -0.33, wave)


func _draw_window(r: Rect2, light: float) -> void:
	_gradient(r.position.y, r.end.y, Color("#3E4C63"), Color("#2C3648"), r.position.x, r.end.x)
	if light > 0.0:
		for ring: int in 3:
			draw_rect(r.grow(3.0 + ring * 3.0), Color(LIT, 0.05 * light))
		_gradient(r.position.y, r.end.y, Color(LIT.lightened(0.1), light), Color(0.98, 0.66, 0.35, light), r.position.x, r.end.x)
	draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color(0.15, 0.13, 0.18, 0.7), 1.5)
	draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color(0.15, 0.13, 0.18, 0.7), 1.5)
	draw_rect(r, Color("#D9D2C6"), false, 2.0)


func _draw_front_trees(drift: float) -> void:
	var spots: Array[Vector3] = [Vector3(400, 74, 4), Vector3(598, 88, 0), Vector3(760, 66, 1), Vector3(965, 84, 2), Vector3(1135, 62, 3)]
	for spot: Vector3 in spots:
		var x: float = spot.x + drift * 1.1
		var base: float = GROUND_Y + 22.0
		var size: float = spot.y
		var sway: float = sin(_time * 0.6 + spot.z) * 2.0
		draw_rect(Rect2(x - 4, base - size * 0.9, 8, size * 0.9), Color("#2B2228"))
		var crown: Vector2 = Vector2(x + sway, base - size * 1.05)
		var dark: Color = Color("#22362F")
		var mid: Color = Color("#2E4A3C")
		draw_circle(crown + Vector2(-size * 0.28, size * 0.12), size * 0.38, dark)
		draw_circle(crown + Vector2(size * 0.28, size * 0.14), size * 0.36, dark)
		draw_circle(crown, size * 0.45, mid)
		draw_circle(crown + Vector2(-size * 0.12, -size * 0.12), size * 0.26, mid.lightened(0.08))
		# Warm rim light from the sunset side.
		draw_arc(crown, size * 0.45, -0.6, 0.5, 12, Color(1.0, 0.7, 0.45, 0.18), 3.0)


func _draw_fence(drift: float) -> void:
	var y: float = GROUND_Y + 26.0
	var x: float = fposmod(drift * 1.2, 14.0) - 14.0
	while x < VIEW_SIZE.x:
		if fposmod(x - drift * 1.2, 280.0) > 40.0:
			draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x, y - 16), Vector2(x + 3, y - 20), Vector2(x + 6, y - 16), Vector2(x + 6, y)]), Color("#C9C3C6", 0.85))
		x += 14.0
	draw_rect(Rect2(0, y - 12, VIEW_SIZE.x, 2), Color("#C9C3C6", 0.6))


func _draw_lamp(foot: Vector2, index: int) -> void:
	var head: Vector2 = foot + Vector2(0, -122)
	var flicker: float = 0.92 + 0.08 * sin(_time * 7.0 + index * 2.0) * sin(_time * 3.1)
	# Pool of light on the sidewalk.
	for ring: int in 5:
		draw_colored_polygon(_ellipse(foot + Vector2(0, 6), Vector2(120 - ring * 20, 18 - ring * 3)), Color(LIT, 0.05 * flicker))
	draw_rect(Rect2(foot.x - 2.5, head.y + 10, 5, foot.y - head.y - 10), Color("#1F1E26"))
	draw_rect(Rect2(foot.x - 6, foot.y - 6, 12, 6), Color("#1F1E26"))
	for ring: int in 7:
		draw_circle(head + Vector2(0, 6), 10.0 + ring * 9.0, Color(LIT, 0.045 * flicker))
	draw_colored_polygon(PackedVector2Array([head + Vector2(-9, 0), head + Vector2(9, 0), head + Vector2(6, 14), head + Vector2(-6, 14)]), Color(LIT.lightened(0.2), flicker))
	draw_colored_polygon(PackedVector2Array([head + Vector2(-12, 1), head + Vector2(0, -8), head + Vector2(12, 1)]), Color("#1F1E26"))
	draw_rect(Rect2(head.x - 7, head.y + 14, 14, 3), Color("#1F1E26"))


func _draw_fireflies(drift: float) -> void:
	for fly: Vector4 in _fireflies:
		var at: Vector2 = Vector2(fly.x + sin(_time * fly.w + fly.z) * 26.0 + drift, fly.y + cos(_time * fly.w * 1.3 + fly.z) * 12.0)
		var glow: float = maxf(0.0, sin(_time * 1.4 + fly.z * 3.0))
		if glow > 0.05:
			draw_circle(at, 6.0, Color(1.0, 0.9, 0.45, 0.10 * glow))
			draw_circle(at, 1.6, Color(1.0, 0.95, 0.6, 0.9 * glow))


## Darkens the left side, where the title and buttons sit, and the edges.
func _draw_vignette() -> void:
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(720, 0), Vector2(720, VIEW_SIZE.y), Vector2(0, VIEW_SIZE.y)]),
		PackedColorArray([Color(0.04, 0.05, 0.10, 0.62), Color(0.04, 0.05, 0.10, 0.0), Color(0.04, 0.05, 0.10, 0.0), Color(0.04, 0.05, 0.10, 0.62)]))
	_gradient(0, 120, Color(0.03, 0.04, 0.09, 0.35), Color(0.03, 0.04, 0.09, 0.0))
	_gradient(VIEW_SIZE.y - 90, VIEW_SIZE.y, Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.35))


func _ellipse(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in 28:
		var angle: float = step * TAU / 28.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
