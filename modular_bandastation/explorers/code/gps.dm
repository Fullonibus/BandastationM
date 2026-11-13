/// Corps GPS: besides other signals it bears on the object the ship holds and on the ship itself.
/obj/item/gps/expedition
	name = "полевой GPS"
	desc = "GPS экспедиционного корпуса. Кроме обычных сигналов показывает направление к объекту, у которого стоит корабль, и к самому кораблю."
	icon_state = "gps-m"
	gpstag = "EXP0"

/obj/item/gps/expedition/add_gps_component()
	AddComponent(/datum/component/gps/item/expedition, gpstag, tracking_on, overlay_state = overlay_icon, debug = debug_mode)

/datum/component/gps/item/expedition

/datum/component/gps/item/expedition/ui_data(mob/user)
	. = ..()
	if(!tracking || emped)
		return
	var/turf/here = get_turf(parent)
	var/list/bearings = expedition_gps_bearings(here)
	for(var/label in bearings)
		var/turf/target = bearings[label]
		.["signals"] += list(list(
			"entrytag" = label,
			"coords" = "[target.x], [target.y], [target.z]",
			"dist" = get_dist(here, target),
			"degrees" = round(get_angle(here, target)),
		))

/// Label -> turf on `here`'s level for the corps bearings: the object the ship holds and each ship not boarded.
/proc/expedition_gps_bearings(turf/here)
	. = list()
	if(!here)
		return
	var/turf/object = stationtrauma_docking_beacon(here)
	if(object)
		.["Объект стоянки"] = object
	for(var/sector_id in SSstationtrauma_space_voyage.sectors)
		var/datum/stationtrauma_overmap_sector/sector = SSstationtrauma_space_voyage.sectors[sector_id]
		for(var/ship_id in sector.ships)
			var/datum/stationtrauma_overmap/space/navigation = sector.ships[ship_id]
			var/turf/ship = expedition_ship_bearing(navigation, here)
			if(ship)
				.["Корабль «[navigation.vessel.name]»"] = ship

/// The turf on `here`'s level to head for to reach the ship of `navigation`, or null: aboard, elsewhere, or out of reach.
/proc/expedition_ship_bearing(datum/stationtrauma_overmap/space/navigation, turf/here)
	var/obj/docking_port/mobile/stationtrauma_space/vessel = navigation?.vessel
	if(QDELETED(vessel) || !here || (get_area(here) in vessel.shuttle_areas))
		return null
	var/turf/ship = get_turf(vessel)
	if(ship?.z == here.z)
		return ship
	// Held through a remote seam, the ship lies beyond its berth on the object's level.
	var/datum/stationtrauma_overmap_site/space/site = navigation.docked
	if(!istype(site) || site.landing || site.physical_docking || QDELETED(site.berth) || site.berth.z != here.z || !navigation.connection?.active)
		return null
	return get_turf(site.berth)
