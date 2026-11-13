extends RefCounted
## Calendar arithmetic for the game's continuous calendar (D-013).
##
## A date is a "day index": whole days since 1950-01-01, which is day 0 and a
## Sunday. Dates before 1950 (for example dates of birth) are negative.
## Pure functions only: no engine time, no rendering (D-029).

const START_YEAR: int = 1950
const END_YEAR: int = 1959
## Day index of 1959-12-31, the last day of the game.
const LAST_DAY: int = 3651
## Number of days in the game, 1950-01-01 through 1959-12-31.
const TOTAL_DAYS: int = 3652
const MINUTES_PER_DAY: int = 1440

const WEEKDAY_NAMES: Array[String] = [
	"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
]

# Days from 1970-01-01 to 1950-01-01 in the proleptic Gregorian calendar.
const _EPOCH_OFFSET: int = -7305


static func is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or year % 400 == 0


static func days_in_month(year: int, month: int) -> int:
	if month == 2:
		return 29 if is_leap_year(year) else 28
	if month in [4, 6, 9, 11]:
		return 30
	return 31


static func is_valid_date(year: int, month: int, day: int) -> bool:
	return month >= 1 and month <= 12 and day >= 1 and day <= days_in_month(year, month)


## Day index for a calendar date. Standard days-from-civil algorithm.
@warning_ignore("integer_division")
static func to_day_index(year: int, month: int, day: int) -> int:
	var y: int = year - (1 if month <= 2 else 0)
	var era: int = (y if y >= 0 else y - 399) / 400
	var yoe: int = y - era * 400
	var mp: int = (month + 9) % 12
	var doy: int = (153 * mp + 2) / 5 + day - 1
	var doe: int = yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468 - _EPOCH_OFFSET


## Calendar date for a day index, as {"year", "month", "day"}.
@warning_ignore("integer_division")
static func from_day_index(day_index: int) -> Dictionary:
	var z: int = day_index + _EPOCH_OFFSET + 719468
	var era: int = (z if z >= 0 else z - 146096) / 146097
	var doe: int = z - era * 146097
	var yoe: int = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	var doy: int = doe - (365 * yoe + yoe / 4 - yoe / 100)
	var mp: int = (5 * doy + 2) / 153
	var day: int = doy - (153 * mp + 2) / 5 + 1
	var month: int = mp + 3 if mp < 10 else mp - 9
	var year: int = yoe + era * 400 + (1 if month <= 2 else 0)
	return {"year": year, "month": month, "day": day}


## 0 = Sunday ... 6 = Saturday.
static func weekday(day_index: int) -> int:
	return ((day_index % 7) + 7) % 7


static func weekday_name(day_index: int) -> String:
	return WEEKDAY_NAMES[weekday(day_index)]


## Parses "YYYY-MM-DD". Returns null if the text is not a valid date.
static func parse_iso(text: String) -> Variant:
	var parts: PackedStringArray = text.split("-")
	if parts.size() != 3:
		return null
	for part: String in parts:
		if not part.is_valid_int():
			return null
	var year: int = parts[0].to_int()
	var month: int = parts[1].to_int()
	var day: int = parts[2].to_int()
	if not is_valid_date(year, month, day):
		return null
	return to_day_index(year, month, day)


static func to_iso(day_index: int) -> String:
	var date: Dictionary = from_day_index(day_index)
	return "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]


## Month and day on which a birthday is observed in a given year.
## Game convention: a 29 February birthday is observed on 1 March in
## non-leap years.
static func observed_birthday(birth_month: int, birth_day: int, year: int) -> Dictionary:
	if birth_month == 2 and birth_day == 29 and not is_leap_year(year):
		return {"month": 3, "day": 1}
	return {"month": birth_month, "day": birth_day}


## Age in whole years on a given day. Age is never stored, only computed.
static func age_on(birth_day_index: int, current_day_index: int) -> int:
	var birth: Dictionary = from_day_index(birth_day_index)
	var now: Dictionary = from_day_index(current_day_index)
	var observed: Dictionary = observed_birthday(birth["month"], birth["day"], now["year"])
	var age: int = now["year"] - birth["year"]
	var before_birthday: bool = (
		now["month"] < observed["month"]
		or (now["month"] == observed["month"] and now["day"] < observed["day"])
	)
	if before_birthday:
		age -= 1
	return age


## True if the given day is this person's (observed) birthday, excluding the
## day of birth itself.
static func is_birthday(birth_day_index: int, current_day_index: int) -> bool:
	if current_day_index <= birth_day_index:
		return false
	var birth: Dictionary = from_day_index(birth_day_index)
	var now: Dictionary = from_day_index(current_day_index)
	var observed: Dictionary = observed_birthday(birth["month"], birth["day"], now["year"])
	return now["month"] == observed["month"] and now["day"] == observed["day"]
