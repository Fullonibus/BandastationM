/// Configure native, self-looping sector borders on the isolated unit-test z-level.
/datum/unit_test/spacepod_transition
	abstract_type = /datum/unit_test/spacepod_transition
	var/list/original_links = list()
	var/list/prepared_turfs = list()
	var/list/replaced_turfs = list()
	var/list/movement_events = list()

/datum/unit_test/spacepod_transition/Destroy()
	// Raw unit-test z-level edges are uninitialized /space/basic; dispose of gas-bearing fixtures first.
	QDEL_LIST(allocated)
	for(var/list/saved as anything in replaced_turfs)
		var/turf/location = locate(saved[1], saved[2], saved[3])
		location.ChangeTurf(saved[4], flags = CHANGETURF_IGNORE_AIR)
	for(var/turf/open/location as anything in original_links)
		var/list/saved = original_links[location]
		location.destination_x = saved[1]
		location.destination_y = saved[2]
		location.destination_z = saved[3]
	for(var/key in prepared_turfs)
		var/list/saved = prepared_turfs[key]
		var/turf/location = locate(saved[1], saved[2], saved[3])
		location.ChangeTurf(saved[4], flags = CHANGETURF_IGNORE_AIR)
	original_links = null
	prepared_turfs = null
	replaced_turfs = null
	movement_events = null
	return ..()

/datum/unit_test/spacepod_transition/proc/set_link(turf/open/source, tx, ty, tz)
	source = prepare_space_patch(source)
	prepare_space_patch(locate(tx, ty, tz))
	if(!(source in original_links))
		original_links[source] = list(source.destination_x, source.destination_y, source.destination_z)
	source.destination_x = tx
	source.destination_y = ty
	source.destination_z = tz

/// Include the whole hull, nearby crew exits and the native arrival-search detour in initialized vacuum.
/datum/unit_test/spacepod_transition/proc/prepare_space_patch(turf/center)
	var/cx = center.x
	var/cy = center.y
	var/cz = center.z
	for(var/turf/open/location in block(locate(cx - 4, cy - 4, cz), locate(cx + 4, cy + 4, cz)))
		if(location.type == /turf/open/space && location.air)
			continue
		var/key = "[location.x],[location.y],[location.z]"
		if(!prepared_turfs[key])
			prepared_turfs[key] = list(location.x, location.y, location.z, location.type)
		location.ChangeTurf(/turf/open/space, flags = CHANGETURF_IGNORE_AIR)
	return locate(cx, cy, cz)

/datum/unit_test/spacepod_transition/proc/configure_edge(direction, first, last)
	var/test_z = run_loc_floor_bottom_left.z
	for(var/parallel in first to last)
		var/turf/open/source
		switch(direction)
			if(NORTH)
				source = locate(parallel, world.maxy - TRANSITIONEDGE, test_z)
				set_link(source, parallel, TRANSITIONEDGE + 2, test_z)
			if(SOUTH)
				source = locate(parallel, TRANSITIONEDGE + 1, test_z)
				set_link(source, parallel, world.maxy - TRANSITIONEDGE - 1, test_z)
			if(EAST)
				source = locate(world.maxx - TRANSITIONEDGE, parallel, test_z)
				set_link(source, TRANSITIONEDGE + 2, parallel, test_z)
			if(WEST)
				source = locate(TRANSITIONEDGE + 1, parallel, test_z)
				set_link(source, world.maxx - TRANSITIONEDGE - 1, parallel, test_z)

/datum/unit_test/spacepod_transition/proc/start_turf(atom/movable/subject, direction)
	var/middle_x = round(world.maxx / 2)
	var/middle_y = round(world.maxy / 2)
	var/test_z = run_loc_floor_bottom_left.z
	switch(direction)
		if(NORTH)
			return locate(middle_x, world.maxy - TRANSITIONEDGE - round((subject.bound_y + subject.bound_height - 1) / ICON_SIZE_Y) - 1, test_z)
		if(SOUTH)
			return locate(middle_x, TRANSITIONEDGE + 2 - round(subject.bound_y / ICON_SIZE_Y), test_z)
		if(EAST)
			return locate(world.maxx - TRANSITIONEDGE - round((subject.bound_x + subject.bound_width - 1) / ICON_SIZE_X) - 1, middle_y, test_z)
		if(WEST)
			return locate(TRANSITIONEDGE + 2 - round(subject.bound_x / ICON_SIZE_X), middle_y, test_z)

/datum/unit_test/spacepod_transition/proc/arrival_turf(atom/movable/subject, direction)
	var/middle_x = round(world.maxx / 2)
	var/middle_y = round(world.maxy / 2)
	var/test_z = run_loc_floor_bottom_left.z
	switch(direction)
		if(NORTH)
			return locate(middle_x, TRANSITIONEDGE + 2 - round(subject.bound_y / ICON_SIZE_Y), test_z)
		if(SOUTH)
			return locate(middle_x, world.maxy - TRANSITIONEDGE - 1 - round((subject.bound_y + subject.bound_height - 1) / ICON_SIZE_Y), test_z)
		if(EAST)
			return locate(TRANSITIONEDGE + 2 - round(subject.bound_x / ICON_SIZE_X), middle_y, test_z)
		if(WEST)
			return locate(world.maxx - TRANSITIONEDGE - 1 - round((subject.bound_x + subject.bound_width - 1) / ICON_SIZE_X), middle_y, test_z)

/datum/unit_test/spacepod_transition/proc/on_moved(atom/movable/source, atom/old_loc, movement_dir, forced, list/old_locs)
	SIGNAL_HANDLER
	movement_events += list(list("from" = old_loc, "to" = source.loc, "old_locs" = old_locs?.Copy()))

/// Count dispatches while retaining the real transition validation and movement.
/turf/open/floor/iron/spacepod_transition_counter
	var/transfer_calls = 0

/turf/open/floor/iron/spacepod_transition_counter/transfer_occupant(atom/movable/occupant)
	transfer_calls++
	return ..()

/// Ordinary floor movement and turf initialization must not enter the sector-transfer path.
/datum/unit_test/spacepod_transition/ordinary_floor/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y + 1, run_loc_floor_bottom_left.z)
	var/turf/changed = get_step(origin, NORTH)
	var/original_type = changed.type
	replaced_turfs += list(list(changed.x, changed.y, changed.z, original_type))
	var/turf/open/floor/iron/spacepod_transition_counter/floor = changed.ChangeTurf(/turf/open/floor/iron/spacepod_transition_counter, flags = CHANGETURF_IGNORE_AIR)
	var/obj/mover = allocate(/obj, origin)
	floor.transfer_calls = 0
	TEST_ASSERT(mover.Move(floor, NORTH), "The ordinary floor fixture could not perform a real movement step.")
	TEST_ASSERT_EQUAL(mover.loc, floor, "Avoiding sector checks changed ordinary movement.")
	TEST_ASSERT_EQUAL(floor.transfer_calls, 0, "An ordinary floor's Entered callback dispatched sector-transfer work.")

	// ChangeTurf initializes the occupant already standing on the replacement turf.
	changed = floor.ChangeTurf(original_type, flags = CHANGETURF_IGNORE_AIR)
	floor = changed.ChangeTurf(/turf/open/floor/iron/spacepod_transition_counter, flags = CHANGETURF_IGNORE_AIR)
	TEST_ASSERT_EQUAL(mover.loc, floor, "Initializing the replacement floor moved its existing occupant.")
	TEST_ASSERT_EQUAL(floor.transfer_calls, 0, "An ordinary floor's initialization dispatched sector-transfer work.")

	var/turf/arrival = get_step(floor, EAST)
	floor.destination_x = arrival.x
	floor.destination_y = arrival.y
	floor.destination_z = arrival.z
	TEST_ASSERT(mover.forceMove(origin), "The true-border control could not return to its starting turf.")
	floor.transfer_calls = 0
	TEST_ASSERT(mover.Move(floor, NORTH), "The true-border control could not enter its configured transition.")
	TEST_ASSERT_EQUAL(floor.transfer_calls, 1, "A configured border did not dispatch exactly one native transition.")
	TEST_ASSERT_EQUAL(mover.loc, arrival, "The floor fast path also suppressed a configured border transition.")

	TEST_ASSERT(mover.forceMove(origin), "The initialized-border control could not return to its starting turf.")
	floor.destination_z = null
	TEST_ASSERT(mover.forceMove(floor), "The initialized-border control could not occupy its test turf.")
	floor.destination_z = arrival.z
	floor.transfer_calls = 0
	floor.initialize_occupant(mover)
	TEST_ASSERT_EQUAL(floor.transfer_calls, 1, "Initializing a configured border did not dispatch exactly one native transition.")
	TEST_ASSERT_EQUAL(mover.loc, arrival, "The initialization fast path also suppressed a configured border transition.")

/// The first boundary-touching step must transfer in either direction, without a second movement or timer.
/datum/unit_test/spacepod_transition/cardinals/Run()
	for(var/direction in GLOB.cardinals)
		var/parallel = round((direction & (NORTH | SOUTH) ? world.maxx : world.maxy) / 2)
		configure_edge(direction, parallel - 4, parallel + 4)
	for(var/variant in list("single", "pod", "offset_rectangle"))
		for(var/direction in GLOB.cardinals)
			var/atom/movable/subject = allocate(variant == "single" ? /obj : /obj/vehicle/sealed/spacepod/sec)
			if(variant == "offset_rectangle")
				subject.bound_width = 96
				subject.bound_height = 64
				subject.bound_x = -32
				subject.bound_y = 32
			var/turf/start = start_turf(subject, direction)
			var/turf/arrival = arrival_turf(subject, direction)
			TEST_ASSERT(subject.forceMove(start), "Could not place the [variant] border fixture for [direction].")
			var/list/original_footprint = subject.locs.Copy()
			var/obj/vehicle/sealed/spacepod/pod = istype(subject, /obj/vehicle/sealed/spacepod) ? subject : null
			var/list/crew = list()
			if(pod)
				var/turf/boarding_turf = locate(start.x + round(subject.bound_x / ICON_SIZE_X), start.y + round(subject.bound_y / ICON_SIZE_Y) - 1, start.z)
				for(var/index in 1 to 2)
					var/mob/living/carbon/human/consistent/occupant = allocate(__IMPLIED_TYPE__, boarding_turf)
					TEST_ASSERT(pod.mob_enter(occupant, silent = TRUE), "The [variant] border fixture could not board occupant [index].")
					crew += occupant
			RegisterSignal(subject, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
			movement_events.Cut()
			var/time_before = world.time
			if(pod)
				pod.flight.heading = dir2angle(direction)
				TEST_ASSERT(pod.relaymove(pod.pilot, NORTH), "The pilot could not approach the [variant] border for [direction].")
				STOP_PROCESSING(SSnewtonian_movement, pod.flight)
				pod.flight.process(0.05)
			else
				TEST_ASSERT(subject.Move(get_step(subject, direction), direction), "The ordinary one-tile control could not cross [direction].")
			TEST_ASSERT_EQUAL(subject.loc, arrival, "[variant] did not transition on its first boundary-touching step for [direction]: actual=([subject.x],[subject.y],[subject.z]), expected=([arrival.x],[arrival.y],[arrival.z]), start=([start.x],[start.y],[start.z]).")
			TEST_ASSERT_EQUAL(world.time, time_before, "The [variant] transition for [direction] yielded instead of completing synchronously.")
			TEST_ASSERT_EQUAL(length(movement_events), 2, "The [variant] transition emitted duplicate or missing movement events.")
			var/list/departure = movement_events[1]
			var/list/transfer = movement_events[2]
			TEST_ASSERT_EQUAL(departure["from"], start, "The ordinary movement event lost its original location.")
			TEST_ASSERT_EQUAL(transfer["to"], arrival, "The final movement event still describes a departed sector.")
			if(pod)
				TEST_ASSERT_EQUAL(length(departure["old_locs"]), length(original_footprint), "The physical step lost its old footprint arguments.")
				TEST_ASSERT_EQUAL(length(transfer["old_locs"]), length(original_footprint), "The sector transfer lost its old footprint arguments.")
				TEST_ASSERT_NULL(pod.drift_handler, "A sector transfer started a second movement controller.")
				TEST_ASSERT(pod.flight.velocity_x || pod.flight.velocity_y, "A sector transfer stopped the cabin's velocity.")
			for(var/turf/part as anything in subject.locs)
				TEST_ASSERT(!part.is_transition_turf(), "The arriving [variant] still overlaps a reverse transition for [direction].")
			TEST_ASSERT_EQUAL(subject.last_move, direction, "The sector transfer overwrote the requested last movement direction.")
			TEST_ASSERT_EQUAL(subject.dir, direction, "The sector transfer changed the requested facing.")
			TEST_ASSERT(!subject.currently_z_moving && !subject.moving_diagonally, "The sector transfer leaked an active movement state.")
			// Test the return boundary itself; reversing thrust now decelerates before changing velocity.
			TEST_ASSERT(subject.Move(get_step(subject, REVERSE_DIR(direction)), REVERSE_DIR(direction)), "The [variant] control could not return across the border.")
			TEST_ASSERT_EQUAL(subject.loc, start, "The [variant] return transition required another step or landed at a different location.")
			TEST_ASSERT_EQUAL(world.time, time_before, "The [variant] return transition yielded.")
			TEST_ASSERT_EQUAL(length(movement_events), 4, "The complete round trip emitted unexpected extra movement events.")
			for(var/mob/living/occupant as anything in crew)
				TEST_ASSERT(pod.is_occupant(occupant) && occupant.loc == pod, "The sector round trip detached a crew member.")
				TEST_ASSERT_EQUAL(HAS_TRAIT_FROM(occupant, TRAIT_HANDS_BLOCKED, VEHICLE_TRAIT), occupant == pod.pilot, "The sector round trip changed the crew's vehicle hand state.")
			if(pod)
				TEST_ASSERT(pod.can_control(pod.pilot), "The sector round trip revoked the pilot's controls.")
			UnregisterSignal(subject, COMSIG_MOVABLE_MOVED)
			qdel(subject)
			QDEL_LIST(crew)

/// Keep the native inward search when a far footprint tile, rather than its anchor, blocks arrival.
/datum/unit_test/spacepod_transition/arrival_safety/Run()
	var/middle = round(world.maxx / 2)
	configure_edge(NORTH, middle - 4, middle + 4)
	configure_edge(SOUTH, middle - 4, middle + 4)
	for(var/obstacle in list("dense_object", "closed_turf"))
		var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__)
		var/turf/start = start_turf(pod, NORTH)
		var/turf/arrival = arrival_turf(pod, NORTH)
		var/turf/far_corner = locate(arrival.x + 1, arrival.y + 1, arrival.z)
		var/obj/blocker
		if(obstacle == "dense_object")
			blocker = allocate(/obj/structure/closet/crate, far_corner)
		else
			replaced_turfs += list(list(far_corner.x, far_corner.y, far_corner.z, far_corner.type))
			far_corner = far_corner.ChangeTurf(/turf/closed/indestructible, flags = CHANGETURF_IGNORE_AIR)
		TEST_ASSERT(pod.forceMove(start), "Could not place the blocked-arrival fixture.")
		var/time_before = world.time
		TEST_ASSERT(pod.Move(get_step(pod, NORTH), NORTH), "The pod could not reach its source border.")
		TEST_ASSERT(pod.y < TRANSITIONEDGE + 8, "The native inward search failed to find a nearby receiving-sector arrival.")
		TEST_ASSERT(pod.loc != arrival && !(far_corner in pod.locs), "The [obstacle] on the far corner was ignored during sector arrival.")
		TEST_ASSERT_EQUAL(length(pod.locs), 4, "The blocked-arrival search clipped the pod's footprint.")
		TEST_ASSERT_EQUAL(world.time, time_before, "Searching for safe sector placement introduced a transition delay.")
		for(var/turf/part as anything in pod.locs)
			TEST_ASSERT(!part.density && !part.is_transition_turf(), "The receiving pod overlaps a wall or reciprocal boundary.")
		qdel(pod)
		qdel(blocker)
		if(obstacle == "closed_turf")
			var/list/saved = replaced_turfs[replaced_turfs.len]
			far_corner.ChangeTurf(saved[4], flags = CHANGETURF_IGNORE_AIR)
			replaced_turfs.Cut(replaced_turfs.len)

/// A corner link with both destination axes must transfer only once and leave the complete hull inside.
/datum/unit_test/spacepod_transition/corner/Run()
	var/test_z = run_loc_floor_bottom_left.z
	var/turf/open/corner = locate(world.maxx - TRANSITIONEDGE, world.maxy - TRANSITIONEDGE, test_z)
	set_link(corner, TRANSITIONEDGE + 2, TRANSITIONEDGE + 2, test_z)
	var/obj/vehicle/sealed/spacepod/pod = allocate(__IMPLIED_TYPE__, locate(corner.x - 2, corner.y - 2, test_z))
	RegisterSignal(pod, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	TEST_ASSERT(pod.Move(get_step(pod, NORTHEAST), NORTHEAST), "The pod could not cross the linked corner diagonally.")
	TEST_ASSERT_EQUAL(pod.loc, locate(TRANSITIONEDGE + 2, TRANSITIONEDGE + 2, test_z), "The corner transition did not normalize both receiving axes.")
	TEST_ASSERT_EQUAL(length(movement_events), 3, "The diagonal corner crossing transferred more than once or lost a cardinal movement event.")
	TEST_ASSERT_EQUAL(length(pod.locs), 4, "The corner crossing clipped the hull.")
	TEST_ASSERT(!pod.currently_z_moving && !pod.moving_diagonally, "The corner transition leaked a movement state.")
	for(var/turf/part as anything in pod.locs)
		TEST_ASSERT(!part.is_transition_turf(), "The corner arrival left the hull on another transition.")
	UnregisterSignal(pod, COMSIG_MOVABLE_MOVED)

/// Transfer the native pull chain once, and never independently teleport an object being pulled.
/datum/unit_test/spacepod_transition/pulling/Run()
	var/middle = round(world.maxx / 2)
	configure_edge(NORTH, middle - 4, middle + 4)
	configure_edge(SOUTH, middle - 4, middle + 4)
	var/obj/vehicle/sealed/spacepod/pod = allocate(__IMPLIED_TYPE__)
	var/turf/start = start_turf(pod, NORTH)
	var/turf/arrival = arrival_turf(pod, NORTH)
	TEST_ASSERT(pod.forceMove(start), "Could not place the pulling fixture.")
	var/obj/structure/closet/crate/pullee = allocate(__IMPLIED_TYPE__, get_step(start, SOUTH))
	pod.setDir(NORTH)
	TEST_ASSERT(pod.start_pulling(pullee), "The native pod could not start pulling its cargo crate.")
	TEST_ASSERT(pod.Move(get_step(pod, NORTH), NORTH), "The pulling pod could not enter the border.")
	TEST_ASSERT_EQUAL(pod.loc, arrival, "Pulling a crate prevented the sector transition.")
	TEST_ASSERT_EQUAL(pod.pulling, pullee, "The transition detached the original pulled cargo.")
	TEST_ASSERT_EQUAL(pullee.pulledby, pod, "The transferred cargo lost its pulling owner.")
	TEST_ASSERT_EQUAL(pullee.loc, get_step(arrival, SOUTH), "The outer movement pulled transferred cargo back toward the departed sector.")
	TEST_ASSERT(!pullee.currently_z_moving, "The transferred cargo retained its z-movement state.")
	pod.stop_pulling()
	TEST_ASSERT(pod.forceMove(start), "Could not restore the pulled-by fixture.")
	pod.move_resist = MOVE_FORCE_WEAK
	var/mob/living/carbon/human/consistent/technician = allocate(__IMPLIED_TYPE__, locate(start.x - 1, start.y + 1, start.z))
	technician.start_pulling(pod)
	TEST_ASSERT_EQUAL(technician.pulling, pod, "The native technician could not establish the pulled-by fixture.")
	TEST_ASSERT_EQUAL(pod.pulledby, technician, "The pod did not record the native pulling technician.")
	TEST_ASSERT(pod.Move(get_step(pod, NORTH), NORTH), "The pulled pod could not reach its border turf.")
	TEST_ASSERT_EQUAL(pod.loc, get_step(start, NORTH), "A pod being pulled teleported independently of its puller.")
	TEST_ASSERT_EQUAL(pod.pulledby, technician, "The blocked sector transfer broke an adjacent native pull.")
	TEST_ASSERT_EQUAL(technician.pulling, pod, "The blocked sector transfer detached the puller's ownership.")
	technician.stop_pulling()
