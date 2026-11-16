extends RefCounted
## Small pictures for the interface, drawn in code (D-058): portraits,
## mood faces, need icons and event icons. Presentation only. Colours for
## people come from world_view's lists with the same deterministic choice,
## so a portrait matches the figure on the street.

const WorldView := preload("res://view/world_view.gd")

const PAPER: Color = Color("#F3E9D2")
const PAPER_DARK: Color = Color("#E4D3AE")
const TEAL: Color = Color("#2F5D62")
const TEAL_DARK: Color = Color("#22474B")
const MUSTARD: Color = Color("#E0A526")
const CHERRY: Color = Color("#B5442F")
const INK: Color = Color("#3B2F2A")
const INK_SOFT: Color = Color("#7A6658")
const LEAF: Color = Color("#5E8C4A")
const BLUSH: Color = Color(0.90, 0.48, 0.42, 0.45)


## The same choice world_view makes for a figure.
static func pick(colors: Array[Color], key: String) -> Color:
	return colors[absi(key.hash()) % colors.size()]


static func clothes_of(person_id: String, players: bool) -> Color:
	return pick(WorldView.PLAYER_CLOTHES, person_id) if players else pick(WorldView.CLOTHES, person_id)


static func hair_of(person_id: String) -> Color:
	return pick(WorldView.HAIR, person_id + "hair")


## Head and shoulders in rect: clothes and hair as on the street, the face
## showing face_kind ("happy", "fine", "low", "asleep"). Children are drawn
## smaller and rounder.
static func portrait(c: CanvasItem, rect: Rect2, person_id: String, players: bool, child: bool, face_kind: String) -> void:
	var middle: float = rect.position.x + rect.size.x / 2.0
	var backdrop: Vector2 = rect.get_center()
	c.draw_circle(backdrop, minf(rect.size.x, rect.size.y) / 2.0, PAPER_DARK)
	c.draw_arc(backdrop, minf(rect.size.x, rect.size.y) / 2.0 - 0.5, 0.0, TAU, 40, Color(TEAL, 0.35), 1.5, true)
	var k: float = rect.size.y / 64.0 * (0.82 if child else 1.0)
	var bottom: float = rect.end.y - 4.0
	var body: Color = clothes_of(person_id, players)
	var shoulder_w: float = (17.0 if child else 21.0) * k
	var shoulder_y: float = bottom - (14.0 if child else 17.0) * k
	# Shoulders: a rounded block in the figure's clothes.
	var torso: PackedVector2Array = PackedVector2Array()
	torso.append(Vector2(middle - shoulder_w - 2.0 * k, bottom))
	for step: int in 11:
		var angle: float = PI + PI * float(step) / 10.0
		torso.append(Vector2(middle + cos(angle) * shoulder_w, shoulder_y + 6.0 * k + sin(angle) * 6.0 * k))
	torso.append(Vector2(middle + shoulder_w + 2.0 * k, bottom))
	c.draw_colored_polygon(torso, body)
	c.draw_polyline(torso, body.darkened(0.4), 1.0, true)
	# Collar.
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(middle - 5.0 * k, shoulder_y + 0.5), Vector2(middle, shoulder_y + 6.0 * k), Vector2(middle + 5.0 * k, shoulder_y + 0.5),
	]), PAPER)
	# Neck and head.
	var head_r: float = (12.5 if child else 11.0) * k
	var head: Vector2 = Vector2(middle, shoulder_y - head_r + 1.0 * k)
	c.draw_rect(Rect2(middle - 3.5 * k, shoulder_y - 4.0 * k, 7.0 * k, 6.0 * k), WorldView.COLOR_SKIN.darkened(0.08))
	c.draw_circle(head, head_r, WorldView.COLOR_SKIN)
	c.draw_arc(head, head_r, 0.0, TAU, 32, WorldView.COLOR_SKIN.darkened(0.4), 1.0, true)
	# Hair: a cap over the top of the head, as the figure's arc.
	var hair: Color = hair_of(person_id)
	var cap: PackedVector2Array = PackedVector2Array()
	for step: int in 17:
		var angle: float = PI * 1.02 + PI * 0.96 * float(step) / 16.0
		cap.append(head + Vector2(cos(angle), sin(angle)) * (head_r + 1.0))
	for step: int in 17:
		var angle: float = PI * 1.98 - PI * 0.96 * float(step) / 16.0
		var dip: float = 0.45 + 0.12 * sin(float(step) * 1.7)
		cap.append(head + Vector2(cos(angle) * head_r, sin(angle) * head_r * dip))
	c.draw_colored_polygon(cap, hair)
	face(c, head + Vector2(0, 2.0 * k), head_r * 0.62, face_kind, false)


## Eyes and mouth inside a head of the given radius. With badge true, a
## round face of its own is drawn first (for small mood chips).
static func face(c: CanvasItem, center: Vector2, r: float, kind: String, badge: bool) -> void:
	if badge:
		var fill: Color = MUSTARD if kind == "happy" else (PAPER_DARK if kind != "low" else Color("#F0B9A8"))
		c.draw_circle(center, r, fill)
		c.draw_arc(center, r, 0.0, TAU, 24, INK, 1.0, true)
	var eye_dx: float = r * 0.42
	var eye_y: float = center.y - r * 0.2
	var line: float = maxf(1.0, r * 0.14)
	if kind == "asleep":
		for side: float in [-1.0, 1.0]:
			c.draw_arc(Vector2(center.x + side * eye_dx, eye_y), r * 0.18, 0.15, PI - 0.15, 6, INK, line, true)
	else:
		for side: float in [-1.0, 1.0]:
			c.draw_circle(Vector2(center.x + side * eye_dx, eye_y), maxf(0.9, r * 0.11), INK)
	var mouth: Vector2 = Vector2(center.x, center.y + r * 0.38)
	match kind:
		"happy":
			c.draw_arc(mouth - Vector2(0, r * 0.18), r * 0.36, 0.25, PI - 0.25, 10, INK, line, true)
			if not badge:
				for side: float in [-1.0, 1.0]:
					c.draw_circle(Vector2(center.x + side * r * 0.72, center.y + r * 0.18), r * 0.16, BLUSH)
		"fine":
			c.draw_arc(mouth - Vector2(0, r * 0.32), r * 0.4, 0.6, PI - 0.6, 8, INK, line, true)
		"low":
			c.draw_arc(mouth + Vector2(0, r * 0.22), r * 0.3, PI + 0.4, TAU - 0.4, 8, INK, line, true)
		"asleep":
			c.draw_circle(mouth, r * 0.1, INK)


## A small icon for a need, centred on center, about 14 pixels across.
static func need_icon(c: CanvasItem, center: Vector2, need: String, color: Color, background: Color) -> void:
	match need:
		"hunger":
			# A plate with a fork beside it.
			c.draw_circle(center + Vector2(2, 0), 5.0, color)
			c.draw_circle(center + Vector2(2, 0), 3.0, background)
			c.draw_line(center + Vector2(-5, -5), center + Vector2(-5, 6), color, 1.4)
			for dx: float in [-6.2, -5.0, -3.8]:
				c.draw_line(center + Vector2(dx, -6), center + Vector2(dx, -3), color, 0.9)
			c.draw_line(center + Vector2(-6.2, -3), center + Vector2(-3.8, -3), color, 1.0)
		"rest":
			c.draw_circle(center, 5.5, color)
			c.draw_circle(center + Vector2(3.0, -2.2), 4.6, background)
			c.draw_circle(center + Vector2(4.5, 3.5), 0.9, color)
		"company":
			c.draw_circle(center + Vector2(-3, -2), 2.4, color)
			c.draw_circle(center + Vector2(3.2, -2.6), 2.4, color)
			c.draw_arc(center + Vector2(-3, 5), 4.2, PI, TAU, 8, color, 2.2)
			c.draw_arc(center + Vector2(3.2, 4.4), 4.2, PI, TAU, 8, color, 2.2)
		"fun":
			c.draw_colored_polygon(star(center, 6.2, 2.6), color)


static func star(center: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in 10:
		var angle: float = -PI / 2.0 + PI * float(index) / 5.0
		var r: float = outer if index % 2 == 0 else inner
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points


## The badge colour behind each kind of event icon.
static func event_color(kind: String) -> Color:
	match kind:
		"talk", "meet":
			return TEAL
		"cake":
			return Color("#C75C7A")
		"coin", "basket":
			return LEAF
		"rent":
			return MUSTARD.darkened(0.15)
		"plate", "clock", "short", "closed", "away":
			return CHERRY
	return INK_SOFT


## A round badge with a little picture for an event kind (from
## Describe.event_icon), r about 8.
static func event_icon(c: CanvasItem, center: Vector2, kind: String, r: float = 8.0) -> void:
	var badge: Color = event_color(kind)
	c.draw_circle(center, r, badge)
	c.draw_arc(center, r, 0.0, TAU, 24, badge.darkened(0.3), 1.0, true)
	var g: Color = PAPER
	var s: float = r / 8.0
	match kind:
		"talk", "meet":
			var bubble: Rect2 = Rect2(center + Vector2(-4.6, -4.0) * s, Vector2(9.2, 6.4) * s)
			c.draw_rect(bubble, g)
			c.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-2.6, 2.3) * s, center + Vector2(-3.4, 5.2) * s, center + Vector2(0.2, 2.3) * s,
			]), g)
			if kind == "meet":
				c.draw_colored_polygon(star(center + Vector2(0, -0.8) * s, 2.6 * s, 1.1 * s), MUSTARD)
			else:
				for dx: float in [-2.4, 0.0, 2.4]:
					c.draw_circle(center + Vector2(dx, -0.8) * s, 0.8 * s, badge)
		"cake":
			c.draw_rect(Rect2(center + Vector2(-5, 0) * s, Vector2(10, 4.5) * s), g)
			c.draw_rect(Rect2(center + Vector2(-4, -2.5) * s, Vector2(8, 2.5) * s), Color(g, 0.8))
			c.draw_line(center + Vector2(0, -2.5) * s, center + Vector2(0, -5) * s, g, 1.2)
			c.draw_circle(center + Vector2(0, -6) * s, 1.1 * s, MUSTARD)
		"coin", "short":
			c.draw_circle(center, 5.2 * s, MUSTARD)
			c.draw_arc(center, 5.2 * s, 0.0, TAU, 16, MUSTARD.darkened(0.35), 1.0, true)
			c.draw_line(center + Vector2(0, -3.6) * s, center + Vector2(0, 3.6) * s, INK, 1.0)
			c.draw_arc(center + Vector2(0, -1.1) * s, 1.5 * s, PI * 0.5, PI * 1.9, 6, INK, 1.1)
			c.draw_arc(center + Vector2(0, 1.1) * s, 1.5 * s, -PI * 0.5, PI * 0.9, 6, INK, 1.1)
			if kind == "short":
				c.draw_line(center + Vector2(-5, 5) * s, center + Vector2(5, -5) * s, g, 1.6)
		"rent":
			c.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-5, -0.5) * s, center + Vector2(0, -5) * s, center + Vector2(5, -0.5) * s,
			]), g)
			c.draw_rect(Rect2(center + Vector2(-3.6, -0.5) * s, Vector2(7.2, 5) * s), g)
			c.draw_rect(Rect2(center + Vector2(-0.9, 1.5) * s, Vector2(1.8, 3) * s), badge)
		"basket":
			c.draw_arc(center + Vector2(0, -0.5) * s, 3.4 * s, PI, TAU, 8, g, 1.3)
			c.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-5, -0.5) * s, center + Vector2(5, -0.5) * s,
				center + Vector2(3.6, 4.6) * s, center + Vector2(-3.6, 4.6) * s,
			]), g)
			c.draw_line(center + Vector2(-4, 1.8) * s, center + Vector2(4, 1.8) * s, badge, 1.0)
		"plate":
			c.draw_arc(center, 5.0 * s, 0.0, TAU, 16, g, 1.4, true)
			c.draw_arc(center, 2.8 * s, 0.0, TAU, 12, Color(g, 0.7), 1.0, true)
		"clock":
			c.draw_circle(center, 5.4 * s, g)
			c.draw_line(center, center + Vector2(0, -3.8) * s, INK, 1.2)
			c.draw_line(center, center + Vector2(2.8, 0.8) * s, INK, 1.2)
		"closed":
			c.draw_rect(Rect2(center + Vector2(-5, -2.5) * s, Vector2(10, 5) * s), g)
			c.draw_line(center + Vector2(-3, 0) * s, center + Vector2(3, 0) * s, badge, 1.4)
		"away":
			c.draw_arc(center + Vector2(0, -1.5) * s, 2.4 * s, PI * 1.0, PI * 2.3, 8, g, 1.5)
			c.draw_circle(center + Vector2(0, 3.6) * s, 0.9 * s, g)
		_:
			c.draw_circle(center, 2.0 * s, g)


## A checkbox for a goal's status, in box.
static func goal_box(c: CanvasItem, box: Rect2, status: String) -> void:
	match status:
		"done":
			c.draw_rect(box, MUSTARD)
			c.draw_rect(box, MUSTARD.darkened(0.35), false, 1.0)
			c.draw_polyline(PackedVector2Array([
				box.position + Vector2(2, 5), box.position + Vector2(4.5, 7.5), box.position + Vector2(8.5, 2),
			]), TEAL_DARK, 2.0)
		"missed":
			c.draw_rect(box, CHERRY, false, 1.0)
			c.draw_line(box.position + Vector2(2, 2), box.end - Vector2(2, 2), CHERRY, 2.0)
			c.draw_line(box.position + Vector2(8, 2), box.position + Vector2(2, 8), CHERRY, 2.0)
		"on_track":
			c.draw_rect(box, INK_SOFT, false, 1.0)
			c.draw_circle(box.get_center(), 2.0, TEAL)
		_:
			c.draw_rect(box, INK_SOFT, false, 1.0)


## Regard each way as two small bars growing left (cool) or right (warm)
## from a centre line: yours on top, theirs below. Full scale is span.
static func regard_meter(c: CanvasItem, rect: Rect2, mine: int, theirs: int, met: bool, span: int) -> void:
	var middle: float = rect.position.x + rect.size.x / 2.0
	var half: float = rect.size.x / 2.0
	var row_h: float = (rect.size.y - 1.0) / 2.0
	c.draw_rect(rect, Color(PAPER_DARK, 0.9))
	if met:
		var index: int = 0
		for value: int in [mine, theirs]:
			var length: float = clampf(float(absi(value)) / float(span), 0.0, 1.0) * half
			var y: float = rect.position.y + float(index) * (row_h + 1.0)
			var color: Color = LEAF if value >= 0 else CHERRY
			if value >= 0:
				c.draw_rect(Rect2(middle, y, length, row_h), color)
			else:
				c.draw_rect(Rect2(middle - length, y, length, row_h), color)
			index += 1
	c.draw_line(Vector2(middle, rect.position.y - 1.0), Vector2(middle, rect.end.y + 1.0), INK_SOFT, 1.0)


## A lit light bulb for the tip bubble, centred on center; r is the glass's radius.
static func bulb(c: CanvasItem, center: Vector2, r: float) -> void:
	for ray: int in 7:
		var direction: Vector2 = Vector2.UP.rotated((float(ray) - 3.0) * 0.52)
		c.draw_line(center + direction * (r + 2.0), center + direction * (r + 4.5), Color(MUSTARD, 0.8), 1.5, true)
	c.draw_circle(center, r, MUSTARD)
	c.draw_arc(center, r, 0.0, TAU, 24, MUSTARD.darkened(0.35), 1.0, true)
	c.draw_arc(center, r * 0.55, PI * 1.1, PI * 1.6, 6, Color(1, 1, 1, 0.8), 1.5, true)
	var neck: Rect2 = Rect2(center.x - r * 0.45, center.y + r * 0.8, r * 0.9, r * 0.75)
	c.draw_rect(neck, INK_SOFT)
	c.draw_line(Vector2(neck.position.x, neck.position.y + neck.size.y * 0.5), Vector2(neck.end.x, neck.position.y + neck.size.y * 0.5), PAPER, 1.0)
