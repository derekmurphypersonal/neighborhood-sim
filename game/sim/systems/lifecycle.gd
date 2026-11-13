extends RefCounted
## Day-level lifecycle: birthdays (D-030). Runs at the start of each day at
## every level of detail.

const SimDate := preload("res://sim/clock/sim_date.gd")


static func on_day_start(sim: RefCounted) -> void:
	var day: int = sim.clock.day_index
	for person_id: String in sim.state.sorted_person_ids():
		var person: Dictionary = sim.state.people[person_id]
		if SimDate.is_birthday(person["birth_day"], day):
			sim.state.log_event(day, 0, "birthday", 1, {
				"person_id": person_id, "age": SimDate.age_on(person["birth_day"], day),
			})
