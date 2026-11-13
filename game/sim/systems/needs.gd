extends RefCounted
## Needs: hunger, rest and company rise and fall each minute according to
## what a person is doing. Higher is better; 0 is desperate.

const Records := preload("res://sim/state/records.gd")


static func step(sim: RefCounted, person: Dictionary) -> void:
	var needs: Dictionary = person["needs"]
	var action: Dictionary = person["action"]
	var doing: String = action["kind"] if not action.is_empty() and action["started"] else ""
	var tuning: Dictionary = sim.tuning

	if doing == "sleep":
		needs["rest"] += int(tuning["rest_gain_asleep"])
		needs["hunger"] -= int(tuning["hunger_loss_asleep"])
	else:
		needs["rest"] -= int(tuning["rest_loss_awake"])
		if doing == "eat":
			needs["hunger"] += int(tuning["hunger_gain_eating"])
		else:
			needs["hunger"] -= int(tuning["hunger_loss_awake"])
		if doing == "talk":
			needs["company"] += int(tuning["company_gain_talking"])
		elif person["at"] == Records.AT_OFFMAP:
			needs["company"] += int(tuning["company_gain_away"])
		elif not sim.world["schedules"][person["schedule_id"]].get("housebound", false):
			# The very young are cared for at home and do not go looking for company.
			needs["company"] -= int(tuning["company_loss_alone"])

	# People who are away at work or school get a midday meal there.
	if person["at"] == Records.AT_OFFMAP:
		needs["hunger"] = maxi(needs["hunger"], int(tuning["hunger_floor_away"]))

	for need_name: String in Records.NEED_NAMES:
		needs[need_name] = clampi(needs[need_name], 0, Records.NEED_MAX)
