extends RefCounted
## What each person does, minute by minute: choosing an action, walking to
## where it happens, carrying it out, and giving way to something more
## pressing.
##
## Order of precedence when choosing: a player's order, then the timetable
## (sleep, work, school), then a pressing need, then idle preference.

const Records := preload("res://sim/state/records.gd")
const SimDate := preload("res://sim/clock/sim_date.gd")
const Economy := preload("res://sim/systems/economy.gd")

const MINUTES_PER_DAY: int = 1440
## The kind of room each action is carried out in, where the building has an
## interior. Actions not listed here have no particular room.
const ROOM_FOR: Dictionary = {"eat": "kitchen", "sleep": "bedroom", "be_home": "living", "pastime": "living"}
## What a person does when the player sends them to a room of a given kind.
const ACTION_IN_ROOM: Dictionary = {"kitchen": "eat", "bedroom": "sleep", "living": "pastime"}


static func step(sim: RefCounted, person: Dictionary) -> void:
	_give_way(sim, person)
	if person["action"].is_empty():
		var chosen: Dictionary = _choose(sim, person)
		if chosen["room_kind"] == "":
			chosen["room_kind"] = ROOM_FOR.get(chosen["kind"], "")
		person["action"] = chosen
	var action: Dictionary = person["action"]
	if not action["started"]:
		_travel(sim, person, action)
	elif sim.clock.abs_minute() >= action["ends_at"]:
		match action["kind"]:
			"eat":
				Economy.finish_meal(sim, person)
			"shop":
				Economy.finish_shopping(sim, person)
		person["action"] = {}


# --- Timetable ---------------------------------------------------------------

static func schedule_of(sim: RefCounted, person: Dictionary) -> Dictionary:
	return sim.world["schedules"][person["schedule_id"]]


## A person's timetable for a given weekday: {wake, bed, away?, meals?}.
static func plan_for(sim: RefCounted, person: Dictionary, weekday: int) -> Dictionary:
	return schedule_of(sim, person)["days"][SimDate.day_kind(weekday)]


static func plan_today(sim: RefCounted, person: Dictionary) -> Dictionary:
	return plan_for(sim, person, sim.clock.weekday())


static func is_sleep_time(plan: Dictionary, minute: int) -> bool:
	return minute >= int(plan["bed"]) or minute < int(plan["wake"])


## The away period (work or school) in force right now, or {}.
static func away_now(sim: RefCounted, plan: Dictionary) -> Dictionary:
	if not plan.has("away"):
		return {}
	var away: Dictionary = plan["away"]
	var minute: int = sim.clock.minute_of_day
	if minute >= int(away["leave"]) and minute < int(away["back"]):
		return away
	return {}


## True if a fixed household mealtime is under way and this person has not
## yet sat down to it today.
static func set_meal_due(sim: RefCounted, person: Dictionary, plan: Dictionary) -> bool:
	if person["last_set_meal_day"] == sim.clock.day_index:
		return false
	var minute: int = sim.clock.minute_of_day
	for meal: int in plan.get("meals", []):
		if minute >= meal and minute < meal + int(sim.tuning["set_meal_window_minutes"]):
			return true
	return false


# --- Giving way --------------------------------------------------------------

## Drops a low-priority action when the timetable or the player calls.
static func _give_way(sim: RefCounted, person: Dictionary) -> void:
	var action: Dictionary = person["action"]
	if action.is_empty() or action["kind"] == "talk":
		return
	# Visitors leave an institution when it closes; staff finish their shift.
	if action["where"] == Records.AT_INSIDE and action["kind"] != "work" and sim.area.is_institution(action["place_id"]) \
			and not sim.area.is_open(action["place_id"], sim.clock.weekday(), sim.clock.minute_of_day):
		person["action"] = {}
		return
	if not person["orders"].is_empty() and action["source"] != "player" and person["at"] != Records.AT_OFFMAP:
		person["action"] = {}
		return
	if action["source"] == "need" or action["source"] == "idle" or action["source"] == "errand":
		var plan: Dictionary = plan_today(sim, person)
		if is_sleep_time(plan, sim.clock.minute_of_day) or not away_now(sim, plan).is_empty() \
				or set_meal_due(sim, person, plan):
			# Finish a meal already started; otherwise the timetable wins.
			if not (action["kind"] == "eat" and action["started"]):
				person["action"] = {}


# --- Choosing ----------------------------------------------------------------

static func _choose(sim: RefCounted, person: Dictionary) -> Dictionary:
	var now: int = sim.clock.abs_minute()
	var minute: int = sim.clock.minute_of_day
	var household: Dictionary = sim.state.households[person["household_id"]]
	var home: String = household["home_id"]
	var schedule: Dictionary = schedule_of(sim, person)
	var plan: Dictionary = plan_today(sim, person)
	var tuning: Dictionary = sim.tuning
	var generator: RandomNumberGenerator = sim.rng.stream("behavior")

	while not person["orders"].is_empty():
		var order: Dictionary = person["orders"].pop_front()
		var ordered: Dictionary = _from_order(sim, person, order, home)
		if not ordered.is_empty():
			return ordered

	if is_sleep_time(plan, minute):
		var sleep: Dictionary = Records.new_action("sleep", "schedule", Records.AT_INSIDE, home)
		var day_start: int = now - minute
		if minute < int(plan["wake"]):
			sleep["until"] = day_start + int(plan["wake"])
		else:
			# Past bedtime: sleep until tomorrow's waking time, which may differ.
			var tomorrow: Dictionary = plan_for(sim, person, (sim.clock.weekday() + 1) % 7)
			sleep["until"] = day_start + MINUTES_PER_DAY + int(tomorrow["wake"])
		return sleep

	var away: Dictionary = away_now(sim, plan)
	if not away.is_empty() and person["workplace_id"] != "":
		# A job on the street itself: go to the workplace and stay for the shift.
		var shift: Dictionary = Records.new_action(away["kind"], "schedule", Records.AT_INSIDE, person["workplace_id"])
		shift["until"] = now - minute + int(away["back"])
		return shift
	if not away.is_empty():
		var exit_id: String = sim.area.nearest_exit(sim.area.front_of(home))
		var leave: Dictionary = Records.new_action(away["kind"], "schedule", Records.AT_OFFMAP, exit_id)
		leave["until"] = now - minute + int(away["back"])
		return leave

	if set_meal_due(sim, person, plan):
		person["last_set_meal_day"] = sim.clock.day_index
		var dinner: Dictionary = Records.new_action("eat", "schedule", Records.AT_INSIDE, home)
		dinner["minutes"] = int(tuning["set_meal_minutes"])
		return dinner

	var needs: Dictionary = person["needs"]
	if needs["hunger"] < int(tuning["hunger_threshold"]):
		var eat: Dictionary = Records.new_action("eat", "need", Records.AT_INSIDE, home)
		eat["minutes"] = int(tuning["meal_minutes"])
		return eat
	if needs["rest"] < int(tuning["rest_threshold"]):
		var nap: Dictionary = Records.new_action("sleep", "need", Records.AT_INSIDE, home)
		nap["minutes"] = int(tuning["nap_minutes"])
		return nap

	var housebound: bool = schedule.get("housebound", false)
	if not housebound:
		var store: String = Economy.shopping_errand(sim, person)
		if store != "":
			var shop: Dictionary = Records.new_action("shop", "errand", Records.AT_INSIDE, store)
			shop["minutes"] = int(tuning["shop_minutes"])
			return shop

	var outgoing: bool = (person["traits"] as Array).has("outgoing")
	var homebody: bool = (person["traits"] as Array).has("homebody")

	# Of company and fun, see to whichever is lower, if it is low enough.
	var wants_company: bool = not housebound and needs["company"] < int(tuning["company_threshold"])
	var wants_fun: bool = not housebound and needs["fun"] < int(tuning["fun_threshold"])
	if wants_fun and (not wants_company or needs["fun"] <= needs["company"]):
		return _amusement(sim, person, home, generator)
	if wants_company:
		if generator.randi_range(1, 100) <= int(tuning["visit_chance_percent"]):
			var visit: Dictionary = _visit(sim, person, generator)
			if not visit.is_empty():
				return visit
		return _sit_out(sim, home, "need", generator)

	var outdoors_chance: int = int(tuning["idle_outdoors_percent"])
	if outgoing:
		outdoors_chance += int(tuning["trait_outdoors_shift"])
	if homebody:
		outdoors_chance -= int(tuning["trait_outdoors_shift"])
	if not housebound:
		var drop_in: Dictionary = _drop_in(sim, generator)
		if not drop_in.is_empty():
			return drop_in
	if not housebound and generator.randi_range(1, 100) <= outdoors_chance:
		return _sit_out(sim, home, "idle", generator)
	var be_home: Dictionary = Records.new_action("be_home", "idle", Records.AT_INSIDE, home)
	be_home["minutes"] = generator.randi_range(int(tuning["idle_min_minutes"]), int(tuning["idle_max_minutes"]))
	return be_home


static func _sit_out(sim: RefCounted, home: String, source: String, generator: RandomNumberGenerator) -> Dictionary:
	var action: Dictionary = Records.new_action("sit_out", source, Records.AT_OUTSIDE, home)
	var front: Array = sim.area.front_of(home)
	action["tx"] = front[0]
	action["ty"] = front[1]
	action["minutes"] = generator.randi_range(int(sim.tuning["idle_min_minutes"]), int(sim.tuning["idle_max_minutes"]))
	return action


## Something enjoyable: children play outdoors in the daytime; everyone else,
## and children after dark, take up a pastime at home.
static func _amusement(sim: RefCounted, person: Dictionary, home: String, generator: RandomNumberGenerator) -> Dictionary:
	var tuning: Dictionary = sim.tuning
	var minutes: int = generator.randi_range(int(tuning["pastime_min_minutes"]), int(tuning["pastime_max_minutes"]))
	var age: int = SimDate.age_on(person["birth_day"], sim.clock.day_index)
	var minute: int = sim.clock.minute_of_day
	var playtime: bool = minute >= int(tuning["play_from_minute"]) and minute < int(tuning["play_until_minute"])
	if playtime and age >= int(tuning["play_min_age"]) and age <= int(tuning["play_max_age"]):
		var play: Dictionary = Records.new_action("play", "need", Records.AT_OUTSIDE, home)
		var front: Array = sim.area.front_of(home)
		play["tx"] = front[0]
		play["ty"] = front[1]
		play["minutes"] = minutes
		return play
	var pastime: Dictionary = Records.new_action("pastime", "need", Records.AT_INSIDE, home)
	pastime["minutes"] = minutes
	return pastime


## With time to spare, a person may drop in at an institution that is open.
static func _drop_in(sim: RefCounted, generator: RandomNumberGenerator) -> Dictionary:
	var open_now: Array = []
	var ids: Array = sim.area.institutions.keys()
	ids.sort()
	for building_id: String in ids:
		if sim.area.is_open(building_id, sim.clock.weekday(), sim.clock.minute_of_day):
			open_now.append(building_id)
	if open_now.is_empty() or generator.randi_range(1, 100) > int(sim.tuning["idle_drop_in_percent"]):
		return {}
	var target: String = open_now[generator.randi_range(0, open_now.size() - 1)]
	var action: Dictionary = Records.new_action("be_inside", "idle", Records.AT_INSIDE, target)
	action["minutes"] = generator.randi_range(int(sim.tuning["drop_in_min_minutes"]), int(sim.tuning["drop_in_max_minutes"]))
	return action


## Go and stand at the front of another household's home, hoping for a chat.
static func _visit(sim: RefCounted, person: Dictionary, generator: RandomNumberGenerator) -> Dictionary:
	var candidates: Array = []
	for household_id: String in sim.state.sorted_household_ids():
		if household_id != person["household_id"]:
			candidates.append(sim.state.households[household_id]["home_id"])
	if candidates.is_empty():
		return {}
	var target: String = candidates[generator.randi_range(0, candidates.size() - 1)]
	var action: Dictionary = Records.new_action("visit", "need", Records.AT_OUTSIDE, target)
	var front: Array = sim.area.front_of(target)
	action["tx"] = front[0]
	action["ty"] = front[1]
	action["minutes"] = int(sim.tuning["visit_wait_minutes"])
	return action


static func _from_order(sim: RefCounted, person: Dictionary, order: Dictionary, home: String) -> Dictionary:
	match order["kind"]:
		"go_home":
			var be_home: Dictionary = Records.new_action("be_home", "player", Records.AT_INSIDE, home)
			be_home["minutes"] = int(sim.tuning["order_stay_minutes"])
			return be_home
		"go_to":
			var go: Dictionary = Records.new_action("go_to", "player", Records.AT_OUTSIDE, order["place_id"])
			var front: Array = sim.area.front_of(order["place_id"])
			go["tx"] = front[0]
			go["ty"] = front[1]
			go["minutes"] = int(sim.tuning["order_stay_minutes"])
			return go
		"enter":
			if not sim.area.is_open(order["place_id"], sim.clock.weekday(), sim.clock.minute_of_day):
				sim.state.log_event(sim.clock.day_index, sim.clock.minute_of_day, "order_failed", 1, {
					"person_id": person["id"], "place_id": order["place_id"], "reason": "closed",
				})
				return {}
			var inside: Dictionary = Records.new_action("be_inside", "player", Records.AT_INSIDE, order["place_id"])
			inside["minutes"] = int(sim.tuning["order_stay_minutes"])
			return inside
		"use_room":
			var kind: String = sim.area.interiors[home]["rooms"][order["room_id"]]["kind"]
			var use: Dictionary = Records.new_action(ACTION_IN_ROOM.get(kind, "be_home"), "player", Records.AT_INSIDE, home)
			use["room_kind"] = kind
			use["minutes"] = int(sim.tuning["order_stay_minutes"])
			return use
		"talk_to":
			var other: Dictionary = sim.state.people[order["other_id"]]
			var call: Dictionary = Records.new_action("call_on", "player", Records.AT_OUTSIDE, "")
			call["other_id"] = other["id"]
			call["minutes"] = int(sim.tuning["visit_wait_minutes"])
			if other["at"] == Records.AT_INSIDE:
				var front: Array = sim.area.front_of(other["place_id"])
				call["place_id"] = other["place_id"]
				call["tx"] = front[0]
				call["ty"] = front[1]
				return call
			if other["at"] == Records.AT_OUTSIDE:
				call["tx"] = other["x"]
				call["ty"] = other["y"]
				return call
			sim.state.log_event(sim.clock.day_index, sim.clock.minute_of_day, "order_failed", 1, {
				"person_id": person["id"], "other_id": other["id"], "reason": "away",
			})
	return {}


# --- Travelling --------------------------------------------------------------

static func _travel(sim: RefCounted, person: Dictionary, action: Dictionary) -> void:
	if not action["routed"]:
		action["routed"] = true
		var from_building: String = person["place_id"] if person["at"] == Records.AT_INSIDE else ""
		if action["where"] == Records.AT_INSIDE and from_building == action["place_id"]:
			# Already in the right building: nothing to walk.
			_arrive(sim, person, action)
			return
		if person["at"] == Records.AT_OFFMAP:
			person["at"] = Records.AT_OUTSIDE  # stepping back onto the map at the exit
		match action["where"]:
			Records.AT_INSIDE:
				action["path"] = sim.area.route(from_building, action["place_id"], [])
			Records.AT_OFFMAP:
				action["path"] = sim.area.route(from_building, "", sim.area.exits[action["place_id"]]["point"])
			_:
				action["path"] = sim.area.route(from_building, "", [action["tx"], action["ty"]])
		if from_building != "" and not action["path"].is_empty():
			var door: Array = sim.area.door_of(from_building)
			person["at"] = Records.AT_OUTSIDE
			person["place_id"] = ""
			person["spot"] = ""
			person["x"] = door[0]
			person["y"] = door[1]

	var budget: int = int(sim.tuning["walk_inches_per_minute"])
	var path: Array = action["path"]
	var trail: Array = [[person["x"], person["y"]]]
	while budget > 0 and not path.is_empty():
		var target: Array = path[0]
		var dx: int = int(target[0]) - int(person["x"])
		var dy: int = int(target[1]) - int(person["y"])
		var distance: int = int(sqrt(float(dx * dx + dy * dy)))
		if distance <= budget:
			person["x"] = int(target[0])
			person["y"] = int(target[1])
			budget -= distance
			path.pop_front()
		else:
			@warning_ignore("integer_division")
			person["x"] += dx * budget / distance
			@warning_ignore("integer_division")
			person["y"] += dy * budget / distance
			budget = 0
		trail.append([person["x"], person["y"]])
	sim.trails[person["id"]] = trail

	if path.is_empty():
		_arrive(sim, person, action)


static func _arrive(sim: RefCounted, person: Dictionary, action: Dictionary) -> void:
	match action["where"]:
		Records.AT_INSIDE:
			person["at"] = Records.AT_INSIDE
			person["place_id"] = action["place_id"]
			person["spot"] = sim.area.room_of_kind(action["place_id"], action["room_kind"])
		Records.AT_OFFMAP:
			person["at"] = Records.AT_OFFMAP
			person["place_id"] = ""
		_:
			person["at"] = Records.AT_OUTSIDE
			person["place_id"] = ""
	action["started"] = true
	var now: int = sim.clock.abs_minute()
	action["ends_at"] = action["until"] if action["until"] >= 0 else now + action["minutes"]
	# Someone returning from work or school reappears at the exit they left by.
	if action["where"] == Records.AT_OFFMAP:
		var point: Array = sim.area.exits[action["place_id"]]["point"]
		person["x"] = point[0]
		person["y"] = point[1]
