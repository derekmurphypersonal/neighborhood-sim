extends "res://tests/test_case.gd"
## Provenance and layer rules (D-019, D-020, D-022, D-035).

const DataValidator := preload("res://sim/io/data_validator.gd")

const REGISTER: Dictionary = {
	"all": {"S-PRIMARY": true, "S-WIKI": true},
	"tertiary": {"S-WIKI": true},
}


func _historical(provenance: Variant) -> Array[String]:
	var record: Dictionary = {"id": "bd_test"}
	if provenance != null:
		record["provenance"] = provenance
	return DataValidator.validate_document(
		{"layer": "historical", "records": [record]}, "historical", "test", REGISTER
	)


func test_repository_data_is_valid() -> void:
	var errors: Array[String] = DataValidator.validate_repository()
	check_eq(errors, [] as Array[String], "all files under data/ pass validation")


func test_source_register_is_readable() -> void:
	var text: String = "## Primary sources\n| S-ONE | x |\n## Tertiary sources (leads only)\n| S-TWO | y |\n"
	var register: Dictionary = DataValidator.read_source_register(text)
	check(register["all"].has("S-ONE") and register["all"].has("S-TWO"), "both IDs read")
	check(register["tertiary"].has("S-TWO") and not register["tertiary"].has("S-ONE"), "tertiary section recognized")


func test_valid_historical_record_passes() -> void:
	var errors: Array[String] = _historical({"status": "verified", "sources": [{"source_id": "S-PRIMARY"}]})
	check_eq(errors.size(), 0, "a sourced, verified record is accepted")


func test_historical_record_needs_provenance() -> void:
	check(_historical(null).size() > 0, "no provenance is rejected")
	check(_historical({"status": "verified", "sources": []}).size() > 0, "no sources is rejected")


func test_historical_record_rejects_unregistered_source() -> void:
	check(_historical({"status": "verified", "sources": [{"source_id": "S-MADE-UP"}]}).size() > 0, "unknown source is rejected")


func test_historical_record_rejects_tertiary_only() -> void:
	check(_historical({"status": "probable", "sources": [{"source_id": "S-WIKI"}]}).size() > 0, "tertiary-only is rejected")
	var both: Array = [{"source_id": "S-WIKI"}, {"source_id": "S-PRIMARY"}]
	check_eq(_historical({"status": "probable", "sources": both}).size(), 0, "tertiary plus primary is accepted")


func test_hypothesis_needs_reasoning() -> void:
	var sources: Array = [{"source_id": "S-PRIMARY"}]
	check(_historical({"status": "hypothesis", "sources": sources}).size() > 0, "hypothesis without reasoning is rejected")
	check_eq(_historical({"status": "hypothesis", "sources": sources, "reasoning": "on both maps"}).size(), 0, "with reasoning is accepted")


func test_fictional_and_placeholder_cannot_be_historical() -> void:
	var sources: Array = [{"source_id": "S-PRIMARY"}]
	check(_historical({"status": "fictional", "sources": sources}).size() > 0, "fictional status rejected in historical")
	check(_historical({"status": "placeholder", "sources": sources}).size() > 0, "placeholder status rejected in historical")


func test_fixture_must_be_marked_fictional() -> void:
	var record: Dictionary = {"id": "fx_1", "name": "Fixture Street", "provenance": {"status": "placeholder"}}
	var good: Dictionary = {"layer": "dev_fixture", "fictional": true, "notice": "Fictional.", "records": [record]}
	check_eq(DataValidator.validate_document(good, "dev_fixture", "test", REGISTER).size(), 0, "a marked fixture is accepted")
	var unmarked: Dictionary = {"layer": "dev_fixture", "records": [record]}
	check(DataValidator.validate_document(unmarked, "dev_fixture", "test", REGISTER).size() > 0, "an unmarked fixture is rejected")


func test_fixture_must_not_use_real_place_names() -> void:
	var record: Dictionary = {"id": "fx_1", "name": "Linden Street", "provenance": {"status": "placeholder"}}
	var doc: Dictionary = {"layer": "dev_fixture", "fictional": true, "notice": "Fictional.", "records": [record]}
	check(DataValidator.validate_document(doc, "dev_fixture", "test", REGISTER).size() > 0, "a real place name in the fixture is rejected")


func test_tuning_values_must_be_labeled() -> void:
	var unlabeled: Dictionary = {"layer": "tuning", "records": [{"id": "x", "value": 1}]}
	check(DataValidator.validate_document(unlabeled, "tuning", "test", REGISTER).size() > 0, "an unlabeled value is rejected")
	var tuned: Dictionary = {"layer": "tuning", "records": [{"id": "x", "value": 1, "label": "gameplay_tuned"}]}
	check_eq(DataValidator.validate_document(tuned, "tuning", "test", REGISTER).size(), 0, "a labeled value is accepted")
	var unsourced: Dictionary = {"layer": "tuning", "records": [{"id": "x", "value": 1, "label": "sourced"}]}
	check(DataValidator.validate_document(unsourced, "tuning", "test", REGISTER).size() > 0, "sourced without a source is rejected")
