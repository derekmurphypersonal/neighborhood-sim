extends RefCounted
## The single persistent clock of the simulation (D-013, D-029).
##
## Owned by the simulation core. It only moves forward and does not depend on
## rendering, frame rate or wall-clock time.

const SimDate := preload("res://sim/clock/sim_date.gd")

var day_index: int = 0
var minute_of_day: int = 0


func _init(start_day_index: int = 0, start_minute: int = 0) -> void:
	day_index = start_day_index
	minute_of_day = start_minute


## True once the clock has passed 1959-12-31.
func is_finished() -> bool:
	return day_index > SimDate.LAST_DAY


## Minutes since 00:00 on 1950-01-01. The one timestamp used inside the sim.
func abs_minute() -> int:
	return day_index * SimDate.MINUTES_PER_DAY + minute_of_day


## Advances by a non-negative number of minutes. Returns the number of
## midnights crossed.
@warning_ignore("integer_division")
func advance_minutes(minutes: int) -> int:
	assert(minutes >= 0, "The clock never runs backwards.")
	var total: int = minute_of_day + minutes
	var days_crossed: int = total / SimDate.MINUTES_PER_DAY
	day_index += days_crossed
	minute_of_day = total % SimDate.MINUTES_PER_DAY
	return days_crossed


## Moves to midnight at the start of the next day.
func advance_to_next_day() -> void:
	day_index += 1
	minute_of_day = 0


func weekday() -> int:
	return SimDate.weekday(day_index)


func describe() -> String:
	@warning_ignore("integer_division")
	var hour: int = minute_of_day / 60
	return "%s %s %02d:%02d" % [
		SimDate.weekday_name(day_index), SimDate.to_iso(day_index), hour, minute_of_day % 60,
	]


func to_save() -> Dictionary:
	return {"day_index": day_index, "minute_of_day": minute_of_day}


func load_save(data: Dictionary) -> void:
	day_index = int(data["day_index"])
	minute_of_day = int(data["minute_of_day"])
