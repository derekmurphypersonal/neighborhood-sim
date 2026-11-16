extends Control
## Small tips shown the first time something happens: one bubble at a time in
## the top-right corner of the map, beside the side panel, dismissed with its
## button. Each tip shows once. This node only keeps the list of tips already
## seen and tells its owner when one is shown (tip_shown); main.gd decides
## whether that list is kept between runs. Presentation only.

signal tip_shown(tip_id: String)

const HudArt := preload("res://view/hud_art.gd")

## What each tip says. The keys are the moments main.gd watches for.
const TIPS: Dictionary = {
	"select": "Now click a neighbor to talk, a house to visit, or a room in \"Inside your home\". Right-click any building to read about it.",
	"talk": "A conversation changes what two people think of each other. Watch the numbers float up, and the bars in the Neighbors list.",
	"payday": "Payday! Wages come on Friday for the days worked. Rent is due on Monday, and the pantry needs filling at the store.",
	"week": "Every Monday the paper sums up the week just gone. \"This week\" in the top bar shows how the week is going at any time.",
	"night": "It is night: residents sleep until morning. Try 1 hour/s (key 3) to pass the time, and Space to pause.",
	"goal": "One done! \"Things to try this week\" on the left has more. Hover over any of them for a hint.",
}
## The bubble's top-right corner: the map's top-right, clear of the toasts
## (bottom centre of the map) and of the side panel.
const ANCHOR: Vector2 = Vector2(894, 80)
const TEXT_WIDTH: float = 250.0
const FADE_SECONDS: float = 0.25
## A tip gives way to the next one waiting after this long, in real seconds.
const WAITING_SECONDS: float = 14.0

var _enabled: bool = true
var _seen: Array[String] = []
var _queue: Array[String] = []
var _current: String = ""
var _blocked: bool = false
var _shown_for: float = 0.0
var _card: PanelContainer
var _text: Label
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color("#FFF6DC")
	box.border_color = HudArt.MUSTARD
	box.set_border_width_all(2)
	box.border_width_left = 6
	box.set_corner_radius_all(9)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 7
	box.content_margin_bottom = 8
	box.shadow_color = Color(0.12, 0.08, 0.05, 0.32)
	box.shadow_size = 7
	box.shadow_offset = Vector2(0, 2)
	_card.add_theme_stylebox_override("panel", box)
	add_child(_card)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_card.add_child(row)
	var bulb: Control = Control.new()
	bulb.custom_minimum_size = Vector2(22, 26)
	bulb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bulb.draw.connect(func() -> void: HudArt.bulb(bulb, Vector2(11, 12), 8.0))
	row.add_child(bulb)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	row.add_child(column)
	var caption: Label = Label.new()
	caption.text = "TIP"
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_color_override("font_color", HudArt.MUSTARD.darkened(0.3))
	column.add_child(caption)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	_text.add_theme_font_size_override("font_size", 13)
	_text.add_theme_color_override("font_color", HudArt.INK)
	column.add_child(_text)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	var got_it: Button = Button.new()
	got_it.text = "Got it"
	got_it.theme_type_variation = "RowButton"
	got_it.focus_mode = Control.FOCUS_NONE
	got_it.tooltip_text = "Close this tip. Each tip is shown once; \"Show tips\" in Settings turns them off or brings them back."
	got_it.pressed.connect(dismiss)
	buttons.add_child(got_it)


## Starts with these tips already seen. With enabled false nothing is shown.
func setup(seen_ids: Array, enabled: bool) -> void:
	_seen.clear()
	for id: Variant in seen_ids:
		if TIPS.has(str(id)) and not _seen.has(str(id)):
			_seen.append(str(id))
	_queue.clear()
	_enabled = enabled
	if not enabled or _seen.has(_current):
		_hide_now()


## Asks for a tip to be shown. Returns true if it will be (now or after the
## one on screen); false if it has been seen, is unknown, or tips are off.
func offer(tip_id: String) -> bool:
	if not _enabled or not TIPS.has(tip_id) or _seen.has(tip_id) or _queue.has(tip_id) or tip_id == _current:
		return false
	_queue.append(tip_id)
	return true


## The tips shown so far, for the owner to keep.
func seen() -> Array[String]:
	return _seen.duplicate()


func showing() -> String:
	return _current


## While blocked (a sheet is open over the game) no tip appears; one already
## showing waits underneath.
func set_blocked(blocked: bool) -> void:
	_blocked = blocked


func dismiss() -> void:
	if _current == "":
		return
	_current = ""
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_card, "modulate:a", 0.0, FADE_SECONDS * 0.6)
	_tween.tween_callback(func() -> void: _card.visible = _current != "")


func _hide_now() -> void:
	_current = ""
	if _tween != null:
		_tween.kill()
	_card.visible = false


func _process(delta: float) -> void:
	if _current != "":
		_shown_for += delta
		if not _queue.is_empty() and _shown_for > WAITING_SECONDS:
			dismiss()
		return
	if _queue.is_empty() or _blocked or not _enabled:
		return
	_show(_queue.pop_front())


func _show(tip_id: String) -> void:
	_current = tip_id
	_shown_for = 0.0
	_seen.append(tip_id)
	_text.text = TIPS[tip_id]
	_card.visible = true
	_card.reset_size()
	_card.size = _card.get_combined_minimum_size()
	var rest: Vector2 = ANCHOR - Vector2(_card.size.x, 0.0)
	if _tween != null:
		_tween.kill()
	_card.modulate.a = 0.0
	_card.position = rest + Vector2(0.0, -10.0)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_card, "modulate:a", 1.0, FADE_SECONDS)
	_tween.tween_property(_card, "position", rest, FADE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tip_shown.emit(tip_id)
