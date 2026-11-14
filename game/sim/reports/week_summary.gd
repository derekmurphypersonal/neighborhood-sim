extends RefCounted
## A household's week, put together from the event log and nothing else.
##
## A week runs Monday to Sunday. Everything in the summary is counted from
## events logged on those days; who belongs to the household is the only
## other thing looked up. All amounts are whole cents.

const SimDate := preload("res://sim/clock/sim_date.gd")


## The Monday of the week a day falls in, as a day index.
static func week_start(day_index: int) -> int:
	return day_index - (SimDate.weekday(day_index) + 6) % 7


## Summarizes the days first_day..last_day (inclusive) for one household.
static func summarize(state: RefCounted, household_id: String, first_day: int, last_day: int) -> Dictionary:
	var members: Array = state.households[household_id]["member_ids"]
	var summary: Dictionary = {
		"household_id": household_id, "first_day": first_day, "last_day": last_day,
		"wages_cents": 0, "other_income_cents": 0,
		"rent_paid_cents": 0, "rent_short_cents": 0,
		"groceries_cents": 0, "meals_bought": 0, "shopping_trips": 0,
		"net_cents": 0,
		"days_missed": 0, "wages_lost_cents": 0,
		"thin_meal_days": 0, "times_short": 0,
		"conversations": 0, "minutes_talking": 0,
		"first_meetings": [],  # [member_id, other_id]
		"neighbors": [],       # {member_id, other_id, talks, member_change, other_change}
		"birthdays": [],       # {person_id, age}
	}
	var pairs: Dictionary = {}
	for event: Dictionary in state.event_log:
		if event["day"] < first_day or event["day"] > last_day:
			continue
		if event["type"] == "conversation":
			_count_conversation(summary, pairs, members, event)
			continue
		if event["type"] == "birthday":
			if members.has(event["person_id"]):
				summary["birthdays"].append({"person_id": event["person_id"], "age": event["age"]})
			continue
		if event.get("household_id", "") != household_id:
			continue
		match event["type"]:
			"payday":
				summary["wages_cents"] += event["wages_cents"]
				summary["other_income_cents"] += event["other_cents"]
			"rent_paid":
				summary["rent_paid_cents"] += event["paid_cents"]
				summary["rent_short_cents"] = event["short_cents"]  # what is still owed after the latest rent day
			"shopping":
				summary["groceries_cents"] += event["cost_cents"]
				summary["meals_bought"] += event["meals"]
				summary["shopping_trips"] += 1
			"missed_work":
				summary["days_missed"] += 1
				summary["wages_lost_cents"] += event["lost_cents"]
			"empty_pantry":
				summary["thin_meal_days"] += 1
			"household_short_of_money":
				summary["times_short"] += 1
	summary["net_cents"] = summary["wages_cents"] + summary["other_income_cents"] \
			- summary["rent_paid_cents"] - summary["groceries_cents"]
	var keys: Array = pairs.keys()
	keys.sort()
	for key: String in keys:
		summary["neighbors"].append(pairs[key])
	return summary


## Counts a conversation between a member of the household and someone
## outside it. Talk within the household is not part of the summary.
static func _count_conversation(summary: Dictionary, pairs: Dictionary, members: Array, event: Dictionary) -> void:
	var a_member: bool = members.has(event["a"])
	var b_member: bool = members.has(event["b"])
	if a_member == b_member:
		return
	var member_id: String = event["a"] if a_member else event["b"]
	var other_id: String = event["b"] if a_member else event["a"]
	var member_change: int = event["a_change"] if a_member else event["b_change"]
	var other_change: int = event["b_change"] if a_member else event["a_change"]
	summary["conversations"] += 1
	summary["minutes_talking"] += event["minutes"]
	if event["first_meeting"]:
		summary["first_meetings"].append([member_id, other_id])
	var key: String = member_id + "|" + other_id
	if not pairs.has(key):
		pairs[key] = {"member_id": member_id, "other_id": other_id, "talks": 0, "member_change": 0, "other_change": 0}
	pairs[key]["talks"] += 1
	pairs[key]["member_change"] += member_change
	pairs[key]["other_change"] += other_change
