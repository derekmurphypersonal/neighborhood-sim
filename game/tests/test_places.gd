extends "res://tests/test_case.gd"
## Capabilities for places (M1-B step 3): rooms inside a building with an
## interior, going into an institution during its hours, and taking an
## interrupted action up again after a conversation.
##
## These tests add a fictional interior and a fictional institution to the
## loaded area directly, so they do not depend on what the scenario contains.

const Simulation := preload("res://sim/simulation.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")
const SaveGame := preload("res://sim/io/save_game.gd")
const Records := preload("res://sim/state/records.gd")
const Area := preload("res://sim/world/area.gd")

const SCENARIO: String = "fixture_street_spring_1950"
const HOME: String = "fx_bd_1"
const HALL: String = "fx_bd_6"
const TEST_PLAN: Dictionary = {
	"id": "fp_test", "name": "Test plan", "rooms": [
		{"id": "kitchen", "name": "Kitchen", "kind": "kitchen", "rect_ft": [0, 0, 15, 20]},
		{"id": "living", "name": "Living room", "kind": "living", "rect_ft": [15, 0, 15, 20]},
		{"id": "bedroom", "name": "Bedroom", "kind": "bedroom", "rect_ft": [0, 20, 30, 20]},
	],
}
const TEST_HALL: Dictionary = {
	"id": "fx_in_test", "type": "institution", "building_id": HALL, "name": "Test hall", "kind": "hall",
	"hours": {"weekday": [480, 1080], "saturday": [480, 720], "sunday": null},
}


func _world() -> Dictionary:
	var world: Dictionary = WorldLoader.load_world(SCENARIO)
	var area: Area = world["area"]
	area.interiors.clear()
	area.institutions.clear()
	area.set_interior(HOME, TEST_PLAN)
	area.add_record(TEST_HALL)
	return world


func _new() -> Simulation:
	return Simulation.new_game(_world(), 1950)


func _doing(person: Dictionary) -> String:
	return person["action"]["kind"] if not person["action"].is_empty() and person["action"]["started"] else ""


func test_interior_rooms_are_placed_in_the_building() -> void:
	var area: Area = _world()["area"]
	check(area.has_interior(HOME), "the home has an interior")
	check(not area.has_interior("fx_bd_2"), "other buildings do not")
	# Building 1's footprint starts at x 45 ft, y 45 ft.
	check_eq(area.interiors[HOME]["rooms"]["kitchen"]["rect"], [540, 540, 180, 240], "rooms are stored in world inches")
	check_eq(area.room_of_kind(HOME, "bedroom"), "bedroom", "a room can be found by kind")
	check_eq(area.room_of_kind(HOME, "cellar"), "", "a kind the plan lacks gives no room")
	check_eq(area.room_of_kind("fx_bd_2", "kitchen"), "", "a building without an interior gives no room")


func test_people_use_the_right_room() -> void:
	var simulation: Simulation = _new()
	var seen: Dictionary = {}
	for minute: int in 1440:
		simulation.tick()
		var person: Dictionary = simulation.state.people["fx_p_01"]
		if person["at"] == Records.AT_INSIDE and person["place_id"] == HOME and _doing(person) != "":
			seen[_doing(person)] = person["spot"]
		if person["at"] != Records.AT_INSIDE:
			check_eq(person["spot"], "", "nobody outdoors is in a room")
	check_eq(seen.get("sleep", "?"), "bedroom", "she sleeps in the bedroom")
	check_eq(seen.get("eat", "?"), "kitchen", "she eats in the kitchen")
	var neighbor: Dictionary = simulation.state.people["fx_p_07"]
	check_eq(neighbor["spot"], "", "people in buildings without an interior have no room")


func test_player_can_send_someone_to_a_room() -> void:
	var simulation: Simulation = _new()
	simulation.advance_minutes(60)
	check(simulation.give_order("fx_p_01", {"kind": "use_room", "room_id": "attic"}) != "", "an unknown room is refused")
	check_eq(simulation.give_order("fx_p_01", {"kind": "use_room", "room_id": "living"}), "", "a real room is accepted")
	var reached: bool = false
	for minute: int in 40:
		simulation.tick()
		var person: Dictionary = simulation.state.people["fx_p_01"]
		if person["spot"] == "living" and person["action"].get("source", "") == "player":
			reached = true
	check(reached, "she goes to the living room")


func test_institution_hours() -> void:
	var area: Area = _world()["area"]
	check(area.is_institution(HALL) and not area.is_institution(HOME), "only the hall is an institution")
	check(area.is_open(HALL, 1, 600), "open on Monday at 10:00")
	check(not area.is_open(HALL, 1, 470), "closed on Monday at 07:50")
	check(not area.is_open(HALL, 1, 1080), "closed at closing time")
	check(area.is_open(HALL, 6, 600) and not area.is_open(HALL, 6, 800), "shorter hours on Saturday")
	check(not area.is_open(HALL, 0, 600), "closed on Sunday")
	check_eq(area.institution_of_kind("hall"), HALL, "an institution can be found by kind")


func test_going_into_an_institution() -> void:
	var simulation: Simulation = _new()
	check(simulation.give_order("fx_p_01", {"kind": "enter", "place_id": HOME}) != "", "a house is not somewhere to go into")
	simulation.advance_minutes(150)  # 08:30, open
	check_eq(simulation.give_order("fx_p_01", {"kind": "enter", "place_id": HALL}), "", "an open institution is accepted")
	var entered: bool = false
	for minute: int in 40:
		simulation.tick()
		var person: Dictionary = simulation.state.people["fx_p_01"]
		if person["at"] == Records.AT_INSIDE and person["place_id"] == HALL:
			entered = true
	check(entered, "she goes inside")


func test_closed_institution_turns_people_away() -> void:
	var simulation: Simulation = _new()
	simulation.advance_minutes(30)  # 06:30, closed
	simulation.give_order("fx_p_01", {"kind": "enter", "place_id": HALL})
	simulation.advance_minutes(40)
	var refused: bool = false
	for event: Dictionary in simulation.state.event_log:
		if event["type"] == "order_failed" and event.get("reason", "") == "closed":
			refused = true
	check(refused, "the order fails because the place is closed")
	check(simulation.state.people["fx_p_01"]["place_id"] != HALL, "and she does not go in")


func test_visitors_leave_at_closing_time() -> void:
	var simulation: Simulation = _new()
	simulation.advance_minutes(705)  # 17:45
	simulation.give_order("fx_p_01", {"kind": "enter", "place_id": HALL})
	var was_inside: bool = false
	var inside_after_closing: bool = false
	for minute: int in 60:
		simulation.tick()
		var person: Dictionary = simulation.state.people["fx_p_01"]
		var inside: bool = person["at"] == Records.AT_INSIDE and person["place_id"] == HALL
		was_inside = was_inside or inside
		if inside and simulation.clock.minute_of_day > 1082:
			inside_after_closing = true
	check(was_inside, "she got in before closing")
	check(not inside_after_closing, "and was out again once it closed at 18:00")


func test_interrupted_action_resumes_after_a_conversation() -> void:
	var simulation: Simulation = _new()
	simulation.advance_minutes(150)
	simulation.give_order("fx_p_01", {"kind": "enter", "place_id": HALL})
	simulation.give_order("fx_p_03", {"kind": "go_to", "place_id": "fx_bd_5"})
	var resumed: int = 0
	var previous: Dictionary = {}
	for minute: int in 600:
		simulation.tick()
		for person_id: String in simulation.state.sorted_person_ids():
			var action: Dictionary = simulation.state.people[person_id]["action"]
			var before: Dictionary = previous.get(person_id, {})
			if not before.is_empty() and before["kind"] == "talk" and not before["resume"].is_empty():
				if not action.is_empty() and action["kind"] == before["resume"]["kind"]:
					resumed += 1
			previous[person_id] = action.duplicate(true)
	check(resumed > 0, "at least one interrupted action was taken up again after talking")


func test_new_state_survives_a_save() -> void:
	var world: Dictionary = _world()
	var straight: Simulation = Simulation.new_game(world, 1950)
	var saved_midway: Simulation = Simulation.new_game(world, 1950)
	for simulation: Simulation in [straight, saved_midway]:
		simulation.advance_minutes(150)
		simulation.give_order("fx_p_01", {"kind": "enter", "place_id": HALL})
		simulation.give_order("fx_p_02", {"kind": "use_room", "room_id": "living"})
		simulation.advance_minutes(12)
	var person: Dictionary = saved_midway.state.people["fx_p_01"]
	check(person.has("spot") and person["action"].has("resume") and person["action"].has("room_kind"), "the new fields are present")
	var restored: Dictionary = SaveGame.restore(SaveGame.to_text(saved_midway), world)
	check(restored["ok"], "a save taken while inside an institution loads")
	var resumed: Simulation = restored["simulation"]
	check_eq(resumed.state_hash(), saved_midway.state_hash(), "with identical state, rooms and interrupted actions included")
	straight.advance_minutes(900)
	resumed.advance_minutes(900)
	check_eq(resumed.state_hash(), straight.state_hash(), "and continues exactly as an uninterrupted run")
