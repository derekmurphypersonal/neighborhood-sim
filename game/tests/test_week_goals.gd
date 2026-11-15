extends "res://tests/test_case.gd"
## "Things to try this week" (D-059) is worked out from the event log and
## current relationships, and changes nothing. Each week shows a few
## suggestions from a pool, chosen from the week's first day alone.

const Simulation := preload("res://sim/simulation.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")
const WeekGoals := preload("res://sim/reports/week_goals.gd")
const WeekSummary := preload("res://sim/reports/week_summary.gd")

const SCENARIO: String = "fixture_street_spring_1950"
const HOUSEHOLD: String = "fx_hh_1"
const DAY: int = 1440


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


func _talk(state: RefCounted, day: int, a: String, b: String, minutes: int, first: bool, place_id: String = "", minute: int = 600) -> void:
	state.log_event(day, minute, "conversation", 1, {
		"a": a, "b": b, "minutes": minutes, "a_change": 1, "b_change": 1, "first_meeting": first, "place_id": place_id,
	})


func _fresh() -> Simulation:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1)
	simulation.state.event_log.clear()
	simulation.state.relationships.clear()
	return simulation


func test_a_fresh_week_has_everything_still_to_do() -> void:
	var simulation: Simulation = _fresh()
	var state: RefCounted = simulation.state
	var today: int = simulation.clock.day_index
	var first: int = WeekSummary.week_start(today)
	var goals: Array = WeekGoals.evaluate_pool(state, HOUSEHOLD, first, first + 6, today)
	check_eq(_ids(goals), WeekGoals.POOL as Array, "the whole pool can be offered, in pool order")
	var found: Dictionary = _by_id(goals)
	check_eq(found["meet_neighbors"]["target"], 5, "five neighbors to meet")
	for id: String in ["meet_neighbors", "new_faces_run", "long_chat", "evening_chat", "hour_of_talk", "chat_most_days",
			"three_households", "same_neighbor_thrice", "make_friend", "chat_at_store", "stock_pantry"]:
		check_eq(found[id]["status"], "open", "%s is open" % id)
		check_eq(found[id]["progress"], 0, "%s has no progress" % id)
	for id: String in ["full_pay", "no_thin_meals", "never_short"]:
		check_eq(found[id]["status"], "on_track", "%s is on track while the week runs" % id)
	for goal: Dictionary in goals:
		check(goal["title"] != "" and goal["hint"] != "", "%s has a title and a hint" % goal["id"])
		check(int(goal["target"]) >= 1, "%s has a target" % goal["id"])


func test_a_week_shows_a_steady_handful() -> void:
	var simulation: Simulation = _fresh()
	var state: RefCounted = simulation.state
	var choices: Dictionary = {}
	for week: int in 10:
		var first: int = 7 * week
		var goals: Array = WeekGoals.evaluate(state, HOUSEHOLD, first, first + 6, first)
		var ids: Array = _ids(goals)
		check_eq(ids.size(), WeekGoals.PER_WEEK, "week %d shows %d suggestions" % [week, WeekGoals.PER_WEEK])
		var last_index: int = -1
		var home: bool = false
		for id: String in ids:
			var index: int = WeekGoals.POOL.find(id)
			check(index > last_index, "week %d: %s is listed in pool order" % [week, id])
			last_index = index
			home = home or WeekGoals.HOME_GOALS.has(id)
		check(home, "week %d has something about keeping the house going" % week)
		# The same week asked about on a later day shows the same suggestions.
		check_eq(_ids(WeekGoals.evaluate(state, HOUSEHOLD, first, first + 6, first + 4)), ids, "week %d is the same all week" % week)
		choices[",".join(PackedStringArray(ids))] = true
	check(choices.size() >= 4, "the choice varies from week to week (%d different in 10 weeks)" % choices.size())


func test_the_choice_depends_on_the_week_alone() -> void:
	var offered: Array = WeekGoals.POOL.duplicate()
	check_eq(WeekGoals.choose(offered, 21), WeekGoals.choose(offered, 21), "same week, same choice")
	var reversed: Array = offered.duplicate()
	reversed.reverse()
	var a: Array = WeekGoals.choose(offered, 21)
	var b: Array = WeekGoals.choose(reversed, 21)
	a.sort()
	b.sort()
	check_eq(a, b, "the order the pool is offered in does not matter")


func test_a_hand_built_log_ticks_each_goal() -> void:
	var simulation: Simulation = _fresh()
	var state: RefCounted = simulation.state
	for other: String in ["fx_p_05", "fx_p_06", "fx_p_07", "fx_p_08"]:
		_talk(state, 10, "fx_p_01", other, 5, true)
	_talk(state, 9, "fx_p_01", "fx_p_11", 5, true)  # the week before: does not count
	_talk(state, 11, "fx_p_01", "fx_p_02", 40, false)  # within the household: does not count
	var found: Dictionary = _by_id(WeekGoals.evaluate_pool(state, HOUSEHOLD, 10, 16, 11))
	check_eq(found["meet_neighbors"]["progress"], 4, "four neighbors met this week")
	check_eq(found["meet_neighbors"]["status"], "open", "one short of five")
	check_eq(found["long_chat"]["status"], "open", "a long talk at home is not a chat with a neighbor")
	check_eq(found["hour_of_talk"]["progress"], 20, "twenty minutes with neighbors so far")
	check_eq(found["new_faces_run"]["progress"], 1, "one day with a new face")

	_talk(state, 11, "fx_p_13", "fx_p_03", 20, true, "fx_bd_6")
	state.log_event(12, 600, "shopping", 1, {"household_id": HOUSEHOLD, "person_id": "fx_p_01", "meals": 8, "cost_cents": 200, "wanted_meals": 8})
	state.log_event(12, 600, "shopping", 1, {"household_id": "fx_hh_2", "person_id": "fx_p_05", "meals": 8, "cost_cents": 200, "wanted_meals": 8})
	var friendship: Dictionary = state.relationship("fx_p_02", "fx_p_07")
	friendship["a_to_b"] = 25
	friendship["b_to_a"] = 12
	found = _by_id(WeekGoals.evaluate_pool(state, HOUSEHOLD, 10, 16, 12))
	check_eq(found["meet_neighbors"]["status"], "done", "five neighbors met")
	check_eq(found["meet_neighbors"]["progress"], 5, "five of five")
	check_eq(found["long_chat"]["status"], "done", "a twenty-minute talk with a neighbor")
	check_eq(found["chat_at_store"]["status"], "done", "a talk inside the store")
	check_eq(found["stock_pantry"]["status"], "done", "the household went shopping")
	check_eq(found["make_friend"]["progress"], 12, "the lower side of the best pair")
	check_eq(found["make_friend"]["status"], "open", "not yet friends")
	check_eq(found["full_pay"]["status"], "on_track", "no payday yet")
	check_eq(found["new_faces_run"]["progress"], 2, "new faces on two days in a row")
	check_eq(found["evening_chat"]["status"], "open", "every talk so far was in the morning")
	check_eq(found["chat_most_days"]["progress"], 2, "talked with neighbors on two days")

	_talk(state, 12, "fx_p_01", "fx_p_09", 40, true, "", 19 * 60)
	_talk(state, 13, "fx_p_02", "fx_p_05", 5, false)
	_talk(state, 13, "fx_p_02", "fx_p_05", 5, false)
	_talk(state, 14, "fx_p_02", "fx_p_05", 5, false)
	friendship["b_to_a"] = 20
	state.log_event(14, 0, "payday", 1, {"household_id": HOUSEHOLD, "wages_cents": 5500, "other_cents": 0})
	found = _by_id(WeekGoals.evaluate_pool(state, HOUSEHOLD, 10, 16, 14))
	check_eq(found["make_friend"]["status"], "done", "+20 each way is a friend")
	check_eq(found["full_pay"]["status"], "done", "paid with no day missed")
	check_eq(found["no_thin_meals"]["status"], "on_track", "not settled until the week is over")
	check_eq(found["never_short"]["status"], "on_track", "never short, so far")
	check_eq(found["new_faces_run"]["status"], "done", "new faces on three days running")
	check_eq(found["evening_chat"]["status"], "done", "a talk that ended at 7 pm")
	check_eq(found["hour_of_talk"]["status"], "done", "over an hour with neighbors")
	check_eq(found["hour_of_talk"]["progress"], 60, "progress stops at the target")
	check_eq(found["same_neighbor_thrice"]["status"], "done", "three talks between the same two")
	check_eq(found["chat_most_days"]["progress"], 5, "talked with neighbors on five days")
	check_eq(found["chat_most_days"]["status"], "done", "five days")
	check(found["three_households"]["progress"] >= 3, "talked with three or more households")
	check_eq(found["three_households"]["status"], "done", "three households")
	found = _by_id(WeekGoals.evaluate_pool(state, HOUSEHOLD, 10, 16, 17))
	check_eq(found["no_thin_meals"]["status"], "done", "settled once the week is over")
	check_eq(found["never_short"]["status"], "done", "and so is making ends meet")

	state.log_event(15, 0, "missed_work", 2, {"household_id": HOUSEHOLD, "person_id": "fx_p_02", "lost_cents": 1100})
	state.log_event(15, 700, "empty_pantry", 2, {"household_id": HOUSEHOLD})
	state.log_event(15, 700, "household_short_of_money", 2, {"household_id": HOUSEHOLD, "reason": "groceries"})
	found = _by_id(WeekGoals.evaluate_pool(state, HOUSEHOLD, 10, 16, 17))
	check_eq(found["full_pay"]["status"], "missed", "a missed day")
	check_eq(found["no_thin_meals"]["status"], "missed", "a thin meal")
	check_eq(found["never_short"]["status"], "missed", "short of money")


func test_people_already_met_are_not_new_faces() -> void:
	var simulation: Simulation = _fresh()
	var state: RefCounted = simulation.state
	var household_of_member: Dictionary = {}
	for person_id: String in state.sorted_person_ids():
		household_of_member[person_id] = state.people[person_id]["household_id"]
	var outsiders: Array = []
	for person_id: String in state.sorted_person_ids():
		if household_of_member[person_id] != HOUSEHOLD:
			outsiders.append(person_id)
	# Everyone but two was met the week before.
	for index: int in outsiders.size() - 2:
		_talk(state, 3, "fx_p_01", outsiders[index], 5, true)
	var found: Dictionary = _by_id(WeekGoals.evaluate_pool(state, HOUSEHOLD, 10, 16, 10))
	check_eq(found["meet_neighbors"]["target"], 2, "only two strangers are left to meet")
	check(not found.has("new_faces_run"), "too few strangers for three days of new faces")
	_talk(state, 4, "fx_p_01", outsiders[outsiders.size() - 2], 5, true)
	_talk(state, 4, "fx_p_01", outsiders[outsiders.size() - 1], 5, true)
	var ids: Array = _ids(WeekGoals.evaluate_pool(state, HOUSEHOLD, 10, 16, 10))
	check(not ids.has("meet_neighbors"), "nobody is left to meet")
	check(ids.size() >= WeekGoals.PER_WEEK, "there are still enough suggestions for a week")


func test_a_household_without_wages_has_no_work_goal() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1)
	var ids: Array = _ids(WeekGoals.evaluate_pool(simulation.state, "fx_hh_2", 10, 16, 10))
	check(not ids.has("full_pay"), "nobody in it earns wages")
	check_eq(ids.size(), WeekGoals.POOL.size() - 1, "the other goals are all there")
	check(not _ids(WeekGoals.evaluate(simulation.state, "fx_hh_2", 10, 16, 10)).has("full_pay"), "and none is shown")


func test_goals_from_a_played_week() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1950)
	var first: int = WeekSummary.week_start(simulation.clock.day_index)
	var shown_at_start: Array = _ids(WeekGoals.evaluate(simulation.state, HOUSEHOLD, first, first + 6, simulation.clock.day_index))
	simulation.advance_minutes(DAY * 7 - simulation.clock.minute_of_day)
	var today: int = simulation.clock.day_index
	var before: String = simulation.state_hash()
	var goals: Array = WeekGoals.evaluate(simulation.state, HOUSEHOLD, first, first + 6, today)
	var pool: Array = WeekGoals.evaluate_pool(simulation.state, HOUSEHOLD, first, first + 6, today)
	check_eq(simulation.state_hash(), before, "evaluating the goals changes nothing")
	check_eq(_ids(goals), shown_at_start, "the same goals in the same order as when the week began")
	check_eq(goals, WeekGoals.evaluate(simulation.state, HOUSEHOLD, first, first + 6, today), "and the same answer twice")
	var found: Dictionary = _by_id(pool)
	check_eq(found["stock_pantry"]["status"], "done", "the household went shopping in its first week")
	check(found["meet_neighbors"]["progress"] > 0, "and met someone")
	for goal: Dictionary in pool:
		check(["done", "missed"].has(goal["status"]), "%s is settled once the week is over" % goal["id"])
		check(goal["progress"] >= 0 and goal["progress"] <= goal["target"], "%s progress is within its target" % goal["id"])
