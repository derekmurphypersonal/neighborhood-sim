extends Node2D
## The game's main scene for M1-A. It owns the simulation, advances it in
## step with real time, and shows it. All rules live in res://sim; this
## scene only reads state and gives orders (docs/ARCHITECTURE.md, section 3).
##
## It also watches for things worth pointing out (someone starting to talk,
## regard changing, payday, people leaving and returning) and tells the view
## and the audio players. None of that feeds back into the simulation.

const Simulation := preload("res://sim/simulation.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")
const Records := preload("res://sim/state/records.gd")
const WorldView := preload("res://view/world_view.gd")
const Hud := preload("res://view/hud.gd")
const Describe := preload("res://view/describe.gd")

const SCENARIO: String = "fixture_street_spring_1950"
## Game minutes per real second for each speed setting.
const SPEEDS: Array[int] = [0, 1, 10, 60]
const MAX_TICKS_PER_FRAME: int = 240
const MUSIC_FILE: String = "music_placeholder_waltz.ogg"
const MUSIC_VOLUME_DB: float = -14.0
const CHIME_VOLUME_DB: float = -9.0
const CHIME_GAP_MS: int = 450
## Indoor activities not worth a note over the house.
const QUIET_INDOORS: Array[String] = ["At home", "Deciding what to do", "Heading home"]

var simulation: Simulation
var world_view: WorldView
var hud: Hud
var speed_index: int = 1
var selected_id: String = ""
var music_on: bool = true
var sound_on: bool = true

var _pending_minutes: float = 0.0
var _screenshot_path: String = ""
var _screenshot_minutes: int = 0
var _music: AudioStreamPlayer
var _chime_talk: AudioStreamPlayer
var _chime_notice: AudioStreamPlayer
var _last_chime_ms: int = 0
var _last_activity: Dictionary = {}
var _last_at: Dictionary = {}
var _last_funds: Dictionary = {}
var _seen_events: int = 0


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
	world_view.room_clicked.connect(_on_room_clicked)
	add_child(world_view)

	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.setup(simulation)
	hud.speed_chosen.connect(func(index: int) -> void: speed_index = index)
	hud.person_chosen.connect(_select)
	hud.order_given.connect(_give_order)
	hud.music_toggled.connect(_set_music)
	hud.sound_toggled.connect(func(on: bool) -> void: sound_on = on)
	layer.add_child(hud)

	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size() - 1:
		if args[i] == "--screenshot":
			_screenshot_path = args[i + 1]
		if args[i] == "--minutes" and args[i + 1].is_valid_int():
			_screenshot_minutes = args[i + 1].to_int()

	_watch(false)
	if _screenshot_path != "":
		_take_screenshot()
		return
	var checking: bool = args.has("--self-check")
	_setup_audio(not checking)
	if checking:
		sound_on = false  # the check confirms the audio loads; it does not play it
		_self_check()


func _process(delta: float) -> void:
	_pending_minutes += delta * SPEEDS[speed_index]
	var ticks: int = mini(int(_pending_minutes), MAX_TICKS_PER_FRAME)
	if ticks > 0:
		_pending_minutes -= ticks
		simulation.advance_minutes(ticks)
		world_view.after_ticks()
		_watch(true)
	# How far into the current minute we are, for smooth walking.
	world_view.minute_fraction = clampf(_pending_minutes, 0.0, 1.0) if SPEEDS[speed_index] > 0 else 1.0
	world_view.selected_id = selected_id
	world_view.queue_redraw()
	hud.refresh(selected_id, speed_index, music_on, sound_on)


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
			KEY_M:
				_set_music(not music_on)


# --- Selecting and ordering --------------------------------------------------

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
	elif simulation.area.is_institution(building_id):
		_give_order(selected_id, {"kind": "enter", "place_id": building_id})
	else:
		_give_order(selected_id, {"kind": "go_to", "place_id": building_id})


func _on_room_clicked(room_id: String) -> void:
	if _is_players(selected_id):
		_give_order(selected_id, {"kind": "use_room", "room_id": room_id})


func _give_order(person_id: String, order: Dictionary) -> void:
	var refusal: String = simulation.give_order(person_id, order)
	var given_name: String = simulation.state.people[person_id]["given_name"]
	if refusal != "":
		hud.show_message(refusal)
		return
	match order["kind"]:
		"go_home":
			world_view.add_toast("You sent %s home." % given_name)
		"go_to":
			world_view.add_toast("You sent %s to %s." % [given_name, simulation.area.buildings[order["place_id"]]["label"]])
		"talk_to":
			world_view.add_toast("You asked %s to talk to %s." % [given_name, Describe.given_name(simulation, order["other_id"])])
		"use_room":
			var home: String = simulation.state.households[simulation.state.people[person_id]["household_id"]]["home_id"]
			world_view.add_toast("You sent %s to the %s." % [given_name, (simulation.area.interiors[home]["rooms"][order["room_id"]]["name"] as String).to_lower()])
		"enter":
			world_view.add_toast("You sent %s into %s." % [given_name, simulation.area.institutions[order["place_id"]]["name"]])
	hud.show_message("Order given to %s." % given_name)


# --- Noticing what happens ---------------------------------------------------

## Compares the simulation with what was last seen and points out changes.
## With announce false it only records the current state (used at start).
func _watch(announce: bool) -> void:
	var notes_allowed: bool = announce and SPEEDS[speed_index] <= 10
	for person_id: String in simulation.state.sorted_person_ids():
		var person: Dictionary = simulation.state.people[person_id]
		var text: String = Describe.activity(simulation, person)
		world_view.show_activity(person_id, text)
		var before_at: String = _last_at.get(person_id, person["at"])
		if announce and before_at != person["at"]:
			if person["at"] == Records.AT_OFFMAP:
				var where: String = "work" if person["action"].get("kind", "") == "work" else "school"
				world_view.add_float([person["x"], person["y"]], 20.0, "%s left for %s" % [person["given_name"], where], WorldView.COLOR_NOTE)
			elif before_at == Records.AT_OFFMAP:
				world_view.add_float([person["x"], person["y"]], 20.0, "%s is back" % person["given_name"], WorldView.COLOR_NOTE)
		if announce and _last_activity.get(person_id, "") != text:
			var action: Dictionary = person["action"]
			var talking: bool = not action.is_empty() and action["kind"] == "talk"
			if talking and person_id < action["other_id"]:
				if _is_players(person_id) or _is_players(action["other_id"]):
					world_view.add_toast("%s and %s are talking." % [person["given_name"], Describe.given_name(simulation, action["other_id"])])
					_chime(_chime_talk)
			if notes_allowed and person["at"] == Records.AT_INSIDE and not QUIET_INDOORS.has(text):
				world_view.add_house_note(person["place_id"], "%s: %s%s" % [person["given_name"], text.left(1).to_lower(), text.substr(1)])
		_last_activity[person_id] = text
		_last_at[person_id] = person["at"]

	var log: Array = simulation.state.event_log
	for index: int in range(_seen_events, log.size()):
		if announce:
			_announce_event(log[index])
	_seen_events = log.size()

	for household_id: String in simulation.state.sorted_household_ids():
		var household: Dictionary = simulation.state.households[household_id]
		var before: int = _last_funds.get(household_id, household["funds_cents"])
		var change: int = household["funds_cents"] - before
		if announce and change != 0:
			var anchor: Dictionary = world_view.building_anchor(household["home_id"])
			var text: String = "%s$%.2f" % ["+" if change > 0 else "-", absf(change / 100.0)]
			world_view.add_float(anchor["point"], anchor["lift"], text, WorldView.COLOR_GOOD if change > 0 else WorldView.COLOR_BAD)
			if household["player_controlled"]:
				world_view.add_toast("Payday settled: your household is %s $%.2f this week." % ["up" if change > 0 else "down", absf(change / 100.0)])
				_chime(_chime_notice)
		_last_funds[household_id] = household["funds_cents"]


func _announce_event(event: Dictionary) -> void:
	match event["type"]:
		"conversation":
			for side: Array in [[event["a"], event["a_change"]], [event["b"], event["b_change"]]]:
				var anchor: Dictionary = world_view.anchor_of(simulation.state.people[side[0]])
				if anchor.is_empty():
					continue
				var color: Color = WorldView.COLOR_GOOD if side[1] > 0 else (WorldView.COLOR_BAD if side[1] < 0 else WorldView.COLOR_NOTE)
				world_view.add_float(anchor["point"], anchor["lift"], "%+d" % side[1], color)
			if event["first_meeting"] and (_is_players(event["a"]) or _is_players(event["b"])):
				world_view.add_toast("%s and %s have met for the first time." % [
					Describe.given_name(simulation, event["a"]), Describe.given_name(simulation, event["b"]),
				])
		"birthday", "household_short_of_money", "order_failed":
			world_view.add_toast(Describe.event(simulation, event))
			_chime(_chime_notice)


# --- Sound -------------------------------------------------------------------

func _setup_audio(start_music: bool) -> void:
	_music = _player(MUSIC_FILE, MUSIC_VOLUME_DB)
	_chime_talk = _player("chime_talk.ogg", CHIME_VOLUME_DB)
	_chime_notice = _player("chime_notice.ogg", CHIME_VOLUME_DB)
	if _music != null:
		(_music.stream as AudioStreamOggVorbis).loop = true
		if start_music:
			_music.play()
	else:
		music_on = false


## Loads a sound straight from the project folder, so no editor import step
## is needed. Returns null if the file is missing or unreadable.
func _player(file_name: String, volume_db: float) -> AudioStreamPlayer:
	var path: String = ProjectSettings.globalize_path("res://audio/" + file_name)
	if not FileAccess.file_exists(path):
		return null
	var stream: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return null
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player


func _set_music(on: bool) -> void:
	music_on = on and _music != null
	if _music != null:
		_music.stream_paused = not music_on
		if music_on and not _music.playing:
			_music.play()


func _chime(player: AudioStreamPlayer) -> void:
	var now: int = Time.get_ticks_msec()
	if player == null or not sound_on or now - _last_chime_ms < CHIME_GAP_MS:
		return
	_last_chime_ms = now
	player.play()


## Development aid: exercises the scene without a person and reports.
##   godot --headless --path game -- --self-check
## Runs a day and a half of game time through the same path as play (so the
## view is told about every bubble, notice and float), gives one order,
## checks the audio files loaded, and exits with code 0 only if all is well.
func _self_check() -> void:
	set_process(false)
	var problems: Array[String] = []
	for entry: Array in [["music", _music], ["talk chime", _chime_talk], ["notice chime", _chime_notice]]:
		var player: AudioStreamPlayer = entry[1]
		if player == null or player.stream == null or player.stream.get_length() <= 0.0:
			problems.append("%s did not load" % entry[0])
		else:
			print("SELF-CHECK  %s loaded, %.1f seconds" % [entry[0], player.stream.get_length()])
	if _music != null and not (_music.stream as AudioStreamOggVorbis).loop:
		problems.append("music is not set to loop")
	var refusal: String = simulation.give_order(selected_id, {"kind": "go_home"})
	if refusal != "":
		problems.append("an order to the player's household was refused: " + refusal)
	var before: String = simulation.clock.describe()
	for step: int in 2160:
		simulation.advance_minutes(1)
		world_view.after_ticks()
		_watch(true)
		if step % 60 == 0:
			world_view.queue_redraw()
			hud.refresh(selected_id, speed_index, music_on, sound_on)
			await get_tree().process_frame
	print("SELF-CHECK  ran from %s to %s" % [before, simulation.clock.describe()])
	print("SELF-CHECK  %d events in the log; %d people have a bubble" % [simulation.state.event_log.size(), _last_activity.size()])
	if simulation.state.event_log.is_empty():
		problems.append("nothing happened in a day and a half")
	if _last_activity.size() != simulation.state.people.size():  # one per resident
		problems.append("not everyone has an activity bubble")
	for problem: String in problems:
		print("SELF-CHECK  PROBLEM: " + problem)
	print("SELF-CHECK  %s" % ("passed" if problems.is_empty() else "FAILED"))
	get_tree().quit(0 if problems.is_empty() else 1)


## Development aid: run some minutes, save a picture of the screen, and quit.
func _take_screenshot() -> void:
	set_process(false)
	simulation.advance_minutes(maxi(_screenshot_minutes - 3, 0))
	_watch(false)
	for i: int in mini(_screenshot_minutes, 3):
		simulation.advance_minutes(1)
		world_view.after_ticks()
		_watch(true)
	world_view.minute_fraction = 1.0
	world_view.selected_id = selected_id
	world_view.queue_redraw()
	hud.refresh(selected_id, speed_index, music_on, sound_on)
	await get_tree().create_timer(0.6).timeout  # let bubbles finish popping
	world_view.queue_redraw()
	hud.refresh(selected_id, speed_index, music_on, sound_on)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_screenshot_path)
	get_tree().quit()
