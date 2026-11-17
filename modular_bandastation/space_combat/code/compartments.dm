/// Share of a compartment's floor in vacuum that marks it depressurised; airlock chambers and nozzles stay below it.
#define COMPARTMENT_DEPRESSURISED_SHARE 0.25
/// Silhouette cell codes for compartment floors, by report index; a hull is far below this many compartments.
#define COMPARTMENT_CELL_CODES "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

/area/shuttle/stationtrauma_space
	/// Exterior equipment and trim still belong to the ship, but are not sealed compartments.
	var/monitored_compartment = TRUE
	/// Mapped airless (external airlock chambers): never reported as depressurised.
	var/vacuum_by_design = FALSE
	/// Burner compartments where flame is the working state: never reported as on fire.
	var/fire_by_design = FALSE

/**
 * Per-compartment damage summary for the helm, read from the physical hull: mean pressure, open fire, tiles open to space.
 * Returns `rooms` and the hull silhouette as `rows`, north first: a space for tiles outside the hull, `#` for walls,
 * `!` for breaches, otherwise the [COMPARTMENT_CELL_CODES] character of the compartment's index in `rooms`.
 * shortcut: scans the hull footprint on every UI refresh (~1 ms for Raven's 672 tiles); cache per tick once capital hulls exist.
 */
/obj/docking_port/mobile/stationtrauma_space/proc/compartment_report()
	var/list/rooms = list()
	var/list/footprint = return_turfs()
	var/turf/low = footprint[1]
	var/turf/high = footprint[length(footprint)]
	var/min_x = min(low.x, high.x)
	var/max_y = max(low.y, high.y)
	var/width = abs(high.x - low.x) + 1
	var/list/cells = new /list(width * (abs(high.y - low.y) + 1))
	for(var/turf/tile as anything in footprint)
		var/cell = (max_y - tile.y) * width + tile.x - min_x + 1
		cells[cell] = " "
		var/area/room = get_area(tile)
		if(!shuttle_areas[room])
			continue
		var/area/shuttle/stationtrauma_space/ship_room = room
		if(istype(ship_room) && !ship_room.monitored_compartment)
			continue
		var/list/entry = rooms[room]
		if(!entry)
			entry = list("name" = room.name, "airless" = istype(ship_room) && ship_room.vacuum_by_design, "burner" = istype(ship_room) && ship_room.fire_by_design, "breaches" = 0, "fire" = FALSE, "floor_tiles" = 0, "vacuum_tiles" = 0, "total_pressure" = 0)
			entry["code"] = copytext(COMPARTMENT_CELL_CODES, length(rooms) + 1, length(rooms) + 2) || "?"
			rooms[room] = entry
		if(isspaceturf(tile))
			entry["breaches"]++
			cells[cell] = "!"
			continue
		if(!isopenturf(tile))
			cells[cell] = "#"
			continue
		cells[cell] = entry["code"]
		var/turf/open/open_tile = tile
		if(open_tile.active_hotspot && !entry["burner"])
			entry["fire"] = TRUE
		var/pressure = open_tile.return_air()?.return_pressure() || 0
		entry["floor_tiles"]++
		entry["total_pressure"] += pressure
		if(pressure < HAZARD_LOW_PRESSURE)
			entry["vacuum_tiles"]++
	var/list/report = list()
	for(var/area/room as anything in rooms)
		var/list/entry = rooms[room]
		var/floor_tiles = entry["floor_tiles"]
		report += list(list(
			"name" = entry["name"],
			"pressure" = floor_tiles ? round(entry["total_pressure"] / floor_tiles) : null,
			"low_pressure" = !entry["airless"] && floor_tiles && entry["vacuum_tiles"] > floor_tiles * COMPARTMENT_DEPRESSURISED_SHARE,
			"fire" = entry["fire"],
			"breaches" = entry["breaches"],
		))
	var/list/rows = list()
	for(var/start in 1 to length(cells) step width)
		rows += jointext(cells.Copy(start, start + width), "")
	return list("rooms" = report, "rows" = rows)

#undef COMPARTMENT_CELL_CODES
#undef COMPARTMENT_DEPRESSURISED_SHARE
