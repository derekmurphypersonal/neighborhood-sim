extends SceneTree
## Validates every file under data/ against the provenance and layer rules,
## and checks that each scenario loads.
##
##   godot --headless --path game --script res://tools/validate_data.gd

const DataValidator := preload("res://sim/io/data_validator.gd")
const DataFiles := preload("res://sim/io/data_files.gd")
const WorldLoader := preload("res://sim/io/world_loader.gd")


func _init() -> void:
	var errors: Array[String] = DataValidator.validate_repository()
	for path: String in DataFiles.list_files(DataFiles.data_root().path_join(WorldLoader.SCENARIO_DIR), "json"):
		for error: String in WorldLoader.load_world(path.get_file().get_basename())["errors"]:
			errors.append("%s: %s" % [path.get_file(), error])
	for error: String in errors:
		print("ERROR  " + error)
	print("Data validation: %d error(s)." % errors.size())
	quit(0 if errors.is_empty() else 1)
