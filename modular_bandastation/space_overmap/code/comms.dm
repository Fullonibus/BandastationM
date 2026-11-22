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
 * On an overmap map a call to another level reaches only command posts in the same sector.
 *
 * Those are hull holopads, the station bridge and the Central Command control room, which every sector reaches;
 * ruins and planets never answer. Another hull must also be a sensor contact of the calling hull.
 * The same level and the station's own decks keep the native network.
 */
/obj/machinery/holopad/holocall_reachable(obj/machinery/holopad/pad, established = FALSE)
	if(!SSmapping.current_map.space_overmap || pad.z == z || (is_station_level(z) && is_station_level(pad.z)))
		return TRUE
	if(is_centcom_level(pad.z))
		return istype(get_area(pad), /area/centcom/central_command_areas/control)
	var/obj/docking_port/mobile/stationtrauma_space/target = SSshuttle.get_containing_shuttle(pad)
	if(!istype(target) && !(is_station_level(pad.z) && istype(get_area(pad), /area/station/command/bridge)))
		return FALSE
	if(is_centcom_level(z))
		return TRUE
	var/obj/docking_port/mobile/stationtrauma_space/ship = SSshuttle.get_containing_shuttle(src)
	if(istype(ship) && istype(target))
		if(ship == target)
			return TRUE
		return ship.overmap?.ship_in_sensor_contact(target.overmap, established)
	return stationtrauma_comms_sector() == pad.stationtrauma_comms_sector()

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
 * Overmap sector this holopad transmits from.
 *
 * A hull between sectors returns itself, so it reaches only its own deck; a level outside the overmap returns null.
 */
/obj/machinery/holopad/proc/stationtrauma_comms_sector()
	var/obj/docking_port/mobile/stationtrauma_space/ship = SSshuttle.get_containing_shuttle(src)
	if(istype(ship))
		return ship.overmap?.sector || ship
	for(var/sector_id in SSstationtrauma_space_voyage.sectors)
		var/datum/stationtrauma_overmap_sector/sector = SSstationtrauma_space_voyage.sectors[sector_id]
		for(var/site_id in sector.sites)
			var/datum/stationtrauma_overmap_site/site = sector.sites[site_id]
			if(!QDELETED(site.berth) && (site.berth.z == z || is_station_level(z) && is_station_level(site.berth.z)))
				return sector
	return null

/** A call that drifted out of reach drops like a lost connection. */
/datum/holocall/Check()
	if(!QDELETED(calling_holopad))
		for(var/obj/machinery/holopad/dialed_holopad as anything in dialed_holopads.Copy())
			if(!calling_holopad.holocall_reachable(dialed_holopad, !!connected_holopad))
				ConnectionFailure(dialed_holopad)
		if(QDELETED(src))
			return FALSE
	return ..()
