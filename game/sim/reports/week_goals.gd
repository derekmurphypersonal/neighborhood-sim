extends RefCounted
## "Things to try this week" for a household (D-059): a few suggestions,
## each ticked off from what has happened.
##
## Worked out read-only, like the other reports (D-054): from events logged
## on the week's days (and, for who is still a stranger, the days before),
## who belongs to which household, the members' wages, and current
## relationships. It never changes state and adds none; there are no
## rewards. The suggestions and their thresholds are invented gameplay
## prompts (gameplay_tuned), not anything historical.
##
## There is a pool of suggestions; each week shows a handful of them, chosen
## from the week's first day alone, so the choice and its order stay the same
## all week and on every machine. No simulation random stream is used.
##
## Each goal is {id, title, hint, status, progress, target}, with status
## one of "done", "on_track" (nothing has gone wrong yet, but it can only be
## settled later in the week), "open" (not yet done) or "missed". Once the
## week is over every goal is either done or missed.

const NEIGHBORS_TO_MEET: int = 5
const LONG_CHAT_MINUTES: int = 20
const FRIEND_REGARD: int = 20
const NEW_FACE_DAYS: int = 3
const CHAT_DAYS: int = 5
const HOUSEHOLDS_TO_TALK_WITH: int = 3
const TALK_MINUTES_IN_ALL: int = 60
const EVENING_STARTS_MINUTE: int = 18 * 60
const SAME_NEIGHBOR_TALKS: int = 3
## How many suggestions a week shows, when that many can be offered.
const PER_WEEK: int = 7

## Every suggestion, in the order they are listed when chosen.
const POOL: Array[String] = [
	"meet_neighbors", "new_faces_run", "long_chat", "evening_chat", "hour_of_talk",
	"chat_most_days", "three_households", "same_neighbor_thrice", "make_friend", "chat_at_store",
	"stock_pantry", "full_pay", "no_thin_meals", "never_short",
]
## Suggestions about keeping the house going. Each week shows at least one.
const HOME_GOALS: Array[String] = ["stock_pantry", "full_pay", "no_thin_meals", "never_short"]


## This week's suggestions for first_day..last_day (inclusive), as seen on
## day today: up to PER_WEEK of the pool, in pool order.
static func evaluate(state: RefCounted, household_id: String, first_day: int, last_day: int, today: int) -> Array:
	var all: Array = evaluate_pool(state, household_id, first_day, last_day, today)
	var chosen: Dictionary = {}
	for id: String in choose(_ids(all), first_day):
		chosen[id] = true
	var goals: Array = []
	for goal: Dictionary in all:
		if chosen.has(goal["id"]):
			goals.append(goal)
	return goals


## Which of the offered ids a week shows. Depends only on the ids and the
## week's first day: each id is ranked by a hash of the two together.
static func choose(offered: Array, first_day: int) -> Array:
	var ranked: Array = offered.duplicate()
	ranked.sort_custom(func(a: String, b: String) -> bool:
		var rank_a: int = _rank(a, first_day)
		var rank_b: int = _rank(b, first_day)
		return rank_a < rank_b if rank_a != rank_b else a < b)
	var picked: Array = ranked.slice(0, PER_WEEK)
	var has_home: bool = false
	for id: String in picked:
		has_home = has_home or HOME_GOALS.has(id)
	if not has_home:
		for id: String in ranked:
			if HOME_GOALS.has(id):
				picked[picked.size() - 1] = id
				break
	return picked


static func _rank(id: String, first_day: int) -> int:
	return ("%d/%s" % [first_day, id]).hash()


## Every suggestion the household can be offered this week, in pool order,
## each worked out. Some are left out when they cannot apply: a full week's
## work for a household with nobody earning wages, meeting new people when
## everyone has been met, talking with several households on a street with
## too few.
static func evaluate_pool(state: RefCounted, household_id: String, first_day: int, last_day: int, today: int) -> Array:
	var members: Array = state.households[household_id]["member_ids"]
	var week_over: bool = today > last_day
	var known_before: Dictionary = {}  # outsiders any member talked with before the week
	var met: Dictionary = {}
	var first_meeting_days: Dictionary = {}
	var chat_days: Dictionary = {}
	var households_talked: Dictionary = {}
	var pair_talks: Dictionary = {}
	var longest_chat: int = 0
	var minutes_talking: int = 0
	var evening_chat: bool = false
	var chatted_at_store: bool = false
	var shopped: bool = false
	var paid: bool = false
	var days_missed: int = 0
	var thin_days: int = 0
	var times_short: int = 0
	for event: Dictionary in state.event_log:
		if event["day"] > last_day:
			continue
		if event["day"] < first_day:
			if event["type"] == "conversation" and members.has(event["a"]) != members.has(event["b"]):
				known_before[event["b"] if members.has(event["a"]) else event["a"]] = true
			continue
		match event["type"]:
			"conversation":
				var a_member: bool = members.has(event["a"])
				var b_member: bool = members.has(event["b"])
				if a_member == b_member:
					continue  # talk within the household, or between other people
				var member_id: String = event["a"] if a_member else event["b"]
				var other_id: String = event["b"] if a_member else event["a"]
				if event["first_meeting"]:
					met[other_id] = true
					first_meeting_days[event["day"]] = true
				chat_days[event["day"]] = true
				households_talked[state.people[other_id]["household_id"]] = true
				var pair: String = member_id + "|" + other_id
				pair_talks[pair] = int(pair_talks.get(pair, 0)) + 1
				longest_chat = maxi(longest_chat, event["minutes"])
				minutes_talking += event["minutes"]
				# A conversation is logged when it ends.
				if event["minute"] >= EVENING_STARTS_MINUTE:
					evening_chat = true
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
			"household_short_of_money":
				if event["household_id"] == household_id:
					times_short += 1

	var strangers: int = 0
	var earners: int = 0
	for person_id: String in state.sorted_person_ids():
		var person: Dictionary = state.people[person_id]
		if person["household_id"] != household_id:
			if not known_before.has(person_id):
				strangers += 1
		elif person["daily_wage_cents"] > 0:
			earners += 1
	var other_households: int = state.households.size() - 1

	var goals: Array = []
	var to_meet: int = mini(NEIGHBORS_TO_MEET, strangers)
	if to_meet > 0:
		goals.append(_goal("meet_neighbors", "Say hello to the neighbors",
				"Meet people from other households for the first time this week.",
				mini(met.size(), to_meet), to_meet, met.size() >= to_meet))
	if strangers >= NEW_FACE_DAYS:
		var run: int = _longest_run(first_meeting_days, first_day, last_day)
		goals.append(_goal("new_faces_run", "Three days of new faces",
				"Meet someone for the first time on %d days in a row." % NEW_FACE_DAYS,
				mini(run, NEW_FACE_DAYS), NEW_FACE_DAYS, run >= NEW_FACE_DAYS))
	goals.append(_goal("long_chat", "Have a good long chat",
			"Talk with a neighbor for %d minutes or more." % LONG_CHAT_MINUTES,
			1 if longest_chat >= LONG_CHAT_MINUTES else 0, 1, longest_chat >= LONG_CHAT_MINUTES))
	goals.append(_goal("evening_chat", "An evening chat",
			"Finish a talk with a neighbor after 6 pm, when the day's work is done.",
			1 if evening_chat else 0, 1, evening_chat))
	goals.append(_goal("hour_of_talk", "An hour of good company",
			"Spend %d minutes in all talking with neighbors this week." % TALK_MINUTES_IN_ALL,
			mini(minutes_talking, TALK_MINUTES_IN_ALL), TALK_MINUTES_IN_ALL, minutes_talking >= TALK_MINUTES_IN_ALL))
	goals.append(_goal("chat_most_days", "Neighborly most days",
			"Talk with a neighbor on %d different days this week." % CHAT_DAYS,
			mini(chat_days.size(), CHAT_DAYS), CHAT_DAYS, chat_days.size() >= CHAT_DAYS))
	if other_households >= HOUSEHOLDS_TO_TALK_WITH:
		goals.append(_goal("three_households", "Get around the street",
				"Talk with people from %d different households this week." % HOUSEHOLDS_TO_TALK_WITH,
				mini(households_talked.size(), HOUSEHOLDS_TO_TALK_WITH), HOUSEHOLDS_TO_TALK_WITH,
				households_talked.size() >= HOUSEHOLDS_TO_TALK_WITH))
	var most_talks: int = 0
	for pair: String in pair_talks:
		most_talks = maxi(most_talks, pair_talks[pair])
	goals.append(_goal("same_neighbor_thrice", "Get to know someone",
			"Talk with the same neighbor %d times this week." % SAME_NEIGHBOR_TALKS,
			mini(most_talks, SAME_NEIGHBOR_TALKS), SAME_NEIGHBOR_TALKS, most_talks >= SAME_NEIGHBOR_TALKS))
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
	var solvent: Dictionary = _goal("never_short", "Make ends meet",
			"Go the whole week without running short of money for rent or groceries.",
			1 if week_over and times_short == 0 else 0, 1, week_over and times_short == 0)
	_settle(solvent, times_short > 0)
	goals.append(solvent)
	if week_over:
		for goal: Dictionary in goals:
			if goal["status"] != "done":
				goal["status"] = "missed"
	return goals


static func _goal(id: String, title: String, hint: String, progress: int, target: int, done: bool) -> Dictionary:
	return {"id": id, "title": title, "hint": hint, "status": "done" if done else "open", "progress": progress, "target": target}


static func _ids(goals: Array) -> Array:
	var ids: Array = []
	for goal: Dictionary in goals:
		ids.append(goal["id"])
	return ids


## For goals that hold until something goes wrong: missed once it has,
## otherwise on track until done.
static func _settle(goal: Dictionary, failed: bool) -> void:
	if failed:
		goal["status"] = "missed"
		goal["progress"] = 0
	elif goal["status"] != "done":
		goal["status"] = "on_track"


## The most days in a row, within the week, that appear in days.
static func _longest_run(days: Dictionary, first_day: int, last_day: int) -> int:
	var best: int = 0
	var run: int = 0
	for day: int in range(first_day, last_day + 1):
		run = run + 1 if days.has(day) else 0
		best = maxi(best, run)
	return best


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
