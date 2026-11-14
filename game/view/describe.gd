extends RefCounted
## Plain-language descriptions of what people are doing and of events.
## Presentation only.

const SimDate := preload("res://sim/clock/sim_date.gd")


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
	match entry["type"]:
		"conversation":
			var first: String = " (their first meeting)" if entry["first_meeting"] else ""
			return "%s and %s talked for %d minutes%s. Regard: %s %+d, %s %+d." % [
				given_name(sim, entry["a"]), given_name(sim, entry["b"]), entry["minutes"], first,
				given_name(sim, entry["a"]), entry["a_change"], given_name(sim, entry["b"]), entry["b_change"],
			]
		"birthday":
			return "%s turned %d." % [given_name(sim, entry["person_id"]), entry["age"]]
		"household_short_of_money":
			return "The %s is short of money for %s." % [_household(sim, entry), entry["reason"]]
		"payday":
			var other: String = "" if entry["other_cents"] == 0 else " and %s other income" % money(entry["other_cents"])
			return "Payday: the %s received %s in wages%s." % [_household(sim, entry), money(entry["wages_cents"]), other]
		"rent_paid":
			if entry["short_cents"] > 0:
				return "Rent day: the %s paid %s and still owes %s." % [_household(sim, entry), money(entry["paid_cents"]), money(entry["short_cents"])]
			return "Rent day: the %s paid %s." % [_household(sim, entry), money(entry["paid_cents"])]
		"shopping":
			if entry["meals"] < entry["wanted_meals"]:
				return "%s could afford only %d of %d meals at the store (%s)." % [
					given_name(sim, entry["person_id"]), entry["meals"], entry["wanted_meals"], money(entry["cost_cents"]),
				]
			return "%s bought %d meals for the %s (%s)." % [
				given_name(sim, entry["person_id"]), entry["meals"], _household(sim, entry), money(entry["cost_cents"]),
			]
		"empty_pantry":
			return "The %s has nothing in the pantry: meals are thin." % _household(sim, entry)
		"missed_work":
			return "%s missed a day's work and lost %s in wages." % [given_name(sim, entry["person_id"]), money(entry["lost_cents"])]
		"order_failed":
			if entry.get("reason", "") == "closed":
				return "%s found %s closed." % [given_name(sim, entry["person_id"]), _place_name(sim, entry["place_id"])]
			return "%s could not find %s: away from the street." % [
				given_name(sim, entry["person_id"]), given_name(sim, entry["other_id"]),
			]
	return str(entry["type"])


## A household's week as text for the summary sheet. The summary itself is
## made by sim/reports/week_summary.gd from the event log.
static func week_summary(sim: RefCounted, summary: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("%s %s to %s %s" % [
		SimDate.weekday_name(summary["first_day"]), SimDate.to_iso(summary["first_day"]),
		SimDate.weekday_name(summary["last_day"]), SimDate.to_iso(summary["last_day"]),
	])
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
