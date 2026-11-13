extends RefCounted
## Household money that follows what people do.
##
##   Wages      Each day a person actually spends enough time at work earns
##              their household that day's wage, paid out on Friday.
##   Rent       Due every Monday. A household pays what it can; the rest is
##              carried forward as rent owed.
##   Groceries  Meals come out of the pantry. When it runs low, an adult goes
##              to the store and buys what the household can afford.
##   Shortfall  A household that cannot cover rent or groceries is short of
##              money; with an empty pantry, meals are thin ones.
##
## Money never goes below zero and every amount is whole cents. All prices,
## wages and rents are invented for play (tuning and scenario data).

const Records := preload("res://sim/state/records.gd")
const SimDate := preload("res://sim/clock/sim_date.gd")

const RENT_WEEKDAY: int = 1    # Monday
const PAYDAY_WEEKDAY: int = 5  # Friday


## Day-level work, run at the start of every day at every level of detail.
static func on_day_start(sim: RefCounted) -> void:
	_settle_attendance(sim)
	if sim.clock.weekday() == RENT_WEEKDAY:
		_collect_rent(sim)
	if sim.clock.weekday() == PAYDAY_WEEKDAY:
		_pay_out(sim)


## Called every minute for each person at close detail.
static func track(person: Dictionary) -> void:
	var action: Dictionary = person["action"]
	if not action.is_empty() and action["started"] and action["kind"] == "work":
		person["worked_minutes_today"] += 1


## Credits yesterday's wage to each person who worked enough of the day.
static func _settle_attendance(sim: RefCounted) -> void:
	var yesterday: int = sim.clock.day_index - 1
	var followed: bool = yesterday > sim.state.last_abstract_day
	for person_id: String in sim.state.sorted_person_ids():
		var person: Dictionary = sim.state.people[person_id]
		if person["daily_wage_cents"] > 0 and followed:
			var household: Dictionary = sim.state.households[person["household_id"]]
			if person["worked_minutes_today"] >= int(sim.tuning["work_attendance_minutes"]):
				household["wages_due_cents"] += person["daily_wage_cents"]
			elif _is_workday(sim, person, SimDate.weekday(yesterday)):
				sim.state.log_event(sim.clock.day_index, 0, "missed_work", 2, {
					"person_id": person_id, "household_id": person["household_id"], "lost_cents": person["daily_wage_cents"],
				})
		person["worked_minutes_today"] = 0


static func _is_workday(sim: RefCounted, person: Dictionary, weekday_number: int) -> bool:
	var plan: Dictionary = sim.world["schedules"][person["schedule_id"]]["days"][SimDate.day_kind(weekday_number)]
	return plan.has("away") and plan["away"]["kind"] == "work"


static func _collect_rent(sim: RefCounted) -> void:
	for household_id: String in sim.state.sorted_household_ids():
		var household: Dictionary = sim.state.households[household_id]
		var due: int = household["weekly_rent_cents"] + household["rent_owed_cents"]
		if due <= 0:
			continue
		var paid: int = mini(household["funds_cents"], due)
		household["funds_cents"] -= paid
		household["rent_owed_cents"] = due - paid
		sim.state.log_event(sim.clock.day_index, 0, "rent_paid", 2 if paid < due else 1, {
			"household_id": household_id, "paid_cents": paid, "short_cents": due - paid,
		})
		if paid < due:
			_short(sim, household_id, "rent")


static func _pay_out(sim: RefCounted) -> void:
	for household_id: String in sim.state.sorted_household_ids():
		var household: Dictionary = sim.state.households[household_id]
		var wages: int = household["wages_due_cents"]
		var other: int = household["other_weekly_income_cents"]
		if wages + other <= 0:
			continue
		household["funds_cents"] += wages + other
		household["wages_due_cents"] = 0
		sim.state.log_event(sim.clock.day_index, 0, "payday", 1, {
			"household_id": household_id, "wages_cents": wages, "other_cents": other,
		})


static func _short(sim: RefCounted, household_id: String, reason: String) -> void:
	sim.state.log_event(sim.clock.day_index, sim.clock.minute_of_day, "household_short_of_money", 2, {
		"household_id": household_id, "reason": reason,
	})


# --- Groceries ---------------------------------------------------------------

static func meals_per_day(sim: RefCounted, household: Dictionary) -> int:
	return (household["member_ids"] as Array).size() * int(sim.tuning["meals_per_person_per_day"])


## True when a household should send someone shopping.
static func pantry_is_low(sim: RefCounted, household: Dictionary) -> bool:
	return household["pantry_meals"] < meals_per_day(sim, household) * int(sim.tuning["pantry_low_days"])


## The store this person should go to now for the household's shopping, or
## "" if there is no call to go: the pantry is not low, there is no money for
## even one meal, the store is shut, someone else has already gone, or the
## person is too young.
static func shopping_errand(sim: RefCounted, person: Dictionary) -> String:
	var household: Dictionary = sim.state.households[person["household_id"]]
	if not pantry_is_low(sim, household) or household["funds_cents"] < int(sim.tuning["meal_price_cents"]):
		return ""
	if SimDate.age_on(person["birth_day"], sim.clock.day_index) < int(sim.tuning["shop_min_age"]):
		return ""
	var store: String = sim.area.institution_of_kind("store")
	if store == "" or not sim.area.is_open(store, sim.clock.weekday(), sim.clock.minute_of_day):
		return ""
	for member_id: String in household["member_ids"]:
		var action: Dictionary = sim.state.people[member_id]["action"]
		if member_id != person["id"] and not action.is_empty() and (action["kind"] == "shop" or action.get("resume", {}).get("kind", "") == "shop"):
			return ""
	return store


## A shopping trip is finished: buy what is wanted and can be afforded.
static func finish_shopping(sim: RefCounted, person: Dictionary) -> void:
	var household: Dictionary = sim.state.households[person["household_id"]]
	var price: int = int(sim.tuning["meal_price_cents"])
	var wanted: int = maxi(meals_per_day(sim, household) * int(sim.tuning["pantry_stock_days"]) - household["pantry_meals"], 0)
	@warning_ignore("integer_division")
	var bought: int = mini(wanted, household["funds_cents"] / price)
	household["funds_cents"] -= bought * price
	household["pantry_meals"] += bought
	sim.state.log_event(sim.clock.day_index, sim.clock.minute_of_day, "shopping", 1, {
		"household_id": household["id"], "person_id": person["id"],
		"meals": bought, "cost_cents": bought * price, "wanted_meals": wanted,
	})
	if bought < wanted:
		_short(sim, household["id"], "groceries")


## A meal is finished: it comes out of the pantry. With nothing in the
## pantry the meal is a thin one and does little for hunger.
static func finish_meal(sim: RefCounted, person: Dictionary) -> void:
	var household: Dictionary = sim.state.households[person["household_id"]]
	if household["pantry_meals"] > 0:
		household["pantry_meals"] -= 1
		return
	person["needs"]["hunger"] = mini(person["needs"]["hunger"], int(sim.tuning["hunger_after_thin_meal"]))
	if household["last_empty_pantry_day"] != sim.clock.day_index:
		household["last_empty_pantry_day"] = sim.clock.day_index
		sim.state.log_event(sim.clock.day_index, sim.clock.minute_of_day, "empty_pantry", 2, {
			"household_id": household["id"],
		})


# --- The abstract level ------------------------------------------------------

## One day at the abstract level, when nobody's movements are followed:
## everyone due at work is taken to have worked, and each household spends
## a day's worth of groceries, as far as its money goes.
static func abstract_day(sim: RefCounted) -> void:
	for person_id: String in sim.state.sorted_person_ids():
		var person: Dictionary = sim.state.people[person_id]
		if person["daily_wage_cents"] > 0 and _is_workday(sim, person, sim.clock.weekday()):
			sim.state.households[person["household_id"]]["wages_due_cents"] += person["daily_wage_cents"]
		person["worked_minutes_today"] = 0
	for household_id: String in sim.state.sorted_household_ids():
		var household: Dictionary = sim.state.households[household_id]
		var cost: int = meals_per_day(sim, household) * int(sim.tuning["meal_price_cents"])
		household["funds_cents"] -= mini(household["funds_cents"], cost)
	sim.state.last_abstract_day = sim.clock.day_index
