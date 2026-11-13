/datum/stationtrauma_overmap/space
	/// The original physical berth retained while the ship visits a planetary surface.
	var/obj/docking_port/stationary/stationtrauma_space_flight/flight_berth
	/// Native shuttle movement yields; navigation commands cannot interrupt a partially moved hull.
	var/relocating = FALSE
	/// world.time at which the current approach, descent, ascent or undocking began; zero outside one, which locks the helm.
	var/approach_started = 0
	/// Destination of the current approach, or the berth being left.
	var/datum/stationtrauma_overmap_site/space/approach_site
	/// Length of the current approach.
	var/approach_duration = 0
	/// Whether the current approach leaves its site instead of arriving.
	var/approach_departing = FALSE

/** Retained native berth marking the hull position on its stationary flight level. */
/obj/docking_port/stationary/stationtrauma_space_flight
	name = "Орбитальная стоянка"
	shuttle_id = "stationtrauma_space_flight"
	area_type = /area/space/stationtrauma_space_home

/** Surface berth sized for the prototype hull; actual compatibility uses native port bounds. */
/obj/docking_port/stationary/stationtrauma_space_surface
	name = "Лунная посадочная площадка"
	shuttle_id = "stationtrauma_space_surface"
	width = 21
	height = 32
	dheight = 16
	area_type = /area/stationtrauma_space_site/planet

/** Generic templates replace space instead of stacking over it; restore the vacuum below the whole hull first. */
/datum/stationtrauma_overmap/space/proc/prepare_flight_berth()
	flight_berth = new(get_turf(vessel))
	flight_berth.width = vessel.width
	flight_berth.height = vessel.height
	flight_berth.dwidth = vessel.dwidth
	flight_berth.dheight = vessel.dheight
	flight_berth.setDir(vessel.dir)
	for(var/turf/tile as anything in vessel.return_ordered_turfs(vessel.x, vessel.y, vessel.z, vessel.dir))
		if(vessel.shuttle_areas[get_area(tile)] && !isspaceturf(tile) && !isshuttleturf(tile))
			tile.insert_baseturf(2, /turf/open/space)
			tile.insert_baseturf(3, /turf/baseturf_skipover/shuttle)
	vessel.initialize_docking_layers()

/** Skip native trampling; expedition docking checks occupancy again after preflight. */
/turf/toShuttleMove(turf/oldT, move_mode, obj/docking_port/mobile/shuttle)
	if(istype(shuttle, /obj/docking_port/mobile/stationtrauma_space))
		return move_mode
	return ..()

/obj/docking_port/mobile/stationtrauma_space/initiate_docking(obj/docking_port/stationary/new_dock, movement_direction, force = FALSE, datum/callback/before_takeoff)
	if(orbital_only || !overmap?.relocating || overmap.docking_relocation \
		|| (overmap.carrier_relocation && overmap.carrier_relocation.root.vessel != src))
		return DOCKING_BLOCKED
	var/datum/stationtrauma_overmap_site/space/site = overmap.sites[overmap.selected_destination]
	// A ship pair's own anchor is the first hull's flush berth; a seam anchor never receives a hull.
	var/pair_berth = overmap.ship_docking && new_dock == overmap.ship_docking.anchor
	var/obj/docking_port/stationary/selected_berth = site?.berth
	if(istype(selected_berth, /obj/docking_port/stationary/stationtrauma_space_station/standard))
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = selected_berth
		selected_berth = slot.active_berth
	if(new_dock != overmap.flight_berth && !pair_berth && ((!site?.landing && !site?.physical_docking) || selected_berth != new_dock || !permits_docking(site)))
		return DOCKING_BLOCKED
	var/datum/stationtrauma_docking_layers/layers = new(src, new_dock, before_takeoff)
	if(!layers.build())
		qdel(layers)
		return DOCKING_BLOCKED
	overmap.docking_relocation = layers
	var/result
	var/exception/movement_failure
	try
		result = ..(new_dock, movement_direction, FALSE, CALLBACK(layers, TYPE_PROC_REF(/datum/stationtrauma_docking_layers, commit)))
	catch(var/exception/failure)
		movement_failure = failure
	if(!QDELETED(overmap))
		overmap.docking_relocation = null
	qdel(layers)
	if(movement_failure)
		throw movement_failure
	return result

/** Reused by native docking before and after its yielding preflight; never trample players or their construction. */
/obj/docking_port/mobile/stationtrauma_space/check_dock(obj/docking_port/stationary/target, silent = FALSE)
	if(orbital_only || !..())
		return FALSE
	if(overmap?.docking_relocation && !overmap.docking_relocation.validate())
		return FALSE
	if(istype(target, /obj/docking_port/stationary/stationtrauma_space_site/standard))
		var/obj/docking_port/stationary/stationtrauma_space_site/standard/berth = target
		if(!berth.route_clear(src))
			return FALSE
	var/datum/stationtrauma_carrier_movement/movement = overmap?.carrier_relocation
	if(movement?.root.vessel == src)
		return movement.validate()
	if(istype(target, /obj/docking_port/stationary/stationtrauma_space_site/standard))
		return TRUE
	// Native index order pairs each hull tile with its rotated target; bounding-box corners outside the hull never move.
	var/list/hull_turfs = return_ordered_turfs(x, y, z, dir)
	var/list/target_turfs = return_ordered_turfs(target.x, target.y, target.z, target.dir)
	if(length(target_turfs) != length(hull_turfs))
		return FALSE
	for(var/index in 1 to length(hull_turfs))
		if(!shuttle_areas[get_area(hull_turfs[index])] || !has_docking_layer(hull_turfs[index]))
			continue
		var/turf/tile = target_turfs[index]
		if(!isopenturf(tile) || tile.density)
			return FALSE
		if(SSshuttle.get_containing_shuttle(tile))
			return FALSE
		for(var/atom/movable/occupant as anything in tile)
			if(isliving(occupant) || (isobj(occupant) && !iseffect(occupant) && !istype(occupant, /obj/docking_port)))
				return FALSE
	return TRUE

/** Reuse free vacuum on this ship's flight level when an evacuation departure finds its old footprint occupied. */
/datum/stationtrauma_overmap/space/proc/position_service_berth(datum/stationtrauma_overmap_site/space/site)
	var/obj/docking_port/stationary/stationtrauma_space_flight/berth = flight_berth
	if(vessel.check_dock(berth, TRUE))
		return TRUE
	if(QDELETED(exterior))
		return FALSE
	var/flight_z = berth.z
	var/list/candidates = exterior.get_turfs_by_zlevel(flight_z)
	if(!length(candidates))
		return FALSE
	candidates = candidates.Copy()
	var/list/hull_turfs = vessel.return_ordered_turfs(vessel.x, vessel.y, vessel.z, vessel.dir)
	var/datum/stationtrauma_work_budget/budget = new
	for(var/turf/candidate as anything in candidates)
		budget.yield()
		if(QDELETED(src) || !is_operational() || QDELETED(site) || QDELETED(berth) || QDELETED(exterior) || QDELETED(connection) || flight_berth != berth || docked != site || site.docking_owner != src || vessel.get_docked() != site.berth)
			return FALSE
		// Native ordered lists collapse off-map null turfs, so reject incomplete bounds before pairing them.
		var/list/bounds = vessel.return_coords(candidate.x, candidate.y, berth.dir)
		if(min(bounds[1], bounds[3]) < 1 || max(bounds[1], bounds[3]) > world.maxx || min(bounds[2], bounds[4]) < 1 || max(bounds[2], bounds[4]) > world.maxy)
			continue
		// Keep both sides usable: this hull may be either participant in the next ship-to-ship seam.
		if(isnull(connection.get_ship_edge(bounds, 1, connection.direction)) || isnull(connection.get_ship_edge(bounds, 1, REVERSE_DIR(connection.direction))))
			continue
		var/list/target_turfs = vessel.return_ordered_turfs(candidate.x, candidate.y, flight_z, berth.dir)
		if(length(target_turfs) != length(hull_turfs))
			return FALSE
		var/clear = TRUE
		for(var/index in 1 to length(hull_turfs))
			if(!vessel.shuttle_areas[get_area(hull_turfs[index])])
				continue
			var/turf/tile = target_turfs[index]
			if(!isspaceturf(tile) || get_area(tile) != exterior)
				clear = FALSE
				break
		if(!clear)
			continue
		berth.forceMove(candidate)
		if(vessel.check_dock(berth, TRUE))
			return TRUE
	return FALSE

/** Relocate the hull and its latejoin turfs through native shuttle movement. */
/datum/stationtrauma_overmap/space/proc/relocate(obj/docking_port/stationary/target, datum/callback/before_takeoff)
	if(length(carrier_docks))
		return relocate_carrier(target, before_takeoff)
	if(!QDELETED(vessel))
		vessel.initialize_docking_layers()
	// A ship pair moves only between the first hull's own berth and its flush berth beside the peer.
	if(relocating || (ship_docking && target != flight_berth && target != ship_docking.anchor) || QDELETED(target) || QDELETED(vessel) || !vessel.check_dock(target, TRUE))
		status = "Манёвр отменён: посадочная площадка занята или перекрыта"
		return FALSE
	var/was_preparing = preparing
	var/original_direction = vessel.dir
	clear_encounters()
	preparing = TRUE
	relocating = TRUE
	var/list/crew_spawns = list()
	var/list/old_turfs = vessel.return_ordered_turfs(vessel.x, vessel.y, vessel.z, vessel.dir)
	var/list/new_turfs = vessel.return_ordered_turfs(target.x, target.y, target.z, target.dir)
	for(var/index in 1 to length(old_turfs))
		var/turf/spawn_tile = old_turfs[index]
		if((spawn_tile in SSjob.latejoin_trackers) && vessel.shuttle_areas[get_area(spawn_tile)])
			crew_spawns[spawn_tile] = new_turfs[index]
	var/result
	try
		result = vessel.initiate_docking(target, before_takeoff = before_takeoff)
	catch(var/exception/failure)
		relocating = FALSE
		preparing = was_preparing
		throw failure
	relocating = FALSE
	preparing = was_preparing
	if(QDELETED(src) || QDELETED(vessel) || QDELETED(target) || result != DOCKING_SUCCESS || vessel.get_docked() != target)
		status = "Манёвр не выполнен: корабль остался у прежней стоянки"
		return FALSE
	vessel.preferred_direction = turn(vessel.preferred_direction, dir2angle(original_direction) - dir2angle(vessel.dir))
	for(var/turf/original as anything in crew_spawns)
		SSjob.latejoin_trackers -= original
		SSjob.latejoin_trackers |= crew_spawns[original]
	// The crew sees the new level's background at once, not after the seam teardown that may still yield.
	update_parallax()
	return TRUE

/** Lock the helm and publish the manoeuvre timer for the pilot plot. */
/datum/stationtrauma_overmap/space/proc/begin_approach(datum/stationtrauma_overmap_site/space/site, duration, departing = FALSE)
	approach_started = world.time
	approach_site = site
	approach_duration = duration
	approach_departing = departing
	update_parallax()
	refresh_engine_audio()

/** Unlock the helm after an approach or departure, whatever its outcome. */
/datum/stationtrauma_overmap/space/proc/end_approach()
	approach_started = 0
	approach_site = null
	approach_duration = 0
	approach_departing = FALSE
	update_parallax()
	refresh_engine_audio()

/** Fly the remaining departure with normal physics after physical release, keeping manual orders locked until it finishes. */
/datum/stationtrauma_overmap/space/proc/departure_flight(revision)
	if(revision != control_revision || !is_operational() || !vessel.engines_running || engine_fraction() <= 0)
		return FALSE
	// Public sail() refuses a preparing or coupled hull; this phase has already committed its physical release.
	helm_engaged = TRUE
	last_update = world.time
	update_parallax()
	while(world.time - approach_started < approach_duration)
		shake_crew()
		sleep(1 SECONDS)
		if(QDELETED(src) || revision != control_revision || !is_operational() || !vessel.engines_running || engine_fraction() <= 0)
			return FALSE
		advance()
		sync_carrier()
	return revision == control_revision

/** Strength of atmospheric flight from 0 to 1: it builds through the middle half of a descent or ascent and peaks halfway. */
/datum/stationtrauma_overmap/space/proc/entry_heat()
	if(!approach_started || !approach_site?.landing || approach_duration <= 0)
		return 0
	var/progress = (world.time - approach_started) / approach_duration
	if(progress <= 0.25 || progress >= 0.75)
		return 0
	return sin(180 * (progress - 0.25) / 0.5)

/** Crew aboard feel atmospheric flight: the camera shakes and the hull groans; the shake is purely visual. */
/datum/stationtrauma_overmap/space/proc/shake_crew()
	var/heat = entry_heat()
	if(heat <= 0)
		return
	var/groan = prob(40 * heat)
	for(var/mob/crew as anything in SSmobs.clients_by_zlevel[vessel.z])
		if(!vessel.is_in_shuttle_bounds(crew))
			continue
		// At most two thirds of a tile at the peak.
		shake_camera(crew, 1 SECONDS, 0.65 * heat)
		if(groan)
			crew.playsound_local(get_turf(crew), SFX_HULL_CREAKING, 30 + 40 * heat, TRUE, pressure_affected = FALSE)

/**
 * Hold the hull on its approach, loading an uncharted destination meanwhile; returns whether docking may proceed.
 *
 * Planetary descents last longer, and crew aboard feel atmospheric entry through their middle; the shake is purely visual.
 */
/datum/stationtrauma_overmap/space/proc/approach(datum/stationtrauma_overmap_site/space/site, revision)
	var/controlled = station_clearance_required(site)
	// A rescue at a distress beacon stops alongside at once; a non-zero length keeps the console's approach clock finite.
	var/duration = length(site.distress_callsigns()) ? 1 SECONDS : site.landing ? ST_SPACE_LANDING_TIME : site.physical_docking ? ST_SPACE_MOORING_TIME : ST_SPACE_APPROACH_TIME
	begin_approach(site, duration)
	status = site.landing ? "Посадка: [site.name]" : "Сближение: [site_label(site)]"
	if(site.awaits_map() && !site.loading_map)
		INVOKE_ASYNC(site, TYPE_PROC_REF(/datum/stationtrauma_overmap_site/space, load_map))
	while(world.time - approach_started < approach_duration || site.loading_map)
		shake_crew()
		sleep(1 SECONDS)
		if(QDELETED(src) || QDELETED(site) || (controlled && site.docking_owner != src))
			return FALSE
		if(site.landing && (!is_operational() || !vessel.engines_running || engine_fraction() <= 0))
			status = "Посадка прервана: нет тяги"
			return FALSE
	if(site.failed)
		status = site.landing ? "Посадка отменена: поверхность не картографирована" : "Стыковка отменена: объект не обнаружен"
		return FALSE
	return can_dock(site, revision)
