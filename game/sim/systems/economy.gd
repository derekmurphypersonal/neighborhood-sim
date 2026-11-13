extends RefCounted
## Day-level household money. For now a simple weekly budget settled on
## Fridays; wages tied to days worked and individual purchases come later.

const PAYDAY_WEEKDAY: int = 5  # Friday


static func on_day_start(sim: RefCounted) -> void:
	if sim.clock.weekday() != PAYDAY_WEEKDAY:
		return
	var generator: RandomNumberGenerator = sim.rng.stream("economy")
	var variation: int = int(sim.tuning.get("weekly_expense_variation_cents", 0))
	for household_id: String in sim.state.sorted_household_ids():
		var household: Dictionary = sim.state.households[household_id]
		var was_short: bool = household["funds_cents"] < 0
		var expenses: int = household["weekly_expense_cents"] + generator.randi_range(-variation, variation)
		household["funds_cents"] += household["weekly_income_cents"] - expenses
		if household["funds_cents"] < 0 and not was_short:
			sim.state.log_event(sim.clock.day_index, 0, "household_short_of_money", 2, {
				"household_id": household_id,
			})
