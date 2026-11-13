extends SceneTree
## Runs the whole decade headless, at the abstract (day-by-day) level, and
## prints a state hash. Two runs with the same seed must print the same hash.
##
##   godot --headless --path game --script res://tools/run_decade.gd -- --seed 1950

const Simulation := preload("res://sim/simulation.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")

const SCENARIO: String = "fixture_street_spring_1950"


func _init() -> void:
	var seed_value: int = 1950
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size():
		if args[i] == "--seed" and i + 1 < args.size() and args[i + 1].is_valid_int():
			seed_value = args[i + 1].to_int()

	var world: Dictionary = WorldLoader.load_world(SCENARIO)
	if not world["errors"].is_empty():
		for error: String in world["errors"]:
			print("ERROR  " + error)
		quit(1)
		return

	var started_ms: int = Time.get_ticks_msec()
	# The decade run starts on 1 January 1950 whatever the scenario's own start.
	var simulation: Simulation = Simulation.new_game(world, seed_value, 0, 0)
	if world["area"].placeholder:
		print("World: FICTIONAL development fixture (%s). Not real geography." % world["area"].display_name)
	print("Start: %s   seed: %d" % [simulation.clock.describe(), seed_value])
	simulation.run_to_end_of_decade()
	print("End:   %s" % simulation.clock.describe())
	print("Events logged: %d" % simulation.state.event_log.size())
	print("State hash: %s" % simulation.state_hash())
	print("Elapsed: %d ms" % (Time.get_ticks_msec() - started_ms))
	quit(0)
