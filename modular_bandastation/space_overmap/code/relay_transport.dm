/// A powered deployment device installed on the relay's physical hull.
/obj/machinery/relay_transport
	icon = 'modular_bandastation/space_overmap/icons/droid_relay.dmi'
	density = TRUE
	anchored = TRUE
	idle_power_usage = 100

/obj/machinery/relay_transport/bluespace
	name = "блюспейс-установка дроидов"
	desc = "Перемещает корпус дроида на заданную точку и возвращает его на корабль."
	icon_state = "transport_bluespace"

/obj/machinery/relay_transport/pod
	name = "капсульная установка дроидов"
	desc = "Отправляет корпус дроида в грузовой капсуле. Возвращает дроида на корабль через блюспейс."
	icon_state = "transport_pod"

/obj/machinery/relay_transport/wrench_act(mob/living/user, obj/item/tool)
	return default_unfasten_wrench(user, tool) == SUCCESSFUL_UNFASTEN ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING

/obj/machinery/relay_transport/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(!check_rights_for(user.client, R_ADMIN))
		return ITEM_INTERACT_BLOCKING
	var/obj/machinery/overmap_droid_relay/relay = tool.buffer
	if(istype(relay) && relay.link_device(src))
		balloon_alert(user, "установка подключена")
	else
		tool.set_buffer(src)
		balloon_alert(user, "установка сохранена в буфер")
	return ITEM_INTERACT_SUCCESS

/// Whether this device can serve its linked relay aboard the same hull.
/obj/machinery/relay_transport/proc/is_link_ready(obj/machinery/overmap_droid_relay/relay)
	return !QDELETED(src) && !QDELETED(relay) && !(machine_stat & (NOPOWER | BROKEN | MAINT)) \
		&& relay.linked_ship() && relay.valid_link(src) && (WEAKREF(src) in relay.transport_refs)

/// Find a known fixed destination in the current sector's normal arrival range without loading its map.
/obj/machinery/relay_transport/proc/target_site(obj/machinery/overmap_droid_relay/relay, site_id)
	if(!istext(site_id) || !is_link_ready(relay))
		return null
	var/obj/docking_port/mobile/stationtrauma_space/ship = relay.linked_ship()
	var/datum/stationtrauma_overmap/space/navigation = ship.overmap
	if(QDELETED(navigation) || !navigation.is_operational())
		return null
	for(var/datum/stationtrauma_overmap/space/hull = navigation; hull; hull = hull.carrier_host())
		if(hull.relocating || hull.approach_started || hull.jump_target || hull.ship_docking)
			return null
	var/datum/stationtrauma_overmap_site/space/site = navigation.sector?.sites[site_id]
	if(QDELETED(site) || site.failed || site.host || istype(site, /datum/stationtrauma_overmap_site/space/distress) \
		|| !navigation.knows_site(site) || !navigation.in_arrival_range(site))
		return null
	if(site.ruin_id || site.awaits_map() || istype(site, /datum/stationtrauma_overmap_site/space/planet) \
		|| (site.physical_docking && !QDELETED(site.berth) && is_station_level(site.berth.z)) || relay_mapped_area(site))
		return site
	return null

/// Choose a destination after the native loader finishes, then recheck the chosen tile and device.
/obj/machinery/relay_transport/proc/resolve_target(obj/machinery/overmap_droid_relay/relay, site_id, mode, turf/aimed_tile, obj/item/relay_beacon/beacon)
	if(!(mode in list("random", "aimed", "beacon")))
		return null
	var/datum/stationtrauma_overmap_site/space/site = target_site(relay, site_id)
	if(!site)
		return null
	if(site.awaits_map() && !site.loading_map)
		INVOKE_ASYNC(site, TYPE_PROC_REF(/datum/stationtrauma_overmap_site/space, load_map))
	while(site.loading_map)
		sleep(1 SECONDS)
		if(target_site(relay, site_id) != site)
			return null
	if(target_site(relay, site_id) != site || QDELETED(site.berth))
		return null

	var/turf/destination
	switch(mode)
		if("aimed")
			destination = aimed_tile
		if("beacon")
			destination = beacon?.active_turf(relay)
		if("random")
			destination = random_turf(site)
	return target_site(relay, site_id) == site && !site.loading_map && relay_drop_turf(destination) && turf_at_site(site, destination) ? destination : null

/// Synchronous admission for a physically suitable tile of the selected destination.
/obj/machinery/relay_transport/proc/target_valid(obj/machinery/overmap_droid_relay/relay, site_id, turf/destination)
	if(!relay_drop_turf(destination))
		return FALSE
	var/datum/stationtrauma_overmap_site/space/site = target_site(relay, site_id)
	return !site?.loading_map && turf_at_site(site, destination)

/// Site membership for cameras and recall, independent of range and whether a machine could land here.
/obj/machinery/relay_transport/proc/turf_at_site(datum/stationtrauma_overmap_site/space/site, turf/tile)
	if(QDELETED(site) || QDELETED(site.berth) || QDELETED(tile) || site.failed || site.host)
		return FALSE
	var/area/tile_area = get_area(tile)
	if(!tile_area || istype(tile_area, /area/shuttle))
		return FALSE
	if(site.physical_docking && is_station_level(site.berth.z))
		return is_station_level(tile.z) && tile_area == GLOB.areas_by_type[tile_area.type] && (tile_area.type in GLOB.the_station_areas)
	var/list/bounds = relay_drop_bounds(site)
	if(bounds)
		return tile.x >= bounds[MAP_MINX] && tile.x <= bounds[MAP_MAXX] && tile.y >= bounds[MAP_MINY] && tile.y <= bounds[MAP_MAXY] \
			&& tile.z >= bounds[MAP_MINZ] && tile.z <= bounds[MAP_MAXZ]
	return tile.z == site.berth.z && tile_area == relay_mapped_area(site)

/// Find random open ground inside the station's registered areas or inside a finite destination.
/obj/machinery/relay_transport/proc/random_turf(datum/stationtrauma_overmap_site/space/site)
	if(site.physical_docking && is_station_level(site.berth.z))
		var/list/station_levels = shuffle(SSmapping.levels_by_trait(ZTRAIT_STATION))
		for(var/area_type in shuffle(GLOB.the_station_areas))
			var/area/station/area = GLOB.areas_by_type[area_type]
			if(QDELETED(area) || (area.area_flags & (NOTELEPORT | LOCAL_TELEPORT)))
				continue
			for(var/level in station_levels)
				var/turf/tile = pick_relay_drop_turf(area.get_turfs_by_zlevel(level))
				if(tile)
					return tile
		return null
	var/list/bounds = relay_drop_bounds(site)
	if(bounds)
		var/surface = bounds[MAP_MAXZ]
		return pick_relay_drop_turf(block(bounds[MAP_MINX], bounds[MAP_MINY], surface, bounds[MAP_MAXX], bounds[MAP_MAXY], surface))
	var/area/mapped_site = relay_mapped_area(site)
	return mapped_site ? pick_relay_drop_turf(mapped_site.get_turfs_by_zlevel(site.berth.z)) : null

/// Registered map footprint of a generated planet or a placed ruin.
/proc/relay_drop_bounds(datum/stationtrauma_overmap_site/space/site)
	var/level = site.berth.z
	var/datum/stationtrauma_overmap_site/space/planet/planet = site
	if(istype(planet))
		var/width = planet.surface_width
		var/min_x = round((world.maxx - width) / 2) + 1
		var/min_y = round((world.maxy - width) / 2) + 1
		var/min_z = SSmapping.level_trait(level, ZTRAIT_DOWN) ? level - 1 : level
		return list(min_x, min_y, min_z, min_x + width - 1, min_y + width - 1, level)
	if(!site.ruin_id)
		return null
	for(var/turf/origin as anything in SSmapping.active_ruins)
		if(origin.z != level)
			continue
		var/datum/map_template/ruin/template = SSmapping.active_ruins[origin]
		if(template.id == site.ruin_id)
			return list(origin.x, origin.y, level, origin.x + template.width - 1, origin.y + template.height - 1, level)
	return null

/// Authored destinations with their own areas rather than a generated footprint.
/proc/relay_mapped_area(datum/stationtrauma_overmap_site/space/site)
	if(QDELETED(site.berth))
		return null
	if(site.physical_docking)
		for(var/area_type in subtypesof(/area/stationtrauma_trade_outpost))
			var/area/area = GLOB.areas_by_type[area_type]
			if(length(area?.get_turfs_by_zlevel(site.berth.z)))
				return area
		return null
	switch(site.approach_scene)
		if("cargo")
			return GLOB.areas_by_type[/area/stationtrauma_space_site/cargo]
		if("asteroids")
			return GLOB.areas_by_type[/area/stationtrauma_space_site/asteroid]
	return null

/// Pick a free tile in a known footprint without copying native area turf lists.
/proc/pick_relay_drop_turf(list/tiles)
	var/count = length(tiles)
	if(!count)
		return null
	var/offset = rand(0, count - 1)
	for(var/index in 0 to count - 1)
		var/turf/tile = tiles[(offset + index) % count + 1]
		if(relay_drop_turf(tile))
			return tile
		CHECK_TICK
		// An area can change its cached turf list while the scan yields.
		if(length(tiles) != count)
			return null
	return null

/// Common terrain and area restrictions for remote insertion, including physical capsules.
/proc/relay_drop_turf(turf/tile, atom/movable/ignore_pod, exclude_mobs = FALSE)
	if(QDELETED(tile) || !isopenturf(tile) || isspaceturf(tile) || isopenspaceturf(tile) || islava(tile) || ischasm(tile) \
		|| tile.is_transition_turf() || HAS_TRAIT(tile, TRAIT_NO_TELEPORT) || HAS_TRAIT(tile, TRAIT_AI_AVOID_TURF))
		return FALSE
	var/area/tile_area = get_area(tile)
	return tile_area && !istype(tile_area, /area/shuttle) && !(tile_area.area_flags & (NOTELEPORT | LOCAL_TELEPORT)) \
		&& !(locate(/obj/effect/pod_landingzone/relay_payload) in tile) \
		&& !tile.is_blocked_turf(exclude_mobs = exclude_mobs, ignore_atoms = ignore_pod ? list(ignore_pod) : null)

/// Dispatch one body pre-admitted by the relay to its destination.
/obj/machinery/relay_transport/proc/deploy(mob/living/basic/relay_droid/unit, turf/destination)
	return teleport_unit(unit, destination)

/// Return one live body to its carrier via the normal bluespace channel.
/obj/machinery/relay_transport/proc/recall(mob/living/basic/relay_droid/unit, turf/destination)
	return teleport_unit(unit, destination)

/// Keep the destination exact even though carried bluespace items can scatter normal teleports.
/obj/machinery/relay_transport/proc/teleport_unit(mob/living/basic/relay_droid/unit, turf/destination)
	if(QDELETED(src) || QDELETED(unit) || QDELETED(destination) || unit.stat == DEAD || unit.in_transit)
		return FALSE
	for(var/obj/item/carried as anything in unit.get_all_contents_type(/obj/item))
		if(HAS_TRAIT(carried, TRAIT_BLUESPACE_INTERFERENCE))
			to_chat(unit, span_warning("Перемещение заблокировано блюспейс-помехами."))
			return FALSE
	return do_teleport(unit, destination)

/obj/machinery/relay_transport/pod/deploy(mob/living/basic/relay_droid/unit, turf/destination)
	if(QDELETED(src) || QDELETED(unit) || unit.stat == DEAD || unit.in_transit || !relay_drop_turf(destination))
		return FALSE
	var/atom/source_location = unit.loc
	var/turf/origin = get_turf(unit)
	if(!origin)
		return FALSE
	var/obj/structure/closet/supplypod/podspawn/relay_payload/pod = new
	pod.origin = origin
	pod.ship_ref = WEAKREF(SSshuttle.get_containing_shuttle(src))
	unit.in_transit = TRUE
	if(!unit.forceMove(pod) || unit.loc != pod)
		unit.in_transit = FALSE
		qdel(pod)
		return FALSE
	var/obj/effect/pod_landingzone/relay_payload/landing_zone = new(destination, pod)
	if(QDELETED(landing_zone) || QDELETED(pod))
		if(!QDELETED(pod))
			qdel(pod)
		if(!QDELETED(unit) && !QDELETED(source_location))
			unit.forceMove(source_location)
		return FALSE
	pod.dispatched = TRUE
	return TRUE

/// Disposable cargo pod with the native descent, opening and departure animations.
/obj/structure/closet/supplypod/podspawn/relay_payload
	specialised = TRUE
	name = "транспортная капсула дроидов"
	desc = "Грузовая капсула с корпусом дроида."
	pod_flags = FIRST_SOUNDS
	/// Safe original turf used if the landing zone is lost before the capsule arrives.
	var/turf/origin
	/// Ship that dispatched the capsule, used to recover its payload even after the ship moves.
	var/datum/weakref/ship_ref
	/// The transport committed the launch and released the source chassis.
	var/dispatched = FALSE
	/// The native opening is releasing the droid on the authorized destination.
	var/delivering = FALSE

/obj/structure/closet/supplypod/podspawn/relay_payload/Initialize(mapload)
	. = ..()
	rubble_type = RUBBLE_NONE

/obj/structure/closet/supplypod/podspawn/relay_payload/open_pod(atom/movable/holder, broken = FALSE, forced = FALSE)
	if(!broken && !opened)
		if(!relay_drop_turf(get_turf(src), src, exclude_mobs = TRUE))
			qdel(src)
			return
		delivering = TRUE
	return ..()

/obj/structure/closet/supplypod/podspawn/relay_payload/Exited(atom/movable/gone, direction)
	. = ..()
	var/mob/living/basic/relay_droid/unit = gone
	if(!istype(unit))
		return
	unit.in_transit = FALSE
	if(!delivering)
		unit.site_ref = null

/obj/structure/closet/supplypod/podspawn/relay_payload/Destroy(force)
	for(var/mob/living/basic/relay_droid/unit in src)
		if(QDELETED(unit))
			continue
		var/obj/machinery/overmap_droid_relay/relay = unit.relay_ref?.resolve()
		var/obj/docking_port/mobile/stationtrauma_space/ship = ship_ref?.resolve()
		var/onboard_relay = dispatched && ship && relay?.linked_ship() == ship
		var/turf/return_turf = QDELETED(origin) ? null : origin
		if(onboard_relay)
			return_turf = get_turf(relay)
			for(var/direction in GLOB.alldirs)
				var/turf/adjacent = get_step(relay, direction)
				if(isfloorturf(adjacent) && ship.shuttle_areas[get_area(adjacent)] && !adjacent.is_blocked_turf())
					return_turf = adjacent
					break
		else if(ship && (!isfloorturf(return_turf) || !ship.is_in_shuttle_bounds(return_turf)))
			return_turf = get_turf(ship)
		if(return_turf)
			unit.forceMove(return_turf)
		if(onboard_relay && unit.loc == return_turf)
			relay.stow_unit(unit)
	origin = null
	ship_ref = null
	return ..()

/// The marker owns the cargo pod until the native landing hands it off to its opening timer.
/obj/effect/pod_landingzone/relay_payload
	/// True once the marker's animation has finished normally.
	var/landed = FALSE

/obj/effect/pod_landingzone/relay_payload/Initialize(mapload, obj/structure/closet/supplypod/podspawn/relay_payload/cargo_pod)
	. = ..()
	if(!QDELETED(cargo_pod))
		RegisterSignal(cargo_pod, COMSIG_QDELETING, PROC_REF(pod_lost))

/obj/effect/pod_landingzone/relay_payload/end_launch()
	landed = TRUE
	return ..()

/obj/effect/pod_landingzone/relay_payload/Destroy()
	if(!QDELETED(pod))
		UnregisterSignal(pod, COMSIG_QDELETING)
		if(!landed)
			qdel(pod)
	pod = null
	QDEL_NULL(helper)
	smoke_effects = null
	return ..()

/obj/effect/pod_landingzone/relay_payload/proc/pod_lost()
	SIGNAL_HANDLER
	qdel(src)

GLOBAL_LIST_EMPTY(relay_beacons)

/// Portable marker; only its bound relay can use a transmission from the ground.
/obj/item/relay_beacon
	name = "маяк высадки дроидов"
	desc = "Укажите этому маяку реле, включите его в руке и положите на место высадки."
	icon = 'modular_bandastation/space_overmap/icons/droid_relay.dmi'
	icon_state = "beacon"
	inhand_icon_state = "beacon"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	light_system = OVERLAY_LIGHT
	light_range = 1
	light_power = 0.3
	light_on = FALSE
	/// Owning relay network, if paired.
	var/datum/weakref/relay_ref
	/// Whether the transmitter is switched on.
	var/active = FALSE

/obj/item/relay_beacon/Initialize(mapload)
	. = ..()
	GLOB.relay_beacons += src

/obj/item/relay_beacon/Destroy()
	GLOB.relay_beacons -= src
	relay_ref = null
	return ..()

/// A new pairing resets the transmitter so an old placement cannot carry over to another relay.
/obj/item/relay_beacon/proc/bind(obj/machinery/overmap_droid_relay/relay)
	if(relay_ref?.resolve() == relay)
		return
	relay_ref = WEAKREF(relay)
	active = FALSE
	set_light_on(FALSE)

/// An active beacon directly on the ground is eligible only for the relay that paired it.
/obj/item/relay_beacon/proc/active_turf(obj/machinery/overmap_droid_relay/relay)
	if(!QDELETED(src) && !QDELETED(relay) && active && isturf(loc) && relay_ref?.resolve() == relay)
		return loc
	return null

/obj/item/relay_beacon/attack_self(mob/user)
	. = ..()
	if(.)
		return
	if(!relay_ref?.resolve())
		balloon_alert(user, "маяк не привязан")
		return TRUE
	active = !active
	set_light_on(active)
	balloon_alert(user, active ? "маяк включён" : "маяк выключен")
	return TRUE
