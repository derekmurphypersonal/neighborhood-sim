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
