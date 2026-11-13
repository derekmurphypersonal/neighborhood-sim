extends Node2D
## The game's main scene for M1-A. It owns the simulation, advances it in
## step with real time, and shows it. All rules live in res://sim; this
## scene only reads state and gives orders (docs/ARCHITECTURE.md, section 3).

const Simulation := preload("res://sim/simulation.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")
const WorldView := preload("res://view/world_view.gd")
const Hud := preload("res://view/hud.gd")

const SCENARIO: String = "fixture_street_spring_1950"
## Game minutes per real second for each speed setting.
const SPEEDS: Array[int] = [0, 1, 10, 60]
const MAX_TICKS_PER_FRAME: int = 240

var simulation: Simulation
var world_view: WorldView
var hud: Hud
var speed_index: int = 1
var selected_id: String = ""
var _pending_minutes: float = 0.0
var _screenshot_path: String = ""
var _screenshot_minutes: int = 0


func _ready() -> void:
	var world: Dictionary = WorldLoader.load_world(SCENARIO)
	if not world["errors"].is_empty():
		var message: Label = Label.new()
		message.text = "Could not load the scenario:\n" + "\n".join(world["errors"])
		add_child(message)
		set_process(false)
		return
	simulation = Simulation.new_game(world, int(world["scenario"].get("default_seed", 1)))
	var player_household: Dictionary = simulation.state.households[simulation.state.player_household_id()]
	selected_id = player_household["member_ids"][0]

	world_view = WorldView.new()
	world_view.setup(simulation)
	world_view.person_clicked.connect(_on_person_clicked)
	world_view.building_clicked.connect(_on_building_clicked)
	add_child(world_view)

	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.setup(simulation)
	hud.speed_chosen.connect(func(index: int) -> void: speed_index = index)
	hud.person_chosen.connect(_select)
	hud.order_given.connect(_give_order)
	layer.add_child(hud)
	_select(selected_id)

	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size() - 1:
		if args[i] == "--screenshot":
			_screenshot_path = args[i + 1]
		if args[i] == "--minutes" and args[i + 1].is_valid_int():
			_screenshot_minutes = args[i + 1].to_int()
	if _screenshot_path != "":
		_take_screenshot()


func _process(delta: float) -> void:
	_pending_minutes += delta * SPEEDS[speed_index]
	var ticks: int = mini(int(_pending_minutes), MAX_TICKS_PER_FRAME)
	if ticks > 0:
		_pending_minutes -= ticks
		simulation.advance_minutes(ticks)
		world_view.after_ticks()
	# How far into the current minute we are, for smooth walking.
	world_view.minute_fraction = clampf(_pending_minutes, 0.0, 1.0) if SPEEDS[speed_index] > 0 else 1.0
	world_view.selected_id = selected_id
	world_view.queue_redraw()
	hud.refresh(selected_id, speed_index)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event is InputEventKey:
		match (event as InputEventKey).keycode:
			KEY_SPACE:
				speed_index = 0 if speed_index != 0 else 1
			KEY_1:
				speed_index = 1
			KEY_2:
				speed_index = 2
			KEY_3:
				speed_index = 3


func _select(person_id: String) -> void:
	selected_id = person_id


func _is_players(person_id: String) -> bool:
	var person: Dictionary = simulation.state.people[person_id]
	return simulation.state.households[person["household_id"]]["player_controlled"]


func _on_person_clicked(person_id: String) -> void:
	if _is_players(person_id) or not _is_players(selected_id):
		_select(person_id)
	else:
		_give_order(selected_id, {"kind": "talk_to", "other_id": person_id})


func _on_building_clicked(building_id: String) -> void:
	if not _is_players(selected_id):
		return
	var household: Dictionary = simulation.state.households[simulation.state.people[selected_id]["household_id"]]
	if building_id == household["home_id"]:
		_give_order(selected_id, {"kind": "go_home"})
	else:
		_give_order(selected_id, {"kind": "go_to", "place_id": building_id})


func _give_order(person_id: String, order: Dictionary) -> void:
	var refusal: String = simulation.give_order(person_id, order)
	hud.show_message(refusal if refusal != "" else "Order given to %s." % simulation.state.people[person_id]["given_name"])


## Development aid: run some minutes, save a picture of the screen, and quit.
func _take_screenshot() -> void:
	simulation.advance_minutes(_screenshot_minutes)
	world_view.after_ticks()
	world_view.minute_fraction = 1.0
	world_view.selected_id = selected_id
	world_view.queue_redraw()
	hud.refresh(selected_id, speed_index)
	set_process(false)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_screenshot_path)
	get_tree().quit()
