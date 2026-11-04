/datum/unit_test/movement_order_sanity/Run()
	var/obj/movement_tester/test_obj = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/list/movement_cache = test_obj.movement_order

	var/obj/movement_interceptor/interceptor = allocate(__IMPLIED_TYPE__)
	interceptor.forceMove(locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))

	var/did_move = step(test_obj, EAST)

	TEST_ASSERT(did_move, "Object did not move at all.")
	TEST_ASSERT(QDELETED(test_obj), "Object was not qdeleted.")
	TEST_ASSERT(length(movement_cache) == 4, "Movement order length was not the expected value of 4, got: [length(movement_cache)].\nMovement Log\n[jointext(movement_cache, "\n")]")

	// Due to when the logging takes place, it will always be Move Move > Moved Moved instead of the reality of
	// Move > Moved > Move > Moved
	TEST_ASSERT(findtext(movement_cache[1], "Moving from"),"Movement step 1 was not a Move attempt.\nMovement Log\n[jointext(movement_cache, "\n")]")
	TEST_ASSERT(findtext(movement_cache[2], "Moving from"),"Movement step 2 was not a Move attempt.\nMovement Log\n[jointext(movement_cache, "\n")]")
	TEST_ASSERT(findtext(movement_cache[3], "Moved from"),"Movement step 3 was not a Moved() call.\nMovement Log\n[jointext(movement_cache, "\n")]")
	TEST_ASSERT(findtext(movement_cache[4], "Moved from"),"Movement step 4 was not a Moved() call.\nMovement Log\n[jointext(movement_cache, "\n")]")

/obj/movement_tester
	name = "movement debugger"
	var/list/movement_order = list()

/obj/movement_tester/Move(atom/newloc, direct, glide_size_override, z_movement_flags)
	movement_order += "Moving from ([loc.x], [loc.y]) to [newloc ? "([newloc.x], [newloc.y])" : "NULL"]"
	return ..()

/obj/movement_tester/doMove(atom/destination)
	movement_order += "Abstractly Moving from ([loc.x], [loc.y]) to [destination ? "([destination.x], [destination.y])" : "NULL"]"
	return ..()

/obj/movement_tester/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	movement_order += "Moved from ([old_loc.x], [old_loc.y]) to [loc ? "([loc.x], [loc.y])" : "NULL"]"
	return ..()

/obj/movement_interceptor
	name = "movement interceptor"

/obj/movement_interceptor/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/connect_loc, list(COMSIG_ATOM_ENTERED = PROC_REF(on_crossed)))

/obj/movement_interceptor/proc/on_crossed(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(src == arrived)
		return

	qdel(arrived)

/// Non-unique areas isolate the real Entered/Exited callbacks without changing station areas.
/area/interrupted_movement_test
	area_flags_mapping = NONE
	requires_power = FALSE
	static_lighting = FALSE
	default_gravity = STANDARD_GRAVITY

/// A turf callback which teleports during a move must finish the intermediate area entry first.
/datum/unit_test/interrupted_area_movement
	/// Private floor keeps callbacks and area changes out of the shared five-by-five test room.
	var/datum/turf_reservation/movement_block
	/// Argumentless area construction avoids native area replacement at allocate()'s default turf.
	var/list/fixture_areas = list()
	/// Original reservation areas restored even if an assertion stops Run().
	var/list/original_areas = list()
	/// Area notifications received by the moving object.
	var/list/area_events = list()
	/// Destination of the nested forceMove, cleared before re-entering movement.
	var/turf/redirect_destination
	/// Moving object used to filter turf callbacks.
	var/atom/movable/subject
	/// Number of completed movements received through the production Moved signal.
	var/moved_count = 0

/datum/unit_test/interrupted_area_movement/Destroy()
	QDEL_LIST(allocated)
	for(var/turf/changed as anything in original_areas)
		changed.change_area(get_area(changed), original_areas[changed])
	original_areas = null
	subject = null
	redirect_destination = null
	QDEL_LIST(fixture_areas)
	QDEL_NULL(movement_block)
	return ..()

/datum/unit_test/interrupted_area_movement/Run()
	movement_block = SSmapping.request_turf_block_reservation(8, 3, 1, turf_type_override = /turf/open/indestructible)
	TEST_ASSERT_NOTNULL(movement_block, "Could not reserve an isolated movement enclosure.")
	var/turf/bottom_left = movement_block.bottom_left_turfs[1]
	var/turf/origin = locate(bottom_left.x + 1, bottom_left.y + 1, bottom_left.z)
	var/turf/intermediate = get_step(origin, EAST)
	var/turf/final_destination = locate(origin.x + 4, origin.y, origin.z)
	var/area/interrupted_movement_test/start_area = new
	var/area/interrupted_movement_test/intermediate_area = new
	var/area/interrupted_movement_test/final_area = new
	fixture_areas = list(start_area, intermediate_area, final_area)
	start_area.name = "A"
	intermediate_area.name = "B"
	final_area.name = "C"
	for(var/turf/position as anything in movement_block.reserved_turfs)
		original_areas[position] = get_area(position)
		var/area/assigned_area = position.x <= origin.x ? start_area : (position.x < final_destination.x ? intermediate_area : final_area)
		position.change_area(get_area(position), assigned_area)
	TEST_ASSERT_EQUAL(get_area(origin), start_area, "The initial turf did not enter its isolated area.")
	TEST_ASSERT_EQUAL(get_area(intermediate), intermediate_area, "The intermediate turf did not enter its isolated area.")
	TEST_ASSERT_EQUAL(get_area(final_destination), final_area, "The final turf did not enter its isolated area.")
	TEST_ASSERT_EQUAL(get_area(run_loc_floor_bottom_left), get_area(run_loc_floor_top_right), "The movement enclosure split the shared test room.")

	for(var/size in list(ICON_SIZE_X, ICON_SIZE_X * 2))
		for(var/forced in list(FALSE, TRUE))
			for(var/redirect_on_exit in list(FALSE, TRUE))
				subject = allocate(/obj/structure, origin)
				subject.bound_width = size
				subject.bound_height = size
				subject.anchored = FALSE
				subject.become_area_sensitive(TRAIT_SOURCE_UNIT_TESTS)
				TEST_ASSERT(subject in subject.important_recursive_contents?[RECURSIVE_CONTENTS_AREA_SENSITIVE], "The movement subject did not become area-sensitive.")
				RegisterSignal(subject, COMSIG_ENTER_AREA, PROC_REF(on_enter_area))
				RegisterSignal(subject, COMSIG_EXIT_AREA, PROC_REF(on_exit_area))
				RegisterSignal(subject, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
				// Multi-tile entry occurs on the newly occupied edge, rather than the overlapping anchor turf.
				var/turf/trigger_turf = redirect_on_exit ? origin : locate(origin.x + size / ICON_SIZE_X, origin.y, origin.z)
				var/trigger_signal = redirect_on_exit ? COMSIG_ATOM_EXITED : COMSIG_ATOM_ENTERED
				RegisterSignal(trigger_turf, trigger_signal, PROC_REF(redirect_movement))
				area_events.Cut()
				moved_count = 0
				redirect_destination = final_destination
				var/did_move = forced ? subject.forceMove(intermediate) : subject.try_step_multiz(EAST)
				UnregisterSignal(trigger_turf, trigger_signal)
				var/scenario = "[size]-pixel [forced ? "forced" : "normal"] move interrupted in turf [redirect_on_exit ? "Exited" : "Entered"]"
				TEST_ASSERT(did_move, "[scenario] failed to start.")
				TEST_ASSERT_EQUAL(subject.loc, final_destination, "[scenario] did not complete the nested teleport.")
				TEST_ASSERT_EQUAL(jointext(area_events, ","), "exit A,enter B,exit B,enter C", "[scenario] sent stale or out-of-order area notifications.")
				TEST_ASSERT_EQUAL(moved_count, 2, "[scenario] did not resolve both movements exactly once.")
				var/list/expected_footprint = block(final_destination, locate(final_destination.x + size / ICON_SIZE_X - 1, final_destination.y + size / ICON_SIZE_Y - 1, final_destination.z))
				TEST_ASSERT_EQUAL(length(subject.locs), length(expected_footprint), "[scenario] changed the footprint size.")
				TEST_ASSERT_EQUAL(length(subject.locs - expected_footprint), 0, "[scenario] left the footprint behind.")
				qdel(subject)
				subject = null

/datum/unit_test/interrupted_area_movement/proc/redirect_movement(datum/source, atom/movable/moving)
	SIGNAL_HANDLER
	if(moving != subject || !redirect_destination)
		return
	var/turf/destination = redirect_destination
	redirect_destination = null
	moving.forceMove(destination)

/datum/unit_test/interrupted_area_movement/proc/on_enter_area(datum/source, area/entered)
	SIGNAL_HANDLER
	area_events += "enter [entered.name]"

/datum/unit_test/interrupted_area_movement/proc/on_exit_area(datum/source, area/exited)
	SIGNAL_HANDLER
	area_events += "exit [exited.name]"

/datum/unit_test/interrupted_area_movement/proc/on_moved(datum/source)
	SIGNAL_HANDLER
	moved_count++
