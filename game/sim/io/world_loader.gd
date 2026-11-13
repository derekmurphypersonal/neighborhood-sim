extends RefCounted
## Builds everything a simulation needs from a scenario (D-020, D-034).
##
## A scenario is fictional data saying where and when a game starts and who
## lives there. It names an area (streets and buildings), which may be a
## placeholder or a researched one; this loader treats both alike.
##
## Returns a "world" dictionary:
##   scenario      the scenario's header record
##   area          Area (static)
##   schedules     {id: schedule record}
##   tuning        {id: value}
##   households    starting household records from the scenario
##   persons       starting person records from the scenario
##   fingerprints  {path: sha256} of every data file read
##   errors        problems found; the world is unusable if not empty

const DataFiles := preload("res://sim/io/data_files.gd")
const Area := preload("res://sim/world/area.gd")
const SaveGame := preload("res://sim/io/save_game.gd")

const SCENARIO_DIR: String = "fiction/scenarios"
const SCHEDULES_PATH: String = "fiction/schedules.json"
const INTERIORS_DIR: String = "fiction/interiors"
const TUNING_DIR: String = "tuning"


static func load_world(scenario_id: String) -> Dictionary:
	var world: Dictionary = {
		"scenario": {}, "area": null, "schedules": {}, "tuning": {},
		"households": [], "persons": [], "fingerprints": {}, "errors": [],
	}
	var root: String = DataFiles.data_root()

	var scenario_doc: Variant = _read(root, SCENARIO_DIR.path_join(scenario_id + ".json"), world)
	if scenario_doc == null:
		return world
	for record: Dictionary in scenario_doc["records"]:
		match record.get("type", ""):
			"scenario":
				world["scenario"] = record
			"household":
				world["households"].append(record)
			"person":
				world["persons"].append(record)
	if world["scenario"].is_empty():
		world["errors"].append("Scenario %s has no scenario record." % scenario_id)
		return world

	var area_path: String = world["scenario"]["area"]
	var area: Area = Area.new()
	area.id = area_path
	var area_files: Array[String] = DataFiles.list_files(root.path_join(area_path), "json")
	if area_files.is_empty():
		world["errors"].append("Area %s has no data files." % area_path)
	for path: String in area_files:
		var doc: Variant = _read(root, path.trim_prefix(root + "/"), world)
		if doc == null:
			continue
		# An area file that declares itself fictional is a stand-in, not real geography.
		if doc.get("fictional", false) == true:
			area.placeholder = true
		if doc.has("notice"):
			area.notice = doc["notice"]
		if doc.has("area_name"):
			area.display_name = doc["area_name"]
		for record: Dictionary in doc["records"]:
			area.add_record(record)
	area.finish()
	world["area"] = area

	_assign_interiors(root, scenario_doc, area, world)

	var schedule_doc: Variant = _read(root, SCHEDULES_PATH, world)
	if schedule_doc != null:
		for record: Dictionary in schedule_doc["records"]:
			world["schedules"][record["id"]] = record
	for path: String in DataFiles.list_files(root.path_join(TUNING_DIR), "json"):
		var doc: Variant = _read(root, path.trim_prefix(root + "/"), world)
		if doc != null:
			for record: Dictionary in doc["records"]:
				world["tuning"][record["id"]] = record["value"]

	_check_references(world)
	return world


## Gives buildings the fictional interiors the scenario assigns them.
static func _assign_interiors(root: String, scenario_doc: Dictionary, area: Area, world: Dictionary) -> void:
	var plans: Dictionary = {}
	for path: String in DataFiles.list_files(root.path_join(INTERIORS_DIR), "json"):
		var doc: Variant = _read(root, path.trim_prefix(root + "/"), world)
		if doc != null:
			for record: Dictionary in doc["records"]:
				if record.get("type", "") == "floor_plan":
					plans[record["id"]] = record
	for record: Dictionary in scenario_doc["records"]:
		if record.get("type", "") != "interior_assignment":
			continue
		var building_id: String = record["building_id"]
		var plan_id: String = record["floor_plan_id"]
		if not area.buildings.has(building_id):
			world["errors"].append("An interior is assigned to unknown building %s." % building_id)
		elif not plans.has(plan_id):
			world["errors"].append("Building %s is assigned unknown floor plan %s." % [building_id, plan_id])
		elif not (plans[plan_id]["for_building_types"] as Array).has(area.buildings[building_id]["building_type"]):
			world["errors"].append("Floor plan %s is not made for a %s building (%s)." % [plan_id, area.buildings[building_id]["building_type"], building_id])
		else:
			area.set_interior(building_id, plans[plan_id])


static func _read(root: String, relative_path: String, world: Dictionary) -> Variant:
	var full_path: String = root.path_join(relative_path)
	var doc: Variant = DataFiles.read_json(full_path)
	if typeof(doc) != TYPE_DICTIONARY or typeof(doc.get("records")) != TYPE_ARRAY:
		world["errors"].append("Could not read data file %s." % relative_path)
		return null
	world["fingerprints"][relative_path] = FileAccess.get_sha256(full_path)
	# Everything except area geometry (authored in feet, possibly fractional)
	# is whole numbers; a JSON reader returns them as decimals.
	if not doc.has("area_name"):
		doc = SaveGame.whole_numbers(doc)
	return doc


static func _check_references(world: Dictionary) -> void:
	var area: Area = world["area"]
	var household_ids: Dictionary = {}
	var players: int = 0
	for household: Dictionary in world["households"]:
		household_ids[household["id"]] = true
		if not area.buildings.has(household["home_id"]):
			world["errors"].append("Household %s lives in unknown building %s." % [household["id"], household["home_id"]])
		if household.get("player_controlled", false):
			players += 1
	if players != 1:
		world["errors"].append("A scenario needs exactly one player household; found %d." % players)
	for person: Dictionary in world["persons"]:
		if not household_ids.has(person["household_id"]):
			world["errors"].append("Person %s belongs to unknown household %s." % [person["id"], person["household_id"]])
		if not world["schedules"].has(person["schedule_id"]):
			world["errors"].append("Person %s has unknown schedule %s." % [person["id"], person["schedule_id"]])
	if area.streets.is_empty():
		world["errors"].append("The area has no street.")
	if area.exits.is_empty():
		world["errors"].append("The area has no exit.")
