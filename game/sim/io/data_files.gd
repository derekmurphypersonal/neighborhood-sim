extends RefCounted
## Reading authored data from the repository's data/ directory (D-020).
##
## data/ sits beside the Godot project, not inside it, so research files can
## be reviewed without the engine. This works when running from the project
## folder; packaging data for an exported build is a later task.


static func repo_root() -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").simplify_path()


static func data_root() -> String:
	return repo_root().path_join("data")


static func read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


## Returns the parsed JSON document, or null if the file is missing or invalid.
static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parser: JSON = JSON.new()
	if parser.parse(read_text(path)) != OK:
		return null
	return parser.data


## All files under a directory with the given extension, sorted, recursive.
static func list_files(dir_path: String, extension: String) -> Array[String]:
	var found: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	for file_name: String in dir.get_files():
		if file_name.get_extension() == extension:
			found.append(dir_path.path_join(file_name))
	for sub_dir: String in dir.get_directories():
		found.append_array(list_files(dir_path.path_join(sub_dir), extension))
	found.sort()
	return found


## SHA-256 of every file under a directory, keyed by path. Used to prove that
## a simulation run leaves authored data untouched (D-023).
static func hash_tree(dir_path: String) -> Dictionary:
	var hashes: Dictionary = {}
	for extension: String in ["json", "md"]:
		for path: String in list_files(dir_path, extension):
			hashes[path] = FileAccess.get_sha256(path)
	return hashes
