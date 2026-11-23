#define ST_PLANET_APPROACH_MIN (14 SECONDS)
#define ST_PLANET_APPROACH_LOADED (30 SECONDS)
#define ST_PLANET_ZOOM_STEP (3 SECONDS)

/// Bridges the visual sequences to the native move. The ship can still land or leave if a picture cannot be built.
/datum/stationtrauma_planet_flight
	var/datum/stationtrauma_overmap/space/navigation
	var/datum/stationtrauma_overmap_site/space/site
	var/datum/stationtrauma_overmap_site/space/planet/planet
	var/obj/docking_port/stationary/berth
	var/datum/landing_animation/descent
	var/datum/launch_animation/launch
	var/departing
	var/failed = FALSE
	var/next_zoom = 0
	/// Nominal time for the orbital zoom. Readiness still determines the actual descent.
	var/orbit_duration
	var/list/launch_pairs
	var/launch_rotation
	var/completed = FALSE

/datum/stationtrauma_planet_flight/New(datum/stationtrauma_overmap/space/navigation, datum/stationtrauma_overmap_site/space/site, datum/stationtrauma_overmap_site/space/planet/planet, departing)
	src.navigation = navigation
	src.site = site
	src.planet = planet
	src.departing = departing
	orbit_duration = (site.loading_map || planet.loading_map || site.awaits_map()) ? ST_SPACE_LANDING_TIME : ST_PLANET_APPROACH_LOADED
	return ..()

/datum/stationtrauma_planet_flight/Destroy()
	if(!departing && !descent?.touchdown_time)
		navigation?.planet_hover?.settle_after_approach()
	if(descent)
		descent.cancel()
		descent = null
	QDEL_NULL(launch)
	launch_pairs = null
	if(departing && !completed)
		QDEL_NULL(navigation.planet_ascent)
	navigation = null
	site = null
	planet = null
	berth = null
	return ..()

/// Keep the orbital disk moving until the map and all its ground pictures are ready.
/datum/stationtrauma_planet_flight/proc/update()
	var/obj/docking_port/mobile/stationtrauma_space/ship = navigation?.vessel
	if(QDELETED(planet) || QDELETED(site) || QDELETED(ship) || site.failed || planet.failed)
		failed = TRUE
		return TRUE
	if(departing)
		if(!berth)
			berth = ship.get_docked()
			var/list/hull_turfs = landing_hull_turfs(ship)
			if(QDELETED(berth) || !length(hull_turfs))
				return TRUE
			var/bow = landing_bow_dir(ship, hull_turfs)
			QDEL_NULL(navigation.planet_ascent)
			navigation.planet_ascent = new(ship, hull_turfs, planet, bow, navigation)
			landing_jolt(hull_turfs, 'modular_bandastation/space_overmap/sound/landing/spool.ogg', 50, whole_site = TRUE)
		return !navigation.planet_ascent?.ground_jobs
	if(descent?.touchdown_time)
		return world.time >= descent.touchdown_time
	var/elapsed = world.time - navigation.approach_started
	if(world.time >= next_zoom)
		next_zoom = world.time + ST_PLANET_ZOOM_STEP
		navigation.update_planet_hover()
		var/progress = (elapsed + ST_PLANET_ZOOM_STEP) / orbit_duration
		// Nearly linear during the normal approach. Beyond the estimate, taper smoothly toward the atmosphere.
		var/extra = max(0, progress - 1)
		var/scale = 0.6 + 2.4 * min(1, progress) + 0.75 * extra / (extra + 0.3125)
		navigation.planet_hover?.approach_scale(scale, ST_PLANET_ZOOM_STEP)
	if(!descent && !site.loading_map && !planet.loading_map && !site.awaits_map())
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = site.berth
		if(istype(slot))
			var/obj/docking_port/stationary/stationtrauma_space_site/standard/port = slot.active_berth || slot.prepare_berth(ship)
			if(port?.ship == ship)
				berth = port
		else
			berth = site.berth
		if(QDELETED(berth))
			failed = TRUE
			return TRUE
		descent = new(navigation, planet, berth)
	if(!descent || descent.inside_view.ground_jobs || elapsed < ST_PLANET_APPROACH_MIN)
		navigation.approach_duration = max(navigation.approach_duration, elapsed + ST_PLANET_APPROACH_MIN + ST_PLANET_DESCENT_TIME)
		return FALSE
	navigation.approach_duration = elapsed + ST_PLANET_DESCENT_TIME
	descent.start(ST_PLANET_DESCENT_TIME, navigation.take_planet_hover())
	return FALSE

/// The native preflight has committed. Remove the descent picture from the crew's view or photograph their hull before it leaves.
/datum/stationtrauma_planet_flight/proc/before_move(obj/docking_port/stationary/target)
	if(!departing)
		if(target == berth)
			descent?.freeze()
		return
	if(target != navigation.flight_berth || !navigation.planet_ascent || launch)
		return
	launch_pairs = landing_hull_pairs(navigation.vessel, target)
	launch_rotation = -landing_rotation(navigation.vessel, target)
	launch = new(launch_pairs[1], navigation.vessel)

/// The real ship has moved and the planet turfs it stood on are now exposed.
/datum/stationtrauma_planet_flight/proc/moved(obj/docking_port/stationary/target)
	var/obj/docking_port/mobile/stationtrauma_space/ship = navigation.vessel
	if(!departing)
		if(target != berth || !descent)
			return
		var/list/arrived_hull = landing_hull_turfs(ship)
		landing_touchdown(arrived_hull, descent.hull_turfs, descent)
		descent.landed()
		descent = null
		return
	if(completed || target != navigation.flight_berth || !navigation.planet_ascent || !launch_pairs)
		return
	completed = TRUE
	navigation.approach_duration = world.time - navigation.approach_started + ST_PLANET_ASCENT_LENGTH
	navigation.planet_ascent.lift_off(launch_pairs[2], launch_pairs[1], launch_rotation)
	launch?.lift_off(launch_pairs[2], launch_pairs[1], navigation.planet_ascent)
	launch = null
	launch_pairs = null

/// Turfs of the physical hull, in native docking order.
/proc/landing_hull_turfs(obj/docking_port/mobile/stationtrauma_space/ship)
	. = list()
	for(var/turf/tile as anything in ship.return_ordered_turfs(ship.x, ship.y, ship.z, ship.dir))
		if(tile && ship.shuttle_areas[tile.loc] && ship.has_docking_layer(tile))
			. += tile

/datum/stationtrauma_overmap/space
	var/datum/landing_view/ascent/planet_ascent
	var/datum/landing_view/hover/planet_hover

/// The vessel has its own physical flight level. The renderer follows the selected world on the overmap.
/datum/stationtrauma_overmap/space/proc/planet_hover_site()
	if(QDELETED(vessel) || QDELETED(flight_berth) || vessel.z != flight_berth.z || vessel.get_docked() != flight_berth)
		return null
	var/datum/stationtrauma_overmap_site/space/planet/planet = parallax_site()
	return istype(planet) ? planet : null

/datum/stationtrauma_overmap/space/proc/update_planet_hover(arriving = TRUE)
	if(!planet_ascent?.liftoff && !planet_flight?.descent?.touchdown_time)
		var/datum/stationtrauma_overmap_site/space/planet/planet = planet_hover_site()
		if(planet && planet_hover?.site == planet && get_turf(vessel) == planet_hover.port_turf)
			return
		if(planet_hover)
			planet_hover.leave()
			planet_hover = null
		if(planet)
			planet_hover = new(vessel, landing_hull_turfs(vessel), planet, src, arriving)

/// Give a descent the same apparent size as the disk it replaces.
/datum/stationtrauma_overmap/space/proc/take_planet_hover()
	if(QDELETED(planet_hover))
		return null
	. = planet_hover.size?.at(world.time)
	QDEL_NULL(planet_hover)

#undef ST_PLANET_APPROACH_MIN
#undef ST_PLANET_APPROACH_LOADED
#undef ST_PLANET_ZOOM_STEP
