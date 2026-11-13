extends RefCounted
## Saving and loading a simulation exactly (see docs/M1_PLAN.md, section 5a).
##
## A save is JSON text: a header, then the complete simulation state taken
## between two ticks. Loading and continuing must give the same result as
## never having stopped. That holds because simulation state contains only
## whole numbers, text, lists and dictionaries (records.gd), and every number
## read back is converted to a whole number.

const FORMAT_VERSION: int = 1


static func to_text(simulation: RefCounted) -> String:
	var document: Dictionary = {
		"format_version": FORMAT_VERSION,
		"engine_version": Engine.get_version_info()["string"],
		"scenario_id": simulation.world["scenario"]["id"],
		"fingerprints": simulation.world["fingerprints"],
		"simulation": simulation.to_save(),
	}
	return JSON.stringify(document, "", true)


## Parses save text. Returns {"ok", "error", "document"}.
static func parse(text: String) -> Dictionary:
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "The save file is not readable.", "document": {}}
	var document: Dictionary = whole_numbers(parser.data)
	if document.get("format_version", 0) != FORMAT_VERSION:
		return {"ok": false, "error": "The save file is from a different save format.", "document": {}}
	return {"ok": true, "error": "", "document": document}


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


## Writes text to a temporary file and then renames it into place.
static func write_file(path: String, text: String) -> bool:
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return DirAccess.rename_absolute(temp_path, path) == OK
