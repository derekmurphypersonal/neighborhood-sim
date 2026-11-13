extends RefCounted
## The simulation core (D-017). No scene nodes, rendering, input or wall-clock
## time: it can be created and advanced with nothing on screen (D-029).
##
## There is one way time advances: tick(), one minute at a time. Work that
## belongs to a whole day (birthdays, the weekly budget) runs when a tick
## falls on midnight. advance_day_abstract() runs only that day-level work
## and jumps to the next midnight; it is what a long fast-forward uses, and
## it calls the very same day-level code, so the two can never disagree.

const SimDate := preload("res://sim/clock/sim_date.gd")
const SimClock := preload("res://sim/clock/sim_clock.gd")
const SimRng := preload("res://sim/rng/sim_rng.gd")
const WorldState := preload("res://sim/state/world_state.gd")
const Records := preload("res://sim/state/records.gd")
const Area := preload("res://sim/world/area.gd")
const Lifecycle := preload("res://sim/systems/lifecycle.gd")
const Economy := preload("res://sim/systems/economy.gd")
const Needs := preload("res://sim/systems/needs.gd")
const Behavior := preload("res://sim/systems/behavior.gd")
const Social := preload("res://sim/systems/social.gd")

## Static world: scenario, area, schedules, tuning (see world_loader.gd).
var world: Dictionary
var area: Area
var tuning: Dictionary
var clock: SimClock
var rng: SimRng
var state: WorldState
## Every order given, with the minute it was given: the record of inputs
## that, with the seed, reproduces a run. Not part of the simulation state.
var input_log: Array = []
## Where each person walked during the latest tick: {person_id: [[x, y], ...]}.
## For drawing only. Not simulation state, never saved, never read by systems.
var trails: Dictionary = {}


func _init(loaded_world: Dictionary) -> void:
	world = loaded_world
	area = loaded_world["area"]
	tuning = loaded_world["tuning"]
	clock = SimClock.new()
	rng = SimRng.new()
	state = WorldState.new()


## Starts a new game from the scenario. start_day_index and start_minute
## override the scenario's own start when given (0 or more).
static func new_game(loaded_world: Dictionary, seed_value: int, start_day_index: int = -1, start_minute: int = -1) -> RefCounted:
	var sim: RefCounted = new(loaded_world)
	var scenario: Dictionary = loaded_world["scenario"]
	sim.rng = SimRng.new(seed_value)
	var day: int = start_day_index if start_day_index >= 0 else int(SimDate.parse_iso(scenario["start_date"]))
	var minute: int = start_minute if start_minute >= 0 else int(scenario.get("start_minute", 0))
	sim.clock = SimClock.new(day, minute)
	sim.state.last_abstract_day = day - 1  # nothing before the start was followed
	sim._populate()
	return sim


func _populate() -> void:
	for source: Dictionary in world["households"]:
		var household: Dictionary = Records.new_household(source["id"], source["name"], source["home_id"])
		household["funds_cents"] = int(source["funds_cents"])
		household["weekly_rent_cents"] = int(source["weekly_rent_cents"])
		household["other_weekly_income_cents"] = int(source["other_weekly_income_cents"])
		household["pantry_meals"] = int(source["pantry_meals"])
		household["player_controlled"] = source.get("player_controlled", false)
		state.households[household["id"]] = household
	for source: Dictionary in world["persons"]:
		var person: Dictionary = Records.new_person(
			source["id"], source["given_name"], source["family_name"],
			int(SimDate.parse_iso(source["birth_date"])), source["household_id"]
		)
		person["schedule_id"] = source["schedule_id"]
		person["workplace_id"] = source.get("workplace_id", "")
		person["daily_wage_cents"] = int(source.get("daily_wage_cents", 0))
		person["traits"] = (source.get("traits", []) as Array).duplicate()
		var home: String = state.households[person["household_id"]]["home_id"]
		var door: Array = area.door_of(home)
		person["place_id"] = home
		person["x"] = door[0]
		person["y"] = door[1]
		state.people[person["id"]] = person
	for person_id: String in state.sorted_person_ids():
		state.households[state.people[person_id]["household_id"]]["member_ids"].append(person_id)
	# People who live together start out knowing and liking each other.
	for household_id: String in state.sorted_household_ids():
		var members: Array = state.households[household_id]["member_ids"]
		for i: int in members.size():
			for j: int in range(i + 1, members.size()):
				var record: Dictionary = state.relationship(members[i], members[j])
				record["kin"] = true
				record["a_to_b"] = int(tuning["kin_starting_regard"])
				record["b_to_a"] = int(tuning["kin_starting_regard"])


# --- Advancing time ----------------------------------------------------------

## Advances the simulation by one minute at close detail.
func tick() -> void:
	if clock.is_finished():
		return
	trails.clear()
	if clock.minute_of_day == 0:
		_on_day_start()
	Social.step(self)
	for person_id: String in state.sorted_person_ids():
		var person: Dictionary = state.people[person_id]
		Needs.step(self, person)
		Behavior.step(self, person)
		Economy.track(person)
	clock.advance_minutes(1)


func advance_minutes(minutes: int) -> void:
	for i: int in minutes:
		tick()


## Runs one whole day at the abstract level: day-level work only.
## Must be called at midnight.
func advance_day_abstract() -> void:
	assert(clock.minute_of_day == 0, "Abstract days start at midnight.")
	_on_day_start()
	Economy.abstract_day(self)
	clock.advance_to_next_day()


## Advances whole days abstractly until the given day or the end of 1959.
func advance_to_day_abstract(target_day_index: int) -> void:
	while clock.day_index < target_day_index and not clock.is_finished():
		advance_day_abstract()


func run_to_end_of_decade() -> void:
	advance_to_day_abstract(SimDate.LAST_DAY + 1)


func _on_day_start() -> void:
	Lifecycle.on_day_start(self)
	Economy.on_day_start(self)


# --- Player orders -----------------------------------------------------------

## Gives an order to a member of the player's household. Returns "" if the
## order was accepted, or the reason it was refused.
##   {"kind": "go_home"}
##   {"kind": "go_to", "place_id": <building id>}
##   {"kind": "talk_to", "other_id": <person id>}
##   {"kind": "enter", "place_id": <institution building id>}
##   {"kind": "use_room", "room_id": <room in the person's own home>}
func give_order(person_id: String, order: Dictionary) -> String:
	if not state.people.has(person_id):
		return "No such person."
	var person: Dictionary = state.people[person_id]
	if not state.households[person["household_id"]]["player_controlled"]:
		return "That person is not in your household."
	if world["schedules"][person["schedule_id"]].get("housebound", false):
		return "That person is too young to be sent out."
	match order.get("kind", ""):
		"go_home":
			pass
		"go_to":
			if not area.buildings.has(order.get("place_id", "")):
				return "No such place."
		"enter":
			if not area.is_institution(order.get("place_id", "")):
				return "That is not a place you can go into."
		"use_room":
			var home: String = state.households[person["household_id"]]["home_id"]
			if not area.has_interior(home) or not area.interiors[home]["rooms"].has(order.get("room_id", "")):
				return "No such room at home."
		"talk_to":
			if not state.people.has(order.get("other_id", "")) or order["other_id"] == person_id:
				return "No such person to talk to."
		_:
			return "Unknown order."
	person["orders"].append(order.duplicate())
	input_log.append({"at": clock.abs_minute(), "person_id": person_id, "order": order.duplicate()})
	return ""


# --- Saving ------------------------------------------------------------------

## The complete simulation state. Contains no floating-point numbers.
func to_save() -> Dictionary:
	return {"clock": clock.to_save(), "rng": rng.to_save(), "state": state.to_save()}


## Rebuilds a simulation from saved state and the static world it ran in.
## Low-level: "saved" is only the "simulation" part of a save document, as
## produced by to_save() and already checked by SaveGame.parse(). To load a
## save, call SaveGame.restore(), which does the checking and then calls this.
static func from_save(loaded_world: Dictionary, saved: Dictionary) -> RefCounted:
	var sim: RefCounted = new(loaded_world)
	sim.clock.load_save(saved["clock"])
	sim.rng.load_save(saved["rng"])
	sim.state.load_save(saved["state"])
	return sim


## SHA-256 of the complete state, in the same form that is written to a
## save. Two simulations agree exactly if and only if their hashes match.
func state_hash() -> String:
	return JSON.stringify(to_save(), "", true).sha256_text()
