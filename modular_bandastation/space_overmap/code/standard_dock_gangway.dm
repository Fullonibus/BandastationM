/** A docking endpoint only opens along the axis of a commissioned passage. */
/obj/machinery/door/airlock/stationtrauma_docking
	name = "стыковочный шлюз"
	autoclose = FALSE
	air_tight = TRUE
	can_atmos_pass = ATMOS_PASS_PROC
	generate_map_preview = TRUE
	WHEN_MAP(icon = 'icons/obj/fluff/map_previews.dmi')
	WHEN_MAP(icon_state = "/obj/machinery/door/airlock/stationtrauma_docking")
	/// The passage using this endpoint, while physically moored.
	var/datum/stationtrauma_dock_gangway/gangway

/** The outward direction points from the hull toward a compatible dock. */
/obj/machinery/door/airlock/stationtrauma_docking/ship
	name = "корабельный стыковочный шлюз"

/** The outward direction points from the dock wall into the slot. */
/obj/machinery/door/airlock/stationtrauma_docking/wall
	name = "секция стыковочной стены"

/obj/machinery/door/airlock/stationtrauma_docking/wall/ui_interact(mob/user, datum/tgui/ui)
	return FALSE

/** Explain the same outward direction used by the docking validator and installation kit. */
/obj/machinery/door/airlock/stationtrauma_docking/examine(mob/user)
	. = ..()
	var/outward_direction
	switch(dir)
		if(NORTH)
			outward_direction = "на север"
		if(SOUTH)
			outward_direction = "на юг"
		if(EAST)
			outward_direction = "на восток"
		if(WEST)
			outward_direction = "на запад"
	. += span_notice("Стрелка смотрит [outward_direction], наружу к месту стыковки. Герметичное помещение должно находиться с противоположной стороны.")

/** Keep the endpoint recognizable while showing which side faces the docking passage. */
/obj/machinery/door/airlock/stationtrauma_docking/update_overlays()
	. = ..()
	. += mutable_appearance('icons/testing/turf_analysis.dmi', "red_arrow")
	if(airlock_state != AIRLOCK_CLOSED)
		return
	// The interlock owns opening. Keep its closed indicator independent of the mechanical bolts.
	if(!locked || !feedback || !hasPower() || (machine_stat & MAINT))
		. += get_airlock_overlay("lights_[AIRLOCK_LIGHT_BOLTS]", overlays_file, src, em_block = FALSE)

/obj/machinery/door/airlock/stationtrauma_docking/open(forced = DEFAULT_DOOR_CHECKS, mob/living/opener)
	if(gangway?.opening_endpoint == src)
		return ..()
	if(opener && forced == DEFAULT_DOOR_CHECKS && !QDELETED(gangway))
		return gangway.open_passage()
	return FALSE

/obj/machinery/door/airlock/stationtrauma_docking/close(forced = DEFAULT_DOOR_CHECKS, force_crush = FALSE)
	if(force_crush && gangway)
		return FALSE
	return ..()

/obj/machinery/door/airlock/stationtrauma_docking/can_atmos_pass(turf/target_turf, vertical = FALSE)
	var/heading = get_dir(src, target_turf)
	return !density && !vertical && (!heading || heading == dir || heading == REVERSE_DIR(dir))

/** A retractable floor must not claim ownership of a ship or invent air while deploying. */
/turf/open/floor/plating/stationtrauma_dock_gangway
	name = "стыковочный трап"
	initial_gas_mix = AIRLESS_ATMOS
	attachment_holes = FALSE
	upgradable = FALSE
	rcd_proof = TRUE
	/// Owns this floor and its two temporary side seals.
	var/datum/stationtrauma_dock_gangway/gangway
	/// Ground covered when a carrier transports this temporary floor onto a surface.
	var/datum/stationtrauma_dock_surface/docking_surface

/turf/open/floor/plating/stationtrauma_dock_gangway/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/forced_gravity, STANDARD_GRAVITY)

/turf/open/floor/plating/stationtrauma_dock_gangway/Destroy(force)
	RemoveElement(/datum/element/forced_gravity, STANDARD_GRAVITY)
	QDEL_NULL(docking_surface)
	return ..()

/turf/open/floor/plating/stationtrauma_dock_gangway/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/stack/tile))
		return ITEM_INTERACT_BLOCKING
	return ..()

/turf/open/floor/plating/stationtrauma_dock_gangway/zAirIn(direction, turf/source)
	return FALSE

/turf/open/floor/plating/stationtrauma_dock_gangway/zAirOut(direction, turf/source)
	return FALSE

/turf/open/floor/plating/stationtrauma_dock_gangway/zPassIn(direction)
	return FALSE

/turf/open/floor/plating/stationtrauma_dock_gangway/zPassOut(direction)
	return FALSE

/** Temporary border wall using the native window collision and atmos behavior. */
/obj/structure/window/reinforced/stationtrauma_dock_side
	name = "борт стыковочного трапа"

/** The dock uses the RCD animation without taking input or blocking passage. */
/obj/effect/constructing_effect/stationtrauma_gangway
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	obj_flags = NONE

/obj/docking_port/stationary/stationtrauma_space_site/standard
	/// All passages on this berth belong to the current departure attempt.
	var/retraction_prepared = FALSE

/** Close and animate all passages together before authorizing any of them to fold. */
/obj/docking_port/stationary/stationtrauma_space_site/standard/proc/prepare_retraction(instant)
	if(retraction_prepared || !length(gangways))
		return FALSE
	var/list/attempt = list("pending" = length(gangways))
	for(var/datum/stationtrauma_dock_gangway/gangway as anything in gangways)
		if(QDELETED(gangway) || gangway.busy || (gangway in attempt))
			return FALSE
		attempt[gangway] = FALSE
	// The typed loop selects gangways from the snapshot and skips the pending count.
	for(var/datum/stationtrauma_dock_gangway/gangway in attempt)
		INVOKE_ASYNC(gangway, TYPE_PROC_REF(/datum/stationtrauma_dock_gangway, prepare_group_retraction), instant, attempt)
	UNTIL(!attempt["pending"])
	attempt -= "pending"
	var/ready = !QDELETED(src) && length(gangways) == length(attempt)
	for(var/datum/stationtrauma_dock_gangway/gangway as anything in attempt)
		if(!attempt[gangway] || QDELETED(gangway) || !(gangway in gangways) || !gangway.can_fold_for_departure())
			ready = FALSE
			break
	if(!ready)
		for(var/datum/stationtrauma_dock_gangway/gangway as anything in attempt)
			if(attempt[gangway] && !QDELETED(gangway))
				gangway.cancel_retraction()
		return FALSE
	retraction_prepared = TRUE
	return TRUE

/** Validate every interlock before removing the temporary passage. */
/obj/docking_port/stationary/stationtrauma_space_site/standard/proc/fold_for_departure()
	if(!retraction_prepared)
		return FALSE
	for(var/datum/stationtrauma_dock_gangway/gangway as anything in gangways)
		if(QDELETED(gangway) || !gangway.can_fold_for_departure())
			return FALSE
	for(var/datum/stationtrauma_dock_gangway/gangway as anything in gangways)
		gangway.fold_for_departure()
	return TRUE

/** Revalidate and release all interlocks in the native movement commit. */
/obj/docking_port/stationary/stationtrauma_space_site/standard/proc/finish_retraction()
	if(!fold_for_departure())
		return FALSE
	retraction_prepared = FALSE
	for(var/datum/stationtrauma_dock_gangway/gangway as anything in gangways)
		gangway.finish_retraction()
	return TRUE

/** Restore all passages held by a cancelled departure. */
/obj/docking_port/stationary/stationtrauma_space_site/standard/proc/cancel_retraction()
	if(!retraction_prepared)
		return
	retraction_prepared = FALSE
	for(var/datum/stationtrauma_dock_gangway/gangway as anything in gangways)
		if(!QDELETED(gangway))
			gangway.cancel_retraction()

/** Owns a straight physical passage and the interlock between its two endpoints. */
/datum/stationtrauma_dock_gangway
	/// Mobile endpoint at the far end of the floor strip.
	var/obj/machinery/door/airlock/stationtrauma_docking/ship/ship
	/// Fixed endpoint serving the strip.
	var/obj/machinery/door/airlock/stationtrauma_docking/wall/wall
	/// Passage floors ordered from wall to ship; existing ground is reused.
	var/list/turf/open/floor/floors = list()
	/// Side walls on the temporary floors.
	var/list/obj/structure/window/reinforced/stationtrauma_dock_side/seals = list()
	/// Bridge cells exposed during the departure pause, retained until the move commits.
	var/list/folded_path
	/// Temporary cells must redeploy over their original substrate if departure is cancelled.
	var/list/folded_temporary
	/// Only this endpoint may open during the current operation.
	var/obj/machinery/door/airlock/stationtrauma_docking/opening_endpoint
	/// An endpoint is currently animating as part of an operation.
	var/busy = FALSE
	/// A participant in this passage moved, changed direction, or was replaced.
	var/breached = FALSE
	/// Changes that invalidate a fitted doorway or side seal.
	var/static/list/watched_signals = list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED, COMSIG_ATOM_DIR_CHANGE, COMSIG_MOVABLE_SET_ANCHORED)

/datum/stationtrauma_dock_gangway/Destroy()
	remove_passage()
	return ..()

/** Native carrying replaces floors and moves both endpoints as one assembly. Deletion stays watched. */
/datum/stationtrauma_dock_gangway/proc/begin_carrier_move()
	busy = TRUE
	var/list/movement_signals = watched_signals - list(COMSIG_QDELETING)
	for(var/atom/movable/part as anything in seals + list(ship, wall))
		UnregisterSignal(part, movement_signals)
	for(var/turf/tile as anything in floors)
		UnregisterSignal(tile, COMSIG_TURF_CHANGE)

/** Resume breach detection only after native floor scraping and rotation are complete. */
/datum/stationtrauma_dock_gangway/proc/finish_carrier_move()
	var/list/movement_signals = watched_signals - list(COMSIG_QDELETING)
	for(var/atom/movable/part as anything in seals + list(ship, wall))
		if(!QDELETED(part))
			RegisterSignals(part, movement_signals, PROC_REF(on_breach))
	for(var/turf/tile as anything in floors)
		RegisterSignal(tile, COMSIG_TURF_CHANGE, PROC_REF(on_breach))
	busy = FALSE
	if(breached)
		INVOKE_ASYNC(src, PROC_REF(seal_breach))

/** Install the airless corridor only after the actual hull and port are in position. */
/datum/stationtrauma_dock_gangway/proc/deploy(obj/machinery/door/airlock/stationtrauma_docking/ship/ship_endpoint, obj/machinery/door/airlock/stationtrauma_docking/wall/wall_endpoint, list/path, direction)
	if(ship || wall || QDELETED(ship_endpoint) || QDELETED(wall_endpoint) || ship_endpoint.gangway || wall_endpoint.gangway)
		return FALSE
	if(!path_available(ship_endpoint, wall_endpoint, path, direction))
		return FALSE
	ship = ship_endpoint
	wall = wall_endpoint
	ship.gangway = wall.gangway = src
	RegisterSignals(ship, watched_signals, PROC_REF(on_breach))
	RegisterSignals(wall, watched_signals, PROC_REF(on_breach))
	if(!install_floors(path, direction))
		remove_passage()
		return FALSE
	return TRUE

/datum/stationtrauma_dock_gangway/proc/path_available(obj/machinery/door/airlock/stationtrauma_docking/ship/ship_endpoint, obj/machinery/door/airlock/stationtrauma_docking/wall/wall_endpoint, list/path, direction, restoring = FALSE, list/temporary)
	if(QDELETED(ship_endpoint) || QDELETED(wall_endpoint))
		return FALSE
	if(!(direction in GLOB.cardinals) || wall_endpoint.dir != direction || ship_endpoint.dir != REVERSE_DIR(direction))
		return FALSE
	if(!ship_endpoint.density || ship_endpoint.operating || !wall_endpoint.density || wall_endpoint.operating)
		return FALSE
	var/turf/cursor = get_turf(wall_endpoint)
	var/datum/stationtrauma_overmap/space/host = stationtrauma_carrier_at(wall_endpoint)
	for(var/turf/tile as anything in path)
		if(get_step(cursor, direction) != tile || !stationtrauma_standard_dock_surface(tile) || (!restoring && !clear_tile(tile)))
			return FALSE
		var/obj/docking_port/mobile/owner = SSshuttle.get_containing_shuttle(tile)
		if((owner && owner != host?.vessel) || (host && isfloorturf(tile) && owner != host.vessel && !(restoring && temporary?[tile])))
			return FALSE
		if(temporary?[tile] && isfloorturf(tile) && (islist(tile.baseturfs) ? length(tile.baseturfs) : 1) >= 10)
			return FALSE
		cursor = tile
	return get_step(cursor, direction) == get_turf(ship_endpoint)

/datum/stationtrauma_dock_gangway/proc/install_floors(list/path, direction, list/temporary)
	for(var/turf/tile as anything in path)
		var/turf/open/floor/floor = tile
		if(isspaceturf(tile) || temporary?[tile])
			var/datum/stationtrauma_dock_surface/surface
			if(isfloorturf(tile))
				surface = new(tile)
				surface.conceal(tile)
			var/turf/open/floor/plating/stationtrauma_dock_gangway/temporary_floor = tile.place_on_top(/turf/open/floor/plating/stationtrauma_dock_gangway, CHANGETURF_NO_AREA_CHANGE | CHANGETURF_IGNORE_AIR)
			if(!istype(temporary_floor))
				surface?.restore(tile)
				qdel(surface)
				return FALSE
			temporary_floor.gangway = src
			temporary_floor.docking_surface = surface
			var/area/original_area = temporary?[tile]
			if(!QDELETED(original_area) && get_area(temporary_floor) != original_area)
				temporary_floor.change_area(get_area(temporary_floor), original_area)
			floor = temporary_floor
		if(!isfloorturf(floor))
			return FALSE
		floors += floor
		RegisterSignal(floor, COMSIG_TURF_CHANGE, PROC_REF(on_breach))
		seals += new /obj/structure/window/reinforced/stationtrauma_dock_side(floor, turn(direction, 90))
		seals += new /obj/structure/window/reinforced/stationtrauma_dock_side(floor, turn(direction, -90))
	for(var/obj/structure/window/reinforced/stationtrauma_dock_side/seal as anything in seals)
		RegisterSignals(seal, watched_signals, PROC_REF(on_breach))
	return TRUE

/** Fill the closed corridor with air drawn from its two ends and open the two interlocked doors. */
/datum/stationtrauma_dock_gangway/proc/open_passage()
	if(busy || breached || QDELETED(ship) || QDELETED(wall))
		return FALSE
	if(!ship.density && !wall.density && !ship.operating && !wall.operating)
		return TRUE
	if(ship.operating || wall.operating || (ship.density && wall.density && !equalize_pressure()))
		return FALSE
	busy = TRUE
	var/opened = TRUE
	for(var/obj/machinery/door/airlock/stationtrauma_docking/endpoint as anything in list(wall, ship))
		if(breached || QDELETED(endpoint))
			opened = FALSE
			break
		if(!endpoint.density)
			continue
		if(!endpoint_pressure_matches(endpoint))
			opened = FALSE
			break
		opening_endpoint = endpoint
		opened = endpoint.open()
		if(QDELETED(src))
			return FALSE
		if(!opened)
			break
	opening_endpoint = null
	if(!opened || breached || QDELETED(ship) || QDELETED(wall))
		close_endpoints()
		opened = FALSE
	busy = FALSE
	return opened

/datum/stationtrauma_dock_gangway/proc/endpoint_pressure_matches(obj/machinery/door/airlock/stationtrauma_docking/endpoint)
	var/turf/open/floor/inside = get_step(endpoint, REVERSE_DIR(endpoint.dir))
	var/turf/open/floor/outside = get_step(endpoint, endpoint.dir)
	if(!isfloorturf(inside) || !isfloorturf(outside) || !inside.air || !outside.air)
		return FALSE
	var/inside_pressure = inside.air.return_pressure()
	var/outside_pressure = outside.air.return_pressure()
	return abs(inside_pressure - outside_pressure) <= ONE_ATMOSPHERE * 0.1 && min(inside_pressure, outside_pressure) > HAZARD_LOW_PRESSURE && max(inside_pressure, outside_pressure) < HAZARD_HIGH_PRESSURE

/** Draw on the air already in the doorway and its adjacent compartments without spawning gas. */
/datum/stationtrauma_dock_gangway/proc/equalize_pressure()
	var/turf/open/floor/ship_inside = get_step(ship, REVERSE_DIR(ship.dir))
	var/turf/open/floor/wall_inside = get_step(wall, REVERSE_DIR(wall.dir))
	if(!isfloorturf(ship_inside) || !isfloorturf(wall_inside) || !ship_inside.air || !wall_inside.air)
		return FALSE
	var/ship_pressure = ship_inside.air.return_pressure()
	var/wall_pressure = wall_inside.air.return_pressure()
	if(abs(ship_pressure - wall_pressure) > ONE_ATMOSPHERE * 0.1 || min(ship_pressure, wall_pressure) <= HAZARD_LOW_PRESSURE || max(ship_pressure, wall_pressure) >= HAZARD_HIGH_PRESSURE)
		return FALSE
	var/list/turf/open/floor/volume_tiles = floors + list(get_turf(ship), get_turf(wall), ship_inside, wall_inside)
	var/datum/gas_mixture/total_air = new
	var/total_volume = 0
	for(var/turf/open/floor/tile as anything in volume_tiles)
		if(!isfloorturf(tile) || !tile.air)
			qdel(total_air)
			return FALSE
		total_air.merge(tile.air)
		total_volume += tile.air.volume
	total_air.volume = total_volume
	var/pressure = total_air.return_pressure()
	if(pressure <= HAZARD_LOW_PRESSURE || pressure >= HAZARD_HIGH_PRESSURE)
		qdel(total_air)
		return FALSE
	for(var/turf/open/floor/tile as anything in volume_tiles)
		tile.air.copy_from_ratio(total_air, tile.air.volume / total_volume)
		tile.air_update_turf(FALSE, FALSE)
	qdel(total_air)
	return TRUE

/** Close the doors and play the retraction animation before the native departure commits. */
/datum/stationtrauma_dock_gangway/proc/prepare_retraction(instant)
	if(QDELETED(src) || busy)
		return FALSE
	busy = TRUE
	var/closed = close_endpoints()
	if(QDELETED(src))
		return FALSE
	if(!closed)
		cancel_retraction()
		return FALSE
	if(!instant && length(floors))
		var/duration = 1.5 SECONDS
		var/list/effects = list()
		for(var/turf/open/floor/floor as anything in floors)
			effects += new /obj/effect/constructing_effect/stationtrauma_gangway(floor, duration, RCD_DECONSTRUCT)
		sleep(duration)
		QDEL_LIST(effects)
	return !QDELETED(src)

/** Report completion to the berth even if a passage fails while a door is closing. */
/datum/stationtrauma_dock_gangway/proc/prepare_group_retraction(instant, list/attempt)
	var/exception/preparation_failure
	try
		attempt[src] = prepare_retraction(instant)
	catch(var/exception/failure)
		preparation_failure = failure
	attempt["pending"]--
	if(preparation_failure)
		if(!QDELETED(src))
			cancel_retraction()
		stack_trace("Failed to prepare docking gangway retraction: [preparation_failure]")

/** Restore a folded bridge if the move was cancelled while both endpoints were still connected. */
/datum/stationtrauma_dock_gangway/proc/cancel_retraction()
	if(length(folded_path))
		var/direction = wall?.dir
		if(breached || !path_available(ship, wall, folded_path, direction, restoring = TRUE, temporary = folded_temporary) || !install_floors(folded_path, direction, folded_temporary))
			remove_floors()
			breached = TRUE
		folded_path = null
		folded_temporary = null
	busy = FALSE
	if(breached)
		INVOKE_ASYNC(src, PROC_REF(seal_breach))
	else
		INVOKE_ASYNC(src, PROC_REF(open_passage))

/** A bridge can fold only while its surviving endpoints are closed and interlocked. */
/datum/stationtrauma_dock_gangway/proc/can_fold_for_departure()
	return busy && (QDELETED(ship) || (ship.density && !ship.operating)) && (QDELETED(wall) || (wall.density && !wall.operating))

/** Remove the temporary floor after every passage in the group is ready. */
/datum/stationtrauma_dock_gangway/proc/fold_for_departure()
	if(length(floors))
		if(!breached)
			folded_path = floors.Copy()
			folded_temporary = list()
			for(var/turf/open/floor/plating/stationtrauma_dock_gangway/floor in floors)
				if(floor.gangway == src)
					folded_temporary[floor] = get_area(floor)
		playsound(floors[1], 'sound/machines/click.ogg', 50, vary = TRUE, pressure_affected = FALSE)
		remove_floors()

/** Leave the contents on their original cells and release the interlock when the ship departs. */
/datum/stationtrauma_dock_gangway/proc/finish_retraction()
	remove_passage()
	busy = FALSE

/datum/stationtrauma_dock_gangway/proc/close_endpoints()
	var/closed = TRUE
	for(var/obj/machinery/door/airlock/stationtrauma_docking/endpoint as anything in list(ship, wall))
		if(QDELETED(endpoint))
			continue
		if(endpoint.operating || (!endpoint.density && (!endpoint.safe || !clear_tile(get_turf(endpoint), endpoint) || !endpoint.close())))
			closed = FALSE
	return closed

/datum/stationtrauma_dock_gangway/proc/clear_tile(turf/tile, atom/movable/ignored)
	for(var/atom/movable/occupant in tile)
		if(occupant == ignored || (occupant in seals))
			continue
		if(occupant.density || isliving(occupant) || (isobj(occupant) && !iseffect(occupant)))
			return FALSE
	return TRUE

/** A changed floor or seal must never authorize another opening. */
/datum/stationtrauma_dock_gangway/proc/on_breach()
	SIGNAL_HANDLER
	if(breached)
		return
	breached = TRUE
	INVOKE_ASYNC(src, PROC_REF(seal_breach))

/datum/stationtrauma_dock_gangway/proc/seal_breach()
	if(busy || QDELETED(src))
		return
	busy = TRUE
	close_endpoints()
	busy = FALSE

/datum/stationtrauma_dock_gangway/proc/remove_passage()
	opening_endpoint = null
	folded_path = null
	folded_temporary = null
	for(var/obj/machinery/door/airlock/stationtrauma_docking/endpoint as anything in list(ship, wall))
		if(!QDELETED(endpoint))
			UnregisterSignal(endpoint, watched_signals)
			if(endpoint.gangway == src)
				endpoint.gangway = null
	ship = null
	wall = null
	remove_floors()

/datum/stationtrauma_dock_gangway/proc/remove_floors()
	for(var/obj/structure/window/reinforced/stationtrauma_dock_side/seal as anything in seals)
		if(!QDELETED(seal))
			UnregisterSignal(seal, watched_signals)
			qdel(seal)
	seals.Cut()
	for(var/turf/tile as anything in floors)
		UnregisterSignal(tile, COMSIG_TURF_CHANGE)
		var/turf/open/floor/plating/stationtrauma_dock_gangway/floor = tile
		if(istype(floor) && floor.gangway == src)
			floor.gangway = null
			var/datum/stationtrauma_dock_surface/surface = floor.docking_surface
			floor.docking_surface = null
			var/turf/revealed = floor.ScrapeAway(flags = CHANGETURF_NO_AREA_CHANGE)
			if(surface)
				if(surface.surface_area && get_area(revealed) != surface.surface_area)
					revealed.change_area(get_area(revealed), surface.surface_area)
				surface.restore(revealed)
				qdel(surface)
	floors.Cut()
