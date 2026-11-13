extends RefCounted
## Conversations and what they do to relationships.
##
## Two people can fall into conversation when they are near each other
## outdoors, or when one stands at the front of a house and the other is
## awake inside it. A conversation holds both for a while; when it ends,
## each one's regard for the other shifts and the event is logged.

const Records := preload("res://sim/state/records.gd")
const Area := preload("res://sim/world/area.gd")

const TALKABLE_OUTDOORS: Array[String] = ["sit_out", "visit", "go_to", "call_on", "wait"]
## What people may be doing inside an institution when they fall into talk.
const TALKABLE_INDOORS: Array[String] = ["be_inside", "work", "shop"]
## Actions taken up again after a conversation that interrupted them.
const RESUMED_AFTER_TALK: Array[String] = ["be_inside", "work", "shop", "go_to"]
const NOT_AT_THE_DOOR: Array[String] = ["sleep", "talk"]


static func step(sim: RefCounted) -> void:
	_finish_conversations(sim)
	_door_calls(sim)
	_street_meetings(sim)
	_indoor_meetings(sim)


static func _finish_conversations(sim: RefCounted) -> void:
	var now: int = sim.clock.abs_minute()
	for person_id: String in sim.state.sorted_person_ids():
		var person: Dictionary = sim.state.people[person_id]
		var action: Dictionary = person["action"]
		if action.is_empty() or action["kind"] != "talk" or now < action["ends_at"]:
			continue
		var other_id: String = action["other_id"]
		if person_id > other_id:
			continue  # the pair is settled once, from the lower ID
		var other: Dictionary = sim.state.people[other_id]
		_settle(sim, person, other, action["minutes"])
		for talker: Dictionary in [person, other]:
			var resume: Dictionary = talker["action"]["resume"]
			if not resume.is_empty() and resume["until"] < 0:
				resume["ends_at"] += action["minutes"]  # the talk did not count toward it
			talker["action"] = resume


static func _settle(sim: RefCounted, person: Dictionary, other: Dictionary, minutes: int) -> void:
	var generator: RandomNumberGenerator = sim.rng.stream("social")
	var record: Dictionary = sim.state.relationship(person["id"], other["id"])
	var first: Dictionary = person if record["a"] == person["id"] else other
	var second: Dictionary = other if record["a"] == person["id"] else person
	var a_change: int = _change(sim, generator, first, second, record["kin"])
	var b_change: int = _change(sim, generator, second, first, record["kin"])
	record["a_to_b"] = clampi(record["a_to_b"] + a_change, -100, 100)
	record["b_to_a"] = clampi(record["b_to_a"] + b_change, -100, 100)
	record["familiarity"] += 1
	record["last_talk_end"] = sim.clock.abs_minute()
	var event_id: int = sim.state.log_event(sim.clock.day_index, sim.clock.minute_of_day, "conversation", 1, {
		"a": record["a"], "b": record["b"], "minutes": minutes,
		"a_change": a_change, "b_change": b_change,
		"first_meeting": record["familiarity"] == 1 and not record["kin"],
		# Set when the two talked inside an institution; "" otherwise.
		"place_id": person["place_id"] if (
			person["at"] == Records.AT_INSIDE and other["at"] == Records.AT_INSIDE
			and person["place_id"] == other["place_id"] and sim.area.is_institution(person["place_id"])
		) else "",
	})
	record["history"].append(event_id)


## How much one person's regard for the other shifts after a conversation.
static func _change(sim: RefCounted, generator: RandomNumberGenerator, from: Dictionary, about: Dictionary, kin: bool) -> int:
	var tuning: Dictionary = sim.tuning
	var change: int = generator.randi_range(int(tuning["talk_change_min"]), int(tuning["talk_change_max"]))
	if (about["traits"] as Array).has("warm"):
		change += int(tuning["trait_warm_bonus"])
	if (about["traits"] as Array).has("prickly"):
		change -= int(tuning["trait_prickly_penalty"])
	if (from["traits"] as Array).has("prickly"):
		change -= 1
	if kin:
		change = maxi(change, -1)  # family quarrels pass quickly
	return change


static func _begin(sim: RefCounted, person: Dictionary, other: Dictionary) -> void:
	var generator: RandomNumberGenerator = sim.rng.stream("social")
	var minutes: int = generator.randi_range(int(sim.tuning["talk_min_minutes"]), int(sim.tuning["talk_max_minutes"]))
	var ends_at: int = sim.clock.abs_minute() + minutes
	for pair: Array in [[person, other], [other, person]]:
		var talk: Dictionary = Records.new_action("talk", "social", pair[0]["at"], pair[0]["place_id"])
		talk["routed"] = true
		talk["started"] = true
		talk["minutes"] = minutes
		talk["ends_at"] = ends_at
		talk["other_id"] = pair[1]["id"]
		var interrupted: Dictionary = pair[0]["action"]
		if not interrupted.is_empty() and interrupted["started"] and RESUMED_AFTER_TALK.has(interrupted["kind"]):
			talk["resume"] = interrupted
		pair[0]["action"] = talk


static func _can_talk(sim: RefCounted, person: Dictionary, other: Dictionary, ordered: bool) -> bool:
	var key: String = Records.relationship_key(person["id"], other["id"])
	if not sim.state.relationships.has(key):
		return true
	var record: Dictionary = sim.state.relationships[key]
	if ordered:
		return true
	if sim.clock.abs_minute() - record["last_talk_end"] < int(sim.tuning["talk_cooldown_minutes"]):
		return false
	# People who have come to dislike each other stop seeking each other out.
	return mini(record["a_to_b"], record["b_to_a"]) > int(sim.tuning["avoid_below_regard"])


## Someone standing at the front of a house talks with a person awake inside.
static func _door_calls(sim: RefCounted) -> void:
	for person_id: String in sim.state.sorted_person_ids():
		var person: Dictionary = sim.state.people[person_id]
		var action: Dictionary = person["action"]
		if action.is_empty() or not action["started"] or action["place_id"] == "":
			continue
		if action["kind"] != "visit" and action["kind"] != "call_on":
			continue
		var ordered: bool = action["kind"] == "call_on"
		for other_id: String in sim.state.sorted_person_ids():
			if other_id == person_id or (ordered and other_id != action["other_id"]):
				continue
			var other: Dictionary = sim.state.people[other_id]
			if other["at"] != Records.AT_INSIDE or other["place_id"] != action["place_id"]:
				continue
			if not other["action"].is_empty() and other["action"]["started"] and NOT_AT_THE_DOOR.has(other["action"]["kind"]):
				continue
			if other["household_id"] == person["household_id"] or not _can_talk(sim, person, other, ordered):
				continue
			if sim.world["schedules"][other["schedule_id"]].get("housebound", false):
				continue  # small children do not answer the door
			_begin(sim, person, other)
			break


## People near each other outdoors may strike up a conversation.
static func _street_meetings(sim: RefCounted) -> void:
	var available: Array = []
	for person_id: String in sim.state.sorted_person_ids():
		var person: Dictionary = sim.state.people[person_id]
		var action: Dictionary = person["action"]
		if person["at"] != Records.AT_OUTSIDE or action.is_empty():
			continue
		if action["started"] and TALKABLE_OUTDOORS.has(action["kind"]):
			available.append(person)
		elif not action["started"] and (action["source"] == "need" or action["source"] == "idle"):
			available.append(person)  # walking somewhere with time to spare
	if available.size() < 2:
		return
	var generator: RandomNumberGenerator = sim.rng.stream("social")
	var reach: int = int(sim.tuning["talk_reach_inches"])
	var chance: int = int(sim.tuning["street_talk_chance_percent"])
	var busy: Dictionary = {}
	for i: int in available.size():
		var person: Dictionary = available[i]
		if busy.has(person["id"]):
			continue
		for j: int in range(i + 1, available.size()):
			var other: Dictionary = available[j]
			if busy.has(other["id"]) or other["household_id"] == person["household_id"]:
				continue
			if Area.distance_between([person["x"], person["y"]], [other["x"], other["y"]]) > reach:
				continue
			var ordered: bool = (
				(person["action"]["kind"] == "call_on" and person["action"]["other_id"] == other["id"])
				or (other["action"]["kind"] == "call_on" and other["action"]["other_id"] == person["id"])
			)
			if not _can_talk(sim, person, other, ordered):
				continue
			if not ordered and generator.randi_range(1, 100) > chance:
				continue
			_begin(sim, person, other)
			busy[person["id"]] = true
			busy[other["id"]] = true
			break


## People inside the same institution (staff and visitors) may talk.
static func _indoor_meetings(sim: RefCounted) -> void:
	var by_building: Dictionary = {}
	for person_id: String in sim.state.sorted_person_ids():
		var person: Dictionary = sim.state.people[person_id]
		var action: Dictionary = person["action"]
		if person["at"] != Records.AT_INSIDE or action.is_empty() or not action["started"]:
			continue
		if not sim.area.is_institution(person["place_id"]) or not TALKABLE_INDOORS.has(action["kind"]):
			continue
		# No new conversations so close to closing time that they would run past it.
		if not sim.area.is_open(person["place_id"], sim.clock.weekday(), sim.clock.minute_of_day + int(sim.tuning["talk_max_minutes"])):
			continue
		if not by_building.has(person["place_id"]):
			by_building[person["place_id"]] = []
		by_building[person["place_id"]].append(person)
	var generator: RandomNumberGenerator = sim.rng.stream("social")
	var chance: int = int(sim.tuning["indoor_talk_chance_percent"])
	var buildings: Array = by_building.keys()
	buildings.sort()
	for building_id: String in buildings:
		var present: Array = by_building[building_id]
		var busy: Dictionary = {}
		for i: int in present.size():
			if busy.has(present[i]["id"]):
				continue
			for j: int in range(i + 1, present.size()):
				var person: Dictionary = present[i]
				var other: Dictionary = present[j]
				if busy.has(other["id"]) or other["household_id"] == person["household_id"]:
					continue
				if not _can_talk(sim, person, other, false) or generator.randi_range(1, 100) > chance:
					continue
				_begin(sim, person, other)
				busy[person["id"]] = true
				busy[other["id"]] = true
				break
