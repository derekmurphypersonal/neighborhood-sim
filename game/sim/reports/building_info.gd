extends RefCounted
## What is known about a building, kept in separate parts so that documented
## facts are never mixed with invented content:
##
##   exterior     what the area data says about the outside of the building,
##                with its provenance. Only a record whose status is verified,
##                probable or hypothesis counts as documented; a placeholder
##                record documents nothing.
##   interior     the floor plan assigned to it, if any. Always fictional (D-032).
##   institution  the institution in it, if any, with that record's own status.
##   households   who lives there in this scenario. Always fictional.
##
## Reads the area and the state; changes nothing.

const DOCUMENTED_STATUSES: Array[String] = ["verified", "probable", "hypothesis"]


static func describe(sim: RefCounted, building_id: String) -> Dictionary:
	var area: RefCounted = sim.area
	var building: Dictionary = area.buildings[building_id]
	var provenance: Dictionary = building.get("provenance", {})
	var status: String = provenance.get("status", "")
	var info: Dictionary = {
		"building_id": building_id,
		"label": building["label"],
		"area_placeholder": area.placeholder,
		"area_notice": area.notice,
		"exterior": {
			"status": status,
			"documented": DOCUMENTED_STATUSES.has(status),
			"facts": [
				{"field": "building_type", "value": str(building["building_type"])},
				{"field": "stories", "value": str(building["stories"])},
			],
			"sources": (provenance.get("sources", []) as Array).duplicate(true),
			"reasoning": provenance.get("reasoning", ""),
		},
		"interior": {},
		"institution": {},
		"households": [],
	}
	if area.interiors.has(building_id):
		var interior: Dictionary = area.interiors[building_id]
		var rooms: Array = []
		var room_ids: Array = interior["rooms"].keys()
		room_ids.sort()
		for room_id: String in room_ids:
			rooms.append(interior["rooms"][room_id]["name"])
		info["interior"] = {"module_id": interior["module_id"], "name": interior["name"], "rooms": rooms, "fictional": true}
	if area.institutions.has(building_id):
		var institution: Dictionary = area.institutions[building_id]
		var institution_status: String = institution.get("provenance", {}).get("status", "")
		info["institution"] = {
			"name": institution["name"], "kind": institution["kind"], "hours": institution["hours"],
			"status": institution_status, "documented": DOCUMENTED_STATUSES.has(institution_status),
		}
	for household_id: String in sim.state.sorted_household_ids():
		var household: Dictionary = sim.state.households[household_id]
		if household["home_id"] == building_id:
			info["households"].append({
				"household_id": household_id, "name": household["name"],
				"member_ids": (household["member_ids"] as Array).duplicate(), "fictional": true,
			})
	return info
