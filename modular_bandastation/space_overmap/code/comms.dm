/**
 * Ship telecommunications node: headsets aboard keep working in flight.
 *
 * It processes only its own level and stays silent on a station level, where the station network serves headsets,
 * and when another node already handled the signal, so a docked hull never duplicates speech.
 */
/obj/machinery/telecomms/allinone/ship
	name = "корабельный узел связи"
	desc = "Компактный сервер подпространственной связи. Обслуживает гарнитуры на борту, пока корабль вдали от станции."

/obj/machinery/telecomms/allinone/ship/receive_signal(datum/signal/subspace/signal)
	if(is_station_level(z) || signal?.data["done"])
		return
	return ..()

/** A shipboard projector supplies the caller's view of the compartment. */
/obj/machinery/holopad/ship
	desc = "Голопад со встроенной оптикой. После ответа звонящий видит отсек вокруг своей голограммы."
	circuit = /obj/item/circuitboard/machine/holopad/ship
	holocall_eye_type = /mob/eye/camera/remote/holo/ship

/** Shipboard projector for compartments where the crew must accept incoming calls. */
/obj/machinery/holopad/secure/ship
	desc = "Голопад со встроенной оптикой. Экипаж должен принять вызов, прежде чем звонящий увидит отсек вокруг своей голограммы."
	circuit = /obj/item/circuitboard/machine/holopad/ship
	holocall_eye_type = /mob/eye/camera/remote/holo/ship

/** The projector keeps its onboard optics when rebuilt in either security mode. */
/obj/item/circuitboard/machine/holopad/ship
	build_path = /obj/machinery/holopad/ship
	secure_build_path = /obj/machinery/holopad/secure/ship

/** View the deck from the hologram using ordinary line of sight. */
/mob/eye/camera/remote/holo/ship
	use_visibility = FALSE

/mob/eye/camera/remote/holo/ship/update_remote_sight(mob/living/user)
	. = ..()
	user.set_sight(NONE)

/**
 * Ship holopads can reach the station bridge across sectors. Central Command keeps its control room link.
 * Calls between ships still require a sensor contact. The same level and the station's own decks keep the native network.
 */
/obj/machinery/holopad/holocall_reachable(obj/machinery/holopad/pad, established = FALSE)
	if(!SSmapping.current_map.space_overmap || pad.z == z || (is_station_level(z) && is_station_level(pad.z)))
		return TRUE
	if(is_centcom_level(pad.z))
		return istype(get_area(pad), /area/centcom/central_command_areas/control)
	var/obj/docking_port/mobile/stationtrauma_space/target = SSshuttle.get_containing_shuttle(pad)
	var/target_is_bridge = is_station_level(pad.z) && istype(get_area(pad), /area/station/command/bridge)
	if(!istype(target) && !target_is_bridge)
		return FALSE
	if(is_centcom_level(z))
		return TRUE
	var/obj/docking_port/mobile/stationtrauma_space/ship = SSshuttle.get_containing_shuttle(src)
	if(istype(ship) && istype(target))
		if(ship == target)
			return TRUE
		return ship.overmap?.ship_in_sensor_contact(target.overmap, established)
	if(istype(ship) && target_is_bridge)
		return !!ship.overmap?.sector
	if(istype(target) && is_station_level(z) && istype(get_area(src), /area/station/command/bridge))
		return !!target.overmap?.sector
	return stationtrauma_comms_sector(src) == stationtrauma_comms_sector(pad)

/**
 * Whether another hull is inside sensor range now and was caught by a scan still shown on the plot.
 *
 * An established link needs only the range: two silent hulls would otherwise lose a call once the contact ages out.
 */
/datum/stationtrauma_overmap/space/proc/ship_in_sensor_contact(datum/stationtrauma_overmap/space/other, established)
	if(QDELETED(other) || !sector || other.sector != sector || (other.pos_x - pos_x) ** 2 + (other.pos_y - pos_y) ** 2 > sensor_range ** 2)
		return FALSE
	if(established)
		return TRUE
	var/list/contact = ship_observations[other.vessel.shuttle_id]
	return contact && world.time - contact["seen"] < ST_NAV_SHIP_MEMORY

/**
 * Returns the overmap sector containing a communications endpoint.
 * An unregistered hull uses its own identity until it has a sector.
 */
/proc/stationtrauma_comms_sector(atom/endpoint)
	var/turf/position = get_turf(endpoint)
	if(!position)
		return null
	if(is_station_level(position.z))
		return SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	if(istype(get_area(position), /area/shuttle/stationtrauma_space))
		var/obj/docking_port/mobile/stationtrauma_space/ship = SSshuttle.get_containing_shuttle(position)
		if(istype(ship))
			return ship.overmap?.sector || ship
	for(var/datum/stationtrauma_lost_space/loss as anything in GLOB.stationtrauma_lost_spaces)
		if(loss.level?.z_value == position.z)
			return SSstationtrauma_space_voyage.sectors[loss.sector_id]
	for(var/sector_id in SSstationtrauma_space_voyage.sectors)
		var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors[sector_id]
		for(var/ship_id in sector.ships)
			var/datum/stationtrauma_overmap/space/navigation = sector.ships[ship_id]
			if(position.z in navigation.flight_levels)
				return sector
		for(var/site_id in sector.sites)
			var/datum/stationtrauma_overmap_site/space/site = sector.sites[site_id]
			if(!QDELETED(site.berth) && site.berth.z == position.z)
				return sector
	return null

/** Checks system range for ordinary communications. Native station levels outside the plot belong to the home system. */
/proc/stationtrauma_comms_in_range(atom/origin, atom/destination)
	if(!SSmapping.current_map?.space_overmap)
		return TRUE
	var/turf/origin_turf = get_turf(origin)
	var/turf/destination_turf = get_turf(destination)
	if(!origin_turf || !destination_turf)
		return FALSE
	if(origin_turf.z == destination_turf.z)
		return TRUE
	var/datum/home = SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	return (stationtrauma_comms_sector(origin_turf) || home) == (stationtrauma_comms_sector(destination_turf) || home)

/** A call that drifted out of reach drops like a lost connection. */
/datum/holocall/Check()
	if(!QDELETED(calling_holopad))
		for(var/obj/machinery/holopad/dialed_holopad as anything in dialed_holopads.Copy())
			if(!calling_holopad.holocall_reachable(dialed_holopad, !!connected_holopad))
				ConnectionFailure(dialed_holopad)
		if(QDELETED(src))
			return FALSE
	return ..()
