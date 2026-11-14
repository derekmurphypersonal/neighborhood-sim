extends SceneTree
## Runs the first week of the scenario with nobody giving orders and reports
## how it paces: what people spend their time on, how their needs hold up,
## how often they talk, and how each household's money goes.
##
##   godot --headless --path game --script res://tools/playtest_week.gd
##
## This measures the simulation. It is not a substitute for a person playing.

const Simulation := preload("res://sim/simulation.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")
const WeekSummary := preload("res://sim/reports/week_summary.gd")
const SimDate := preload("res://sim/clock/sim_date.gd")
const Records := preload("res://sim/state/records.gd")

const SCENARIO: String = "fixture_street_spring_1950"
const WEEK_MINUTES: int = 7 * 1440


func _init() -> void:
	var world: Dictionary = WorldLoader.load_world(SCENARIO)
	if not world["errors"].is_empty():
		print("Could not load: ", world["errors"])
		quit(1)
		return
	var seed_value: int = int(world["scenario"].get("default_seed", 1))
	var simulation: Simulation = Simulation.new_game(world, seed_value)
	var area: RefCounted = simulation.area
	print("World: %s" % ("FICTIONAL development fixture (%s). Not real geography." % area.display_name if area.placeholder else area.display_name))
	print("Start: %s   seed: %d" % [simulation.clock.describe(), seed_value])
	var first_day: int = simulation.clock.day_index

	var time_on: Dictionary = {}     # person -> kind -> minutes
	var lowest: Dictionary = {}      # person -> need -> lowest value
	var low_minutes: Dictionary = {} # need -> person-minutes below a fifth of full
	var awake_minutes: int = 0
	var quiet_minutes: int = 0       # waking minutes with none of the player's household on the street or talking
	var player_ids: Array = simulation.state.households[simulation.state.player_household_id()]["member_ids"]
	for need: String in Records.NEED_NAMES:
		low_minutes[need] = 0
	for person_id: String in simulation.state.sorted_person_ids():
		time_on[person_id] = {}
		lowest[person_id] = {}
		for need: String in Records.NEED_NAMES:
			lowest[person_id][need] = Records.NEED_MAX

	for minute: int in WEEK_MINUTES:
		simulation.tick()
		var daytime: bool = simulation.clock.minute_of_day >= 420 and simulation.clock.minute_of_day < 1320
		var player_visible: bool = false
		for person_id: String in simulation.state.sorted_person_ids():
			var person: Dictionary = simulation.state.people[person_id]
			var kind: String = "deciding" if person["action"].is_empty() else str(person["action"]["kind"])
			if not person["action"].is_empty() and not person["action"]["started"]:
				kind = "walking"
			time_on[person_id][kind] = int(time_on[person_id].get(kind, 0)) + 1
			for need: String in Records.NEED_NAMES:
				lowest[person_id][need] = mini(lowest[person_id][need], person["needs"][need])
				@warning_ignore("integer_division")
				if person["needs"][need] < Records.NEED_MAX / 5:
					low_minutes[need] += 1
			if player_ids.has(person_id) and (person["at"] == Records.AT_OUTSIDE or kind == "talk" or kind == "shop"):
				player_visible = true
		if daytime:
			awake_minutes += 1
			if not player_visible:
				quiet_minutes += 1
	print("End:   %s" % simulation.clock.describe())

	print("\nWhere the time went (hours over the week, all %d residents together):" % simulation.state.people.size())
	var totals: Dictionary = {}
	for person_id: String in time_on:
		for kind: String in time_on[person_id]:
			totals[kind] = int(totals.get(kind, 0)) + int(time_on[person_id][kind])
	var kinds: Array = totals.keys()
	kinds.sort_custom(func(a: String, b: String) -> bool: return totals[a] > totals[b] if totals[a] != totals[b] else a < b)
	for kind: String in kinds:
		@warning_ignore("integer_division")
		print("  %-10s %5d h  %3d%%" % [kind, totals[kind] / 60, totals[kind] * 100 / (WEEK_MINUTES * simulation.state.people.size())])

	print("\nLowest each need fell (0 to 100), by person:")
	for person_id: String in simulation.state.sorted_person_ids():
		var parts: Array[String] = []
		for need: String in Records.NEED_NAMES:
			@warning_ignore("integer_division")
			parts.append("%s %d" % [need, lowest[person_id][need] / 1000])
		print("  %-9s %s" % [simulation.state.people[person_id]["given_name"], ", ".join(parts)])
	print("Person-hours with a need below 20:")
	for need: String in Records.NEED_NAMES:
		@warning_ignore("integer_division")
		print("  %-8s %d" % [need, low_minutes[need] / 60])

	var counts: Dictionary = {}
	var per_day: Dictionary = {}
	for event: Dictionary in simulation.state.event_log:
		counts[event["type"]] = int(counts.get(event["type"], 0)) + 1
		var day_name: String = SimDate.weekday_name(event["day"]).left(3) + (" (2)" if event["day"] >= first_day + 7 else "")
		if event["type"] == "conversation":
			per_day[day_name] = int(per_day.get(day_name, 0)) + 1
	print("\nEvents in the week: %s" % [counts])
	print("Conversations by day: %s" % [per_day])
	var regards: Array = []
	var met: int = 0
	for key: String in simulation.state.relationships:
		var record: Dictionary = simulation.state.relationships[key]
		if not record["kin"] and record["familiarity"] > 0:
			met += 1
			regards.append(record["a_to_b"])
			regards.append(record["b_to_a"])
	regards.sort()
	if not regards.is_empty():
		@warning_ignore("integer_division")
		print("Pairs of neighbors who have met: %d.  Regard: lowest %d, middle %d, highest %d" % [met, regards[0], regards[regards.size() / 2], regards[-1]])
	@warning_ignore("integer_division")
	print("Daytime (07:00 to 22:00) with none of the player's household out on the street, talking or shopping: %d%%" % (quiet_minutes * 100 / awake_minutes))

	print("\nHouseholds over the week (invented amounts):")
	for household_id: String in simulation.state.sorted_household_ids():
		var household: Dictionary = simulation.state.households[household_id]
		var summary: Dictionary = WeekSummary.summarize(simulation.state, household_id, first_day, first_day + 6)
		print("  %-20s wages %5d  other %4d  rent %4d  groceries %4d (%d trips)  net %+5d  now %5d cents, %2d meals; missed %d, thin days %d, short %d" % [
			household["name"], summary["wages_cents"], summary["other_income_cents"], summary["rent_paid_cents"],
			summary["groceries_cents"], summary["shopping_trips"], summary["net_cents"], household["funds_cents"], household["pantry_meals"],
			summary["days_missed"], summary["thin_meal_days"], summary["times_short"],
		])
	print("\nState hash: %s" % simulation.state_hash())
	quit(0)
