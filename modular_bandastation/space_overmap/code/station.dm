/datum/map_config
	/// Optional expedition profile; absent for ordinary station configurations.
	var/list/space_overmap

/datum/map_config/LoadConfig(filename, error_if_missing)
	. = ..()
	var/list/config = .
	space_overmap = islist(config) && islist(config["space_overmap"]) ? config["space_overmap"] : null

/// A mapped native berth registered as a destination in the station's sector.
/obj/docking_port/stationary/stationtrauma_space_station
	shuttle_id = "overmap_station"
	/// Stable sector destination ID associated with this station berth.
	var/site_id
	/// Crew-facing station destination name.
	var/station_name
	/// Position on the sector chart. Native station berths use the station's coordinates by default.
	var/overmap_x = 1000
	/// Position on the sector chart along the north-south axis.
	var/overmap_y = 0
	/// Unstaffed berths automatically answer clearance requests.
	var/auto_approve_docking = FALSE

/** A shared bay may have several profiles on one turf. The S-slot marker only describes its envelope. */
/obj/docking_port/mobile/stationtrauma_space/get_docked()
	var/obj/docking_port/stationary/stationtrauma_space_site/standard/berth = locate() in loc
	if(berth?.ship == src)
		return berth
	var/obj/docking_port/stationary/stationtrauma_space_station/port = locate() in loc
	if(istype(port, /obj/docking_port/stationary/stationtrauma_space_station/standard))
		for(var/obj/docking_port/stationary/other in loc)
			if(other != port && other != berth)
				return other
		return null
	if(port)
		return port
	return ..()

/** The emergency controller normally ignores occupancy; shared bays must not crush expedition ships. */
/obj/docking_port/mobile/emergency/canDock(obj/docking_port/stationary/target)
	if(istype(target?.get_docked(), /obj/docking_port/mobile/stationtrauma_space))
		return SHUTTLE_SOMEONE_ELSE_DOCKED
	return ..()

/** Every evacuation call path ends here; expedition hulls yield the shared bay without propulsion. */
/obj/docking_port/mobile/emergency/request(obj/docking_port/stationary/S, area/signal_origin, reason, red_alert, set_coefficient = null)
	. = ..()
	// Only opt-in overmap maps place expedition bays on the evacuation berth.
	if(mode == SHUTTLE_CALL && SSmapping.current_map.space_overmap)
		clear_stationtrauma_bay(SSshuttle.getDock("emergency_home"))

/** Arrival retries cover hulls that finished docking during the call or could not leave on the first attempt. */
/obj/docking_port/mobile/emergency/initiate_docking(obj/docking_port/stationary/new_dock, movement_direction, force = FALSE)
	if(!force && mode == SHUTTLE_CALL)
		clear_stationtrauma_bay(new_dock)
	return ..()

/**
 * Start a service departure for an expedition hull docked at a station bay sharing the evacuation berth.
 *
 * Native occupancy keeps the bay blocked until the hull physically leaves, so crush protection is unchanged.
 * Arguments:
 * * home - Stationary port the evacuation shuttle is heading to
 */
/obj/docking_port/mobile/emergency/proc/clear_stationtrauma_bay(obj/docking_port/stationary/home)
	if(QDELETED(home))
		return
	for(var/obj/docking_port/stationary/stationtrauma_space_station/bay in home.loc)
		var/obj/docking_port/mobile/stationtrauma_space/ship = bay.get_docked()
		if(istype(ship) && !QDELETED(ship.overmap) && ship.overmap.docked?.berth == bay)
			INVOKE_ASYNC(ship.overmap, TYPE_PROC_REF(/datum/stationtrauma_overmap/space, yield_station_bay))

/** A called evacuation shuttle claims the shared bay before arrival; native occupancy covers its stay. */
/obj/docking_port/mobile/stationtrauma_space/canDock(obj/docking_port/stationary/target)
	. = ..()
	if(. != SHUTTLE_CAN_DOCK || !istype(target, /obj/docking_port/stationary/stationtrauma_space_station) || SSshuttle.emergency?.mode != SHUTTLE_CALL)
		return .
	for(var/obj/docking_port/stationary/home in target.loc)
		if(home.shuttle_id == "emergency_home")
			return SHUTTLE_SOMEONE_ELSE_DOCKED
	return .

/** Service departure from a shared bay: no propulsion, fuel or helm order; the hull keeps its virtual position. */
/datum/stationtrauma_overmap/space/proc/yield_station_bay()
	var/datum/stationtrauma_overmap_site/space/site = docked
	if(!site?.physical_docking || relocating || preparing || ship_docking || QDELETED(flight_berth) || !is_operational() || site.docking_owner != src || vessel.get_docked() != site.berth)
		return
	var/obj/docking_port/stationary/stationtrauma_space_flight/berth = flight_berth
	var/turf/original_position = get_turf(berth)
	var/moved = FALSE
	var/exception/relocation_error
	preparing = TRUE
	try
		if(position_service_berth(site))
			moved = relocate(berth)
	catch(var/exception/failure)
		relocation_error = failure
	// Searching moves only our empty marker. Restore it if the physical hull never left the bay.
	if(!moved && !QDELETED(berth) && !QDELETED(vessel) && vessel.get_docked() == site.berth)
		berth.forceMove(original_position)
	if(QDELETED(src))
		return
	preparing = FALSE
	if(relocation_error)
		throw relocation_error
	if(!moved)
		status = "Причал не освобождён: нет безопасной орбитальной стоянки"
		return
	// Native relocation yields; only a hull still holding this dock state drops it.
	if(docked != site)
		return
	if(site.docking_owner == src)
		site.docking_owner = null
	docked = null
	if(selected_destination == site.id || (site.docking_target && selected_destination == site.docking_target.id))
		selected_destination = null
		prepared_site = null
	stop("Причал станции освобождён для эвакуационного шаттла")
	navigation_notice("Причал станции освобождён для эвакуационного шаттла; корабль переведён на орбитальную стоянку.")

/**
 * Living crew away from the station network miss station-wide announcements: a ship in flight,
 * an expedition sector and a planet all occupy away levels. A ship docked at the station shares its level.
 * Ghosts keep receiving them.
 */
/proc/stationtrauma_out_of_station_contact(mob/target)
	if(!isliving(target))
		return FALSE
	var/turf/position = get_turf(target)
	return !!position && SSmapping.level_trait(position.z, ZTRAIT_AWAY)
