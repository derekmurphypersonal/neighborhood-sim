extends "res://tests/test_case.gd"
## The world a simulation runs in: scenario plus area (D-020, D-022, D-035).
## The core must work with any area, placeholder or researched.

const Area := preload("res://sim/world/area.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")
const DataFiles := preload("res://sim/io/data_files.gd")

const SCENARIO: String = "fixture_street_spring_1950"


func test_scenario_loads_cleanly() -> void:
	var world: Dictionary = WorldLoader.load_world(SCENARIO)
	check_eq(world["errors"], [], "no loading errors")
	check_eq(world["households"].size(), 5, "households from the scenario")
	check_eq(world["persons"].size(), 17, "residents from the scenario")
	check(world["fingerprints"].size() >= 4, "every data file read is fingerprinted")


func test_player_home_has_a_fictional_interior() -> void:
	var world: Dictionary = WorldLoader.load_world(SCENARIO)
	var area: Area = world["area"]
	var home: String = ""
	for household: Dictionary in world["households"]:
		if household.get("player_controlled", false):
			home = household["home_id"]
	check(area.has_interior(home), "the player's home has an interior")
	check_eq(area.interiors.size(), 1, "and it is the only building with one")
	for kind: String in ["kitchen", "bedroom", "living"]:
		check(area.room_of_kind(home, kind) != "", "it has a %s" % kind)
	check(not area.buildings[home].has("rooms"), "the building record itself holds no interior information")
	var plan_text: String = DataFiles.read_text(DataFiles.data_root().path_join("fiction/interiors/floor_plans.json"))
	check(plan_text.contains("\"status\": \"fictional\""), "floor plans are marked fictional")
	check(plan_text.to_upper().contains("FICTIONAL FLOOR PLANS"), "and the file says so in words")


func test_placeholder_area_is_marked() -> void:
	var area: Area = WorldLoader.load_world(SCENARIO)["area"]
	check(area.placeholder, "the fixture is flagged as a stand-in")
	check(area.notice.to_lower().contains("fictional"), "and carries its notice")


func test_door_and_front_are_derived_from_geometry() -> void:
	var area: Area = WorldLoader.load_world(SCENARIO)["area"]
	# Building 1: footprint x 45..75 ft, y 45..85 ft, north of a 40 ft street on y = 0.
	check_eq(area.front_of("fx_bd_1"), [720, 240], "front is on the street edge, in inches")
	check_eq(area.door_of("fx_bd_1"), [720, 540], "door is on the wall facing the street")
	check_eq(area.front_of("fx_bd_4"), [720, -240], "south-side buildings face north")
	check_eq(area.nearest_exit(area.front_of("fx_bd_1")), "fx_exit_west", "nearest way off the map")


func test_routes() -> void:
	var area: Area = WorldLoader.load_world(SCENARIO)["area"]
	check_eq(area.route("fx_bd_1", "fx_bd_4", []), [[720, 240], [720, -240], [720, -540]], "house to house goes by both fronts")
	check_eq(area.route("", "fx_bd_1", []), [[720, 240], [720, 540]], "arriving from outdoors")
	check_eq(area.route("fx_bd_1", "", [0, 0]), [[720, 240], [0, 0]], "leaving for a point outdoors")


func test_any_area_can_be_supplied() -> void:
	# A different, tiny area built directly: nothing in the core is tied to one place.
	var area: Area = Area.new()
	area.add_record({"id": "s", "type": "street", "name": "Other Road", "centerline": [[0, 0], [0, 200]], "width_ft": 30})
	area.add_record({"id": "b", "type": "building", "footprint": [[40, 90], [70, 90], [70, 120], [40, 120]]})
	area.add_record({"id": "x", "type": "exit", "point": [0, 200]})
	area.finish()
	check_eq(area.front_of("b"), [180, 1260], "a north-south street works as well as an east-west one")
	check_eq(area.door_of("b"), [480, 1260], "the door faces it")
	check(not area.placeholder, "an area is real geography unless its data says otherwise")


func test_core_names_no_particular_place() -> void:
	# The validator is the one file allowed to know real place names (to keep
	# them out of the fixture).
	var offenders: Array[String] = []
	for path: String in DataFiles.list_files(ProjectSettings.globalize_path("res://sim"), "gd"):
		if path.ends_with("data_validator.gd"):
			continue
		var text: String = DataFiles.read_text(path).to_lower()
		for word: String in ["fixture", "linden", "maynard", "malden"]:
			if text.contains(word):
				offenders.append("%s mentions %s" % [path.get_file(), word])
	check_eq(offenders, [] as Array[String], "simulation code is independent of which place it runs")


func test_missing_scenario_is_reported() -> void:
	var world: Dictionary = WorldLoader.load_world("no_such_scenario")
	check(world["errors"].size() > 0, "an unknown scenario produces an error, not a crash")
