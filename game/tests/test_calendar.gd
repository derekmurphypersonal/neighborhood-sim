extends "res://tests/test_case.gd"
## The continuous calendar, 1950-01-01 to 1959-12-31 (D-013, D-029).

const SimDate := preload("res://sim/clock/sim_date.gd")
const SimClock := preload("res://sim/clock/sim_clock.gd")


func test_first_and_last_day() -> void:
	check_eq(SimDate.to_day_index(1950, 1, 1), 0, "1950-01-01 is day 0")
	check_eq(SimDate.to_day_index(1959, 12, 31), SimDate.LAST_DAY, "1959-12-31 is the last day")
	check_eq(SimDate.to_day_index(1960, 1, 1), SimDate.TOTAL_DAYS, "the decade has 3,652 days")
	check_eq(SimDate.weekday_name(0), "Sunday", "1950-01-01 was a Sunday")
	check_eq(SimDate.weekday_name(SimDate.LAST_DAY), "Thursday", "1959-12-31 was a Thursday")


func test_known_weekdays() -> void:
	# Checked against Python's datetime module.
	check_eq(SimDate.weekday_name(SimDate.to_day_index(1952, 2, 29)), "Friday", "1952-02-29")
	check_eq(SimDate.weekday_name(SimDate.to_day_index(1955, 7, 4)), "Monday", "1955-07-04")
	check_eq(SimDate.weekday_name(SimDate.to_day_index(1958, 5, 16)), "Friday", "1958-05-16")
	check_eq(SimDate.weekday_name(SimDate.to_day_index(1941, 12, 7)), "Sunday", "1941-12-07 (before 1950)")


func test_leap_years() -> void:
	check(SimDate.is_leap_year(1952), "1952 is a leap year")
	check(SimDate.is_leap_year(1956), "1956 is a leap year")
	check(not SimDate.is_leap_year(1950), "1950 is not a leap year")
	check(not SimDate.is_leap_year(1900), "1900 is not a leap year")
	check_eq(SimDate.days_in_month(1952, 2), 29, "February 1952")
	check_eq(SimDate.days_in_month(1953, 2), 28, "February 1953")


func test_every_day_round_trips() -> void:
	# From 1880 to 1960, covering every possible date of birth and game day.
	var first: int = SimDate.to_day_index(1880, 1, 1)
	var mismatches: int = 0
	var previous: Dictionary = {}
	for day_index: int in range(first, SimDate.TOTAL_DAYS):
		var date: Dictionary = SimDate.from_day_index(day_index)
		if SimDate.to_day_index(date["year"], date["month"], date["day"]) != day_index:
			mismatches += 1
		if not SimDate.is_valid_date(date["year"], date["month"], date["day"]):
			mismatches += 1
		if not previous.is_empty() and date == previous:
			mismatches += 1
		previous = date
	check_eq(mismatches, 0, "every day index maps to one valid date and back")


func test_iso_text() -> void:
	check_eq(SimDate.to_iso(0), "1950-01-01", "day 0 as text")
	check_eq(SimDate.parse_iso("1959-12-31"), SimDate.LAST_DAY, "parse the last day")
	check_eq(SimDate.parse_iso("1953-02-29"), null, "29 February 1953 does not exist")
	check_eq(SimDate.parse_iso("not a date"), null, "nonsense is rejected")


func test_clock_advances_without_presentation() -> void:
	# This test runs with no scene loaded and no frames drawn.
	var clock: SimClock = SimClock.new()
	check_eq(clock.advance_minutes(90), 0, "90 minutes stays within the day")
	check_eq(clock.minute_of_day, 90, "01:30")
	check_eq(clock.advance_minutes(SimDate.MINUTES_PER_DAY * 3), 3, "three midnights crossed")
	check_eq(clock.day_index, 3, "now on day 3")
	check_eq(clock.minute_of_day, 90, "time of day preserved")
	check_eq(clock.describe(), "Wednesday 1950-01-04 01:30", "readable clock")
	check(not clock.is_finished(), "not finished in 1950")
	clock.advance_minutes(SimDate.MINUTES_PER_DAY * SimDate.TOTAL_DAYS)
	check(clock.is_finished(), "finished after 1959")
