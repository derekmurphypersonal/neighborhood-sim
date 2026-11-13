extends SceneTree
## Runs the scenario minute by minute for a number of days with nobody
## playing, then prints what happened and a state hash.
##
##   godot --headless --path game --script res://tools/run_days.gd -- --days 3 --seed 1950

const Simulation := preload("res://sim/simulation.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")
const SimDate := preload("res://sim/clock/sim_date.gd")

const SCENARIO: String = "fixture_street_spring_1950"


func _init() -> void:
	var seed_value: int = 1950
	var days: int = 3
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size() - 1:
		if args[i] == "--seed" and args[i + 1].is_valid_int():
			seed_value = args[i + 1].to_int()
		if args[i] == "--days" and args[i + 1].is_valid_int():
			days = args[i + 1].to_int()

	var world: Dictionary = WorldLoader.load_world(SCENARIO)
	if not world["errors"].is_empty():
		for error: String in world["errors"]:
			print("ERROR  " + error)
		quit(1)
		return

	var started_ms: int = Time.get_ticks_msec()
	var simulation: Simulation = Simulation.new_game(world, seed_value)
	if world["area"].placeholder:
		print("World: FICTIONAL development fixture (%s). Not real geography." % world["area"].display_name)
	print("Start: %s   seed: %d" % [simulation.clock.describe(), seed_value])
	simulation.advance_minutes(days * SimDate.MINUTES_PER_DAY)
	print("End:   %s" % simulation.clock.describe())

	var counts: Dictionary = {}
	for event: Dictionary in simulation.state.event_log:
		counts[event["type"]] = counts.get(event["type"], 0) + 1
	print("Events: %s" % str(counts))
	print("Regard between people of different households:")
	var keys: Array = simulation.state.relationships.keys()
	keys.sort()
	for key: String in keys:
		var record: Dictionary = simulation.state.relationships[key]
		if not record["kin"]:
			var a: Dictionary = simulation.state.people[record["a"]]
			var b: Dictionary = simulation.state.people[record["b"]]
			print("  %s and %s: %d / %d after %d conversation(s)" % [
				a["given_name"], b["given_name"], record["a_to_b"], record["b_to_a"], record["familiarity"],
			])
	print("State hash: %s" % simulation.state_hash())
	print("Elapsed: %d ms" % (Time.get_ticks_msec() - started_ms))
	quit(0)
