extends "res://tests/test_case.gd"
## Headless decade run, reproducibility and immutability of authored data
## (D-013, D-017, D-023, D-025, D-029). Runs on the fictional fixture.

const SimDate := preload("res://sim/clock/sim_date.gd")
const Simulation := preload("res://sim/simulation.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")
const DataFiles := preload("res://sim/io/data_files.gd")

const SCENARIO: String = "fixture_street_spring_1950"


func _decade(seed_value: int) -> Simulation:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), seed_value, 0, 0)
	simulation.run_to_end_of_decade()
	return simulation


func test_scenario_starts_in_spring_1950() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1)
	check_eq(simulation.state.people.size(), 17, "seventeen residents (M1-B asks for fifteen to twenty-five)")
	check_eq(simulation.state.households.size(), 5, "five households (M1-B asks for four to six)")
	check_eq(simulation.clock.describe(), "Monday 1950-04-03 06:00", "the scenario's own start (D-034)")
	check_eq(simulation.state.player_household_id(), "fx_hh_1", "one player household")


func test_decade_runs_to_the_end() -> void:
	var simulation: Simulation = _decade(1950)
	check(simulation.clock.is_finished(), "the clock passed 1959-12-31")
	check_eq(simulation.clock.day_index, SimDate.TOTAL_DAYS, "exactly 3,652 days were simulated")


func test_every_birthday_is_logged() -> void:
	var simulation: Simulation = _decade(1950)
	var birthdays: int = 0
	var leapling_days: Array[String] = []
	var ids_in_order: bool = true
	var last_id: int = 0
	for event: Dictionary in simulation.state.event_log:
		ids_in_order = ids_in_order and event["id"] == last_id + 1
		last_id = event["id"]
		if event["type"] == "birthday":
			birthdays += 1
			if event["person_id"] == "fx_p_04":
				leapling_days.append(SimDate.to_iso(event["day"]))
	check_eq(birthdays, 170, "ten birthdays each for seventeen residents")
	check(leapling_days.has("1952-02-29") and leapling_days.has("1953-03-01"), "leap-day birthday observed correctly")
	check(ids_in_order, "events are numbered in order")


func test_same_seed_gives_identical_decade() -> void:
	check_eq(_decade(1950).state_hash(), _decade(1950).state_hash(), "two runs from the same seed have the same state hash")


func test_different_seed_gives_different_decade() -> void:
	check(_decade(1950).state_hash() != _decade(1951).state_hash(), "a different seed changes the outcome")


func test_stopping_and_continuing_matches_running_straight_through() -> void:
	var straight: Simulation = _decade(77)
	var stepped: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 77, 0, 0)
	stepped.advance_to_day_abstract(SimDate.to_day_index(1953, 6, 1))
	stepped.advance_to_day_abstract(SimDate.to_day_index(1957, 2, 14))
	stepped.run_to_end_of_decade()
	check_eq(stepped.state_hash(), straight.state_hash(), "skipping in stages does not disconnect the world")


func test_minute_by_minute_run_is_reproducible() -> void:
	var first: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 5)
	var second: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 5)
	first.advance_minutes(3 * SimDate.MINUTES_PER_DAY)
	second.advance_minutes(3 * SimDate.MINUTES_PER_DAY)
	check_eq(first.state_hash(), second.state_hash(), "three days at close detail repeat exactly")
	var other: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 6)
	other.advance_minutes(3 * SimDate.MINUTES_PER_DAY)
	check(other.state_hash() != first.state_hash(), "a different seed gives different days")


func test_day_level_work_agrees_between_detail_levels() -> void:
	# Two weeks from a midnight start: once minute by minute, once day by day.
	var close: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 9, 92, 0)
	var abstract: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 9, 92, 0)
	close.advance_minutes(14 * SimDate.MINUTES_PER_DAY)
	abstract.advance_to_day_abstract(92 + 14)
	check_eq(close.clock.to_save(), abstract.clock.to_save(), "both reach the same moment")
	for household_id: String in close.state.sorted_household_ids():
		check_eq(
			close.state.households[household_id]["funds_cents"],
			abstract.state.households[household_id]["funds_cents"],
			"household money agrees for " + household_id
		)


func test_run_does_not_modify_authored_data() -> void:
	var before: Dictionary = DataFiles.hash_tree(DataFiles.data_root())
	_decade(1950)
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 3)
	simulation.advance_minutes(SimDate.MINUTES_PER_DAY)
	var after: Dictionary = DataFiles.hash_tree(DataFiles.data_root())
	check(before.size() > 0, "data files were found")
	check_eq(after, before, "every file under data/ is byte-identical after running")
