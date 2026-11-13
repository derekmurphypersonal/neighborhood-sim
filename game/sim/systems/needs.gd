extends RefCounted
## Needs: hunger, rest, company and fun rise and fall each minute according
## to what a person is doing and where. Higher is better; 0 is desperate.
##
## Each need is met by particular actions in particular places:
##   hunger   eating, at home (in the kitchen where the home has rooms)
##   rest     sleeping, at home (in the bedroom)
##   company  talking with someone from another household, wherever they meet
##   fun      a pastime at home (in the living room); playing outdoors, for
##            children; looking around an institution; a little from talking

const Records := preload("res://sim/state/records.gd")

## What each action restores per minute: [need, tuning value] pairs.
const RESTORES: Dictionary = {
	"sleep": [["rest", "rest_gain_asleep"]],
	"eat": [["hunger", "hunger_gain_eating"]],
	"talk": [["company", "company_gain_talking"], ["fun", "fun_gain_talking"]],
	"pastime": [["fun", "fun_gain_pastime"]],
	"play": [["fun", "fun_gain_play"]],
	"be_inside": [["fun", "fun_gain_browsing"]],
}


static func step(sim: RefCounted, person: Dictionary) -> void:
	var needs: Dictionary = person["needs"]
	var action: Dictionary = person["action"]
	var doing: String = action["kind"] if not action.is_empty() and action["started"] else ""
	var tuning: Dictionary = sim.tuning
	var housebound: bool = sim.world["schedules"][person["schedule_id"]].get("housebound", false)
	var asleep: bool = doing == "sleep"

	# What falls with time.
	needs["hunger"] -= int(tuning["hunger_loss_asleep"]) if asleep else int(tuning["hunger_loss_awake"])
	if not asleep:
		needs["rest"] -= int(tuning["rest_loss_awake"])
		# The very young are cared for at home and do not go looking for
		# company or amusement.
		if not housebound:
			needs["company"] -= int(tuning["company_loss_alone"])
			# Work and school are neither fun nor a drain on it.
			if doing != "work" and doing != "school":
				needs["fun"] -= int(tuning["fun_loss_awake"])

	# What the current action gives back.
	for restore: Array in RESTORES.get(doing, []):
		needs[restore[0]] += int(tuning[restore[1]])
	if person["at"] == Records.AT_OFFMAP:
		needs["company"] += int(tuning["company_gain_away"])

	# People at work or school get a midday meal there, on the street or off it.
	if doing == "work" or doing == "school":
		needs["hunger"] = maxi(needs["hunger"], int(tuning["hunger_floor_away"]))

	for need_name: String in Records.NEED_NAMES:
		needs[need_name] = clampi(needs[need_name], 0, Records.NEED_MAX)
