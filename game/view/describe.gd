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
			"go_to": return "Walking where you sent them"
			"be_inside": return "Going to " + _place_name(sim, action["place_id"])
		return "Heading home"
	match kind:
		"sleep": return "Asleep"
		"eat": return "Having a meal"
		"work": return "At work in " + _place_name(sim, action["place_id"]) if person["workplace_id"] != "" else "Away at work"
		"be_inside": return "In " + _place_name(sim, action["place_id"])
		"school": return "Away at school"
		"be_home": return "At home"
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
			return "The %s is short of money." % sim.state.households[entry["household_id"]]["name"]
		"order_failed":
			if entry.get("reason", "") == "closed":
				return "%s found %s closed." % [given_name(sim, entry["person_id"]), _place_name(sim, entry["place_id"])]
			return "%s could not find %s: away from the street." % [
				given_name(sim, entry["person_id"]), given_name(sim, entry["other_id"]),
			]
	return str(entry["type"])
