/** Finite emergency construction materials placed on the cargo platform. */
/obj/structure/closet/crate/stationtrauma_salvage
	name = "аварийный запас материалов"

/obj/structure/closet/crate/stationtrauma_salvage/PopulateContents()
	new /obj/item/stack/sheet/iron(src, 15)
	new /obj/item/stack/sheet/glass(src, 5)
	new /obj/item/stack/cable_coil(src, 20)

/** Starting EVA and mining equipment. */
/obj/structure/closet/crate/stationtrauma_space_eva
	name = "экспедиционное снаряжение"

/obj/structure/closet/crate/stationtrauma_space_eva/PopulateContents()
	for(var/index in 1 to 2)
		new /obj/item/clothing/suit/space(src)
		new /obj/item/clothing/head/helmet/space(src)
		new /obj/item/tank/jetpack/void(src)
		new /obj/item/clothing/mask/breath(src)
		new /obj/item/pickaxe(src)
		new /obj/item/storage/bag/ore(src)
		new /obj/item/stationtrauma_distress_beacon(src)
	new /obj/item/pinpointer/stationtrauma_docking(src)

GLOBAL_LIST_EMPTY(stationtrauma_distress_beacons)

/**
 * Personal distress transmitter for crew lost overboard.
 *
 * While on, the destination its holder was swept to reads on ship sensors as an SOS with the callsign, and a ship may stop there at once.
 */
/obj/item/stationtrauma_distress_beacon
	name = "аварийный маячок"
	desc = "Личный передатчик сигнала бедствия. Включённый, он виден на навигационных сенсорах кораблей поблизости как SOS с позывным."
	icon = 'icons/obj/devices/tracker.dmi'
	icon_state = "beacon-off"
	inhand_icon_state = "beacon"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	/// Whether the beacon is transmitting.
	var/active = FALSE
	/// Transmitted callsign; set on first activation or by the owner.
	var/callsign

/obj/item/stationtrauma_distress_beacon/Initialize(mapload)
	. = ..()
	GLOB.stationtrauma_distress_beacons += src

/obj/item/stationtrauma_distress_beacon/Destroy()
	GLOB.stationtrauma_distress_beacons -= src
	return ..()

/obj/item/stationtrauma_distress_beacon/update_icon_state()
	icon_state = active ? "beacon" : "beacon-off"
	return ..()

/obj/item/stationtrauma_distress_beacon/examine(mob/user)
	. = ..()
	. += span_notice("Сигнал [active ? "передаётся" : "выключен"]. Позывной: [callsign || "не задан"].")
	. += span_notice("Alt-клик — сменить позывной.")

/obj/item/stationtrauma_distress_beacon/attack_self(mob/user)
	. = ..()
	if(.)
		return
	if(!callsign)
		callsign = default_callsign(user)
	active = !active
	update_appearance(UPDATE_ICON_STATE)
	stationtrauma_distress_changed(get_turf(src))
	balloon_alert(user, active ? "сигнал включён" : "сигнал выключен")
	playsound(src, 'sound/machines/beep/twobeep.ogg', 30, TRUE)
	return TRUE

/obj/item/stationtrauma_distress_beacon/click_alt(mob/user)
	var/entered = tgui_input_text(user, "Позывной, который увидят на сенсорах", "Аварийный маячок", callsign || default_callsign(user), max_length = 32)
	// The prompt yields: the beacon may have changed hands meanwhile.
	if(isnull(entered) || QDELETED(src) || !user.can_perform_action(src))
		return CLICK_ACTION_BLOCKING
	callsign = trim(entered) || default_callsign(user)
	user.log_message("set distress beacon callsign to \"[callsign]\"", LOG_GAME)
	balloon_alert(user, "позывной задан")
	return CLICK_ACTION_SUCCESS

/** Name and assignment from the holder's ID. */
/obj/item/stationtrauma_distress_beacon/proc/default_callsign(mob/user)
	var/mob/living/holder = user
	var/obj/item/card/id/card = isliving(holder) ? holder.get_idcard(hand_first = TRUE) : null
	return card?.registered_name ? "[card.registered_name], [card.assignment || "без должности"]" : (user?.real_name || "неизвестный")

/** Chart or withdraw the distress destination of a loss overboard on the beacon's level. */
/proc/stationtrauma_distress_changed(turf/tile)
	for(var/datum/stationtrauma_lost_space/loss as anything in GLOB.stationtrauma_lost_spaces)
		if(loss.level && loss.level.z_value == tile?.z)
			loss.refresh_signal()

/** Callsigns of transmitting beacons on a level. */
/proc/stationtrauma_distress_callsigns(z)
	. = list()
	for(var/obj/item/stationtrauma_distress_beacon/beacon as anything in GLOB.stationtrauma_distress_beacons)
		var/turf/tile = get_turf(beacon)
		if(beacon.active && tile?.z == z)
			. += beacon.callsign

/**
 * Handheld guide to the airlock of the destination a vessel holds through a remote seam.
 *
 * Aboard, it points at the seam exit level with the berth, since the seam keeps the crossing row; beyond the seam it points
 * at the entrance airlock itself, or at the berth when the destination has none.
 */
/obj/item/pinpointer/stationtrauma_docking
	name = "стыковочный пеленгатор"
	desc = "Указывает путь к входному шлюзу объекта, у которого стоит корабль. На борту ведёт к точке выхода напротив шлюза."
	/// Turf to head for on the holder's level; null without a seam-docked destination there.
	var/turf/beacon

/obj/item/pinpointer/stationtrauma_docking/Destroy()
	beacon = null
	return ..()

/obj/item/pinpointer/stationtrauma_docking/scan_for_target()
	beacon = stationtrauma_docking_beacon(get_turf(src))

/// The turf on `here`'s level leading to the airlock of the destination a vessel holds through a remote seam, or null.
/proc/stationtrauma_docking_beacon(turf/here)
	if(!here)
		return null
	for(var/sector_id in SSstationtrauma_space_voyage.sectors)
		var/datum/stationtrauma_overmap_sector/sector = SSstationtrauma_space_voyage.sectors[sector_id]
		for(var/ship_id in sector.ships)
			var/datum/stationtrauma_overmap/space/navigation = sector.ships[ship_id]
			var/datum/stationtrauma_overmap_site/space/site = navigation?.docked
			if(!istype(navigation) || !istype(site) || site.landing || site.physical_docking || QDELETED(site.berth) || !navigation.connection.active)
				continue
			if(here.z == site.berth.z)
				return site.entrance || get_turf(site.berth)
			if(here.z != navigation.vessel.z)
				continue
			var/datum/stationtrauma_map_connection/connection = navigation.connection
			var/edge = connection.get_ship_edge(navigation.vessel.return_coords(), 1, connection.direction)
			if(isnull(edge))
				continue
			return connection.direction & (EAST|WEST) ? locate(edge, site.berth.y, here.z) : locate(site.berth.x, edge, here.z)
	return null

/obj/item/pinpointer/stationtrauma_docking/update_overlays()
	. = ..()
	var/turf/here = get_turf(src)
	if(!active || !beacon || here?.z != beacon.z)
		return
	// The base pinpointer tracks movables only; a turf beacon replaces its idle overlay.
	. -= "pinonnull"
	. += get_direction_icon(here, beacon)
