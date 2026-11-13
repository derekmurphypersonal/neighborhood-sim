extends RefCounted
## The place the simulation runs in: streets, buildings and ways off the map.
## Built once from area data and never changed during play (D-023). The same
## class serves a placeholder area and a researched one; nothing here knows
## which it has been given.
##
## All coordinates are whole inches in the area's local system (the data is
## authored in feet, D-016). Two points per building are derived, not
## authored: "door" (on the footprint, facing the nearest street) and
## "front" (on the edge of that street). They are walking aids, not
## historical claims.

const SimDate := preload("res://sim/clock/sim_date.gd")

const INCHES_PER_FOOT: int = 12

var id: String = ""
var display_name: String = ""
## True when the area is a development stand-in and not real geography.
var placeholder: bool = false
var notice: String = ""
var streets: Dictionary = {}    # id -> {id, name, centerline: [[x, y], ...], width}
var lots: Dictionary = {}       # id -> {id, boundary: [[x, y], ...]}
var buildings: Dictionary = {}  # id -> {id, lot_id, footprint, stories, building_type, label, door, front}
var exits: Dictionary = {}      # id -> {id, point: [x, y]}
## building_id -> {id, building_id, name, kind, hours: {weekday, saturday, sunday}}.
## A building people other than its household may enter during opening hours.
## Each day's hours are [open, close] in minutes after midnight, or null if closed.
var institutions: Dictionary = {}
## building_id -> {module_id, name, rooms: {room_id: {id, name, kind, rect}}}.
## Interiors are always fictional floor plans (D-032); rect is [x, y, w, h] in inches.
var interiors: Dictionary = {}


func sorted_building_ids() -> Array:
	var ids: Array = buildings.keys()
	ids.sort()
	return ids


func door_of(building_id: String) -> Array:
	return buildings[building_id]["door"]


func front_of(building_id: String) -> Array:
	return buildings[building_id]["front"]


## The exit nearest to a point, by ID ("" if the area has none).
func nearest_exit(point: Array) -> String:
	var best_id: String = ""
	var best: int = -1
	var ids: Array = exits.keys()
	ids.sort()
	for exit_id: String in ids:
		var distance: int = distance_between(point, exits[exit_id]["point"])
		if best < 0 or distance < best:
			best = distance
			best_id = exit_id
	return best_id


static func distance_between(a: Array, b: Array) -> int:
	var dx: int = int(b[0]) - int(a[0])
	var dy: int = int(b[1]) - int(a[1])
	return int(sqrt(float(dx * dx + dy * dy)))


## Waypoints for walking out of a building (if inside one) to a target.
## from_building: the building the walker is inside, or "".
## to_building:   the building to enter, or "".
## to_point:      the final outdoor point, used when to_building is "".
func route(from_building: String, to_building: String, to_point: Array) -> Array:
	var path: Array = []
	if from_building != "":
		path.append(front_of(from_building).duplicate())
	if to_building != "":
		if to_building != from_building:
			path.append(front_of(to_building).duplicate())
		else:
			path.clear()
		path.append(door_of(to_building).duplicate())
	else:
		path.append([int(to_point[0]), int(to_point[1])])
	return path


# --- Institutions and interiors ----------------------------------------------

func is_institution(building_id: String) -> bool:
	return institutions.has(building_id)


## True if the institution in this building is open at the given time.
func is_open(building_id: String, weekday_number: int, minute: int) -> bool:
	if not institutions.has(building_id):
		return false
	var hours: Variant = institutions[building_id]["hours"].get(SimDate.day_kind(weekday_number))
	if typeof(hours) != TYPE_ARRAY or (hours as Array).size() != 2:
		return false
	return minute >= int(hours[0]) and minute < int(hours[1])


## The first institution of a kind, by building ID ("" if there is none).
func institution_of_kind(kind: String) -> String:
	var ids: Array = institutions.keys()
	ids.sort()
	for building_id: String in ids:
		if institutions[building_id]["kind"] == kind:
			return building_id
	return ""


## Gives a building a fictional interior from a floor-plan module. Room
## rectangles in the module are in feet from the footprint's south-west
## corner; they are stored in world inches.
func set_interior(building_id: String, module: Dictionary) -> void:
	var footprint: Array = buildings[building_id]["footprint"]
	var min_x: int = int(footprint[0][0])
	var min_y: int = int(footprint[0][1])
	for point: Array in footprint:
		min_x = mini(min_x, int(point[0]))
		min_y = mini(min_y, int(point[1]))
	var rooms: Dictionary = {}
	for room: Dictionary in module["rooms"]:
		var rect: Array = room["rect_ft"]
		rooms[room["id"]] = {
			"id": room["id"],
			"name": room.get("name", room["id"]),
			"kind": room.get("kind", ""),
			"rect": [
				min_x + roundi(float(rect[0]) * INCHES_PER_FOOT), min_y + roundi(float(rect[1]) * INCHES_PER_FOOT),
				roundi(float(rect[2]) * INCHES_PER_FOOT), roundi(float(rect[3]) * INCHES_PER_FOOT),
			],
		}
	interiors[building_id] = {"module_id": module["id"], "name": module.get("name", ""), "rooms": rooms}


func has_interior(building_id: String) -> bool:
	return interiors.has(building_id)


## The room of a kind in a building's interior ("" if it has none).
func room_of_kind(building_id: String, kind: String) -> String:
	if kind == "" or not interiors.has(building_id):
		return ""
	var ids: Array = interiors[building_id]["rooms"].keys()
	ids.sort()
	for room_id: String in ids:
		if interiors[building_id]["rooms"][room_id]["kind"] == kind:
			return room_id
	return ""


# --- Construction from data -------------------------------------------------

static func _to_inches(point: Array) -> Array:
	return [roundi(float(point[0]) * INCHES_PER_FOOT), roundi(float(point[1]) * INCHES_PER_FOOT)]


static func _points_to_inches(points: Array) -> Array:
	var result: Array = []
	for point: Array in points:
		result.append(_to_inches(point))
	return result


## Adds one data record. Unknown record types are ignored.
func add_record(record: Dictionary) -> void:
	match record.get("type", ""):
		"street":
			streets[record["id"]] = {
				"id": record["id"],
				"name": record.get("name", ""),
				"centerline": _points_to_inches(record["centerline"]),
				"width": roundi(float(record["width_ft"]) * INCHES_PER_FOOT),
			}
		"lot":
			lots[record["id"]] = {"id": record["id"], "boundary": _points_to_inches(record["boundary"])}
		"building":
			buildings[record["id"]] = {
				"id": record["id"],
				"lot_id": record.get("lot_id", ""),
				"footprint": _points_to_inches(record["footprint"]),
				"stories": int(record.get("stories", 1)),
				"building_type": record.get("building_type", ""),
				"label": record.get("label", ""),
				"provenance": record.get("provenance", {}),
			}
		"institution":
			institutions[record["building_id"]] = {
				"id": record["id"],
				"building_id": record["building_id"],
				"name": record.get("name", ""),
				"kind": record.get("kind", ""),
				"hours": record.get("hours", {}),
				"provenance": record.get("provenance", {}),
			}
		"exit":
			exits[record["id"]] = {"id": record["id"], "point": _to_inches(record["point"])}


## Derives each building's door and front points. Call after all records
## have been added.
func finish() -> void:
	for building_id: String in sorted_building_ids():
		var building: Dictionary = buildings[building_id]
		var footprint: Array = building["footprint"]
		var centre: Vector2 = Vector2.ZERO
		for point: Array in footprint:
			centre += Vector2(point[0], point[1])
		centre /= float(footprint.size())
		var nearest: Dictionary = _nearest_street_point(centre)
		var on_street: Vector2 = nearest["point"]
		var toward_building: Vector2 = (centre - on_street).normalized()
		var front: Vector2 = on_street + toward_building * (float(nearest["width"]) / 2.0)
		# Door: the midpoint of the footprint edge closest to the street.
		var door: Vector2 = centre
		var best: float = -1.0
		for index: int in footprint.size():
			var a: Array = footprint[index]
			var b: Array = footprint[(index + 1) % footprint.size()]
			var mid: Vector2 = (Vector2(a[0], a[1]) + Vector2(b[0], b[1])) / 2.0
			var distance: float = mid.distance_to(front)
			if best < 0.0 or distance < best:
				best = distance
				door = mid
		building["front"] = [roundi(front.x), roundi(front.y)]
		building["door"] = [roundi(door.x), roundi(door.y)]


func _nearest_street_point(from: Vector2) -> Dictionary:
	var best_point: Vector2 = from
	var best_width: int = 0
	var best: float = -1.0
	var ids: Array = streets.keys()
	ids.sort()
	for street_id: String in ids:
		var line: Array = streets[street_id]["centerline"]
		for index: int in line.size() - 1:
			var a: Vector2 = Vector2(line[index][0], line[index][1])
			var b: Vector2 = Vector2(line[index + 1][0], line[index + 1][1])
			var candidate: Vector2 = Geometry2D.get_closest_point_to_segment(from, a, b)
			var distance: float = candidate.distance_to(from)
			if best < 0.0 or distance < best:
				best = distance
				best_point = candidate
				best_width = streets[street_id]["width"]
	return {"point": best_point, "width": best_width}
