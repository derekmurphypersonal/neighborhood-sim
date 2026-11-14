extends "res://tests/test_case.gd"
## The end-of-week summary (M1-B step 8) is made from the event log alone.

const Simulation := preload("res://sim/simulation.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")
const WeekSummary := preload("res://sim/reports/week_summary.gd")
const SimDate := preload("res://sim/clock/sim_date.gd")

const SCENARIO: String = "fixture_street_spring_1950"
const HOUSEHOLD: String = "fx_hh_1"
const DAY: int = 1440


func test_a_week_runs_monday_to_sunday() -> void:
	var monday: int = int(SimDate.parse_iso("1950-04-03"))
	check_eq(SimDate.weekday(monday), 1, "3 April 1950 was a Monday")
	for offset: int in 7:
		check_eq(WeekSummary.week_start(monday + offset), monday, "day %d of the week belongs to that Monday" % offset)
	check_eq(WeekSummary.week_start(monday + 7), monday + 7, "the next Monday starts a new week")
	check_eq(WeekSummary.week_start(monday - 1), monday - 7, "the Sunday before belongs to the week before")


func test_summary_counts_only_the_log() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1)
	var state: RefCounted = simulation.state
	state.event_log.clear()
	state.log_event(10, 0, "payday", 1, {"household_id": HOUSEHOLD, "wages_cents": 4400, "other_cents": 100})
	state.log_event(10, 0, "payday", 1, {"household_id": "fx_hh_2", "wages_cents": 9999, "other_cents": 0})
	state.log_event(11, 0, "rent_paid", 2, {"household_id": HOUSEHOLD, "paid_cents": 1000, "short_cents": 400})
	state.log_event(11, 600, "shopping", 1, {"household_id": HOUSEHOLD, "person_id": "fx_p_01", "meals": 10, "cost_cents": 220, "wanted_meals": 12})
	state.log_event(11, 600, "household_short_of_money", 2, {"household_id": HOUSEHOLD, "reason": "groceries"})
	state.log_event(12, 0, "missed_work", 2, {"household_id": HOUSEHOLD, "person_id": "fx_p_02", "lost_cents": 1100})
	state.log_event(12, 700, "empty_pantry", 2, {"household_id": HOUSEHOLD})
	state.log_event(12, 800, "birthday", 2, {"person_id": "fx_p_03", "age": 9})
	state.log_event(12, 800, "birthday", 2, {"person_id": "fx_p_05", "age": 65})
	state.log_event(12, 900, "conversation", 1, {"a": "fx_p_01", "b": "fx_p_05", "minutes": 10, "a_change": 3, "b_change": -1, "first_meeting": true, "place_id": ""})
	state.log_event(13, 900, "conversation", 1, {"a": "fx_p_05", "b": "fx_p_01", "minutes": 12, "a_change": 2, "b_change": 4, "first_meeting": false, "place_id": ""})
	state.log_event(13, 950, "conversation", 1, {"a": "fx_p_01", "b": "fx_p_02", "minutes": 20, "a_change": 1, "b_change": 1, "first_meeting": false, "place_id": ""})
	state.log_event(13, 960, "conversation", 1, {"a": "fx_p_05", "b": "fx_p_07", "minutes": 20, "a_change": 1, "b_change": 1, "first_meeting": true, "place_id": ""})
	state.log_event(20, 0, "payday", 1, {"household_id": HOUSEHOLD, "wages_cents": 7777, "other_cents": 0})

	var summary: Dictionary = WeekSummary.summarize(state, HOUSEHOLD, 10, 16)
	check_eq(summary["wages_cents"], 4400, "wages from this household's payday in the week only")
	check_eq(summary["other_income_cents"], 100, "other income")
	check_eq(summary["rent_paid_cents"], 1000, "rent paid")
	check_eq(summary["rent_short_cents"], 400, "rent still owed")
	check_eq(summary["groceries_cents"], 220, "groceries")
	check_eq(summary["meals_bought"], 10, "meals bought")
	check_eq(summary["shopping_trips"], 1, "shopping trips")
	check_eq(summary["net_cents"], 4400 + 100 - 1000 - 220, "net is income less rent and groceries")
	check_eq(summary["days_missed"], 1, "days of work missed")
	check_eq(summary["wages_lost_cents"], 1100, "wages lost")
	check_eq(summary["thin_meal_days"], 1, "days with an empty pantry")
	check_eq(summary["times_short"], 1, "times short of money")
	check_eq(summary["birthdays"], [{"person_id": "fx_p_03", "age": 9}], "only the household's own birthdays")
	check_eq(summary["conversations"], 2, "talks with people outside the household")
	check_eq(summary["minutes_talking"], 22, "minutes of those talks")
	check_eq(summary["first_meetings"], [["fx_p_01", "fx_p_05"]], "first meetings")
	check_eq(summary["neighbors"], [
		{"member_id": "fx_p_01", "other_id": "fx_p_05", "talks": 2, "member_change": 7, "other_change": 1},
	], "regard changes added up for each pair, whichever way round the talk was logged")


func test_summary_accounts_for_every_cent() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1950)
	var start: int = simulation.clock.day_index
	var before: Dictionary = {}
	for household_id: String in simulation.state.sorted_household_ids():
		before[household_id] = simulation.state.households[household_id]["funds_cents"]
	# The first week, and one minute into the second so that Monday's rent is in neither.
	simulation.advance_minutes(DAY * 7 - simulation.clock.minute_of_day)
	for household_id: String in simulation.state.sorted_household_ids():
		var summary: Dictionary = WeekSummary.summarize(simulation.state, household_id, start, start + 6)
		check_eq(
			simulation.state.households[household_id]["funds_cents"] - before[household_id], summary["net_cents"],
			"%s: the summary's net is exactly the change in money" % household_id
		)
	var players: Dictionary = WeekSummary.summarize(simulation.state, HOUSEHOLD, start, start + 6)
	check(players["wages_cents"] > 0, "the player's household was paid")
	check(players["shopping_trips"] > 0, "and went shopping")
	check(players["conversations"] > 0, "and talked to neighbors")


func test_summary_survives_save_and_load() -> void:
	var SaveGame: GDScript = load("res://sim/io/save_game.gd")
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 4)
	simulation.advance_minutes(DAY * 3)
	var start: int = WeekSummary.week_start(simulation.clock.day_index)
	var restored: Dictionary = SaveGame.restore(SaveGame.to_text(simulation), WorldLoader.load_world(SCENARIO))
	check(restored["ok"], "the save loads")
	check_eq(
		WeekSummary.summarize(restored["simulation"].state, HOUSEHOLD, start, start + 6),
		WeekSummary.summarize(simulation.state, HOUSEHOLD, start, start + 6),
		"the same summary before and after"
	)
