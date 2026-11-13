extends RefCounted
## What each person does, minute by minute: choosing an action, walking to
## where it happens, carrying it out, and giving way to something more
## pressing.
##
## Order of precedence when choosing: a player's order, then the timetable
## (sleep, work, school), then a pressing need, then idle preference.

const Records := preload("res://sim/state/records.gd")
const SimDate := preload("res://sim/clock/sim_date.gd")

const MINUTES_PER_DAY: int = 1440


static func step(sim: RefCounted, person: Dictionary) -> void:
	_give_way(sim, person)
	if person["action"].is_empty():
		person["action"] = _choose(sim, person)
	var action: Dictionary = person["action"]
	if not action["started"]:
		_travel(sim, person, action)
	elif sim.clock.abs_minute() >= action["ends_at"]:
		person["action"] = {}


# --- Timetable ---------------------------------------------------------------

static func schedule_of(sim: RefCounted, person: Dictionary) -> Dictionary:
	return sim.world["schedules"][person["schedule_id"]]


static func is_sleep_time(schedule: Dictionary, minute: int) -> bool:
	return minute >= int(schedule["bed"]) or minute < int(schedule["wake"])


## The away period (work or school) in force right now, or {}.
static func away_now(sim: RefCounted, schedule: Dictionary) -> Dictionary:
	if not schedule.has("away"):
		return {}
	var away: Dictionary = schedule["away"]
	var minute: int = sim.clock.minute_of_day
	if not (away["days"] as Array).has(sim.clock.weekday()):
		return {}
	if minute >= int(away["leave"]) and minute < int(away["back"]):
		return away
	return {}


# --- Giving way --------------------------------------------------------------

## Drops a low-priority action when the timetable or the player calls.
static func _give_way(sim: RefCounted, person: Dictionary) -> void:
	var action: Dictionary = person["action"]
	if action.is_empty() or action["kind"] == "talk":
		return
	if not person["orders"].is_empty() and action["source"] != "player" and person["at"] != Records.AT_OFFMAP:
		person["action"] = {}
		return
	if action["source"] == "need" or action["source"] == "idle":
		var schedule: Dictionary = schedule_of(sim, person)
		if is_sleep_time(schedule, sim.clock.minute_of_day) or not away_now(sim, schedule).is_empty():
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
	var tuning: Dictionary = sim.tuning
	var generator: RandomNumberGenerator = sim.rng.stream("behavior")

	while not person["orders"].is_empty():
		var order: Dictionary = person["orders"].pop_front()
		var ordered: Dictionary = _from_order(sim, person, order, home)
		if not ordered.is_empty():
			return ordered

	if is_sleep_time(schedule, minute):
		var sleep: Dictionary = Records.new_action("sleep", "schedule", Records.AT_INSIDE, home)
		var wake: int = int(schedule["wake"])
		var day_start: int = now - minute
		sleep["until"] = day_start + wake if minute < wake else day_start + MINUTES_PER_DAY + wake
		return sleep

	var away: Dictionary = away_now(sim, schedule)
	if not away.is_empty():
		var exit_id: String = sim.area.nearest_exit(sim.area.front_of(home))
		var leave: Dictionary = Records.new_action(away["kind"], "schedule", Records.AT_OFFMAP, exit_id)
		leave["until"] = now - minute + int(away["back"])
		return leave

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
	var outgoing: bool = (person["traits"] as Array).has("outgoing")
	var homebody: bool = (person["traits"] as Array).has("homebody")

	if not housebound and needs["company"] < int(tuning["company_threshold"]):
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
