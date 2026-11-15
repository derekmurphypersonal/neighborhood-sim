extends RefCounted
## Plain-language descriptions of what people are doing and of events.
## Presentation only.

const SimDate := preload("res://sim/clock/sim_date.gd")
const Records := preload("res://sim/state/records.gd")


static func given_name(sim: RefCounted, person_id: String) -> String:
	return sim.state.people[person_id]["given_name"]


## What a person is doing, as a short phrase starting with a capital.
static func activity(sim: RefCounted, person: Dictionary) -> String:
	var action: Dictionary = person["action"]
	if action.is_empty():
		return "Deciding what to do"
	var kind: String = action["kind"]
	if not action["started"]:
		match kind:
			"work": return "Leaving for work"
			"school": return "Leaving for school"
			"call_on": return "Going to talk to " + given_name(sim, action["other_id"])
			"visit": return "Going to call on a neighbor"
			"sit_out": return "Stepping outside"
			"play": return "Going out to play"
			"go_to": return "Walking where you sent them"
			"be_inside": return "Going to " + _place_name(sim, action["place_id"])
			"shop": return "Going shopping at " + _place_name(sim, action["place_id"])
		return "Heading home"
	match kind:
		"sleep": return "Asleep"
		"eat": return "Having a meal"
		"work": return "At work in " + _place_name(sim, action["place_id"]) if person["workplace_id"] != "" else "Away at work"
		"be_inside": return "In " + _place_name(sim, action["place_id"])
		"shop": return "Shopping in " + _place_name(sim, action["place_id"])
		"school": return "Away at school"
		"be_home": return "At home"
		"pastime": return "Enjoying a pastime at home"
		"play": return "Playing outside"
		"sit_out": return "Sitting out front"
		"visit": return "Calling at a neighbor's door"
		"go_to": return "Waiting where you sent them"
		"call_on": return "Looking for " + given_name(sim, action["other_id"])
		"talk": return "Talking with " + given_name(sim, action["other_id"])
	return kind


static func _place_name(sim: RefCounted, building_id: String) -> String:
	if sim.area.institutions.has(building_id):
		return "the " + sim.area.institutions[building_id]["name"]
	return "the " + str(sim.area.buildings[building_id]["label"]) if sim.area.buildings.has(building_id) else "work"


static func _household(sim: RefCounted, entry: Dictionary) -> String:
	return sim.state.households[entry["household_id"]]["name"]


## An amount of money in whole cents, as dollars and cents.
static func money(cents: int) -> String:
	@warning_ignore("integer_division")
	return "$%d.%02d" % [cents / 100, cents % 100]


static func event_time(event: Dictionary) -> String:
	@warning_ignore("integer_division")
	return "%s %02d:%02d" % [SimDate.weekday_name(event["day"]).left(3), event["minute"] / 60, event["minute"] % 60]


static func event(sim: RefCounted, entry: Dictionary) -> String:
	return _event(sim, entry, [], false)


## The same sentence as event(), in BBCode for the feed: names of the
## player's household (player_ids) in bold teal, regard changes green or red.
static func event_rich(sim: RefCounted, entry: Dictionary, player_ids: Array) -> String:
	return _event(sim, entry, player_ids, true)


const RICH_TEAL: String = "#2F5D62"
const RICH_GOOD: String = "#3E7A33"
const RICH_BAD: String = "#B5442F"
const RICH_EVEN: String = "#7A6658"


static func _who(sim: RefCounted, person_id: String, player_ids: Array, rich: bool) -> String:
	var name: String = given_name(sim, person_id)
	if rich and player_ids.has(person_id):
		return "[b][color=%s]%s[/color][/b]" % [RICH_TEAL, name]
	return name


static func _house(sim: RefCounted, entry: Dictionary, player_ids: Array, rich: bool) -> String:
	var name: String = _household(sim, entry)
	if rich and sim.state.households[entry["household_id"]]["player_controlled"]:
		return "[b][color=%s]%s[/color][/b]" % [RICH_TEAL, name]
	return name


static func _change(amount: int, rich: bool) -> String:
	if not rich:
		return "%+d" % amount
	var color: String = RICH_GOOD if amount > 0 else (RICH_BAD if amount < 0 else RICH_EVEN)
	return "[color=%s]%+d[/color]" % [color, amount]


static func _event(sim: RefCounted, entry: Dictionary, players: Array, rich: bool) -> String:
	match entry["type"]:
		"conversation":
			var first: String = " (their first meeting)" if entry["first_meeting"] else ""
			return "%s and %s talked for %d minutes%s. Regard: %s %s, %s %s." % [
				_who(sim, entry["a"], players, rich), _who(sim, entry["b"], players, rich), entry["minutes"], first,
				given_name(sim, entry["a"]), _change(entry["a_change"], rich), given_name(sim, entry["b"]), _change(entry["b_change"], rich),
			]
		"birthday":
			return "%s turned %d." % [_who(sim, entry["person_id"], players, rich), entry["age"]]
		"household_short_of_money":
			return "The %s is short of money for %s." % [_house(sim, entry, players, rich), entry["reason"]]
		"payday":
			var other: String = "" if entry["other_cents"] == 0 else " and %s other income" % money(entry["other_cents"])
			return "Payday: the %s received %s in wages%s." % [_house(sim, entry, players, rich), money(entry["wages_cents"]), other]
		"rent_paid":
			if entry["short_cents"] > 0:
				return "Rent day: the %s paid %s and still owes %s." % [_house(sim, entry, players, rich), money(entry["paid_cents"]), money(entry["short_cents"])]
			return "Rent day: the %s paid %s." % [_house(sim, entry, players, rich), money(entry["paid_cents"])]
		"shopping":
			if entry["meals"] < entry["wanted_meals"]:
				return "%s could afford only %d of %d meals at the store (%s)." % [
					_who(sim, entry["person_id"], players, rich), entry["meals"], entry["wanted_meals"], money(entry["cost_cents"]),
				]
			return "%s bought %d meals for the %s (%s)." % [
				_who(sim, entry["person_id"], players, rich), entry["meals"], _house(sim, entry, players, rich), money(entry["cost_cents"]),
			]
		"empty_pantry":
			return "The %s has nothing in the pantry: meals are thin." % _house(sim, entry, players, rich)
		"missed_work":
			return "%s missed a day's work and lost %s in wages." % [_who(sim, entry["person_id"], players, rich), money(entry["lost_cents"])]
		"order_failed":
			if entry.get("reason", "") == "closed":
				return "%s found %s closed." % [_who(sim, entry["person_id"], players, rich), _place_name(sim, entry["place_id"])]
			return "%s could not find %s: away from the street." % [
				_who(sim, entry["person_id"], players, rich), _who(sim, entry["other_id"], players, rich),
			]
	return str(entry["type"])


## Which small picture the feed shows beside an event.
static func event_icon(entry: Dictionary) -> String:
	match entry["type"]:
		"conversation":
			return "meet" if entry["first_meeting"] else "talk"
		"birthday":
			return "cake"
		"payday":
			return "coin"
		"rent_paid":
			return "rent"
		"shopping":
			return "basket"
		"empty_pantry":
			return "plate"
		"missed_work":
			return "clock"
		"household_short_of_money":
			return "short"
		"order_failed":
			return "closed" if entry.get("reason", "") == "closed" else "away"
	return "dot"


## How someone seems, read from their needs alone: a word and a face kind
## ("happy", "fine", "low", "asleep"). Presentation only; nothing is stored.
static func mood(person: Dictionary) -> Dictionary:
	var action: Dictionary = person["action"]
	if not action.is_empty() and action["started"] and action["kind"] == "sleep":
		return {"word": "Asleep", "face": "asleep", "need": ""}
	var lowest_name: String = ""
	var lowest: int = Records.NEED_MAX + 1
	for need_name: String in Records.NEED_NAMES:
		if int(person["needs"][need_name]) < lowest:
			lowest = person["needs"][need_name]
			lowest_name = need_name
	@warning_ignore("integer_division")
	var percent: int = lowest * 100 / Records.NEED_MAX
	if percent >= MOOD_CHEERFUL_PERCENT:
		return {"word": "Cheerful", "face": "happy", "need": ""}
	if percent >= MOOD_CONTENT_PERCENT:
		return {"word": "Content", "face": "fine", "need": ""}
	var word: String = MOOD_WORDS[lowest_name]
	if percent < MOOD_VERY_PERCENT:
		word = "Very " + word.to_lower()
	return {"word": word, "face": "low", "need": lowest_name}


const MOOD_CHEERFUL_PERCENT: int = 70
const MOOD_CONTENT_PERCENT: int = 45
const MOOD_VERY_PERCENT: int = 20
const MOOD_WORDS: Dictionary = {"hunger": "Hungry", "rest": "Tired", "company": "Lonely", "fun": "Bored"}

## Regard thresholds for the words in the neighbors list. Friend matches
## "Make a friend" in sim/reports/week_goals.gd.
const FRIEND_REGARD: int = 20
const FRIENDLY_REGARD: int = 8
const UNFRIENDLY_REGARD: int = -10


## A word for how two people stand, from the regard each way. The lower of
## the two decides, since a friendship needs both sides.
static func relationship_word(met: bool, mine: int, theirs: int) -> String:
	if not met:
		return "Stranger"
	var lower: int = mini(mine, theirs)
	if lower >= FRIEND_REGARD:
		return "Friend"
	if lower >= FRIENDLY_REGARD:
		return "Friendly"
	if lower <= UNFRIENDLY_REGARD:
		return "Unfriendly"
	if lower < 0:
		return "Cool"
	return "Acquaintance"


## The week paper's headline: the biggest thing in the week's summary, in a
## few words. Every case reads only the summary and the goals; when nothing
## stands out it says so.
static func week_headline(sim: RefCounted, summary: Dictionary, goals: Array) -> String:
	for birthday: Dictionary in summary["birthdays"]:
		return "Happy birthday, %s!" % given_name(sim, birthday["person_id"])
	var met_now: Dictionary = {}
	for pair: Array in summary["first_meetings"]:
		met_now[pair[0] + "|" + pair[1]] = true
	var best: Dictionary = {}
	var best_warmth: int = 0
	for pair: Dictionary in summary["neighbors"]:
		var warmth: int = mini(pair["member_change"], pair["other_change"])
		if warmth > best_warmth:
			best_warmth = warmth
			best = pair
	if summary["rent_short_cents"] > 0:
		return "Rent comes up short"
	if not best.is_empty() and best_warmth >= HEADLINE_WARMTH:
		var names: String = "%s and %s" % [given_name(sim, best["member_id"]), given_name(sim, best["other_id"])]
		if met_now.has(best["member_id"] + "|" + best["other_id"]):
			return "%s hit it off" % names
		return "%s grow closer" % names
	if summary["thin_meal_days"] > 0:
		return "A lean week in the pantry"
	if (summary["first_meetings"] as Array).size() >= HEADLINE_MEETINGS:
		return "%d new acquaintances" % (summary["first_meetings"] as Array).size()
	var done: int = 0
	for goal: Dictionary in goals:
		if goal["status"] == "done":
			done += 1
	if not goals.is_empty() and done == goals.size():
		return "Everything tried, everything done"
	return "A quiet week"


## How much both sides must have warmed to each other for a pair to make
## the headline, and how many first meetings make news on their own.
const HEADLINE_WARMTH: int = 10
const HEADLINE_MEETINGS: int = 3


## A household's week as text for the summary sheet. The summary itself is
## made by sim/reports/week_summary.gd from the event log; goals, if given,
## come from sim/reports/week_goals.gd.
static func week_summary(sim: RefCounted, summary: Dictionary, goals: Array = []) -> String:
	var lines: Array[String] = []
	lines.append("%s %s to %s %s" % [
		SimDate.weekday_name(summary["first_day"]), SimDate.to_iso(summary["first_day"]),
		SimDate.weekday_name(summary["last_day"]), SimDate.to_iso(summary["last_day"]),
	])
	if not goals.is_empty():
		lines.append("")
		lines.append_array(_goals_tried(goals))
	lines.append("")
	lines.append("[b]Money[/b]")
	lines.append("  Wages paid: %s" % money(summary["wages_cents"]))
	if summary["other_income_cents"] > 0:
		lines.append("  Other income: %s" % money(summary["other_income_cents"]))
	var owed: String = "" if summary["rent_short_cents"] == 0 else "  (still owed: %s)" % money(summary["rent_short_cents"])
	lines.append("  Rent paid: %s%s" % [money(summary["rent_paid_cents"]), owed])
	lines.append("  Groceries: %s for %d meals in %d %s" % [
		money(summary["groceries_cents"]), summary["meals_bought"], summary["shopping_trips"],
		"trip" if summary["shopping_trips"] == 1 else "trips",
	])
	var net: int = summary["net_cents"]
	lines.append("  Over the week: %s%s" % ["up " if net >= 0 else "down ", money(absi(net))])
	if summary["days_missed"] > 0:
		lines.append("  Days of work missed: %d (%s in wages lost)" % [summary["days_missed"], money(summary["wages_lost_cents"])])
	if summary["thin_meal_days"] > 0:
		lines.append("  Days with nothing in the pantry: %d" % summary["thin_meal_days"])
	if summary["times_short"] > 0:
		lines.append("  Times short of money: %d" % summary["times_short"])
	lines.append("")
	lines.append("[b]Neighbors[/b]")
	lines.append("  Talks with people outside the household: %d (%d minutes)" % [summary["conversations"], summary["minutes_talking"]])
	lines.append("  First meetings: %d" % (summary["first_meetings"] as Array).size())
	lines.append("  Where regard changed most:")
	var shown: int = 0
	var ranked: Array = (summary["neighbors"] as Array).duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var size_a: int = absi(a["member_change"]) + absi(a["other_change"])
		var size_b: int = absi(b["member_change"]) + absi(b["other_change"])
		return size_a > size_b if size_a != size_b else (a["member_id"] + a["other_id"]) < (b["member_id"] + b["other_id"]))
	for pair: Dictionary in ranked:
		if shown == 5:
			break
		shown += 1
		lines.append("    %s and %s, %d %s: %s %+d, %s %+d" % [
			given_name(sim, pair["member_id"]), given_name(sim, pair["other_id"]), pair["talks"],
			"talk" if pair["talks"] == 1 else "talks",
			given_name(sim, pair["member_id"]), pair["member_change"], given_name(sim, pair["other_id"]), pair["other_change"],
		])
	if not (summary["birthdays"] as Array).is_empty():
		lines.append("")
		lines.append("[b]Birthdays[/b]")
		for birthday: Dictionary in summary["birthdays"]:
			lines.append("  %s turned %d." % [given_name(sim, birthday["person_id"]), birthday["age"]])
	return "\n".join(lines)


## The week's things to try, grouped by how they went, in a few lines so the
## sheet stays short.
static func _goals_tried(goals: Array) -> Array[String]:
	var groups: Dictionary = {}
	var done: int = 0
	for goal: Dictionary in goals:
		if goal["status"] == "done":
			done += 1
		if not groups.has(goal["status"]):
			groups[goal["status"]] = []
		(groups[goal["status"]] as Array).append(goal["title"])
	var lines: Array[String] = ["[b]Things you tried[/b]: %d of %d done" % [done, goals.size()]]
	for entry: Array in GOAL_GROUPS:
		if groups.has(entry[0]):
			lines.append("  [color=%s]%s:[/color] %s" % [entry[2], entry[1], ", ".join(PackedStringArray(groups[entry[0]]))])
	return lines


const GOAL_GROUPS: Array = [
	["done", "Done", "#ffd166"], ["on_track", "On track", "#9fd3c7"],
	["open", "Not yet", "#e8dcc0"], ["missed", "Missed", "#f4a38f"],
]


const FACT_LABELS: Dictionary = {"building_type": "Kind of building", "stories": "Stories"}
const DAY_KIND_LABELS: Array = [["weekday", "Weekdays"], ["saturday", "Saturday"], ["sunday", "Sunday"]]


static func clock_time(minute: int) -> String:
	@warning_ignore("integer_division")
	return "%d:%02d" % [minute / 60, minute % 60]


## What is known about a building, as text. The parts come from
## sim/reports/building_info.gd and are kept apart here too: documented
## exterior first, then the fictional interior, then the fictional scenario.
static func building_info(sim: RefCounted, info: Dictionary) -> String:
	var lines: Array[String] = []
	var exterior: Dictionary = info["exterior"]
	if info["area_placeholder"]:
		lines.append("[color=#ffeb8c]FICTIONAL TEST BUILDING. This street is a made-up stand-in for development. It is not a real place.[/color]")
		lines.append("")
	lines.append("[b]Documented exterior[/b]")
	if exterior["documented"]:
		lines.append("  Research status: %s" % exterior["status"])
		for fact: Dictionary in exterior["facts"]:
			lines.append("  %s: %s" % [FACT_LABELS.get(fact["field"], fact["field"]), fact["value"]])
		for source: Dictionary in exterior["sources"]:
			lines.append("  Source %s, %s (finding %s)" % [source.get("source_id", "?"), source.get("locator", "?"), source.get("finding_id", "?")])
		if exterior["reasoning"] != "":
			lines.append("  Reasoning: %s" % exterior["reasoning"])
	else:
		lines.append("  Nothing is documented about this building.")
		lines.append("")
		lines.append("[b]Placeholder exterior (invented)[/b]")
		for fact: Dictionary in exterior["facts"]:
			lines.append("  %s: %s" % [FACT_LABELS.get(fact["field"], fact["field"]), fact["value"]])
	lines.append("")
	lines.append("[b]Interior (fictional)[/b]")
	var interior: Dictionary = info["interior"]
	if interior.is_empty():
		lines.append("  No interior has been made for this building.")
	else:
		lines.append("  Invented layout \"%s\": %s." % [interior["name"], ", ".join(PackedStringArray(interior["rooms"])).to_lower()])
		lines.append("  Interiors are never taken from the historical record.")
	lines.append("")
	lines.append("[b]In this scenario (fictional)[/b]")
	var institution: Dictionary = info["institution"]
	if not institution.is_empty():
		var standing: String = "documented, %s" % institution["status"] if institution["documented"] else "invented, not a documented business"
		lines.append("  %s (%s)" % [institution["name"], standing])
		for entry: Array in DAY_KIND_LABELS:
			var hours: Variant = institution["hours"].get(entry[0])
			var open: String = "closed" if typeof(hours) != TYPE_ARRAY else "%s to %s" % [clock_time(int(hours[0])), clock_time(int(hours[1]))]
			lines.append("    %s: %s" % [entry[1], open])
	for household: Dictionary in info["households"]:
		var names: PackedStringArray = []
		for member_id: String in household["member_ids"]:
			names.append(given_name(sim, member_id))
		lines.append("  Home of the %s: %s. All residents are fictional." % [household["name"], ", ".join(names)])
	if institution.is_empty() and (info["households"] as Array).is_empty():
		lines.append("  Nobody lives or works here in this scenario.")
	return "\n".join(lines)
