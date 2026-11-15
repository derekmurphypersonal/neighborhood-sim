extends RefCounted
## "Things to try this week" for a household (D-059): a few suggestions,
## each ticked off from what has happened.
##
## Worked out read-only, like the other reports (D-054): from events logged
## on the week's days, who belongs to which household, the members' wages,
## and current relationships. It never changes state and adds none; there
## are no rewards. The suggestions and their thresholds are invented
## gameplay prompts (gameplay_tuned), not anything historical.
##
## Each goal is {id, title, hint, status, progress, target}, with status
## one of "done", "on_track" (nothing has gone wrong yet, but it can only be
## settled later in the week), "open" (not yet done) or "missed". Once the
## week is over every goal is either done or missed.

const NEIGHBORS_TO_MEET: int = 5
const LONG_CHAT_MINUTES: int = 20
const FRIEND_REGARD: int = 20


## Goals for first_day..last_day (inclusive), as seen on day today. Always
## the same goals in the same order, except that "full_pay" is left out for
## a household with nobody earning wages.
static func evaluate(state: RefCounted, household_id: String, first_day: int, last_day: int, today: int) -> Array:
	var members: Array = state.households[household_id]["member_ids"]
	var week_over: bool = today > last_day
	var met: Dictionary = {}
	var longest_chat: int = 0
	var chatted_at_store: bool = false
	var shopped: bool = false
	var paid: bool = false
	var days_missed: int = 0
	var thin_days: int = 0
	for event: Dictionary in state.event_log:
		if event["day"] < first_day or event["day"] > last_day:
			continue
		match event["type"]:
			"conversation":
				var a_member: bool = members.has(event["a"])
				var b_member: bool = members.has(event["b"])
				if a_member == b_member:
					continue  # talk within the household, or between other people
				var other_id: String = event["b"] if a_member else event["a"]
				if event["first_meeting"]:
					met[other_id] = true
				longest_chat = maxi(longest_chat, event["minutes"])
				# place_id is set only when the two talked inside an institution.
				if event["place_id"] != "":
					chatted_at_store = true
			"shopping":
				if event["household_id"] == household_id and event["meals"] > 0:
					shopped = true
			"payday":
				if event["household_id"] == household_id and event["wages_cents"] > 0:
					paid = true
			"missed_work":
				if event["household_id"] == household_id:
					days_missed += 1
			"empty_pantry":
				if event["household_id"] == household_id:
					thin_days += 1

	var goals: Array = []
	var others: int = 0
	var earners: int = 0
	for person_id: String in state.sorted_person_ids():
		var person: Dictionary = state.people[person_id]
		if person["household_id"] != household_id:
			others += 1
		elif person["daily_wage_cents"] > 0:
			earners += 1
	var to_meet: int = mini(NEIGHBORS_TO_MEET, others)
	goals.append(_goal("meet_neighbors", "Say hello to the neighbors",
			"Meet people from other households for the first time this week.",
			mini(met.size(), to_meet), to_meet, met.size() >= to_meet))
	goals.append(_goal("long_chat", "Have a good long chat",
			"Talk with a neighbor for %d minutes or more." % LONG_CHAT_MINUTES,
			1 if longest_chat >= LONG_CHAT_MINUTES else 0, 1, longest_chat >= LONG_CHAT_MINUTES))
	var best: int = _best_mutual_regard(state, members)
	goals.append(_goal("make_friend", "Make a friend",
			"One of your household and a neighbor who both think well of each other (+%d each way)." % FRIEND_REGARD,
			clampi(best, 0, FRIEND_REGARD), FRIEND_REGARD, best >= FRIEND_REGARD))
	goals.append(_goal("chat_at_store", "Catch up at the store",
			"Talk with someone while you are both inside the store.",
			1 if chatted_at_store else 0, 1, chatted_at_store))
	goals.append(_goal("stock_pantry", "Stock the pantry",
			"Someone in the household buys groceries at the store.",
			1 if shopped else 0, 1, shopped))
	if earners > 0:
		var full: Dictionary = _goal("full_pay", "A full week's work",
				"Nobody in the household misses a day's work. Settled on payday.",
				1 if (paid or week_over) and days_missed == 0 else 0, 1, (paid or week_over) and days_missed == 0)
		_settle(full, days_missed > 0)
		goals.append(full)
	var fed: Dictionary = _goal("no_thin_meals", "Nobody goes hungry",
			"Keep food in the pantry all week, so no meal is a thin one.",
			1 if week_over and thin_days == 0 else 0, 1, week_over and thin_days == 0)
	_settle(fed, thin_days > 0)
	goals.append(fed)
	if week_over:
		for goal: Dictionary in goals:
			if goal["status"] != "done":
				goal["status"] = "missed"
	return goals


static func _goal(id: String, title: String, hint: String, progress: int, target: int, done: bool) -> Dictionary:
	return {"id": id, "title": title, "hint": hint, "status": "done" if done else "open", "progress": progress, "target": target}


## For goals that hold until something goes wrong: missed once it has,
## otherwise on track until done.
static func _settle(goal: Dictionary, failed: bool) -> void:
	if failed:
		goal["status"] = "missed"
		goal["progress"] = 0
	elif goal["status"] != "done":
		goal["status"] = "on_track"


## The best regard any member and someone from another household have for
## each other, counting the lower of the two directions. Reads the
## relationship records directly so that nothing is created.
static func _best_mutual_regard(state: RefCounted, members: Array) -> int:
	var best: int = 0
	for key: String in state.relationships:
		var record: Dictionary = state.relationships[key]
		if record["kin"] or members.has(record["a"]) == members.has(record["b"]):
			continue
		best = maxi(best, mini(record["a_to_b"], record["b_to_a"]))
	return best
