extends "res://tests/test_case.gd"
## Age from date of birth (D-030). Age is never stored.

const SimDate := preload("res://sim/clock/sim_date.gd")


func _day(text: String) -> int:
	return SimDate.parse_iso(text)


func test_age_changes_on_the_birthday() -> void:
	var born: int = _day("1941-06-21")
	check_eq(SimDate.age_on(born, _day("1950-01-01")), 8, "age at game start")
	check_eq(SimDate.age_on(born, _day("1950-06-20")), 8, "day before birthday")
	check_eq(SimDate.age_on(born, _day("1950-06-21")), 9, "on the birthday")
	check_eq(SimDate.age_on(born, _day("1959-12-31")), 18, "age at game end")


func test_people_do_not_all_age_on_the_same_day() -> void:
	var early: int = _day("1940-01-02")
	var late: int = _day("1940-12-30")
	check_eq(SimDate.age_on(early, _day("1950-06-01")), 10, "January birthday already passed")
	check_eq(SimDate.age_on(late, _day("1950-06-01")), 9, "December birthday still to come")


func test_leap_day_birthday() -> void:
	var born: int = _day("1944-02-29")
	check(SimDate.is_birthday(born, _day("1952-02-29")), "leap year: observed on 29 February")
	check(not SimDate.is_birthday(born, _day("1952-03-01")), "leap year: not on 1 March")
	check(SimDate.is_birthday(born, _day("1953-03-01")), "other years: observed on 1 March")
	check(not SimDate.is_birthday(born, _day("1953-02-28")), "other years: not on 28 February")
	check_eq(SimDate.age_on(born, _day("1953-02-28")), 8, "still 8 on 28 February 1953")
	check_eq(SimDate.age_on(born, _day("1953-03-01")), 9, "9 on 1 March 1953")


func test_born_during_the_game() -> void:
	var born: int = _day("1953-04-10")
	check(not SimDate.is_birthday(born, born), "the day of birth is not a birthday")
	check_eq(SimDate.age_on(born, born), 0, "age 0 at birth")
	check_eq(SimDate.age_on(born, _day("1959-12-31")), 6, "age 6 at game end")
