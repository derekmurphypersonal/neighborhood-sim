extends "res://tests/test_case.gd"
## Residents left alone: timetables, needs and conversations (M1-A).

const SimDate := preload("res://sim/clock/sim_date.gd")
const Simulation := preload("res://sim/simulation.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")
const Records := preload("res://sim/state/records.gd")

const SCENARIO: String = "fixture_street_spring_1950"


func _run_until(simulation: Simulation, year: int, month: int, day: int, minute: int) -> void:
	var target: int = SimDate.to_day_index(year, month, day) * SimDate.MINUTES_PER_DAY + minute
	while simulation.clock.abs_minute() < target:
		simulation.tick()


func _doing(person: Dictionary) -> String:
	return person["action"]["kind"] if not person["action"].is_empty() and person["action"]["started"] else ""


func test_everyone_is_home_asleep_at_night() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1950)
	_run_until(simulation, 1950, 4, 4, 180)  # Tuesday 03:00
	for person_id: String in simulation.state.sorted_person_ids():
		var person: Dictionary = simulation.state.people[person_id]
		var home: String = simulation.state.households[person["household_id"]]["home_id"]
		check(person["at"] == Records.AT_INSIDE and person["place_id"] == home, person["given_name"] + " is at home at 03:00")
		check_eq(_doing(person), "sleep", person["given_name"] + " is asleep at 03:00")


func test_workers_and_pupils_are_away_on_weekdays_only() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1950)
	_run_until(simulation, 1950, 4, 4, 630)  # Tuesday 10:30
	for person_id: String in simulation.state.sorted_person_ids():
		var person: Dictionary = simulation.state.people[person_id]
		var has_away: bool = simulation.world["schedules"][person["schedule_id"]]["days"]["weekday"].has("away")
		var away_from_street: bool = has_away and person["workplace_id"] == ""
		check_eq(person["at"] == Records.AT_OFFMAP, away_from_street, person["given_name"] + " on Tuesday morning")
	_run_until(simulation, 1950, 4, 9, 630)  # Sunday 10:30
	for person_id: String in simulation.state.sorted_person_ids():
		var person: Dictionary = simulation.state.people[person_id]
		check(person["at"] != Records.AT_OFFMAP, person["given_name"] + " is in the neighborhood on Sunday")


func _away_kind(simulation: Simulation, person: Dictionary) -> String:
	return person["action"]["kind"] if person["at"] == Records.AT_OFFMAP else ""


## Saturday: no school, most workers at home, shift workers away in the morning.
func test_saturday_is_different() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1950)
	_run_until(simulation, 1950, 4, 8, 600)  # Saturday 10:00
	check_eq(simulation.clock.weekday(), 6, "it is Saturday")
	for person_id: String in simulation.state.sorted_person_ids():
		var person: Dictionary = simulation.state.people[person_id]
		match person["schedule_id"]:
			"sched_shift":
				check_eq(_away_kind(simulation, person), "work", person["given_name"] + " works Saturday morning")
			"sched_storekeeper":
				var store: String = simulation.area.institution_of_kind("store")
				check(person["at"] == Records.AT_INSIDE and person["place_id"] == store, person["given_name"] + " is in the store on Saturday morning")
				check(["work", "talk"].has(_doing(person)), person["given_name"] + " is working there, or talking with a customer")
			_:
				check(person["at"] != Records.AT_OFFMAP, person["given_name"] + " is in the neighborhood on Saturday morning")
	_run_until(simulation, 1950, 4, 8, 840)  # Saturday 14:00
	for person_id: String in simulation.state.sorted_person_ids():
		check(simulation.state.people[person_id]["at"] != Records.AT_OFFMAP, "everyone is back by Saturday afternoon")


## Sunday: a later start, nobody away, and a midday dinner at home.
func test_sunday_is_different() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1950)
	_run_until(simulation, 1950, 4, 9, 430)  # Sunday 07:10
	var asleep: int = 0
	for person_id: String in simulation.state.sorted_person_ids():
		if _doing(simulation.state.people[person_id]) == "sleep":
			asleep += 1
	check_eq(asleep, simulation.state.people.size(), "everyone sleeps in on Sunday (all are up by 07:10 on a weekday)")
	_run_until(simulation, 1950, 4, 9, 800)  # Sunday 13:20
	var at_dinner: int = 0
	for person_id: String in simulation.state.sorted_person_ids():
		var person: Dictionary = simulation.state.people[person_id]
		var home: String = simulation.state.households[person["household_id"]]["home_id"]
		check(person["at"] != Records.AT_OFFMAP, person["given_name"] + " is not away on Sunday")
		if _doing(person) == "eat" and person["place_id"] == home:
			at_dinner += 1
	check(at_dinner >= simulation.state.people.size() - 3, "nearly everyone is at Sunday dinner at home (%d of %d)" % [at_dinner, simulation.state.people.size()])


## The street's one institution: a fictional store with a storekeeper.
func test_the_store_is_staffed_and_visited() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1950)
	var store: String = simulation.area.institution_of_kind("store")
	check(store != "", "the street has a store")
	check_eq(simulation.area.institutions.size(), 1, "and it is the only institution")
	var keeper: Dictionary = {}
	for person_id: String in simulation.state.sorted_person_ids():
		if simulation.state.people[person_id]["workplace_id"] == store:
			keeper = simulation.state.people[person_id]
	check(not keeper.is_empty(), "someone works there")
	var visitors: Dictionary = {}
	var keeper_in_at_ten: bool = false
	var anyone_in_when_closed: bool = false
	while simulation.clock.day_index < 99:  # through Sunday 9 April
		simulation.tick()
		var open: bool = simulation.area.is_open(store, simulation.clock.weekday(), simulation.clock.minute_of_day)
		if simulation.clock.day_index == 93 and simulation.clock.minute_of_day == 600:
			keeper_in_at_ten = keeper["at"] == Records.AT_INSIDE and keeper["place_id"] == store and _doing(keeper) == "work"
		for person_id: String in simulation.state.sorted_person_ids():
			var person: Dictionary = simulation.state.people[person_id]
			if person["at"] == Records.AT_INSIDE and person["place_id"] == store and person["id"] != keeper["id"]:
				visitors[person_id] = true
				# Two minutes' grace to get out of the door at closing time.
				if not open and not simulation.area.is_open(store, simulation.clock.weekday(), maxi(simulation.clock.minute_of_day - 2, 0)):
					anyone_in_when_closed = true
	check(keeper_in_at_ten, "the storekeeper is at work in the store on Tuesday at 10:00, not off the map")
	check(visitors.size() >= 3, "several residents went into the store during the week (%d did)" % visitors.size())
	check(not anyone_in_when_closed, "no visitor was inside while it was closed")
	var talked_inside: int = 0
	for event: Dictionary in simulation.state.event_log:
		if event["type"] == "conversation" and event["place_id"] == store:
			talked_inside += 1
	check(talked_inside >= 1, "people talked inside the store (%d conversations)" % talked_inside)


func test_weekday_mornings_start_early() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1950)
	_run_until(simulation, 1950, 4, 4, 430)  # Tuesday 07:10
	var asleep: int = 0
	for person_id: String in simulation.state.sorted_person_ids():
		if _doing(simulation.state.people[person_id]) == "sleep":
			asleep += 1
	check_eq(asleep, 0, "everyone is up by 07:10 on a weekday")


func test_residents_look_after_themselves() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1950)
	var lowest: Dictionary = {}
	for need_name: String in Records.NEED_NAMES:
		lowest[need_name] = Records.NEED_MAX
	var small_child_went_out: bool = false
	for minute: int in 3 * SimDate.MINUTES_PER_DAY:
		simulation.tick()
		for person_id: String in simulation.state.sorted_person_ids():
			var person: Dictionary = simulation.state.people[person_id]
			for need_name: String in Records.NEED_NAMES:
				lowest[need_name] = mini(lowest[need_name], person["needs"][need_name])
			if simulation.world["schedules"][person["schedule_id"]].get("housebound", false):
				small_child_went_out = small_child_went_out or person["at"] != Records.AT_INSIDE
	check(lowest["hunger"] > 0, "nobody went completely hungry in three days")
	check(lowest["rest"] > 0, "nobody ran completely out of rest in three days")
	check(lowest["fun"] > 0, "nobody ran completely out of fun in three days")
	check(not small_child_went_out, "small children stayed at home")


## Each need is met by particular actions in particular places.
func test_needs_are_met_in_the_right_places() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1950)
	check_eq(Records.NEED_NAMES, ["hunger", "rest", "company", "fun"] as Array[String], "the four needs")
	var home_of: Dictionary = {}
	for person_id: String in simulation.state.sorted_person_ids():
		home_of[person_id] = simulation.state.households[simulation.state.people[person_id]["household_id"]]["home_id"]
	var seen: Dictionary = {"pastime": 0, "play": 0}
	var misplaced: Array[String] = []
	var player_rooms: Dictionary = {}
	for minute: int in 4 * SimDate.MINUTES_PER_DAY:
		simulation.tick()
		for person_id: String in simulation.state.sorted_person_ids():
			var person: Dictionary = simulation.state.people[person_id]
			var doing: String = _doing(person)
			var at_home: bool = person["at"] == Records.AT_INSIDE and person["place_id"] == home_of[person_id]
			var age: int = SimDate.age_on(person["birth_day"], simulation.clock.day_index)
			match doing:
				"eat", "sleep", "pastime":
					if not at_home:
						misplaced.append("%s did %s away from home" % [person["given_name"], doing])
					if person["household_id"] == "fx_hh_1":
						player_rooms[doing] = person["spot"]
				"play":
					if person["at"] != Records.AT_OUTSIDE or age < 4 or age > 15:
						misplaced.append("%s (age %d) played where or when they should not" % [person["given_name"], age])
					if simulation.clock.minute_of_day < 480 or simulation.clock.minute_of_day >= 1190:
						misplaced.append("%s played outdoors at night" % person["given_name"])
			if seen.has(doing):
				seen[doing] += 1
	check_eq(misplaced, [] as Array[String], "eating, sleeping and pastimes happen at home; play happens outdoors, by day, for children")
	check(seen["pastime"] > 0, "people took up pastimes at home")
	check(seen["play"] > 0, "children played outside")
	check_eq(player_rooms.get("eat", "?"), "kitchen", "meals are in the kitchen")
	check_eq(player_rooms.get("sleep", "?"), "bedroom", "sleep is in the bedroom")
	check_eq(player_rooms.get("pastime", "?"), "living", "pastimes are in the living room")


func test_fun_falls_and_is_restored() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1950)
	simulation.advance_minutes(120)
	var person: Dictionary = simulation.state.people["fx_p_01"]
	check(person["needs"]["fun"] < Records.NEED_MAX, "fun falls while awake")
	person["needs"]["fun"] = 20000
	simulation.give_order("fx_p_01", {"kind": "use_room", "room_id": "living"})
	var best: int = 0
	for minute: int in 60:
		simulation.tick()
		best = maxi(best, person["needs"]["fun"])
	check(best > 40000, "a pastime in the living room restores it")


func test_neighbors_meet_and_relationships_change() -> void:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1950)
	simulation.advance_minutes(3 * SimDate.MINUTES_PER_DAY)
	var conversations: int = 0
	var first_meetings: int = 0
	for event: Dictionary in simulation.state.event_log:
		if event["type"] == "conversation":
			conversations += 1
			var a: Dictionary = simulation.state.people[event["a"]]
			var b: Dictionary = simulation.state.people[event["b"]]
			check(a["household_id"] != b["household_id"], "conversations are between households")
			if event["first_meeting"]:
				first_meetings += 1
	check(conversations >= 5, "neighbors talked without being told to (%d conversations)" % conversations)
	check(first_meetings >= 2, "some met for the first time")
	var changed: int = 0
	for key: String in simulation.state.relationships:
		var record: Dictionary = simulation.state.relationships[key]
		if not record["kin"] and (record["a_to_b"] != 0 or record["b_to_a"] != 0):
			changed += 1
			check_eq(record["history"].size(), record["familiarity"], "each relationship remembers its conversations")
	check(changed >= 2, "regard between neighbors changed")
