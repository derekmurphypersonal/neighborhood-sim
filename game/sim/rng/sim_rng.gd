extends RefCounted
## Seeded randomness for the simulation (D-017, D-025).
##
## One master seed; one independent stream per named system, so adding a
## random roll in one system does not disturb another. Simulation code must
## get all randomness from here and never call global random functions.
##
## Each stream's seed is derived from the master seed and the stream name by
## a fixed function written out below (64-bit FNV-1a), so it does not depend
## on any engine hashing behaviour.

const SEEDING_METHOD: String = "fnv1a64-v1"

const _FNV_OFFSET: int = -3750763034362895579  # 0xCBF29CE484222325 as signed 64-bit
const _FNV_PRIME: int = 1099511628211

var master_seed: int = 0
var _streams: Dictionary = {}


func _init(seed_value: int = 0) -> void:
	master_seed = seed_value


static func derive_seed(seed_value: int, stream_name: String) -> int:
	var value: int = _FNV_OFFSET
	for byte: int in ("%d:%s" % [seed_value, stream_name]).to_utf8_buffer():
		value = (value ^ byte) * _FNV_PRIME  # wraps at 64 bits by design
	return value


## Returns the generator for a named stream, creating it on first use.
func stream(stream_name: String) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		var generator: RandomNumberGenerator = RandomNumberGenerator.new()
		generator.seed = derive_seed(master_seed, stream_name)
		_streams[stream_name] = generator
	return _streams[stream_name]


## Generator state for saves and state hashing. Values are text because
## 64-bit integers do not survive a JSON round trip. Streams that have not
## been used yet are not listed: they are recreated from the master seed on
## first use, exactly as in an uninterrupted run.
func to_save() -> Dictionary:
	var states: Dictionary = {}
	for stream_name: String in _streams:
		var generator: RandomNumberGenerator = _streams[stream_name]
		states[stream_name] = {"seed": str(generator.seed), "state": str(generator.state)}
	return {"master_seed": str(master_seed), "method": SEEDING_METHOD, "streams": states}


func load_save(data: Dictionary) -> void:
	master_seed = str(data["master_seed"]).to_int()
	_streams.clear()
	var states: Dictionary = data["streams"]
	for stream_name: String in states:
		var generator: RandomNumberGenerator = RandomNumberGenerator.new()
		generator.seed = str(states[stream_name]["seed"]).to_int()
		generator.state = str(states[stream_name]["state"]).to_int()
		_streams[stream_name] = generator
