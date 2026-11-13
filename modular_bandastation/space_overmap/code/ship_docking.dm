/datum/stationtrauma_overmap/space
	/// Shared voluntary docking link; null outside a reserved or connected pair.
	var/datum/stationtrauma_ship_docking/ship_docking
	/// Weak sender reference for an incoming voluntary docking request.
	var/datum/weakref/docking_request
	/// world.time expiry of the pending request.
	var/docking_request_until = 0
	/// Sender control revision captured when the request was issued.
	var/docking_request_revision = 0
	/// Monotonic response token rejecting replies to superseded requests.
	var/docking_request_sequence = 0
	/// Interval between successful outgoing requests, independent of helm revisions and recipient replies.
	COOLDOWN_DECLARE(ship_docking_request_cooldown)

/** Whether this free hull may reserve or accept a voluntary ship connection. */
/datum/stationtrauma_overmap/space/proc/available_for_ship_docking()
	return !QDELETED(src) && is_operational() && !vessel.orbital_only && sector?.ships[vessel.shuttle_id] == src && !preparing && !planning && !relocating && !arrival_pending && !docked && !ship_docking && !connection.active && vessel.z == flight_berth.z

/** Check two available hulls for common sector, proximity and low relative speed. */
/datum/stationtrauma_overmap/space/proc/can_join_ship(datum/stationtrauma_overmap/space/other)
	return !QDELETED(other) && other != src && available_for_ship_docking() && other.available_for_ship_docking() && other.sector == sector \
		&& (pos_x - other.pos_x) ** 2 + (pos_y - other.pos_y) ** 2 <= (radius + other.radius + ST_NAV_APPROACH) ** 2 \
		&& (velocity_x - other.velocity_x) ** 2 + (velocity_y - other.velocity_y) ** 2 <= ST_SPACE_DOCK_SPEED ** 2

/** Crew-local contact numbers that currently pass the same check as a docking request. */
/datum/stationtrauma_overmap/space/proc/dockable_ship_contacts()
	var/list/numbers = list()
	if(!available_for_ship_docking())
		return numbers
	for(var/id in ship_observations)
		var/list/contact = ship_observations[id]
		if(world.time - contact["seen"] < ST_NAV_SHIP_MEMORY && can_join_ship(sector.ships[id]))
			numbers += contact["id"]
	return numbers

/** Return the live sender only while its request and order revision remain valid. */
/datum/stationtrauma_overmap/space/proc/incoming_ship_request()
	var/datum/stationtrauma_overmap/space/sender = docking_request?.resolve()
	if(QDELETED(sender) || world.time >= docking_request_until || sender.sector != sector || sender.control_revision != docking_request_revision)
		docking_request = null
		return null
	return sender

/** Expose a reply token and crew-local contact number, never a native hull ID. */
/datum/stationtrauma_overmap/space/proc/ship_docking_request_data()
	var/datum/stationtrauma_overmap/space/sender = incoming_ship_request()
	if(!sender)
		return null
	var/list/contact = ship_observations[sender.vessel.shuttle_id]
	return list("token" = docking_request_sequence, "contact" = contact?["id"])

/** Only an unexpired crew-local contact may address another vessel; native IDs never leave the server. */
/datum/stationtrauma_overmap/space/proc/request_ship_docking(number)
	if(!ISINTEGER(number) || number < 1 || !available_for_ship_docking())
		return FALSE
	if(!COOLDOWN_FINISHED(src, ship_docking_request_cooldown))
		status = "Запрос не передан: подождите перед повторным запросом на стыковку"
		return FALSE
	var/datum/stationtrauma_overmap/space/other
	for(var/id in ship_observations)
		var/list/contact = ship_observations[id]
		if(contact["id"] == number && world.time - contact["seen"] < ST_NAV_SHIP_MEMORY)
			other = sector.ships[id]
			break
	if(!istype(other))
		return FALSE
	advance()
	other.advance()
	if(!can_join_ship(other) || other.incoming_ship_request())
		status = "Запрос не передан: сократите дистанцию и относительную скорость либо дождитесь ответа борта"
		return FALSE
	COOLDOWN_START(src, ship_docking_request_cooldown, ST_SPACE_DOCK_REQUEST_TIME)
	other.docking_request = WEAKREF(src)
	other.docking_request_revision = control_revision
	other.docking_request_until = world.time + ST_SPACE_DOCK_REQUEST_TIME
	other.docking_request_sequence++
	other.record_ship_observation(vessel.shuttle_id, src, "signal")
	other.navigation_notice("Получен запрос на стыковку. Подтвердите или отклоните его на навигационной консоли.")
	// Audible across the bridge, so nobody has to watch the console to notice a request.
	for(var/area/ship_area as anything in other.vessel.shuttle_areas)
		for(var/obj/machinery/computer/stationtrauma_space_navigation/console in ship_area)
			playsound(console, 'sound/machines/terminal/terminal_alert.ogg', 70, extrarange = 4)
	status = "Запрос на стыковку передан"
	return TRUE

/** Consume a current reply token and reserve both hulls only after revalidation. */
/datum/stationtrauma_overmap/space/proc/respond_ship_docking(token, accepted)
	var/datum/stationtrauma_overmap/space/sender = incoming_ship_request()
	if(!sender || !ISINTEGER(token) || token != docking_request_sequence)
		return FALSE
	docking_request = null
	if(!accepted)
		sender.navigation_notice("Запрос на стыковку отклонён.")
		return TRUE
	advance()
	sender.advance()
	if(!can_join_ship(sender))
		status = "Стыковка невозможна: проверьте дистанцию и относительную скорость"
		return FALSE
	var/datum/stationtrauma_ship_docking/link = new(sender, src)
	// Both orders are committed before the first yield; leaving the console does not cancel a manoeuvre.
	INVOKE_ASYNC(link, TYPE_PROC_REF(/datum/stationtrauma_ship_docking, connect))
	return TRUE

/**
 * Outer hatches of this hull: turf mapped to the cardinal direction of the open space it leads to.
 *
 * A hatch is an airlock against space, or an open hull tile against space just outside a door, such as cargo bay doors.
 * Airlocks come first, so airlock pairings are tried before bay openings.
 */
/obj/docking_port/mobile/stationtrauma_space/proc/outer_hatches()
	var/list/airlocks = list()
	var/list/openings = list()
	for(var/turf/tile as anything in return_turfs())
		if(!shuttle_areas[get_area(tile)] || tile.density)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/outside = get_step(tile, direction)
			var/turf/inside = get_step(tile, REVERSE_DIR(direction))
			if(!isspaceturf(outside) || shuttle_areas[get_area(outside)] || !inside || !shuttle_areas[get_area(inside)])
				continue
			if(locate(/obj/machinery/door/airlock) in tile)
				airlocks[tile] = direction
			else if(locate(/obj/machinery/door) in inside)
				openings[tile] = direction
			break
	return airlocks + openings

/** Offset from this port to a hull `tile` if the port faced `facing`, following native ordered-turf rotation. */
/obj/docking_port/mobile/stationtrauma_space/proc/rotated_offset(turf/tile, facing)
	var/list/current = stationtrauma_port_rotation(dir)
	var/list/target = stationtrauma_port_rotation(facing)
	var/relative_x = tile.x - x
	var/relative_y = tile.y - y
	var/component_x = relative_x * current[1] + relative_y * current[2]
	var/component_y = relative_y * current[1] - relative_x * current[2]
	return list(component_x * target[1] - component_y * target[2], component_y * target[1] + component_x * target[2])

/** Native docking port cosine and sine for a cardinal direction. */
/proc/stationtrauma_port_rotation(direction)
	switch(direction)
		if(WEST)
			return list(0, 1)
		if(SOUTH)
			return list(-1, 0)
		if(EAST)
			return list(0, -1)
	return list(1, 0)

/**
 * Create a berth on `host`'s level holding one outer hatch of this hull directly against one of the host's, or return null.
 *
 * The hull may rotate; every moving hull tile must land on the host's open exterior vacuum away from the level border.
 * Both hulls are held by the pair while `budget` yields between candidate placements; relocation rechecks the berth.
 */
/datum/stationtrauma_overmap/space/proc/flush_berth(datum/stationtrauma_overmap/space/host, datum/stationtrauma_work_budget/budget)
	if(QDELETED(host?.exterior))
		return null
	var/list/hull = vessel.return_ordered_turfs(vessel.x, vessel.y, vessel.z, vessel.dir)
	var/list/guest_hatches = vessel.outer_hatches()
	var/list/host_hatches = host.vessel.outer_hatches()
	for(var/turf/host_hatch as anything in host_hatches)
		var/host_out = host_hatches[host_hatch]
		var/turf/meeting = get_step(host_hatch, host_out)
		var/turf/beyond = get_step(meeting, host_out)
		if(!beyond)
			continue
		for(var/turf/guest_hatch as anything in guest_hatches)
			var/turf/guest_inside = get_step(guest_hatch, REVERSE_DIR(guest_hatches[guest_hatch]))
			for(var/facing in GLOB.cardinals)
				var/list/door_offset = vessel.rotated_offset(guest_hatch, facing)
				var/list/inside_offset = vessel.rotated_offset(guest_inside, facing)
				// The guest hatch takes the meeting tile and its own interior lies farther from the host.
				if(inside_offset[1] - door_offset[1] != beyond.x - meeting.x || inside_offset[2] - door_offset[2] != beyond.y - meeting.y)
					continue
				var/turf/port_turf = locate(meeting.x - door_offset[1], meeting.y - door_offset[2], meeting.z)
				if(!port_turf)
					continue
				budget.yield()
				if(QDELETED(src) || QDELETED(host) || QDELETED(host.exterior))
					return null
				var/list/bounds = vessel.return_coords(port_turf.x, port_turf.y, facing)
				if(min(bounds[1], bounds[3]) <= TRANSITIONEDGE + 1 || max(bounds[1], bounds[3]) >= world.maxx - TRANSITIONEDGE || min(bounds[2], bounds[4]) <= TRANSITIONEDGE + 1 || max(bounds[2], bounds[4]) >= world.maxy - TRANSITIONEDGE)
					continue
				var/list/landing = vessel.return_ordered_turfs(port_turf.x, port_turf.y, port_turf.z, facing)
				if(length(landing) != length(hull))
					continue
				var/clear = TRUE
				for(var/index in 1 to length(hull))
					if(!vessel.shuttle_areas[get_area(hull[index])])
						continue
					var/turf/tile = landing[index]
					if(!isspaceturf(tile) || get_area(tile) != host.exterior)
						clear = FALSE
						break
				if(!clear)
					continue
				var/obj/docking_port/stationary/stationtrauma_space_site/berth = new(port_turf)
				berth.name = "Стыковочный узел"
				berth.width = vessel.width
				berth.height = vessel.height
				berth.dwidth = vessel.dwidth
				berth.dheight = vessel.dheight
				berth.setDir(facing)
				if(vessel.check_dock(berth, TRUE))
					return berth
				qdel(berth, force = TRUE)
	return null

/** A reserved pair of hulls joined hatch against hatch on the second hull's level, or through one shared seam between their levels. */
/datum/stationtrauma_ship_docking
	/// First reserved navigation instance; cleared when the pair is destroyed.
	var/datum/stationtrauma_overmap/space/first
	/// Second reserved navigation instance; cleared when the pair is destroyed.
	var/datum/stationtrauma_overmap/space/second
	/// Physical seam used for traversal between hull and destination; its gates show the far side.
	var/datum/stationtrauma_map_connection/connection
	/// Owned temporary berth: the first hull's flush berth on the second's level, or the seam anchor beside the second hull.
	var/obj/docking_port/stationary/anchor
	/// Whether the first hull physically moved beside the second, hatch against hatch, instead of using a remote seam.
	var/flush = FALSE
	/// Physical position captured before yielding connection preparation.
	var/turf/first_origin
	/// Peer physical position captured before yielding connection preparation.
	var/turf/second_origin
	/// First helm order revision captured at pair reservation.
	var/first_revision
	/// Peer helm order revision captured at pair reservation.
	var/second_revision
	/// Whether a safe cooperative disconnect has started.
	var/closing = FALSE

/datum/stationtrauma_ship_docking/New(datum/stationtrauma_overmap/space/a, datum/stationtrauma_overmap/space/b)
	first = a
	second = b
	connection = a.connection
	a.ship_docking = b.ship_docking = src
	a.stop("Стыковочный манёвр")
	b.stop("Стыковочный манёвр")
	a.clear_encounters()
	b.clear_encounters()
	a.preparing = b.preparing = TRUE
	a.docking_request = b.docking_request = null
	a.selected_destination = b.selected_destination = null
	a.prepared_site = b.prepared_site = null
	first_revision = a.control_revision
	second_revision = b.control_revision
	first_origin = get_turf(a.vessel)
	second_origin = get_turf(b.vessel)
	return ..()

/datum/stationtrauma_ship_docking/Destroy()
	if(!QDELETED(connection))
		connection.disconnect()
	for(var/datum/stationtrauma_overmap/space/map as anything in list(first, second))
		if(!QDELETED(map) && map.ship_docking == src)
			if(closing && map.approach_departing)
				map.end_approach()
			map.ship_docking = null
			map.preparing = FALSE
			map.status = closing ? "Соединение разомкнуто" : "Стыковка прервана"
			map.refresh_engine_audio()
	// An interrupted flush pair must not strand the first hull on its peer's level.
	if(flush && !QDELETED(first) && !QDELETED(first.vessel) && first.vessel.z != first.flight_berth?.z)
		INVOKE_ASYNC(first, TYPE_PROC_REF(/datum/stationtrauma_overmap/space, relocate), first.flight_berth)
	if(anchor)
		qdel(anchor, force = TRUE)
		anchor = null
	first = second = null
	first_origin = second_origin = null
	connection = null
	return ..()

/** Revalidate both reservations, native locations and pilot orders before publishing the prepared seam. */
/datum/stationtrauma_ship_docking/proc/current()
	return !closing && !QDELETED(first) && !QDELETED(second) && first.is_operational() && second.is_operational() \
		&& first.ship_docking == src && second.ship_docking == src && first.sector == second.sector \
		&& first.control_revision == first_revision && second.control_revision == second_revision \
		&& get_turf(first.vessel) == first_origin && get_turf(second.vessel) == second_origin

/** Hold the pair through a manoeuvre; fails as soon as the pair is gone or `still_valid` does. */
/datum/stationtrauma_ship_docking/proc/hold(datum/callback/still_valid, duration = ST_SPACE_MOORING_TIME)
	var/started = world.time
	while(world.time - started < duration)
		sleep(1 SECONDS)
		if(QDELETED(src) || !still_valid.Invoke())
			return FALSE
	return TRUE

/**
 * Join the reserved hulls after the mooring manoeuvre, rechecking both.
 *
 * The first hull moves beside the second, outer hatch against outer hatch, when such a pairing fits in open space;
 * otherwise a remote seam is built cooperatively.
 */
/datum/stationtrauma_ship_docking/proc/connect()
	first.status = second.status = "Стыковочный манёвр: сближение шлюзов"
	if(!hold(CALLBACK(src, PROC_REF(current))))
		if(!QDELETED(src))
			qdel(src)
		return FALSE
	var/ready = FALSE
	var/datum/stationtrauma_work_budget/budget = new
	if(current())
		anchor = first.flush_berth(second, budget)
		if(QDELETED(src))
			if(anchor)
				qdel(anchor, force = TRUE)
			return FALSE
		if(anchor && current())
			flush = first.relocate(anchor)
			if(QDELETED(src))
				return FALSE
			if(flush && !QDELETED(anchor) && first.vessel.get_docked() == anchor)
				ready = TRUE
				// A committed native arrival retains the pair even if an engine stop changed the helm order.
				first_origin = get_turf(first.vessel)
				first_revision = first.control_revision
				second_revision = second.control_revision
			else
				qdel(anchor, force = TRUE)
				anchor = null
	if(!flush && current())
		var/list/bounds = second.vessel.return_coords()
		var/horizontal = !!(connection.direction & (EAST|WEST))
		var/positive = connection.direction == NORTH || connection.direction == EAST
		var/low = horizontal ? min(bounds[1], bounds[3]) : min(bounds[2], bounds[4])
		var/high = horizontal ? max(bounds[1], bounds[3]) : max(bounds[2], bounds[4])
		var/edge = positive ? low - 1 : high + 1
		var/turf/edge_tile = locate(horizontal ? edge : second.vessel.x, horizontal ? second.vessel.y : edge, second.vessel.z)
		if(isspaceturf(edge_tile))
			anchor = new /obj/docking_port/stationary/stationtrauma_space_site(edge_tile)
			try
				ready = connection.connect(anchor, budget, FALSE, 1, 1) && connection.activate(budget, CALLBACK(src, PROC_REF(current)))
			catch(var/exception/failure)
				stack_trace("Ship docking connection failed: [failure]")
	if(QDELETED(src))
		return FALSE
	if(!ready || !current())
		qdel(src)
		return FALSE
	first.preparing = second.preparing = FALSE
	first.status = second.status = flush ? "Корабли состыкованы шлюзами" : "Корабли состыкованы; внешний переход через шлюзы"
	first.play_maneuver_audio(second.vessel)
	return TRUE

/**
 * Either pilot may release a voluntary pair after casting off; stop during cleanup cancels thrust, not the safe disconnect.
 *
 * Arguments:
 * * instant - Skip casting off, for admin repositioning
 */
/datum/stationtrauma_ship_docking/proc/release(datum/stationtrauma_overmap/space/departing, instant = FALSE)
	if(closing || !(departing in list(first, second)) || QDELETED(first) || QDELETED(second) || !(flush || connection.active) || first.preparing || second.preparing || !departing.is_operational() || !departing.vessel.engines_running || departing.engine_fraction() <= 0)
		return FALSE
	closing = TRUE
	first.preparing = second.preparing = TRUE
	var/revision = departing.control_revision
	var/datum/stationtrauma_overmap/space/peer = departing == first ? second : first
	if(!instant)
		departing.begin_approach(null, ST_SPACE_MOORING_TIME, departing = TRUE)
	departing.status = peer.status = "Расстыковка: набор тяги"
	if(!instant && !hold(CALLBACK(src, PROC_REF(releasable), departing, revision), ST_SPACE_DEPARTURE_DELAY))
		if(QDELETED(src))
			return FALSE
		closing = FALSE
		departing.end_approach()
		first.preparing = second.preparing = FALSE
		first.status = second.status = "Расстыковка прервана"
		return FALSE
	if(flush)
		// The first hull returns to its own level before either pilot may fly away.
		if(!first.relocate(first.flight_berth, CALLBACK(src, PROC_REF(commit_release), departing, revision, instant)))
			if(QDELETED(src))
				return FALSE
			closing = FALSE
			departing.end_approach()
			first.preparing = second.preparing = FALSE
			departing.status = "Расстыковка не выполнена: стоянка корабля перекрыта"
			return FALSE
	else
		if(!commit_release(departing, revision, instant))
			closing = FALSE
			departing.end_approach()
			first.preparing = second.preparing = FALSE
			return FALSE
		connection.disconnect_cooperatively(new /datum/stationtrauma_work_budget)
	if(QDELETED(src))
		return FALSE
	var/ready = releasable(departing, revision)
	if(ready && !instant)
		ready = departing.departure_flight(revision)
		if(QDELETED(src))
			return FALSE
	qdel(src)
	return ready

/** Play the release after preflight revalidation and immediately before the hull moves. */
/datum/stationtrauma_ship_docking/proc/commit_release(datum/stationtrauma_overmap/space/departing, revision, instant)
	if(QDELETED(src) || !closing || !releasable(departing, revision))
		return FALSE
	departing.status = "Расстыковка: отдача захватов"
	if(!instant)
		departing.play_departure_effects()
	return TRUE

/** Whether the departing hull may still fly away under the order that started the release. */
/datum/stationtrauma_ship_docking/proc/releasable(datum/stationtrauma_overmap/space/departing, revision)
	return !QDELETED(departing) && departing.is_operational() && departing.control_revision == revision && departing.vessel.engines_running && departing.engine_fraction() > 0
