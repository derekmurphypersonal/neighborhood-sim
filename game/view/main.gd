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
const BuildingInfo := preload("res://sim/reports/building_info.gd")
const SaveGame := preload("res://sim/io/save_game.gd")
const SimDate := preload("res://sim/clock/sim_date.gd")
const WeekSummary := preload("res://sim/reports/week_summary.gd")
const WeekGoals := preload("res://sim/reports/week_goals.gd")
const TitleScreen := preload("res://view/title_screen.gd")
const SettingsSheet := preload("res://view/settings_sheet.gd")
const ScreenFx := preload("res://view/screen_fx.gd")

const SCENARIO: String = "fixture_street_spring_1950"
## Game minutes per real second for each speed setting.
const SPEEDS: Array[int] = [0, 1, 10, 60]
const MAX_TICKS_PER_FRAME: int = 240
const MUSIC_FILE: String = "music_placeholder_waltz.ogg"
const MUSIC_VOLUME_DB: float = -14.0
const CHIME_VOLUME_DB: float = -9.0
const CHIME_GAP_MS: int = 450
## Outdoor ambience sits well under the music. The day bed is full from 06:30
## to 18:30; it crossfades to the night crickets over dusk (18:30 to 20:30)
## and back over dawn (04:30 to 06:30). Times are minutes after midnight.
const AMBIENCE_DAY_FILE: String = "ambience_day.ogg"
const AMBIENCE_NIGHT_FILE: String = "ambience_night.ogg"
const AMBIENCE_VOLUME_DB: float = -19.0
const DAWN_START: int = 270
const DAWN_END: int = 390
const DUSK_START: int = 1110
const DUSK_END: int = 1230
const SILENT_DB: float = -80.0
## Player settings (presentation only), kept between runs on this computer.
const SETTINGS_PATH: String = "user://settings.cfg"
const DEFAULT_SETTINGS: Dictionary = {
	"music_volume": 1.0, "sound_volume": 1.0, "fullscreen": false, "music_on": true, "sound_on": true,
}
const MUSIC_BUS: String = "Music"
const SOUNDS_BUS: String = "Sounds"
const WINDOW_TITLE: String = "The Neighborhood (working title)"
const MIN_WINDOW_SIZE: Vector2i = Vector2i(960, 540)
## Fades between the title and the game, in real seconds.
const FADE_OUT_SECONDS: float = 0.45
const FADE_IN_SECONDS: float = 0.7
## Indoor activities not worth a note over the house.
const QUIET_INDOORS: Array[String] = ["At home", "Deciding what to do", "Heading home"]

## The one saved game. Where saves belong in an exported build is still an
## open question (Q-016); for now it is the per-user data folder.
var save_path: String = "user://saved_game.json"
var simulation: Simulation
var _layer: CanvasLayer
var world_view: WorldView
var hud: Hud
var speed_index: int = 1
var selected_id: String = ""
var music_on: bool = true
var sound_on: bool = true

var _pending_minutes: float = 0.0
var _screenshot_path: String = ""
var _screenshot_minutes: int = 0
var _screenshot_sheet: String = ""
var _screenshot_zoom: float = 1.0
var _music: AudioStreamPlayer
var _chime_talk: AudioStreamPlayer
var _chime_notice: AudioStreamPlayer
var _ambience_day: AudioStreamPlayer
var _ambience_night: AudioStreamPlayer
var _last_chime_ms: int = 0
var _last_activity: Dictionary = {}
var _last_at: Dictionary = {}
var _last_funds: Dictionary = {}
var _seen_events: int = 0
## The Monday of the week now being played, for the end-of-week summary.
var _week_start: int = 0
## The week the goals were last worked out for, and each goal's status then,
## so that a goal is announced only when it becomes done during play.
var _goals_week: int = -1
var _goal_status: Dictionary = {}
## The speed to go back to when a sheet is closed.
var _speed_before_sheet: int = -1
## The day last announced with the ribbon at the top of the map.
var _banner_day: int = -1
## A new game shows its first day's ribbon once the welcome card is closed.
var _first_day_banner: bool = false

var _checking: bool = false
var _settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var _fx: ScreenFx
var _title: TitleScreen
var _settings_sheet: SettingsSheet
var _fader: ColorRect
## True while a fade between the title and the game is running.
var _busy: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size() - 1:
		if args[i] == "--screenshot":
			_screenshot_path = args[i + 1]
		if args[i] == "--show":
			_screenshot_sheet = args[i + 1]
		if args[i] == "--zoom" and args[i + 1].is_valid_float():
			_screenshot_zoom = args[i + 1].to_float()
		if args[i] == "--minutes" and args[i + 1].is_valid_int():
			_screenshot_minutes = args[i + 1].to_int()
	_checking = args.has("--self-check")
	var trial: bool = _checking or _screenshot_path != ""

	get_window().title = WINDOW_TITLE
	get_window().min_size = MIN_WINDOW_SIZE
	_layer = CanvasLayer.new()
	add_child(_layer)
	_fx = ScreenFx.new()
	_layer.add_child(_fx)
	_build_front_layers()
	# The self-check and screenshots neither read nor write the player's
	# settings, so they behave the same on every computer.
	if not trial:
		_load_settings()
		_apply_window_settings()

	if _screenshot_path != "":
		if _screenshot_sheet == "title":
			_show_title(false)
		elif not _start_new_game():
			return
		_take_screenshot()
		return
	_setup_audio(not _checking)
	if _checking:
		sound_on = false  # the check confirms the audio loads; it does not play it
		if _start_new_game():
			_self_check()
	else:
		_show_title(true)


## The title screen and the settings sheet sit above the game; the fader
## above everything.
func _build_front_layers() -> void:
	var front: CanvasLayer = CanvasLayer.new()
	front.layer = 10
	add_child(front)
	_title = TitleScreen.new()
	_title.visible = false
	_title.new_game_requested.connect(_on_new_game)
	_title.continue_requested.connect(_on_continue)
	_title.settings_requested.connect(_open_settings)
	_title.quit_requested.connect(func() -> void: get_tree().quit())
	front.add_child(_title)
	_settings_sheet = SettingsSheet.new()
	_settings_sheet.changed.connect(_on_settings_changed)
	front.add_child(_settings_sheet)

	var fade_layer: CanvasLayer = CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	_fader = ColorRect.new()
	_fader.color = Color(0.03, 0.03, 0.05, 0.0)
	_fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fader)


## Makes a new game from the scenario and puts it on screen. Returns false
## (and says why on screen) if the scenario cannot be loaded.
func _start_new_game() -> bool:
	var world: Dictionary = WorldLoader.load_world(SCENARIO)
	if not world["errors"].is_empty():
		var message: Label = Label.new()
		message.text = "Could not load the scenario:\n" + "\n".join(world["errors"])
		_layer.add_child(message)
		set_process(false)
		return false
	_show_simulation(Simulation.new_game(world, int(world["scenario"].get("default_seed", 1))))
	speed_index = 1
	return true


func _process(delta: float) -> void:
	if world_view == null:
		return
	_pending_minutes += delta * SPEEDS[speed_index]
	var ticks: int = mini(int(_pending_minutes), MAX_TICKS_PER_FRAME)
	if ticks > 0:
		_pending_minutes -= ticks
		simulation.advance_minutes(ticks)
		world_view.after_ticks()
		_watch(true)
		var week_now: int = WeekSummary.week_start(simulation.clock.day_index)
		if week_now != _week_start:
			_show_week(_week_start, "The week that was")
			_week_start = week_now
		if simulation.clock.day_index != _banner_day:
			_banner_day = simulation.clock.day_index
			_fx.show_day(_banner_day)
	# How far into the current minute we are, for smooth walking.
	world_view.minute_fraction = clampf(_pending_minutes, 0.0, 1.0) if SPEEDS[speed_index] > 0 else 1.0
	world_view.selected_id = selected_id
	world_view.queue_redraw()
	hud.refresh(selected_id, speed_index, music_on, sound_on)
	_fx.set_paused(speed_index == 0)
	_mix_ambience()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or not event is InputEventKey or event.is_echo():
		return
	var key: Key = (event as InputEventKey).keycode
	if key == KEY_F11:
		_set_fullscreen(not bool(_settings["fullscreen"]))
		return
	if _settings_sheet.is_open():
		if key == KEY_ESCAPE:
			_settings_sheet.close()
		return
	if world_view == null or _busy:
		return
	match key:
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
		KEY_N:
			_set_sound(not sound_on)
		KEY_ESCAPE:
			if hud.sheet_is_open():
				hud.close_sheet()
			else:
				_show_menu()


## Puts a simulation on screen: a new game, or one loaded from a save.
## Anything shown for an earlier simulation is removed first.
func _show_simulation(shown: Simulation) -> void:
	if world_view != null:
		world_view.queue_free()
		hud.queue_free()
	simulation = shown
	selected_id = simulation.state.households[simulation.state.player_household_id()]["member_ids"][0]
	_pending_minutes = 0.0
	_speed_before_sheet = -1
	_last_activity.clear()
	_last_at.clear()
	_last_funds.clear()
	_seen_events = 0
	_week_start = WeekSummary.week_start(simulation.clock.day_index)
	_goals_week = -1
	_goal_status.clear()
	_banner_day = simulation.clock.day_index

	world_view = WorldView.new()
	world_view.setup(simulation)
	world_view.person_clicked.connect(_on_person_clicked)
	world_view.building_clicked.connect(_on_building_clicked)
	world_view.room_clicked.connect(_on_room_clicked)
	world_view.building_info_requested.connect(_show_building)
	add_child(world_view)

	hud = Hud.new()
	hud.setup(simulation)
	hud.speed_chosen.connect(func(index: int) -> void: speed_index = index)
	hud.person_chosen.connect(_select)
	hud.order_given.connect(_give_order)
	hud.music_toggled.connect(_set_music)
	hud.sound_toggled.connect(_set_sound)
	hud.week_requested.connect(func() -> void: _show_week(_week_start, "This week so far"))
	hud.menu_requested.connect(_show_menu)
	hud.sheet_closed.connect(_on_sheet_closed)
	_layer.add_child(hud)
	_watch(false)


# --- The menu: saving and loading --------------------------------------------

func _show_menu(note: String = "") -> void:
	var lines: Array[String] = [
		"The game is paused.", "",
		"[b]Save game[/b] keeps the game exactly as it is now, in one saved game that is replaced each time.",
		"[b]Load game[/b] goes back to the saved game. Anything since then is lost.",
		"[b]Settings[/b] sets the music and sound volume, and full screen.",
		"[b]Main menu[/b] leaves this game for the title screen.", "",
	]
	var saved: Dictionary = SaveGame.read_file(save_path)
	if saved["ok"]:
		var parsed: Dictionary = SaveGame.parse(saved["text"])
		if parsed["ok"]:
			var clock: Dictionary = parsed["document"]["simulation"]["clock"]
			lines.append("Saved game: %s %s, %s." % [
				SimDate.weekday_name(clock["day_index"]), SimDate.to_iso(clock["day_index"]), Describe.clock_time(clock["minute_of_day"]),
			])
		else:
			lines.append("The saved game cannot be read: %s" % parsed["error"])
	else:
		lines.append("There is no saved game yet.")
	if note != "":
		lines.append("")
		lines.append("[color=#ffeb8c]%s[/color]" % note)
	_open_sheet("Menu", "\n".join(lines), [
		["Save game", _save_game], ["Load game", _load_game], ["Settings", _open_settings], ["Main menu", _confirm_main_menu],
	], "Resume")


## Saves the game. Returns "" or the reason it could not be saved.
func _save_game() -> String:
	var problem: String = SaveGame.write_file(save_path, SaveGame.to_text(simulation))
	_show_menu("Game saved." if problem == "" else "The game could not be saved: %s" % problem)
	return problem


## Loads the saved game. Returns "" or the reason it could not be loaded;
## on failure the game in progress carries on untouched.
func _load_game() -> String:
	var saved: Dictionary = SaveGame.read_file(save_path)
	if not saved["ok"]:
		_show_menu("There is no saved game to load.")
		return saved["error"]
	var world: Dictionary = WorldLoader.load_world(SCENARIO)
	var restored: Dictionary = SaveGame.restore(saved["text"], world)
	if not restored["ok"]:
		_show_menu("The saved game could not be loaded: %s" % restored["error"])
		return restored["error"]
	_show_simulation(restored["simulation"])
	speed_index = 0
	var note: String = "Game loaded."
	if not (restored["changed_data"] as Array).is_empty():
		note += " The game's data files have changed since it was saved, so it may not play out as it would have."
	_show_menu(note)
	return ""


# --- Sheets ------------------------------------------------------------------

## Opens a sheet over the game and stops the clock while it is read.
func _open_sheet(title: String, text: String, actions: Array = [], close_label: String = "Continue", content: Control = null) -> void:
	if _speed_before_sheet < 0:
		_speed_before_sheet = speed_index
	speed_index = 0
	_pending_minutes = 0.0
	hud.show_sheet(title, text, actions, close_label, content)


func _on_sheet_closed() -> void:
	if _speed_before_sheet >= 0:
		speed_index = _speed_before_sheet
	_speed_before_sheet = -1
	if _first_day_banner and world_view != null:
		_first_day_banner = false
		_fx.show_day(simulation.clock.day_index, "THE WEEK BEGINS")


# --- Title screen, settings and fades ----------------------------------------

## Shows the title screen. The game, if any, has already been put away.
func _show_title(fade_in: bool) -> void:
	_title.visible = true
	_title.show_note("")
	_title.set_can_continue(FileAccess.file_exists(save_path), _saved_game_detail())
	_title.play_intro()
	if fade_in:
		_fader.color.a = 1.0
		_fade_to(0.0, FADE_IN_SECONDS * 1.4)


## "Saved Tuesday 4 April 1950, 7:30 am", or "" if there is no readable save.
func _saved_game_detail() -> String:
	var saved: Dictionary = SaveGame.read_file(save_path)
	if not saved["ok"]:
		return ""
	var parsed: Dictionary = SaveGame.parse(saved["text"])
	if not parsed["ok"]:
		return "The saved game cannot be read."
	var clock: Dictionary = parsed["document"]["simulation"]["clock"]
	return "Saved game: %s %s, %s" % [
		SimDate.weekday_name(clock["day_index"]), SimDate.to_iso(clock["day_index"]), Describe.clock_time(clock["minute_of_day"]),
	]


func _fade_to(alpha: float, seconds: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fader, "color:a", alpha, seconds).set_trans(Tween.TRANS_SINE)
	await tween.finished


func _on_new_game() -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0, FADE_OUT_SECONDS)
	if _start_new_game():
		_title.visible = false
		_first_day_banner = true
		_show_welcome()
	await _fade_to(0.0, FADE_IN_SECONDS)
	_busy = false


## Continue from the title: loads the saved game and starts it paused.
func _on_continue() -> void:
	if _busy:
		return
	var saved: Dictionary = SaveGame.read_file(save_path)
	if not saved["ok"]:
		_title.show_note("There is no saved game to continue.")
		return
	var restored: Dictionary = SaveGame.restore(saved["text"], WorldLoader.load_world(SCENARIO))
	if not restored["ok"]:
		_title.show_note("The saved game could not be loaded: %s" % restored["error"])
		return
	_busy = true
	await _fade_to(1.0, FADE_OUT_SECONDS)
	_show_simulation(restored["simulation"])
	speed_index = 0
	_title.visible = false
	_fx.show_day(simulation.clock.day_index, "WELCOME BACK")
	world_view.add_toast("Game loaded and paused. Press Space to carry on.")
	if not (restored["changed_data"] as Array).is_empty():
		world_view.add_toast("The game's data files have changed since it was saved, so it may not play out as it would have.")
	await _fade_to(0.0, FADE_IN_SECONDS)
	_busy = false


func _confirm_main_menu() -> void:
	_open_sheet("Leave for the main menu?", "\n".join([
		"This game will be closed and you will go back to the title screen.", "",
		"[color=#ffeb8c]Anything since you last saved will be lost.[/color] Use [b]Save game[/b] in the menu first to keep it.",
	]), [["Leave without saving", _go_to_title], ["Back to the menu", _show_menu]], "Keep playing")


func _go_to_title() -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0, FADE_OUT_SECONDS)
	_close_game()
	_show_title(false)
	await _fade_to(0.0, FADE_IN_SECONDS)
	_busy = false


## Puts the game away: the street and the panels go; the music carries on.
func _close_game() -> void:
	if hud != null:
		hud.close_sheet()
		hud.queue_free()
	if world_view != null:
		world_view.queue_free()
	hud = null
	world_view = null
	simulation = null
	_first_day_banner = false
	_fx.set_paused(false)
	for player: AudioStreamPlayer in [_ambience_day, _ambience_night]:
		if player != null:
			player.volume_db = SILENT_DB


func _open_settings() -> void:
	_settings["music_on"] = music_on
	_settings["sound_on"] = sound_on
	_settings_sheet.open(_settings)


func _on_settings_changed(changed: Dictionary) -> void:
	var music_was_audible: bool = float(_settings["music_volume"]) > 0.0
	var sounds_were_audible: bool = float(_settings["sound_volume"]) > 0.0
	_settings["music_volume"] = changed["music_volume"]
	_settings["sound_volume"] = changed["sound_volume"]
	# Turning a volume right down is the same as switching it off, and
	# turning it back up switches it on again, so the top-bar buttons agree.
	var music_audible: bool = float(_settings["music_volume"]) > 0.0
	var sounds_audible: bool = float(_settings["sound_volume"]) > 0.0
	if music_audible != music_was_audible:
		_set_music(music_audible)
	if sounds_audible != sounds_were_audible:
		_set_sound(sounds_audible)
	_apply_volumes()
	if bool(changed["fullscreen"]) != bool(_settings["fullscreen"]):
		_set_fullscreen(bool(changed["fullscreen"]))
	_save_settings()


func _set_fullscreen(on: bool) -> void:
	_settings["fullscreen"] = on
	_settings_sheet.show_fullscreen(on)
	_apply_window_settings()
	_save_settings()


func _apply_window_settings() -> void:
	if _checking or _screenshot_path != "":
		return
	var want: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if _settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


func _load_settings() -> void:
	var file: ConfigFile = ConfigFile.new()
	if file.load(SETTINGS_PATH) != OK:
		return
	for key: String in DEFAULT_SETTINGS:
		var value: Variant = file.get_value("settings", key, DEFAULT_SETTINGS[key])
		if typeof(value) == typeof(DEFAULT_SETTINGS[key]):
			_settings[key] = value
	_settings["music_volume"] = clampf(_settings["music_volume"], 0.0, 1.0)
	_settings["sound_volume"] = clampf(_settings["sound_volume"], 0.0, 1.0)
	music_on = _settings["music_on"]
	sound_on = _settings["sound_on"]


## Writes the settings to the per-user folder. Never during the self-check
## or a screenshot run, so those leave the computer untouched.
func _save_settings() -> void:
	if _checking or _screenshot_path != "":
		return
	_settings["music_on"] = music_on
	_settings["sound_on"] = sound_on
	var file: ConfigFile = ConfigFile.new()
	for key: String in _settings:
		file.set_value("settings", key, _settings[key])
	file.save(SETTINGS_PATH)


## What is known about a building: documented exterior, fictional interior
## and fictional scenario content, each under its own heading.
func _show_building(building_id: String) -> void:
	var info: Dictionary = BuildingInfo.describe(simulation, building_id)
	_open_sheet(info["label"], Describe.building_info(simulation, info), [], "Close")


## The player's household's week, made from the event log.
func _show_week(first_day: int, title: String) -> void:
	var household_id: String = simulation.state.player_household_id()
	var summary: Dictionary = WeekSummary.summarize(simulation.state, household_id, first_day, first_day + 6)
	var goals: Array = WeekGoals.evaluate(simulation.state, household_id, first_day, first_day + 6, simulation.clock.day_index)
	_open_sheet("%s: the %s" % [title, simulation.state.households[household_id]["name"]], Describe.week_summary(simulation, summary, goals),
			[], "Continue", hud.week_paper(summary, goals))


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
	_check_goals(announce)

	for household_id: String in simulation.state.sorted_household_ids():
		var household: Dictionary = simulation.state.households[household_id]
		var before: int = _last_funds.get(household_id, household["funds_cents"])
		var change: int = household["funds_cents"] - before
		if announce and change != 0:
			var anchor: Dictionary = world_view.building_anchor(household["home_id"])
			var text: String = "%s$%.2f" % ["+" if change > 0 else "-", absf(change / 100.0)]
			world_view.add_float(anchor["point"], anchor["lift"], text, WorldView.COLOR_GOOD if change > 0 else WorldView.COLOR_BAD)
		_last_funds[household_id] = household["funds_cents"]


## Works out this week's things to try, shows them, and announces any that
## have just been done. Nothing is announced for a goal already done when the
## game started or was loaded, or when a new week begins.
func _check_goals(announce: bool) -> void:
	var first_day: int = WeekSummary.week_start(simulation.clock.day_index)
	var goals: Array = WeekGoals.evaluate(simulation.state, simulation.state.player_household_id(), first_day, first_day + 6, simulation.clock.day_index)
	for goal: Dictionary in goals:
		if announce and first_day == _goals_week and goal["status"] == "done" and _goal_status.get(goal["id"], "") != "done":
			world_view.add_toast("Done: %s" % goal["title"])
			_chime(_chime_notice)
		_goal_status[goal["id"]] = goal["status"]
	_goals_week = first_day
	hud.show_goals(goals)


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
		"birthday", "order_failed":
			world_view.add_toast(Describe.event(simulation, event))
			_chime(_chime_notice)
		"payday", "rent_paid", "shopping", "empty_pantry", "household_short_of_money", "missed_work":
			# Money news is announced for the player's own household only.
			if simulation.state.households[event["household_id"]]["player_controlled"]:
				world_view.add_toast(Describe.event(simulation, event))
				_chime(_chime_notice)


# --- Sound -------------------------------------------------------------------

## Loads every sound. Only when start_playing is true do the music and the
## ambience start; the self-check loads them without playing anything.
func _setup_audio(start_playing: bool) -> void:
	_make_bus(MUSIC_BUS)
	_make_bus(SOUNDS_BUS)
	_music = _player(MUSIC_FILE, MUSIC_VOLUME_DB, MUSIC_BUS)
	_chime_talk = _player("chime_talk.ogg", CHIME_VOLUME_DB, SOUNDS_BUS)
	_chime_notice = _player("chime_notice.ogg", CHIME_VOLUME_DB, SOUNDS_BUS)
	_ambience_day = _player(AMBIENCE_DAY_FILE, SILENT_DB, SOUNDS_BUS)
	_ambience_night = _player(AMBIENCE_NIGHT_FILE, SILENT_DB, SOUNDS_BUS)
	_apply_volumes()
	if _music != null:
		(_music.stream as AudioStreamOggVorbis).loop = true
		if start_playing:
			_music.play()
			_music.stream_paused = not music_on
	else:
		music_on = false
	for player: AudioStreamPlayer in [_ambience_day, _ambience_night]:
		if player != null:
			(player.stream as AudioStreamOggVorbis).loop = true
			if start_playing:
				player.play()
				player.stream_paused = not sound_on
	if start_playing:
		_mix_ambience()


## Music and the other sounds each go through their own bus, so the settings
## sheet can set their volumes without touching the mix between them.
func _make_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _apply_volumes() -> void:
	for entry: Array in [[MUSIC_BUS, float(_settings["music_volume"])], [SOUNDS_BUS, float(_settings["sound_volume"])]]:
		var index: int = AudioServer.get_bus_index(entry[0])
		if index == -1:
			continue
		var level: float = entry[1]
		AudioServer.set_bus_mute(index, level <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.001)))


## Loads a sound straight from the project folder, so no editor import step
## is needed. Returns null if the file is missing or unreadable.
func _player(file_name: String, volume_db: float, bus_name: String) -> AudioStreamPlayer:
	var path: String = ProjectSettings.globalize_path("res://audio/" + file_name)
	if not FileAccess.file_exists(path):
		return null
	var stream: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return null
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = bus_name
	add_child(player)
	return player


func _set_music(on: bool) -> void:
	music_on = on and _music != null
	if music_on and float(_settings["music_volume"]) <= 0.0:
		# Switching on music that was turned right down brings it back up.
		_settings["music_volume"] = 0.5
		_apply_volumes()
	if _music != null:
		_music.stream_paused = not music_on
		if music_on and not _music.playing:
			_music.play()
	_save_settings()


## One toggle covers the chimes and the ambience; the music has its own.
func _set_sound(on: bool) -> void:
	sound_on = on
	if on and float(_settings["sound_volume"]) <= 0.0:
		_settings["sound_volume"] = 0.5
		_apply_volumes()
	for player: AudioStreamPlayer in [_ambience_day, _ambience_night]:
		if player != null:
			player.stream_paused = not on
			if on and not player.playing:
				player.play()
	_mix_ambience()
	_save_settings()


## How much of the day bed (rather than the night crickets) to hear at a time
## of day given in minutes after midnight: 1 by day, 0 by night, a straight
## ramp through dawn and dusk.
static func day_share(minute_of_day: int) -> float:
	if minute_of_day < DAWN_START or minute_of_day >= DUSK_END:
		return 0.0
	if minute_of_day < DAWN_END:
		return float(minute_of_day - DAWN_START) / float(DAWN_END - DAWN_START)
	if minute_of_day < DUSK_START:
		return 1.0
	return 1.0 - float(minute_of_day - DUSK_START) / float(DUSK_END - DUSK_START)


## Sets the two ambience levels from the simulation clock (never wall-clock
## time). An equal-power crossfade keeps the overall level steady at dusk.
func _mix_ambience() -> void:
	if _ambience_day == null or _ambience_night == null or simulation == null:
		return
	if not sound_on:
		_ambience_day.volume_db = SILENT_DB
		_ambience_night.volume_db = SILENT_DB
		return
	var share: float = day_share(simulation.clock.minute_of_day)
	_ambience_day.volume_db = _ambience_db(sin(share * PI * 0.5))
	_ambience_night.volume_db = _ambience_db(cos(share * PI * 0.5))


static func _ambience_db(gain: float) -> float:
	if gain <= 0.001:
		return SILENT_DB
	return maxf(AMBIENCE_VOLUME_DB + linear_to_db(gain), SILENT_DB)


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
	for entry: Array in [["music", _music], ["talk chime", _chime_talk], ["notice chime", _chime_notice],
			["day ambience", _ambience_day], ["night ambience", _ambience_night]]:
		var player: AudioStreamPlayer = entry[1]
		if player == null or player.stream == null or player.stream.get_length() <= 0.0:
			problems.append("%s did not load" % entry[0])
		else:
			print("SELF-CHECK  %s loaded, %.1f seconds" % [entry[0], player.stream.get_length()])
	for entry: Array in [["music", _music], ["day ambience", _ambience_day], ["night ambience", _ambience_night]]:
		var looped: AudioStreamPlayer = entry[1]
		if looped != null and not (looped.stream as AudioStreamOggVorbis).loop:
			problems.append("%s is not set to loop" % entry[0])
	for entry: Array in [[0, 0.0], [300, 0.25], [720, 1.0], [1170, 0.5], [1260, 0.0]]:
		if not is_equal_approx(day_share(entry[0]), entry[1]):
			problems.append("ambience mix at minute %d is %.2f, expected %.2f" % [entry[0], day_share(entry[0]), entry[1]])
	print("SELF-CHECK  ambience follows the clock: day share %.2f at noon, %.2f at 19:30, %.2f at midnight" \
			% [day_share(720), day_share(1170), day_share(0)])
	for entry: Array in [["music", _music], ["day ambience", _ambience_day], ["night ambience", _ambience_night]]:
		var silent: AudioStreamPlayer = entry[1]
		if silent != null and silent.playing:
			problems.append("%s is playing during the check" % entry[0])
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
	for building_id: String in simulation.area.sorted_building_ids():
		_show_building(building_id)
	_show_week(_week_start, "This week so far")
	if not hud.sheet_is_open():
		problems.append("the week summary did not open")
	hud.close_sheet()
	# Save and load through the menu's own path, into a scratch folder.
	save_path = OS.get_temp_dir().path_join("neighborhood_selfcheck_%d" % OS.get_process_id()).path_join("saved_game.json")
	var saved_hash: String = simulation.state_hash()
	var save_problem: String = _save_game()
	if save_problem != "":
		problems.append("saving from the menu failed: " + save_problem)
	simulation.advance_minutes(120)
	var load_problem: String = _load_game()
	if load_problem != "":
		problems.append("loading from the menu failed: " + load_problem)
	elif simulation.state_hash() != saved_hash:
		problems.append("the loaded game is not the game that was saved")
	else:
		print("SELF-CHECK  saved and loaded through the menu; the state is identical")
	hud.close_sheet()
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path.get_base_dir())
	if _last_activity.size() != simulation.state.people.size():  # one per resident
		problems.append("not everyone has an activity bubble")
	await _check_front_screens(problems)
	for problem: String in problems:
		print("SELF-CHECK  PROBLEM: " + problem)
	print("SELF-CHECK  %s" % ("passed" if problems.is_empty() else "FAILED"))
	get_tree().quit(0 if problems.is_empty() else 1)


## Part of the self-check: the settings sheet changes the volume live, the
## game can go back to the title and start again, and none of it writes the
## settings file.
func _check_front_screens(problems: Array[String]) -> void:
	var settings_file: String = ProjectSettings.globalize_path(SETTINGS_PATH)
	var file_before: int = FileAccess.get_modified_time(settings_file) if FileAccess.file_exists(settings_file) else -1
	_show_menu()
	_open_settings()
	if not _settings_sheet.is_open():
		problems.append("the settings sheet did not open")
	_settings_sheet.set_music_percent(40)
	var bus: int = AudioServer.get_bus_index(MUSIC_BUS)
	if bus == -1 or not is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.4)):
		problems.append("the music volume slider did not reach the music bus")
	elif _music == null or _music.bus != MUSIC_BUS or _chime_notice == null or _chime_notice.bus != SOUNDS_BUS:
		problems.append("the sounds are not routed through the Music and Sounds buses")
	else:
		print("SELF-CHECK  settings sheet opened; music volume 40%% is %.1f dB on the Music bus" % AudioServer.get_bus_volume_db(bus))
	_settings_sheet.close()
	if not hud.sheet_is_open():
		problems.append("closing the settings sheet also closed the menu under it")

	await _go_to_title()
	if world_view != null or hud != null or not _title.visible:
		problems.append("Main menu did not return to the title screen")
	elif _title.button_count() != 4:
		problems.append("the title screen has %d buttons, expected 4" % _title.button_count())
	else:
		print("SELF-CHECK  returned to the title screen; Continue is %s" % ("enabled" if FileAccess.file_exists(save_path) else "disabled (no saved game)"))
	_open_settings()
	_settings_sheet.close()
	await _on_new_game()
	if world_view == null or _title.visible or not hud.sheet_is_open():
		problems.append("New game from the title did not start a game with the welcome card")
	else:
		print("SELF-CHECK  started a new game from the title; the welcome card is open")
	hud.close_sheet()
	var file_after: int = FileAccess.get_modified_time(settings_file) if FileAccess.file_exists(settings_file) else -1
	if file_after != file_before:
		problems.append("the self-check wrote the settings file")
	else:
		print("SELF-CHECK  the settings file was not written")


## Opens the sheet asked for with "--show <name>" before a screenshot.
func _show_for_screenshot() -> void:
	match _screenshot_sheet:
		"building":
			_show_building(simulation.area.sorted_building_ids()[0])
		"store":
			_show_building(simulation.area.institution_of_kind("store"))
		"menu":
			_show_menu()
		"week":
			_show_week(WeekSummary.week_start(simulation.clock.day_index - 1), "The week that was")
		"welcome":
			_show_welcome()
		"settings":
			_open_settings()
		"paused":
			speed_index = 0
			_fx.set_paused(true)
		"banner":
			_fx.show_day(simulation.clock.day_index)
		"leave":
			_confirm_main_menu()


## A short welcome at the start of a new game: what this is, and the controls.
func _show_welcome() -> void:
	var household: String = simulation.state.households[simulation.state.player_household_id()]["name"]
	var lines: Array[String] = [
		"You look after the [b]%s[/b] for one week in spring 1950, minute by minute. The neighbors live their own lives, and so does your family unless you step in." % household,
		"",
		"[color=#ffeb8c]Fixture Street is a made-up test street used while the game is being built. It is not a real place, and everyone on it is invented.[/color]",
		"",
		"[b]Playing[/b]",
		"[ul]Click someone in your household (in blue), then click a neighbor to talk, a house to visit, or a room in [i]Inside your home[/i].",
		"Right-click any building to read about it.[/ul]",
		"",
		"[b]Keys[/b]",
		"  [b]Space[/b] pause      [b]1 2 3[/b] speed      [b]Esc[/b] menu and settings",
		"  [b]M[/b] music on or off      [b]N[/b] sounds on or off      [b]F11[/b] full screen",
		"  [b]Scroll[/b] zoom      [b]Drag[/b] or [b]arrows[/b] look around      [b]R[/b] reset the view",
		"  [b]F[/b] follow the selected person",
	]
	_open_sheet("Welcome to Fixture Street", "\n".join(lines), [], "Start the week")


## Development aid: run some minutes, save a picture of the screen, and quit.
func _take_screenshot() -> void:
	set_process(false)
	if _screenshot_sheet == "title":
		await get_tree().create_timer(1.6).timeout  # let the title fade in
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_screenshot_path)
		get_tree().quit()
		return
	simulation.advance_minutes(maxi(_screenshot_minutes - 3, 0))
	_watch(false)
	for i: int in mini(_screenshot_minutes, 3):
		simulation.advance_minutes(1)
		world_view.after_ticks()
		_watch(true)
	world_view.minute_fraction = 1.0
	world_view.selected_id = selected_id
	world_view.set_zoom(_screenshot_zoom)
	world_view.queue_redraw()
	hud.refresh(selected_id, speed_index, music_on, sound_on)
	_show_for_screenshot()
	await get_tree().create_timer(0.6).timeout  # let bubbles finish popping
	world_view.queue_redraw()
	hud.refresh(selected_id, speed_index, music_on, sound_on)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_screenshot_path)
	get_tree().quit()
