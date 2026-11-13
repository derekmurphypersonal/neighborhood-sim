extends RefCounted
## Validation of authored data (D-019, D-020, D-022, D-035).
##
## Every data file is a JSON object: {"layer": <layer>, "records": [...]}.
## The layer must match the directory the file is in. Rules per layer:
##
## historical  - each record has provenance with status verified, probable or
##               hypothesis; at least one registered source; not tertiary
##               sources alone; reasoning if hypothesis.
## fiction     - each record has provenance.status "fictional".
## tuning      - each record has a label, "sourced" (with source_id) or
##               "gameplay_tuned".
## dev_fixture - the file declares "fictional": true with a notice; each
##               record has provenance.status "placeholder"; no real place
##               names appear anywhere in the file.
##
## Returns human-readable error strings; an empty list means valid.

const DataFiles := preload("res://sim/io/data_files.gd")

const LAYERS: Array[String] = ["historical", "fiction", "tuning", "dev_fixture"]
const HISTORICAL_STATUSES: Array[String] = ["verified", "probable", "hypothesis"]
## Real place names that must never appear in the fictional fixture.
const FIXTURE_FORBIDDEN_WORDS: Array[String] = ["linden", "malden"]


## Reads source IDs from docs/research/SOURCES.md.
## Returns {"all": {id: true}, "tertiary": {id: true}}.
static func read_source_register(sources_md_text: String) -> Dictionary:
	var all_ids: Dictionary = {}
	var tertiary_ids: Dictionary = {}
	var in_tertiary: bool = false
	var row: RegEx = RegEx.new()
	row.compile("^\\|\\s*(S-[A-Z0-9-]+)\\s*\\|")
	for line: String in sources_md_text.split("\n"):
		if line.begins_with("## "):
			in_tertiary = line.to_lower().contains("tertiary")
			continue
		var found: RegExMatch = row.search(line)
		if found != null:
			var source_id: String = found.get_string(1)
			all_ids[source_id] = true
			if in_tertiary:
				tertiary_ids[source_id] = true
	return {"all": all_ids, "tertiary": tertiary_ids}


static func validate_repository() -> Array[String]:
	var register: Dictionary = read_source_register(
		DataFiles.read_text(DataFiles.repo_root().path_join("docs/research/SOURCES.md"))
	)
	var errors: Array[String] = []
	if register["all"].is_empty():
		errors.append("No source IDs could be read from docs/research/SOURCES.md.")
	for layer: String in LAYERS:
		var layer_dir: String = DataFiles.data_root().path_join(layer)
		for path: String in DataFiles.list_files(layer_dir, "json"):
			var document: Variant = DataFiles.read_json(path)
			var label: String = path.trim_prefix(DataFiles.repo_root() + "/")
			errors.append_array(validate_document(document, layer, label, register))
	return errors


static func validate_document(
	document: Variant, layer: String, label: String, register: Dictionary
) -> Array[String]:
	var errors: Array[String] = []
	if typeof(document) != TYPE_DICTIONARY:
		return [label + ": not a valid JSON object."]
	var doc: Dictionary = document
	if doc.get("layer", "") != layer:
		errors.append("%s: \"layer\" must be \"%s\" to match its directory." % [label, layer])
	if typeof(doc.get("records")) != TYPE_ARRAY:
		errors.append(label + ": missing \"records\" array.")
		return errors
	if layer == "dev_fixture":
		errors.append_array(_validate_fixture_header(doc, label))
	var seen_ids: Dictionary = {}
	var records: Array = doc["records"]
	for index: int in records.size():
		if typeof(records[index]) != TYPE_DICTIONARY:
			errors.append("%s: record %d is not an object." % [label, index])
			continue
		var record: Dictionary = records[index]
		var record_id: String = str(record.get("id", ""))
		var where: String = "%s: record %s" % [label, record_id if record_id != "" else "#%d" % index]
		if record_id == "":
			errors.append(where + " has no id.")
		elif seen_ids.has(record_id):
			errors.append(where + " duplicates an id.")
		seen_ids[record_id] = true
		match layer:
			"historical":
				errors.append_array(_validate_historical(record, where, register))
			"fiction":
				errors.append_array(_require_status(record, where, "fictional"))
			"dev_fixture":
				errors.append_array(_require_status(record, where, "placeholder"))
			"tuning":
				errors.append_array(_validate_tuning(record, where, register))
	return errors


static func _validate_fixture_header(doc: Dictionary, label: String) -> Array[String]:
	var errors: Array[String] = []
	if doc.get("fictional") != true:
		errors.append(label + ": a fixture file must declare \"fictional\": true.")
	if str(doc.get("notice", "")).strip_edges() == "":
		errors.append(label + ": a fixture file must carry a \"notice\" saying it is fictional.")
	var text: String = JSON.stringify(doc.get("records", [])).to_lower()
	for word: String in FIXTURE_FORBIDDEN_WORDS:
		if text.contains(word):
			errors.append("%s: fixture records must not use the real place name \"%s\"." % [label, word])
	return errors


static func _require_status(record: Dictionary, where: String, status: String) -> Array[String]:
	var provenance: Variant = record.get("provenance")
	if typeof(provenance) != TYPE_DICTIONARY or provenance.get("status", "") != status:
		return ["%s must have provenance.status \"%s\"." % [where, status]]
	return []


static func _validate_historical(
	record: Dictionary, where: String, register: Dictionary
) -> Array[String]:
	var errors: Array[String] = []
	var provenance: Variant = record.get("provenance")
	if typeof(provenance) != TYPE_DICTIONARY:
		return [where + " has no provenance."]
	var status: String = str(provenance.get("status", ""))
	if not HISTORICAL_STATUSES.has(status):
		errors.append("%s has status \"%s\"; historical records must be verified, probable or hypothesis." % [where, status])
	if status == "hypothesis" and str(provenance.get("reasoning", "")).strip_edges() == "":
		errors.append(where + " is a hypothesis without reasoning.")
	var sources: Variant = provenance.get("sources")
	if typeof(sources) != TYPE_ARRAY or sources.is_empty():
		errors.append(where + " cites no sources.")
		return errors
	var has_non_tertiary: bool = false
	for source: Variant in sources:
		var source_id: String = ""
		if typeof(source) == TYPE_DICTIONARY:
			source_id = str(source.get("source_id", ""))
		if not register["all"].has(source_id):
			errors.append("%s cites \"%s\", which is not in the source register." % [where, source_id])
		elif not register["tertiary"].has(source_id):
			has_non_tertiary = true
	if not has_non_tertiary:
		errors.append(where + " relies only on tertiary or unregistered sources.")
	return errors


static func _validate_tuning(record: Dictionary, where: String, register: Dictionary) -> Array[String]:
	var label: String = str(record.get("label", ""))
	if label == "gameplay_tuned":
		return []
	if label == "sourced":
		if register["all"].has(str(record.get("source_id", ""))):
			return []
		return [where + " is labeled sourced but has no registered source_id."]
	return [where + " must be labeled \"sourced\" or \"gameplay_tuned\"."]
