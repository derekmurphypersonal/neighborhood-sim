extends RefCounted
## Saving and loading a simulation exactly (D-040).
##
## A save is JSON text: a header, then the complete simulation state taken
## between two ticks. Loading and continuing must give the same result as
## never having stopped. That holds because simulation state contains only
## whole numbers, text, lists and dictionaries (records.gd, D-042), and every
## number read back is converted to a whole number.
##
## THE CONTRACT
##   to_text(simulation)   -> the whole save document as text.
##   restore(text, world)  -> {"ok", "error", "simulation", "changed_data"}.
##                            The one call for turning save text back into a
##                            running simulation. Never crashes on bad input:
##                            "ok" is false, "simulation" is null and "error"
##                            says why.
##   parse(text)           -> {"ok", "error", "document"}. Reads and checks
##                            the document without building a simulation.
##                            "document" is {} when "ok" is false.
##   Simulation.from_save(world, saved) is the low-level step restore() uses.
##   It takes only the document's "simulation" part, already checked by
##   parse(); call restore() instead.
##   write_file(path, text) -> "" on success, or the reason it failed.
##   read_file(path)        -> {"ok", "error", "text"}.
##
## Where saves are kept is the caller's choice; nothing here assumes a folder.

const Simulation := preload("res://sim/simulation.gd")

const FORMAT_VERSION: int = 1
## Parts every save must have: the document, then its "simulation" part.
const DOCUMENT_PARTS: Array[String] = ["format_version", "scenario_id", "fingerprints", "simulation"]
const SIMULATION_PARTS: Dictionary = {
	"clock": ["day_index", "minute_of_day"],
	"rng": ["master_seed", "streams"],
	"state": ["people", "households", "relationships", "event_log", "next_event_id", "last_abstract_day"],
}


static func to_text(simulation: RefCounted) -> String:
	var document: Dictionary = {
		"format_version": FORMAT_VERSION,
		"engine_version": Engine.get_version_info()["string"],
		"scenario_id": simulation.world["scenario"]["id"],
		"fingerprints": simulation.world["fingerprints"],
		"simulation": simulation.to_save(),
	}
	return JSON.stringify(document, "", true)


## Reads save text and checks it has every part a save needs.
static func parse(text: String) -> Dictionary:
	var parser: JSON = JSON.new()
	if text.strip_edges() == "" or parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return _refused("The save file is not readable.")
	var document: Dictionary = whole_numbers(parser.data)
	if document.get("format_version", 0) != FORMAT_VERSION:
		return _refused("The save file is from a different save format.")
	for part: String in DOCUMENT_PARTS:
		if not document.has(part):
			return _refused("The save file is incomplete: \"%s\" is missing." % part)
	if typeof(document["simulation"]) != TYPE_DICTIONARY or typeof(document["fingerprints"]) != TYPE_DICTIONARY:
		return _refused("The save file is damaged.")
	var saved: Dictionary = document["simulation"]
	for section: String in SIMULATION_PARTS:
		if typeof(saved.get(section)) != TYPE_DICTIONARY:
			return _refused("The save file is incomplete: \"%s\" is missing." % section)
		for part: String in SIMULATION_PARTS[section]:
			if not (saved[section] as Dictionary).has(part):
				return _refused("The save file is incomplete: \"%s\" is missing." % part)
	return {"ok": true, "error": "", "document": document}


static func _refused(reason: String) -> Dictionary:
	return {"ok": false, "error": reason, "document": {}}


## Turns save text back into a simulation running in the given world.
## "changed_data" lists data files that differ from when the save was made;
## the save still loads, and the caller decides whether to warn.
static func restore(text: String, world: Dictionary) -> Dictionary:
	var result: Dictionary = {"ok": false, "error": "", "simulation": null, "changed_data": [] as Array[String]}
	var parsed: Dictionary = parse(text)
	if not parsed["ok"]:
		result["error"] = parsed["error"]
		return result
	var document: Dictionary = parsed["document"]
	if document["scenario_id"] != world["scenario"].get("id", ""):
		result["error"] = "The save is from a different scenario (%s)." % document["scenario_id"]
		return result
	result["simulation"] = Simulation.from_save(world, document["simulation"])
	result["changed_data"] = changed_data(document, world)
	result["ok"] = true
	return result


## Data files whose content differs from when the save was made.
static func changed_data(document: Dictionary, world: Dictionary) -> Array[String]:
	var changed: Array[String] = []
	var saved: Dictionary = document.get("fingerprints", {})
	var current: Dictionary = world["fingerprints"]
	for path: String in saved:
		if current.get(path, "") != saved[path]:
			changed.append(path)
	for path: String in current:
		if not saved.has(path):
			changed.append(path)
	changed.sort()
	return changed


## Returns a copy in which every number is a whole number.
static func whole_numbers(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return int(value)
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key: Variant in value:
				result[key] = whole_numbers(value[key])
			return result
		TYPE_ARRAY:
			var items: Array = []
			for item: Variant in value:
				items.append(whole_numbers(item))
			return items
	return value


## True if a value contains a floating-point number anywhere.
static func contains_float(value: Variant) -> bool:
	match typeof(value):
		TYPE_FLOAT:
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if contains_float(value[key]):
					return true
		TYPE_ARRAY:
			for item: Variant in value:
				if contains_float(item):
					return true
	return false


## Writes text to a file, creating its folder if needed. The text goes to a
## temporary file first and is then renamed into place, so an interrupted
## write cannot leave a half-written save. Returns "" or the reason it failed.
static func write_file(path: String, text: String) -> String:
	var folder: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder):
		# Find the nearest thing that exists above the folder; if it is a
		# file, no folder can be made under it.
		var above: String = folder
		while above.get_base_dir() != above and not DirAccess.dir_exists_absolute(above) and not FileAccess.file_exists(above):
			above = above.get_base_dir()
		if FileAccess.file_exists(above) or DirAccess.make_dir_recursive_absolute(folder) != OK:
			return "Could not create the folder %s." % folder
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return "Could not write to %s." % folder
	file.store_string(text)
	file.close()
	# Some systems will not rename onto an existing file.
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if DirAccess.rename_absolute(temp_path, path) != OK:
		DirAccess.remove_absolute(temp_path)
		return "Could not save to %s." % path
	return ""


## Reads a file as text. Returns {"ok", "error", "text"}.
static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "There is no file at %s." % path, "text": ""}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Could not read %s." % path, "text": ""}
	return {"ok": true, "error": "", "text": file.get_as_text()}
