extends "res://tests/test_case.gd"
## The player directs members of one household (D-014).

const Simulation := preload("res://sim/simulation.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")
const Records := preload("res://sim/state/records.gd")

const SCENARIO: String = "fixture_street_spring_1950"


func _new() -> Simulation:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), 1950)
	simulation.advance_minutes(60)  # 07:00: the household is up
	return simulation


func test_only_the_players_household_takes_orders() -> void:
	var simulation: Simulation = _new()
	check_eq(simulation.give_order("fx_p_01", {"kind": "go_home"}), "", "a member of the player's household accepts")
	check(simulation.give_order("fx_p_05", {"kind": "go_home"}) != "", "a neighbor refuses")
	check(simulation.give_order("fx_p_01", {"kind": "dance"}) != "", "unknown orders are refused")
	check(simulation.give_order("fx_p_01", {"kind": "go_to", "place_id": "nowhere"}) != "", "unknown places are refused")
	check_eq(simulation.input_log.size(), 1, "only accepted orders are recorded")


func test_go_to_sends_a_person_there() -> void:
	var simulation: Simulation = _new()
	simulation.give_order("fx_p_01", {"kind": "go_to", "place_id": "fx_bd_6"})
	# She may be mid-conversation when told; she finishes it first (25 minutes
	# at most) and then walks over. Once there she may fall into talk with
	# someone else, so the check is that she arrives, not that she stays.
	var arrived: bool = false
	for minute: int in 40:
		simulation.tick()
		var person: Dictionary = simulation.state.people["fx_p_01"]
		if person["at"] == Records.AT_OUTSIDE and [person["x"], person["y"]] == simulation.area.front_of("fx_bd_6"):
			arrived = true
	check(arrived, "she reached the front of the house she was sent to within forty minutes")


func test_talk_to_starts_a_conversation() -> void:
	var simulation: Simulation = _new()
	check_eq(simulation.state.regard("fx_p_01", "fx_p_08"), 0, "they have not met")
	simulation.give_order("fx_p_01", {"kind": "talk_to", "other_id": "fx_p_08"})
	simulation.advance_minutes(60)
	var talked: bool = false
	for event: Dictionary in simulation.state.event_log:
		if event["type"] == "conversation" and [event["a"], event["b"]] == ["fx_p_01", "fx_p_08"]:
			talked = true
	check(talked, "the two talked within the hour")
	var record: Dictionary = simulation.state.relationship("fx_p_01", "fx_p_08")
	check_eq(record["familiarity"], 1, "and the relationship records it")


func test_orders_change_the_outcome() -> void:
	var directed: Simulation = _new()
	var left_alone: Simulation = _new()
	directed.give_order("fx_p_01", {"kind": "talk_to", "other_id": "fx_p_08"})
	directed.advance_minutes(600)
	left_alone.advance_minutes(600)
	check(directed.state_hash() != left_alone.state_hash(), "a day with an order differs from a day without")
