extends RefCounted
## Mutable simulation state (D-023): people, households, relationships and
## the life-event log. It never contains or alters area data; it refers to
## buildings by ID. Record shapes are defined in records.gd.

const Records := preload("res://sim/state/records.gd")

var people: Dictionary = {}
var households: Dictionary = {}
var relationships: Dictionary = {}
var event_log: Array = []
var next_event_id: int = 1


func sorted_person_ids() -> Array:
	var ids: Array = people.keys()
	ids.sort()
	return ids


func sorted_household_ids() -> Array:
	var ids: Array = households.keys()
	ids.sort()
	return ids


func player_household_id() -> String:
	for household_id: String in sorted_household_ids():
		if households[household_id]["player_controlled"]:
			return household_id
	return ""


## Returns the relationship record for a pair, creating it if needed.
func relationship(person_a: String, person_b: String) -> Dictionary:
	var key: String = Records.relationship_key(person_a, person_b)
	if not relationships.has(key):
		relationships[key] = Records.new_relationship(person_a, person_b)
	return relationships[key]


## How person_a regards person_b (0 if they have never met).
func regard(person_a: String, person_b: String) -> int:
	var key: String = Records.relationship_key(person_a, person_b)
	if not relationships.has(key):
		return 0
	var record: Dictionary = relationships[key]
	return record["a_to_b"] if record["a"] == person_a else record["b_to_a"]


## Appends an event and returns its ID. Every event has a running number,
## a day and a minute, a type and an importance (1 routine .. 3 major).
func log_event(day: int, minute: int, type: String, importance: int, details: Dictionary) -> int:
	var event: Dictionary = {
		"id": next_event_id, "day": day, "minute": minute, "type": type, "importance": importance,
	}
	event.merge(details)
	event_log.append(event)
	next_event_id += 1
	return event["id"]


func to_save() -> Dictionary:
	return {
		"people": people,
		"households": households,
		"relationships": relationships,
		"event_log": event_log,
		"next_event_id": next_event_id,
	}


func load_save(data: Dictionary) -> void:
	people = data["people"]
	households = data["households"]
	relationships = data["relationships"]
	event_log = data["event_log"]
	next_event_id = int(data["next_event_id"])
