extends "res://tests/test_case.gd"
## The building information view (M1-B step 9) keeps documented exterior
## facts apart from fictional interiors and scenario content.

const Simulation := preload("res://sim/simulation.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")
const BuildingInfo := preload("res://sim/reports/building_info.gd")
const Describe := preload("res://view/describe.gd")
const Area := preload("res://sim/world/area.gd")

const SCENARIO: String = "fixture_street_spring_1950"


func _simulation() -> Simulation:
	return Simulation.new_game(WorldLoader.load_world(SCENARIO), 1)


func test_a_placeholder_building_documents_nothing() -> void:
	var simulation: Simulation = _simulation()
	var info: Dictionary = BuildingInfo.describe(simulation, "fx_bd_1")
	check(info["area_placeholder"], "the fixture area is a placeholder")
	check_eq(info["exterior"]["status"], "placeholder", "the building record is a placeholder")
	check(not info["exterior"]["documented"], "a placeholder is not a documented fact")
	check_eq(info["exterior"]["sources"], [], "and cites nothing")
	check_eq(info["households"].size(), 1, "one household lives there in the scenario")
	check_eq(info["households"][0]["household_id"], "fx_hh_1", "the player's")
	check(info["households"][0]["fictional"], "marked fictional")
	check_eq(info["interior"]["module_id"], "fp_small_house_30x40", "its assigned floor plan")
	check(info["interior"]["fictional"], "marked fictional")
	check_eq(info["institution"], {}, "a house is not an institution")


func test_a_building_without_an_interior_says_so() -> void:
	var info: Dictionary = BuildingInfo.describe(_simulation(), "fx_bd_2")
	check_eq(info["interior"], {}, "no interior has been assigned")


func test_the_store_is_reported_with_its_own_status() -> void:
	var info: Dictionary = BuildingInfo.describe(_simulation(), "fx_bd_6")
	check_eq(info["institution"]["kind"], "store", "the store")
	check_eq(info["institution"]["status"], "placeholder", "is a placeholder institution")
	check(not info["institution"]["documented"], "not a documented business")
	check_eq(info["households"], [], "nobody lives there")


## A stand-in for a researched record, added in this test only. The IDs name
## no real source or finding.
func test_a_sourced_building_keeps_its_provenance() -> void:
	var simulation: Simulation = _simulation()
	var area: Area = simulation.area
	area.add_record({
		"id": "test_bd_sourced", "type": "building", "lot_id": "", "label": "Test building", "building_type": "two-family",
		"stories": 2, "footprint": [[0, 200], [30, 200], [30, 240], [0, 240]],
		"provenance": {"status": "probable", "sources": [{"source_id": "S-TEST", "locator": "test sheet", "finding_id": "F-TEST"}]},
	})
	area.set_interior("test_bd_sourced", {"id": "fp_test", "name": "Test plan", "rooms": [
		{"id": "kitchen", "name": "Kitchen", "kind": "kitchen", "rect_ft": [0, 0, 30, 40]},
	]})
	var info: Dictionary = BuildingInfo.describe(simulation, "test_bd_sourced")
	check(info["exterior"]["documented"], "a probable record is documented research")
	check_eq(info["exterior"]["status"], "probable", "and keeps its status: probable is not verified")
	check_eq(info["exterior"]["sources"], [{"source_id": "S-TEST", "locator": "test sheet", "finding_id": "F-TEST"}], "with its sources")
	check(info["interior"]["fictional"], "its interior is fictional all the same")
	check(not info["exterior"]["facts"].is_empty(), "exterior facts are listed")
	for fact: Dictionary in info["exterior"]["facts"]:
		check(not ["rooms", "module_id", "households"].has(fact["field"]), "nothing about the inside is among the exterior facts")
	var text: String = Describe.building_info(simulation, info)
	check(text.find("probable") >= 0 and text.find("S-TEST") >= 0 and text.find("F-TEST") >= 0, "the text shows status, source and finding")
	check(text.find("Interior (fictional)") >= 0, "and labels the interior as fictional")
	check(text.find("Interior (fictional)") > text.find("S-TEST"), "after, not among, the documented facts")


func test_the_text_for_a_placeholder_claims_nothing() -> void:
	var simulation: Simulation = _simulation()
	var text: String = Describe.building_info(simulation, BuildingInfo.describe(simulation, "fx_bd_1"))
	check(text.find("Nothing is documented") >= 0, "it says nothing is documented")
	check(text.find("FICTIONAL") >= 0, "and that the building is fictional")
	check(text.find("verified") < 0 and text.find("probable") < 0, "and uses no research status")


func test_looking_changes_nothing() -> void:
	var simulation: Simulation = _simulation()
	var before: String = simulation.state_hash()
	for building_id: String in simulation.area.sorted_building_ids():
		Describe.building_info(simulation, BuildingInfo.describe(simulation, building_id))
	check_eq(simulation.state_hash(), before, "the state is untouched")
