/** Space destination with native docking reservation and detection requirements. */
/datum/stationtrauma_overmap_site/space
	/// Navigation instance currently reserving or occupying this site.
	var/datum/stationtrauma_overmap/space/docking_owner
	/// Whether this destination requires a surface landing.
	var/landing = FALSE
	/// Whether arrival moves the physical hull into the native station berth.
	var/physical_docking = FALSE
	/// Whether this site requires a crew-local sensor discovery.
	var/needs_scan = FALSE
	/// Source ruin template ID retained for diagnostics.
	var/ruin_id
	/// Deferred map load run by the first approach; null once the destination exists or has failed.
	var/datum/callback/map_loader
	/// Set while the first approach loads the destination.
	var/loading_map = FALSE
	/// Approach schematic on the navigation console: "ruin", "cargo" or "asteroids".
	var/approach_scene = "ruin"
	/// Outer airlock of a loaded ruin that the docking pinpointer leads to beyond the seam; null without one.
	var/turf/entrance

/datum/stationtrauma_overmap_site/space/Destroy()
	docking_owner = null
	host = null
	// The loader callback holds the owning sector, which deletes its sites.
	map_loader = null
	return ..()

/** Callsigns of distress beacons transmitting at this space object; stations and planets carry none. */
/datum/stationtrauma_overmap_site/space/proc/distress_callsigns()
	if(landing || physical_docking || QDELETED(berth))
		return list()
	return stationtrauma_distress_callsigns(berth.z)

/** Whether docking may begin before the berth exists because the approach loads the destination. */
/datum/stationtrauma_overmap_site/space/proc/awaits_map()
	return !!map_loader

/**
 * Load the charted destination once, beside live gameplay.
 *
 * Approaches wait on [/datum/stationtrauma_overmap_site/space/var/loading_map]. A crash inside the load only aborts that call,
 * so the site is still released as failed instead of waiting for another attempt. No try block here: it would turn any
 * runtime from a single loaded atom's Initialize into a failed destination.
 */
/datum/stationtrauma_overmap_site/space/proc/load_map()
	if(!map_loader || loading_map)
		return
	loading_map = TRUE
	failed = !map_loader.Invoke()
	map_loader = null
	loading_map = FALSE
	if(!failed)
		SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPEDITION_SITE_LOADED, src)


/** Known planets carry their chart symbol without disclosing hidden signals. */
/datum/stationtrauma_overmap/space/known_sites()
	var/list/records = ..()
	. = list()
	for(var/list/record as anything in records)
		var/datum/stationtrauma_overmap_site/space/site = sites[record["id"]]
		var/sos = length(site.distress_callsigns()) > 0
		// A distress point exists on the chart only while someone transmits there.
		if(istype(site, /datum/stationtrauma_overmap_site/space/distress) && !sos)
			continue
		record["kind"] = istype(site, /datum/stationtrauma_overmap_site/space/planet) ? "planet" : site.physical_docking ? "station" : "signal"
		record["name"] = site_label(site)
		record["type"] = record["kind"] == "signal" ? site_structure(site) : record["kind"] == "planet" ? "Планета" : "Станция"
		record["sos"] = sos
		// A remembered carrier contact is a measurement, not a live position tracker.
		if(site.host && !(src in site.host.carrier_tree()))
			var/list/observation = ship_observations[site.host.vessel.shuttle_id]
			record["x"] = observation["x"]
			record["y"] = observation["y"]
			record["distance"] = round(sqrt((pos_x - observation["x"]) ** 2 + (pos_y - observation["y"]) ** 2))
		. += list(record)

/** Crew-facing name: space objects stay unidentified; planets and stations are charted. */
/datum/stationtrauma_overmap/space/proc/site_label(datum/stationtrauma_overmap_site/space/site)
	var/list/distress = site.distress_callsigns()
	if(length(distress))
		return "SOS · [jointext(distress, "; ")]"
	return site.landing || site.physical_docking ? site.name : "???"

/** Kind of structure a space object reads as on sensors, from its approach schematic; wrecks and stations stay unidentified. */
/datum/stationtrauma_overmap/space/proc/site_structure(datum/stationtrauma_overmap_site/space/site)
	var/static/list/structures = list("cargo" = "Груз", "asteroids" = "Астероиды", "sos" = "Сигнал бедствия")
	return structures[site.approach_scene] || "???"

/** A bounded metadata pulse, independent of loading and never exposing contacts outside detection range. */
/datum/stationtrauma_overmap/space/proc/scan_sector()
	if(relocating || preparing || !is_operational() || world.time < next_scan)
		return FALSE
	next_scan = world.time + 20 SECONDS
	last_ping = world.time
	var/found = 0
	var/reach = sensor_range
	found += observe_ships(reach)
	for(var/id in sites)
		var/datum/stationtrauma_overmap_site/site = sites[id]
		if(!knows_site(site) && !site.failed && distance_to(site) <= reach)
			discover_site(site)
			found++
	for(var/datum/stationtrauma_overmap_zone/zone as anything in zones)
		if(!charted_zones[zone] && (pos_x - zone.pos_x) ** 2 + (pos_y - zone.pos_y) ** 2 <= (reach + zone.radius) ** 2)
			charted_zones[zone] = TRUE
			found++
	navigation_notice("Сканирование завершено: новых точек [found]. Дальность [reach * ST_SPACE_AU_SCALE] а.е.")
	return TRUE
