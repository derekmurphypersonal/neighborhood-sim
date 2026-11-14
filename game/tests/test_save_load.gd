extends "res://tests/test_case.gd"
## Saving and loading reproduce a run exactly (docs/M1_PLAN.md, section 5a).

const SimDate := preload("res://sim/clock/sim_date.gd")
const Simulation := preload("res://sim/simulation.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")
const SaveGame := preload("res://sim/io/save_game.gd")

const SCENARIO: String = "fixture_street_spring_1950"
const TOTAL_MINUTES: int = 6000  # Monday 06:00 to Friday 10:00, crossing a payday

## Orders given by a pretend player, as [minute offset, person, order].
const SCRIPT: Array = [
	[45, "fx_p_01", {"kind": "talk_to", "other_id": "fx_p_08"}],
	[700, "fx_p_01", {"kind": "go_to", "place_id": "fx_bd_6"}],
	[2000, "fx_p_02", {"kind": "talk_to", "other_id": "fx_p_05"}],
	[3100, "fx_p_03", {"kind": "go_home"}],
]


func _new() -> Simulation:
	return Simulation.new_game(WorldLoader.load_world(SCENARIO), 1950)


## Advances to a minute offset from the start, giving scripted orders on the way.
func _advance(simulation: Simulation, start: int, to_offset: int, with_orders: bool) -> void:
	while simulation.clock.abs_minute() - start < to_offset:
		if with_orders:
			for entry: Array in SCRIPT:
				if simulation.clock.abs_minute() - start == entry[0]:
					simulation.give_order(entry[1], entry[2])
		simulation.tick()


func _reload(simulation: Simulation) -> Simulation:
	return SaveGame.restore(SaveGame.to_text(simulation), WorldLoader.load_world(SCENARIO))["simulation"]


func test_state_has_no_fractional_numbers() -> void:
	var simulation: Simulation = _new()
	simulation.advance_minutes(2 * SimDate.MINUTES_PER_DAY)
	check(not SaveGame.contains_float(simulation.to_save()), "simulation state holds whole numbers only")


func test_save_load_save_is_identical() -> void:
	var simulation: Simulation = _new()
	simulation.advance_minutes(1777)
	var first_text: String = SaveGame.to_text(simulation)
	var reloaded: Simulation = _reload(simulation)
	check_eq(SaveGame.to_text(reloaded), first_text, "a reloaded game saves to exactly the same text")
	check_eq(reloaded.state_hash(), simulation.state_hash(), "and has the same state hash")
	check_eq(reloaded.clock.describe(), simulation.clock.describe(), "and the same time")


func test_continuing_after_a_save_matches_running_straight_through() -> void:
	var straight: Simulation = _new()
	var start: int = straight.clock.abs_minute()
	_advance(straight, start, TOTAL_MINUTES, false)
	var expected: String = straight.state_hash()
	# Save points: the first minute, mid-morning, overnight, around midnight
	# on payday, and late in the run.
	for save_at: int in [1, 137, 1000, 3000, 5399, 5400, 5401, 5999]:
		var simulation: Simulation = _new()
		_advance(simulation, start, save_at, false)
		var resumed: Simulation = _reload(simulation)
		_advance(resumed, start, TOTAL_MINUTES, false)
		check_eq(resumed.state_hash(), expected, "save at minute %d, load and continue" % save_at)


func test_continuing_after_a_save_with_player_orders() -> void:
	var straight: Simulation = _new()
	var start: int = straight.clock.abs_minute()
	_advance(straight, start, TOTAL_MINUTES, true)
	var expected: String = straight.state_hash()
	var without: Simulation = _new()
	_advance(without, start, TOTAL_MINUTES, false)
	check(without.state_hash() != expected, "the orders change what happens")
	# 46 is one minute after an order is given: it is still waiting to be carried out.
	for save_at: int in [46, 60, 705, 2010, 3101]:
		var simulation: Simulation = _new()
		_advance(simulation, start, save_at, true)
		var resumed: Simulation = _reload(simulation)
		_advance(resumed, start, TOTAL_MINUTES, true)
		check_eq(resumed.state_hash(), expected, "with orders: save at minute %d, load and continue" % save_at)


func test_save_records_what_it_was_made_from() -> void:
	var simulation: Simulation = _new()
	var parsed: Dictionary = SaveGame.parse(SaveGame.to_text(simulation))
	check(parsed["ok"], "a save can be read back")
	var document: Dictionary = parsed["document"]
	check_eq(document["scenario_id"], SCENARIO, "the scenario is recorded")
	check_eq(document["simulation"]["rng"]["method"], "fnv1a64-v1", "the seeding method is recorded")
	var world: Dictionary = WorldLoader.load_world(SCENARIO)
	check_eq(SaveGame.changed_data(document, world), [] as Array[String], "unchanged data is recognized")
	var first_path: String = world["fingerprints"].keys()[0]
	world["fingerprints"][first_path] = "different"
	check_eq(SaveGame.changed_data(document, world).size(), 1, "changed data is detected")


func test_unreadable_saves_are_refused() -> void:
	check(not SaveGame.parse("not a save")["ok"], "nonsense is refused")
	check(not SaveGame.parse("{\"format_version\": 999}")["ok"], "another format version is refused")
	check(not SaveGame.parse("{\"format_version\": 1}")["ok"], "a save with parts missing is refused")
	check(not SaveGame.parse("[1, 2, 3]")["ok"], "JSON that is not a save is refused")
	for text: String in ["not a save", "{\"format_version\": 1}"]:
		var parsed: Dictionary = SaveGame.parse(text)
		check(parsed["error"] != "", "a refusal says why")
		check_eq(parsed["document"], {}, "a refused save yields no document")


## The contract: to_text() writes a whole save; restore() is the one call
## that turns save text back into a running simulation, or says why not.
func test_restore_gives_back_the_simulation() -> void:
	var simulation: Simulation = _new()
	simulation.advance_minutes(900)
	var world: Dictionary = WorldLoader.load_world(SCENARIO)
	var restored: Dictionary = SaveGame.restore(SaveGame.to_text(simulation), world)
	check(restored["ok"], "a good save is restored")
	check_eq(restored["error"], "", "with no error")
	check_eq(restored["changed_data"], [] as Array[String], "and no changed data")
	check_eq((restored["simulation"] as Simulation).state_hash(), simulation.state_hash(), "to exactly the same state")


func test_restore_refuses_without_crashing() -> void:
	var world: Dictionary = WorldLoader.load_world(SCENARIO)
	for text: String in ["", "not a save", "{\"format_version\": 999}", "{\"format_version\": 1}"]:
		var restored: Dictionary = SaveGame.restore(text, world)
		check(not restored["ok"], "bad save text is refused")
		check(restored["simulation"] == null, "and no simulation is produced")
		check(restored["error"] != "", "and the reason is given")
	# A save from another scenario must not be loaded into this world.
	var document: Dictionary = SaveGame.parse(SaveGame.to_text(_new()))["document"]
	document["scenario_id"] = "some_other_scenario"
	var wrong: Dictionary = SaveGame.restore(JSON.stringify(document), world)
	check(not wrong["ok"], "a save from a different scenario is refused")


func test_restore_reports_changed_data() -> void:
	var simulation: Simulation = _new()
	var world: Dictionary = WorldLoader.load_world(SCENARIO)
	world["fingerprints"][world["fingerprints"].keys()[0]] = "different"
	var restored: Dictionary = SaveGame.restore(SaveGame.to_text(simulation), world)
	check(restored["ok"], "a save still loads when data files have changed")
	check_eq(restored["changed_data"].size(), 1, "but the change is reported")


## Writing and reading a save file. Uses a scratch folder of its own, so the
## test does not depend on the per-user data folder being writable.
func test_save_file_round_trip() -> void:
	var simulation: Simulation = _new()
	simulation.advance_minutes(500)
	var folder: String = OS.get_temp_dir().path_join("neighborhood_test_%d" % OS.get_process_id())
	var path: String = folder.path_join("saves").path_join("test_save.json")
	check_eq(SaveGame.write_file(path, SaveGame.to_text(simulation)), "", "the save file is written, creating its folder")
	check_eq(SaveGame.write_file(path, SaveGame.to_text(simulation)), "", "and can be written over")
	check(not FileAccess.file_exists(path + ".tmp"), "leaving no temporary file behind")
	var read: Dictionary = SaveGame.read_file(path)
	check(read["ok"], "and read back")
	var restored: Dictionary = SaveGame.restore(read["text"], WorldLoader.load_world(SCENARIO))
	check(restored["ok"], "and restored")
	if restored["ok"]:
		check_eq((restored["simulation"] as Simulation).state_hash(), simulation.state_hash(), "with the same state")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder.path_join("saves"))
	DirAccess.remove_absolute(folder)
	check(not DirAccess.dir_exists_absolute(folder), "and the scratch folder is cleaned up")


func test_file_problems_are_reported_not_fatal() -> void:
	# A regular file stands where a folder would be needed, so nothing can be created under it.
	var blocker: String = OS.get_temp_dir().path_join("neighborhood_blocker_%d" % OS.get_process_id())
	check_eq(SaveGame.write_file(blocker, "x"), "", "set up a plain file")
	var impossible: String = blocker.path_join("saves").path_join("test_save.json")
	check(SaveGame.write_file(impossible, "text") != "", "a save that cannot be written reports why")
	var missing: Dictionary = SaveGame.read_file(impossible)
	check(not missing["ok"] and missing["error"] != "", "a save that cannot be read reports why")
	DirAccess.remove_absolute(blocker)


# --- Every state field (M1-B step 10) ----------------------------------------

const Records := preload("res://sim/state/records.gd")
const Economy := preload("res://sim/systems/economy.gd")


## Runs until something is true, at most a week. Returns whether it happened.
func _run_until(simulation: Simulation, condition: Callable) -> bool:
	for minute: int in 7 * SimDate.MINUTES_PER_DAY:
		if condition.call():
			return true
		simulation.tick()
	return false


func _anyone(simulation: Simulation, test: Callable) -> bool:
	for person_id: String in simulation.state.sorted_person_ids():
		if test.call(simulation.state.people[person_id]):
			return true
	return false


## Saves, reloads, and checks the copy is the same now and stays the same.
func _check_exact(simulation: Simulation, moment: String) -> void:
	var reloaded: Simulation = _reload(simulation)
	check_eq(SaveGame.to_text(reloaded), SaveGame.to_text(simulation), "%s: the reloaded game saves to the same text" % moment)
	simulation.advance_minutes(3 * SimDate.MINUTES_PER_DAY)
	reloaded.advance_minutes(3 * SimDate.MINUTES_PER_DAY)
	check_eq(reloaded.state_hash(), simulation.state_hash(), "%s: three days later the two are still identical" % moment)


func test_every_record_field_is_in_the_save() -> void:
	var simulation: Simulation = _new()
	simulation.advance_minutes(600)
	var saved: Dictionary = SaveGame.parse(SaveGame.to_text(simulation))["document"]["simulation"]["state"]
	var person_fields: Array = Records.new_person("x", "x", "x", 0, "x").keys()
	var household_fields: Array = Records.new_household("x", "x", "x").keys()
	var relationship_fields: Array = Records.new_relationship("a", "b").keys()
	var action_fields: Array = Records.new_action("x", "x", "x", "x").keys()
	check(person_fields.has("daily_wage_cents") and person_fields.has("worked_minutes_today") and person_fields.has("spot"), "the person record has the M1-B fields")
	check(household_fields.has("pantry_meals") and household_fields.has("rent_owed_cents") and household_fields.has("wages_due_cents"), "the household record has the M1-B fields")
	check(Records.NEED_NAMES.has("fun"), "fun is a need")
	for person_id: String in saved["people"]:
		for field: String in person_fields:
			check(saved["people"][person_id].has(field), "saved person %s has %s" % [person_id, field])
		for need: String in Records.NEED_NAMES:
			check(saved["people"][person_id]["needs"].has(need), "saved person %s has the need %s" % [person_id, need])
		var action: Dictionary = saved["people"][person_id]["action"]
		for field: String in action_fields:
			check(action.is_empty() or action.has(field), "saved action of %s has %s" % [person_id, field])
	for household_id: String in saved["households"]:
		for field: String in household_fields:
			check(saved["households"][household_id].has(field), "saved household %s has %s" % [household_id, field])
	for key: String in saved["relationships"]:
		for field: String in relationship_fields:
			check(saved["relationships"][key].has(field), "saved relationship %s has %s" % [key, field])
	check(saved.has("last_abstract_day"), "the last abstract day is saved")


func test_new_field_values_come_back_exactly() -> void:
	var simulation: Simulation = _new()
	simulation.advance_minutes(300)
	var household: Dictionary = simulation.state.households["fx_hh_1"]
	household["rent_owed_cents"] = 321
	household["wages_due_cents"] = 2200
	household["pantry_meals"] = 5
	household["last_empty_pantry_day"] = simulation.clock.day_index
	simulation.state.people["fx_p_02"]["worked_minutes_today"] = 123
	simulation.state.people["fx_p_01"]["needs"]["fun"] = 12345
	simulation.state.people["fx_p_01"]["last_set_meal_day"] = simulation.clock.day_index
	simulation.state.last_abstract_day = simulation.clock.day_index - 1
	var reloaded: Simulation = _reload(simulation)
	var copy: Dictionary = reloaded.state.households["fx_hh_1"]
	for field: String in ["rent_owed_cents", "wages_due_cents", "pantry_meals", "last_empty_pantry_day", "funds_cents", "weekly_rent_cents", "other_weekly_income_cents"]:
		check_eq(copy[field], household[field], "household %s comes back" % field)
	check_eq(reloaded.state.people["fx_p_02"]["worked_minutes_today"], 123, "minutes worked today come back")
	check_eq(reloaded.state.people["fx_p_02"]["daily_wage_cents"], simulation.state.people["fx_p_02"]["daily_wage_cents"], "the wage comes back")
	check_eq(reloaded.state.people["fx_p_11"]["workplace_id"], "fx_bd_6", "the workplace comes back")
	check_eq(reloaded.state.people["fx_p_01"]["needs"]["fun"], 12345, "fun comes back")
	check_eq(reloaded.state.people["fx_p_01"]["last_set_meal_day"], simulation.clock.day_index, "the day of the last set meal comes back")
	check_eq(reloaded.state.last_abstract_day, simulation.clock.day_index - 1, "the last abstract day comes back")
	check_eq(reloaded.state_hash(), simulation.state_hash(), "and the whole state is identical")


func test_saving_in_the_middle_of_a_shopping_trip() -> void:
	var simulation: Simulation = _new()
	var found: bool = _run_until(simulation, func() -> bool: return _anyone(simulation, func(person: Dictionary) -> bool:
		return not person["action"].is_empty() and person["action"]["kind"] == "shop" and person["action"]["started"]))
	check(found, "someone goes shopping within the week")
	_check_exact(simulation, "mid-shopping")


func test_saving_while_a_talk_holds_up_something_else() -> void:
	var simulation: Simulation = _new()
	var found: bool = _run_until(simulation, func() -> bool: return _anyone(simulation, func(person: Dictionary) -> bool:
		return not person["action"].is_empty() and person["action"]["kind"] == "talk" and not (person["action"]["resume"] as Dictionary).is_empty()))
	check(found, "a talk interrupts something to be taken up again within the week")
	_check_exact(simulation, "mid-talk with something to resume")


func test_saving_with_someone_in_a_room_and_someone_in_the_store() -> void:
	var simulation: Simulation = _new()
	var found: bool = _run_until(simulation, func() -> bool:
		return _anyone(simulation, func(person: Dictionary) -> bool: return person["spot"] != "") \
			and _anyone(simulation, func(person: Dictionary) -> bool: return person["at"] == Records.AT_INSIDE and person["place_id"] == "fx_bd_6" and person["action"].get("kind", "") != "work"))
	check(found, "someone is in a room of the home while a visitor is in the store")
	_check_exact(simulation, "in a room and in the store")


func test_saving_with_wages_earned_and_rent_owed() -> void:
	var simulation: Simulation = _new()
	simulation.state.households["fx_hh_1"]["funds_cents"] = 0
	simulation.state.households["fx_hh_1"]["weekly_rent_cents"] = 100000  # more than a week's wages: Monday's rent cannot be met
	simulation.state.households["fx_hh_1"]["pantry_meals"] = 0
	var found: bool = _run_until(simulation, func() -> bool:
		var household: Dictionary = simulation.state.households["fx_hh_1"]
		return household["rent_owed_cents"] > 0 and household["wages_due_cents"] > 0)
	check(found, "the household owes rent and has wages coming")
	check(simulation.state.households["fx_hh_1"]["last_empty_pantry_day"] >= 0, "and has had an empty pantry")
	_check_exact(simulation, "rent owed and wages earned")


func test_saving_after_abstract_days() -> void:
	var simulation: Simulation = _new()
	simulation.advance_minutes(SimDate.MINUTES_PER_DAY - simulation.clock.minute_of_day)
	simulation.advance_to_day_abstract(simulation.clock.day_index + 3)
	check_eq(simulation.state.last_abstract_day, simulation.clock.day_index - 1, "yesterday was run abstractly")
	_check_exact(simulation, "the morning after abstract days")


func test_a_week_with_a_save_in_the_middle_matches_a_week_straight_through() -> void:
	var straight: Simulation = _new()
	straight.advance_minutes(7 * SimDate.MINUTES_PER_DAY)
	var stopped: Simulation = _new()
	stopped.advance_minutes(3 * SimDate.MINUTES_PER_DAY + 257)
	stopped = _reload(stopped)
	stopped.advance_minutes(7 * SimDate.MINUTES_PER_DAY - (3 * SimDate.MINUTES_PER_DAY + 257))
	check_eq(stopped.state_hash(), straight.state_hash(), "a full week, with wages, rent and shopping, is identical either way")
