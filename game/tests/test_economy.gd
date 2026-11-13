extends "res://tests/test_case.gd"
## Household money that follows what people do (M1-B step 7): wages for days
## actually worked, rent, groceries bought at the store, and going short.
## Every amount here is invented for the fictional test street.

const Simulation := preload("res://sim/simulation.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")
const Economy := preload("res://sim/systems/economy.gd")
const SimDate := preload("res://sim/clock/sim_date.gd")

const SCENARIO: String = "fixture_street_spring_1950"
const SEED: int = 1950
const PLAYER_HOUSEHOLD: String = "fx_hh_1"
const WORKER: String = "fx_p_02"  # in the player's household
const AT_HOME: String = "fx_p_01"
const DAY: int = 1440


func _monday_sim() -> Simulation:
	var simulation: Simulation = Simulation.new_game(WorldLoader.load_world(SCENARIO), SEED)
	check_eq(simulation.clock.weekday(), 1, "the scenario starts on a Monday")
	return simulation


func _events(simulation: Simulation, type: String, household_id: String) -> Array:
	var found: Array = []
	for event: Dictionary in simulation.state.event_log:
		if event["type"] == type and event.get("household_id", "") == household_id:
			found.append(event)
	return found


## Runs until just after midnight has been dealt with on the given weekday.
func _run_to_start_of(simulation: Simulation, weekday: int) -> void:
	simulation.advance_minutes(DAY - simulation.clock.minute_of_day)
	while simulation.clock.weekday() != weekday:
		simulation.advance_minutes(DAY)
	simulation.advance_minutes(1)


func test_wages_are_paid_on_friday_for_days_worked() -> void:
	var simulation: Simulation = _monday_sim()
	var wage: int = simulation.state.people[WORKER]["daily_wage_cents"]
	check(wage > 0, "the worker has a daily wage")
	_run_to_start_of(simulation, 5)
	var paydays: Array = _events(simulation, "payday", PLAYER_HOUSEHOLD)
	check_eq(paydays.size(), 1, "one payday by the first Friday")
	check_eq(paydays[0]["wages_cents"], wage * 4, "Monday to Thursday worked: four days' wages")
	check_eq(simulation.state.households[PLAYER_HOUSEHOLD]["wages_due_cents"], 0, "nothing left owing after payday")
	check_eq(_events(simulation, "missed_work", PLAYER_HOUSEHOLD).size(), 0, "no day was missed")


func test_a_day_kept_home_earns_nothing() -> void:
	var simulation: Simulation = _monday_sim()
	var wage: int = simulation.state.people[WORKER]["daily_wage_cents"]
	# Keep the worker at home all of Monday by repeating the order.
	while simulation.clock.weekday() == 1:
		if simulation.state.people[WORKER]["orders"].is_empty() and simulation.clock.minute_of_day < 1050:
			simulation.give_order(WORKER, {"kind": "go_home"})
		simulation.advance_minutes(5)
	_run_to_start_of(simulation, 5)
	var missed: Array = _events(simulation, "missed_work", PLAYER_HOUSEHOLD)
	check_eq(missed.size(), 1, "the missed day is recorded")
	check_eq(missed[0]["lost_cents"], wage, "with the wage lost")
	check_eq(_events(simulation, "payday", PLAYER_HOUSEHOLD)[0]["wages_cents"], wage * 3, "three days' wages, not four")


func test_other_income_is_paid_without_work() -> void:
	var simulation: Simulation = _monday_sim()
	_run_to_start_of(simulation, 5)
	var paydays: Array = _events(simulation, "payday", "fx_hh_2")
	check_eq(paydays.size(), 1, "the household with no worker is still paid")
	check_eq(paydays[0]["wages_cents"], 0, "no wages")
	check_eq(paydays[0]["other_cents"], simulation.state.households["fx_hh_2"]["other_weekly_income_cents"], "its other income")


func test_rent_is_paid_on_monday() -> void:
	var simulation: Simulation = _monday_sim()
	var household: Dictionary = simulation.state.households[PLAYER_HOUSEHOLD]
	_run_to_start_of(simulation, 0)  # Sunday
	var before: int = household["funds_cents"]
	check(before >= household["weekly_rent_cents"], "the household can cover its rent")
	check_eq(_events(simulation, "rent_paid", PLAYER_HOUSEHOLD).size(), 0, "no rent before the first Monday midnight")
	simulation.advance_minutes(DAY)
	var paid: Array = _events(simulation, "rent_paid", PLAYER_HOUSEHOLD)
	check_eq(paid.size(), 1, "rent paid on Monday")
	check_eq(paid[0]["paid_cents"], household["weekly_rent_cents"], "in full")
	check_eq(paid[0]["short_cents"], 0, "nothing short")
	check_eq(household["rent_owed_cents"], 0, "nothing owed")


func test_rent_shortfall_is_carried_forward() -> void:
	var simulation: Simulation = _monday_sim()
	var household: Dictionary = simulation.state.households[PLAYER_HOUSEHOLD]
	household["funds_cents"] = 500
	household["wages_due_cents"] = 0
	simulation.clock.minute_of_day = 0  # Monday midnight
	Economy.on_day_start(simulation)
	var rent: int = household["weekly_rent_cents"]
	check_eq(household["funds_cents"], 0, "the household pays what it has; money never goes below zero")
	check_eq(household["rent_owed_cents"], rent - 500, "the rest is owed")
	check_eq(_events(simulation, "household_short_of_money", PLAYER_HOUSEHOLD).size(), 1, "the shortfall is recorded")
	household["funds_cents"] = 10000
	Economy.on_day_start(simulation)
	check_eq(household["funds_cents"], 10000 - rent - (rent - 500), "next rent day settles the arrears as well")
	check_eq(household["rent_owed_cents"], 0, "arrears cleared")


func test_a_meal_comes_out_of_the_pantry() -> void:
	var simulation: Simulation = _monday_sim()
	var household: Dictionary = simulation.state.households[PLAYER_HOUSEHOLD]
	var person: Dictionary = simulation.state.people[AT_HOME]
	household["pantry_meals"] = 1
	person["needs"]["hunger"] = 90000
	Economy.finish_meal(simulation, person)
	check_eq(household["pantry_meals"], 0, "one meal used")
	check_eq(person["needs"]["hunger"], 90000, "a proper meal leaves hunger as eating made it")
	Economy.finish_meal(simulation, person)
	Economy.finish_meal(simulation, person)
	check_eq(household["pantry_meals"], 0, "the pantry never goes below nothing")
	check_eq(person["needs"]["hunger"], int(simulation.tuning["hunger_after_thin_meal"]), "a thin meal does little for hunger")
	check_eq(_events(simulation, "empty_pantry", PLAYER_HOUSEHOLD).size(), 1, "an empty pantry is recorded once a day")


func test_meals_eaten_over_a_day_use_the_pantry() -> void:
	var simulation: Simulation = _monday_sim()
	var household: Dictionary = simulation.state.households[PLAYER_HOUSEHOLD]
	household["pantry_meals"] = 1000  # no call to shop
	simulation.advance_minutes(DAY)
	var used: int = 1000 - household["pantry_meals"]
	check(used >= 6 and used <= 16, "four people eat between six and sixteen meals from the pantry in a day (ate %d)" % used)


func test_a_low_pantry_sends_someone_to_the_store() -> void:
	var simulation: Simulation = _monday_sim()
	var household: Dictionary = simulation.state.households[PLAYER_HOUSEHOLD]
	household["pantry_meals"] = 0
	household["funds_cents"] = 5000
	simulation.advance_minutes(6 * 60)  # to noon; the store opens at 08:00
	var trips: Array = _events(simulation, "shopping", PLAYER_HOUSEHOLD)
	check_eq(trips.size(), 1, "one shopping trip")
	var price: int = int(simulation.tuning["meal_price_cents"])
	var stock: int = Economy.meals_per_day(simulation, household) * int(simulation.tuning["pantry_stock_days"])
	check_eq(trips[0]["meals"], stock, "the pantry is stocked up")
	check_eq(trips[0]["cost_cents"], stock * price, "at the price per meal")
	check_eq(trips[0]["person_id"], AT_HOME, "the adult at home goes; the children and the worker do not")
	check_eq(household["funds_cents"], 5000 - stock * price - 0, "the money is spent")


func test_shopping_buys_only_what_can_be_afforded() -> void:
	var simulation: Simulation = _monday_sim()
	var household: Dictionary = simulation.state.households[PLAYER_HOUSEHOLD]
	var price: int = int(simulation.tuning["meal_price_cents"])
	household["pantry_meals"] = 0
	household["funds_cents"] = price * 3 + 5
	Economy.finish_shopping(simulation, simulation.state.people[AT_HOME])
	check_eq(household["pantry_meals"], 3, "three meals bought")
	check_eq(household["funds_cents"], 5, "money never goes below zero")
	var short: Array = _events(simulation, "household_short_of_money", PLAYER_HOUSEHOLD)
	check_eq(short.size(), 1, "going short on groceries is recorded")
	check_eq(short[0]["reason"], "groceries", "with the reason")
	check_eq(Economy.shopping_errand(simulation, simulation.state.people[AT_HOME]), "", "with no money for a meal, nobody is sent")


func test_money_is_never_negative_and_always_whole() -> void:
	var simulation: Simulation = _monday_sim()
	simulation.advance_minutes(DAY * 7 - simulation.clock.minute_of_day)
	simulation.advance_to_day_abstract(simulation.clock.day_index + 400)
	for household_id: String in simulation.state.sorted_household_ids():
		var household: Dictionary = simulation.state.households[household_id]
		for field: String in ["funds_cents", "rent_owed_cents", "wages_due_cents", "pantry_meals"]:
			check(household[field] is int and household[field] >= 0, "%s %s is a whole number, zero or more" % [household_id, field])


func test_days_run_abstractly_are_not_paid_twice() -> void:
	var simulation: Simulation = _monday_sim()
	simulation.advance_minutes(DAY - simulation.clock.minute_of_day)  # to Tuesday midnight
	simulation.advance_day_abstract()                               # Tuesday, abstractly
	simulation.advance_minutes(DAY * 2 + 1)                         # Wednesday, Thursday, into Friday
	var wage: int = simulation.state.people[WORKER]["daily_wage_cents"]
	var paydays: Array = _events(simulation, "payday", PLAYER_HOUSEHOLD)
	check_eq(paydays[0]["wages_cents"], wage * 4, "four days' wages whichever way the days were run")
	check_eq(_events(simulation, "missed_work", PLAYER_HOUSEHOLD).size(), 0, "an abstract day is not a missed day")


## The abstract level reckons money from timetables alone. Over four weeks it
## should land near what following everyone minute by minute gives.
func test_abstract_and_close_money_roughly_agree() -> void:
	var close: Simulation = _monday_sim()
	var abstract: Simulation = _monday_sim()
	close.advance_minutes(DAY - close.clock.minute_of_day)
	abstract.advance_minutes(DAY - abstract.clock.minute_of_day)
	close.advance_minutes(DAY * 28)
	abstract.advance_to_day_abstract(abstract.clock.day_index + 28)
	for household_id: String in close.state.sorted_household_ids():
		var a: Dictionary = close.state.households[household_id]
		var b: Dictionary = abstract.state.households[household_id]
		# Compare what each household is worth: money, wages earned, food in hand, less rent owed.
		var price: int = int(close.tuning["meal_price_cents"])
		var worth_close: int = a["funds_cents"] + a["wages_due_cents"] + a["pantry_meals"] * price - a["rent_owed_cents"]
		var worth_abstract: int = b["funds_cents"] + b["wages_due_cents"] + b["pantry_meals"] * price - b["rent_owed_cents"]
		var income: int = a["other_weekly_income_cents"] * 4
		for member_id: String in a["member_ids"]:
			income += close.state.people[member_id]["daily_wage_cents"] * 20
		print("    %s after four weeks: close %d, abstract %d, income %d" % [household_id, worth_close, worth_abstract, income])
		@warning_ignore("integer_division")
		check(absi(worth_close - worth_abstract) <= income / 4, "%s: the two levels agree to within a quarter of four weeks' income" % household_id)
