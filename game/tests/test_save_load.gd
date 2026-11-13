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
	var parsed: Dictionary = SaveGame.parse(SaveGame.to_text(simulation))
	return Simulation.from_save(WorldLoader.load_world(SCENARIO), parsed["document"]["simulation"])


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


func test_save_file_round_trip() -> void:
	var simulation: Simulation = _new()
	simulation.advance_minutes(500)
	var path: String = OS.get_user_data_dir().path_join("test_save.json")
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	check(SaveGame.write_file(path, SaveGame.to_text(simulation)), "the save file is written")
	var parsed: Dictionary = SaveGame.parse(FileAccess.get_file_as_string(path))
	check(parsed["ok"], "and read back")
	var reloaded: Simulation = Simulation.from_save(WorldLoader.load_world(SCENARIO), parsed["document"]["simulation"])
	check_eq(reloaded.state_hash(), simulation.state_hash(), "with the same state")
	DirAccess.remove_absolute(path)
