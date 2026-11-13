extends "res://tests/test_case.gd"
## Seeded randomness (D-017, D-025).

const SimRng := preload("res://sim/rng/sim_rng.gd")


func _draw(rng: SimRng, stream_name: String, count: int) -> Array[int]:
	var values: Array[int] = []
	for i: int in count:
		values.append(rng.stream(stream_name).randi())
	return values


func test_same_seed_same_sequence() -> void:
	check_eq(_draw(SimRng.new(42), "economy", 20), _draw(SimRng.new(42), "economy", 20), "same seed repeats")


func test_different_seed_different_sequence() -> void:
	check(_draw(SimRng.new(42), "economy", 20) != _draw(SimRng.new(43), "economy", 20), "different seed differs")


func test_streams_are_independent() -> void:
	var alone: SimRng = SimRng.new(7)
	var expected: Array[int] = _draw(alone, "economy", 10)
	var mixed: SimRng = SimRng.new(7)
	_draw(mixed, "lifecycle", 50)
	check_eq(_draw(mixed, "economy", 10), expected, "drawing from one stream does not disturb another")
	check(_draw(SimRng.new(7), "lifecycle", 10) != expected, "streams differ from each other")
