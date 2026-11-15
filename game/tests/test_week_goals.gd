extends "res://tests/test_case.gd"
## "Things to try this week" (D-059) is worked out from the event log and
## current relationships, and changes nothing.

const Simulation := preload("res://sim/simulation.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")
const WeekGoals := preload("res://sim/reports/week_goals.gd")
const WeekSummary := preload("res://sim/reports/week_summary.gd")

const SCENARIO: String = "fixture_street_spring_1950"
const HOUSEHOLD: String = "fx_hh_1"
const DAY: int = 1440
const IDS: Array = ["meet_neighbors", "long_chat", "make_friend", "chat_at_store", "stock_pantry", "full_pay", "no_thin_meals"]


func _by_id(goals: Array) -> Dictionary:
	var found: Dictionary = {}
	for goal: Dictionary in goals:
		found[goal["id"]] = goal
	return found


func _ids(goals: Array) -> Array:
	var ids: Array = []
	for goal: Dictionary in goals:
		ids.append(goal["id"])
	return ids


func _talk(state: RefCounted, day: int, a: String, b: String, minutes: int, first: bool, place_id: String = "") -> void:
	state.log_event(day, 600, "conversation", 1, {
		"a": a, "b": b, "minutes": minutes, "a_change": 1, "b_change": 1, "first_meeting": first, "place_id": place_id,
	})


func test_a_fresh_week_has_everything_still_to_do() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1)
	var state: RefCounted = simulation.state
	state.event_log.clear()
	var today: int = simulation.clock.day_index
	var first: int = WeekSummary.week_start(today)
	var goals: Array = WeekGoals.evaluate(state, HOUSEHOLD, first, first + 6, today)
	check_eq(_ids(goals), IDS, "the goals come in a fixed order")
	var found: Dictionary = _by_id(goals)
	check_eq(found["meet_neighbors"]["target"], 5, "five neighbors to meet")
	for id: String in ["meet_neighbors", "long_chat", "chat_at_store", "stock_pantry"]:
		check_eq(found[id]["status"], "open", "%s is open" % id)
		check_eq(found[id]["progress"], 0, "%s has no progress" % id)
	check_eq(found["full_pay"]["status"], "on_track", "a full week's work is on track while the week runs")
	check_eq(found["no_thin_meals"]["status"], "on_track", "and so is nobody going hungry")
	for goal: Dictionary in goals:
		check(goal["title"] != "" and goal["hint"] != "", "%s has a title and a hint" % goal["id"])


func test_a_hand_built_log_ticks_each_goal() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1)
	var state: RefCounted = simulation.state
	state.event_log.clear()
	state.relationships.clear()
	for other: String in ["fx_p_05", "fx_p_06", "fx_p_07", "fx_p_08"]:
		_talk(state, 10, "fx_p_01", other, 5, true)
	_talk(state, 9, "fx_p_01", "fx_p_11", 5, true)  # the week before: does not count
	_talk(state, 11, "fx_p_01", "fx_p_02", 40, false)  # within the household: does not count
	var found: Dictionary = _by_id(WeekGoals.evaluate(state, HOUSEHOLD, 10, 16, 11))
	check_eq(found["meet_neighbors"]["progress"], 4, "four neighbors met this week")
	check_eq(found["meet_neighbors"]["status"], "open", "one short of five")
	check_eq(found["long_chat"]["status"], "open", "a long talk at home is not a chat with a neighbor")

	_talk(state, 11, "fx_p_13", "fx_p_03", 20, true, "fx_bd_6")
	state.log_event(12, 600, "shopping", 1, {"household_id": HOUSEHOLD, "person_id": "fx_p_01", "meals": 8, "cost_cents": 200, "wanted_meals": 8})
	state.log_event(12, 600, "shopping", 1, {"household_id": "fx_hh_2", "person_id": "fx_p_05", "meals": 8, "cost_cents": 200, "wanted_meals": 8})
	var friendship: Dictionary = state.relationship("fx_p_02", "fx_p_07")
	friendship["a_to_b"] = 25
	friendship["b_to_a"] = 12
	found = _by_id(WeekGoals.evaluate(state, HOUSEHOLD, 10, 16, 12))
	check_eq(found["meet_neighbors"]["status"], "done", "five neighbors met")
	check_eq(found["meet_neighbors"]["progress"], 5, "five of five")
	check_eq(found["long_chat"]["status"], "done", "a twenty-minute talk with a neighbor")
	check_eq(found["chat_at_store"]["status"], "done", "a talk inside the store")
	check_eq(found["stock_pantry"]["status"], "done", "the household went shopping")
	check_eq(found["make_friend"]["progress"], 12, "the lower side of the best pair")
	check_eq(found["make_friend"]["status"], "open", "not yet friends")
	check_eq(found["full_pay"]["status"], "on_track", "no payday yet")

	friendship["b_to_a"] = 20
	state.log_event(14, 0, "payday", 1, {"household_id": HOUSEHOLD, "wages_cents": 5500, "other_cents": 0})
	found = _by_id(WeekGoals.evaluate(state, HOUSEHOLD, 10, 16, 14))
	check_eq(found["make_friend"]["status"], "done", "+20 each way is a friend")
	check_eq(found["full_pay"]["status"], "done", "paid with no day missed")
	check_eq(found["no_thin_meals"]["status"], "on_track", "not settled until the week is over")
	found = _by_id(WeekGoals.evaluate(state, HOUSEHOLD, 10, 16, 17))
	check_eq(found["no_thin_meals"]["status"], "done", "settled once the week is over")

	state.log_event(15, 0, "missed_work", 2, {"household_id": HOUSEHOLD, "person_id": "fx_p_02", "lost_cents": 1100})
	state.log_event(15, 700, "empty_pantry", 2, {"household_id": HOUSEHOLD})
	found = _by_id(WeekGoals.evaluate(state, HOUSEHOLD, 10, 16, 17))
	check_eq(found["full_pay"]["status"], "missed", "a missed day")
	check_eq(found["no_thin_meals"]["status"], "missed", "a thin meal")


func test_a_household_without_wages_has_no_work_goal() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1)
	var ids: Array = _ids(WeekGoals.evaluate(simulation.state, "fx_hh_2", 10, 16, 10))
	check(not ids.has("full_pay"), "nobody in it earns wages")
	check_eq(ids.size(), IDS.size() - 1, "the other goals are all there")


func test_goals_from_a_played_week() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1950)
	var first: int = WeekSummary.week_start(simulation.clock.day_index)
	simulation.advance_minutes(DAY * 7 - simulation.clock.minute_of_day)
	var today: int = simulation.clock.day_index
	var before: String = simulation.state_hash()
	var goals: Array = WeekGoals.evaluate(simulation.state, HOUSEHOLD, first, first + 6, today)
	check_eq(simulation.state_hash(), before, "evaluating the goals changes nothing")
	check_eq(_ids(goals), IDS, "the same goals in the same order")
	check_eq(goals, WeekGoals.evaluate(simulation.state, HOUSEHOLD, first, first + 6, today), "and the same answer twice")
	var found: Dictionary = _by_id(goals)
	check_eq(found["stock_pantry"]["status"], "done", "the household went shopping in its first week")
	check(found["meet_neighbors"]["progress"] > 0, "and met someone")
	for goal: Dictionary in goals:
		check(["done", "missed"].has(goal["status"]), "%s is settled once the week is over" % goal["id"])
		check(goal["progress"] >= 0 and goal["progress"] <= goal["target"], "%s progress is within its target" % goal["id"])
