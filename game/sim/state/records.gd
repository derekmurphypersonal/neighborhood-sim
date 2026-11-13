extends RefCounted
## The shape of every mutable simulation record, in one place (D-023).
##
## Records are plain dictionaries created only by the functions below, so
## each field is declared exactly once.
##
## RULE: simulation state contains no floating-point numbers. Every number
## is a whole number: money in cents, positions in inches, needs in units of
## 0..NEED_MAX, time in minutes. This is what lets a save be restored exactly
## (a JSON reader returns every number as a decimal; restoring converts them
## all back to whole numbers, which is only safe if none were fractional).

const NEED_MAX: int = 100000
const NEED_NAMES: Array[String] = ["hunger", "rest", "company"]

## Where a person is.
const AT_INSIDE: String = "inside"    # inside the building of place_id
const AT_OUTSIDE: String = "outside"  # outdoors at x, y
const AT_OFFMAP: String = "offmap"    # left the playable area


static func new_person(id: String, given_name: String, family_name: String, birth_day: int, household_id: String) -> Dictionary:
	return {
		"id": id,
		"given_name": given_name,
		"family_name": family_name,
		"birth_day": birth_day,      # day index; age is always computed from it
		"household_id": household_id,
		"schedule_id": "",
		"traits": [],
		"needs": {"hunger": NEED_MAX, "rest": NEED_MAX, "company": NEED_MAX},
		"at": AT_INSIDE,
		"place_id": "",              # building when inside; "" otherwise
		"spot": "",                  # room within that building's interior, if it has one
		"x": 0,                      # inches; meaningful when outside
		"y": 0,
		"last_set_meal_day": -1,     # day index of the last fixed household meal attended
		"action": {},                # current action, or {} when deciding
		"orders": [],                # player commands waiting to be carried out
	}


static func new_household(id: String, household_name: String, home_id: String) -> Dictionary:
	return {
		"id": id,
		"name": household_name,
		"home_id": home_id,          # building ID in the area data
		"member_ids": [],
		"funds_cents": 0,
		"weekly_income_cents": 0,
		"weekly_expense_cents": 0,
		"player_controlled": false,
	}


static func relationship_key(person_a: String, person_b: String) -> String:
	return person_a + "|" + person_b if person_a < person_b else person_b + "|" + person_a


## One record per pair. "a" is the ID that sorts first.
static func new_relationship(person_a: String, person_b: String) -> Dictionary:
	var first: String = person_a if person_a < person_b else person_b
	var second: String = person_b if person_a < person_b else person_a
	return {
		"a": first,
		"b": second,
		"a_to_b": 0,                 # how a regards b, -100..100
		"b_to_a": 0,
		"familiarity": 0,            # number of conversations
		"kin": false,
		"last_talk_end": -1000000,   # absolute minute
		"history": [],               # event IDs
	}


## An action: something a person is doing or on the way to do.
##   kind      sleep, eat, work, school, be_home, sit_out, visit, go_to,
##             call_on, talk, be_inside (inside an institution)
##   source    who chose it: schedule, need, idle, player, social
##   where     AT_INSIDE, AT_OUTSIDE or AT_OFFMAP: where it is carried out
##   place_id  the building or exit it happens at
##   tx, ty    target point in inches when where is AT_OUTSIDE
##   path      remaining waypoints [[x, y], ...] while travelling
##   started   true once the person has arrived and begun
##   ends_at   absolute minute at which it finishes (set on arrival)
##   minutes   how long it lasts once started (0 if until is used)
##   until     fixed absolute end minute, or -1
static func new_action(kind: String, source: String, where: String, place_id: String) -> Dictionary:
	return {
		"kind": kind,
		"source": source,
		"where": where,
		"place_id": place_id,
		"tx": 0,
		"ty": 0,
		"path": [],
		"routed": false,
		"started": false,
		"ends_at": -1,
		"minutes": 0,
		"until": -1,
		"other_id": "",
		"room_kind": "",             # kind of room it is done in, where the building has an interior
		"resume": {},                # for a conversation: the action it interrupted, to be taken up again
	}
