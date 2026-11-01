/// Diagonal thrust keeps the four-tile footprint and preserves the cabin and occupants' facing.
/datum/unit_test/spacepod_diagonal_controls/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	for(var/direction in list(NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST))
		var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, origin)
		var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
		var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
		TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "Pilot could not board for diagonal [direction].")
		TEST_ASSERT(pod.mob_enter(passenger, silent = TRUE), "Passenger could not board for diagonal [direction].")
		pod.setDir(NORTH)
		var/turf/destination = get_step(origin, direction)
		var/diagonal_moved = pod.relaymove(pilot, direction)
		STOP_PROCESSING(SSnewtonian_movement, pod.flight)
		pod.flight.process(0.05)
		TEST_ASSERT(diagonal_moved, "Pilot controls could not complete open diagonal [direction]: origin=([origin.x],[origin.y],[origin.z]) destination=([destination.x],[destination.y],[destination.z]) actual=([pod.x],[pod.y],[pod.z]) control=[pod.can_control(pilot)] facing=[pod.dir] diagonal_state=[pod.moving_diagonally].")
		TEST_ASSERT_EQUAL(pod.loc, destination, "Open diagonal [direction] ended at the wrong origin.")
		var/list/expected_footprint = block(destination, locate(destination.x + 1, destination.y + 1, destination.z))
		TEST_ASSERT_EQUAL(length(pod.locs), 4, "Diagonal [direction] added a phantom row or column.")
		TEST_ASSERT_EQUAL(length(pod.locs - expected_footprint), 0, "Diagonal [direction] occupied a turf outside its actual 2x2 footprint.")
		var/expected_facing = NORTH
		TEST_ASSERT_EQUAL(pod.dir, expected_facing, "Diagonal thrust [direction] turned the nose toward the velocity vector.")
		TEST_ASSERT_EQUAL(pilot.dir, pod.dir, "Diagonal [direction] changed the pilot's facing relative to the cabin.")
		TEST_ASSERT_EQUAL(passenger.dir, pod.dir, "Diagonal [direction] changed the passenger's facing relative to the cabin.")
		TEST_ASSERT_EQUAL(pilot.loc, pod, "Diagonal [direction] detached the pilot from the cabin.")
		TEST_ASSERT_EQUAL(passenger.loc, pod, "Diagonal [direction] detached the passenger from the cabin.")
		TEST_ASSERT_EQUAL(pod.moving_diagonally, 0, "Diagonal [direction] left the pod in an intermediate movement state.")
		TEST_ASSERT(pod.Move(get_step(destination, SOUTH), SOUTH, 0, FALSE), "A subsequent cardinal move with update_dir disabled failed.")
		TEST_ASSERT_EQUAL(pod.dir, expected_facing, "update_dir = FALSE unexpectedly turned the cabin.")
		TEST_ASSERT_EQUAL(passenger.dir, expected_facing, "update_dir = FALSE unexpectedly turned the passenger.")
		qdel(pod)
		qdel(pilot)
		qdel(passenger)

/// Both blocked approaches prevent corner cutting; a blocked second step retains native sliding.
/datum/unit_test/spacepod_diagonal_corners/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	for(var/direction in list(NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST))
		var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, origin)
		var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
		var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
		TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "Pilot could not board for blocked diagonal [direction].")
		TEST_ASSERT(pod.mob_enter(passenger, silent = TRUE), "Passenger could not board for blocked diagonal [direction].")
		var/dx = direction & EAST ? 1 : -1
		var/dy = direction & NORTH ? 1 : -1
		var/obj/structure/vertical_blocker = allocate(__IMPLIED_TYPE__, locate(origin.x + (dx > 0 ? 0 : 1), origin.y + (dy > 0 ? 2 : -1), origin.z))
		var/obj/structure/horizontal_blocker = allocate(__IMPLIED_TYPE__, locate(origin.x + (dx > 0 ? 2 : -1), origin.y + (dy > 0 ? 0 : 1), origin.z))
		vertical_blocker.density = TRUE
		horizontal_blocker.density = TRUE
		TEST_ASSERT(!pod.try_step_multiz(direction), "Diagonal [direction] cut between two blocked cardinal approaches.")
		TEST_ASSERT_EQUAL(pod.loc, origin, "A fully blocked diagonal [direction] moved the pod.")
		TEST_ASSERT(!(get_turf(vertical_blocker) in pod.locs), "Blocked diagonal [direction] overlapped the vertical obstacle.")
		TEST_ASSERT(!(get_turf(horizontal_blocker) in pod.locs), "Blocked diagonal [direction] overlapped the horizontal obstacle.")
		qdel(vertical_blocker)
		qdel(horizontal_blocker)
		var/obj/structure/far_corner = allocate(__IMPLIED_TYPE__, locate(origin.x + (dx > 0 ? 2 : -1), origin.y + (dy > 0 ? 2 : -1), origin.z))
		far_corner.density = TRUE
		TEST_ASSERT(!pod.try_step_multiz(direction), "Diagonal [direction] clipped its final far corner through an obstacle.")
		var/turf/slide_destination = get_step(origin, dy > 0 ? NORTH : SOUTH)
		TEST_ASSERT_EQUAL(pod.loc, slide_destination, "A blocked second step did not preserve native cardinal sliding for [direction]: actual=([pod.x],[pod.y]) expected=([slide_destination.x],[slide_destination.y]).")
		TEST_ASSERT(!(get_turf(far_corner) in pod.locs), "A partially blocked diagonal [direction] overlapped its obstacle.")
		TEST_ASSERT_EQUAL(length(pod.locs), 4, "A failed diagonal [direction] changed the cabin footprint.")
		TEST_ASSERT_EQUAL(pilot.loc, pod, "A failed diagonal [direction] detached its pilot.")
		TEST_ASSERT_EQUAL(passenger.loc, pod, "A failed diagonal [direction] detached its passenger.")
		TEST_ASSERT(pod.is_driver(pilot), "A failed diagonal [direction] removed pilot controls.")
		TEST_ASSERT(passenger in pod.passengers, "A failed diagonal [direction] removed its passenger registration.")
		TEST_ASSERT_EQUAL(passenger.dir, pod.dir, "A failed diagonal [direction] left its passenger facing elsewhere.")
		TEST_ASSERT_EQUAL(pod.moving_diagonally, 0, "A failed diagonal [direction] retained an intermediate movement state.")
		qdel(far_corner)
		qdel(pod)
		qdel(pilot)
		qdel(passenger)
	var/obj/vehicle/sealed/spacepod/pod = allocate(__IMPLIED_TYPE__, origin)
	var/turf/destination = get_step(origin, NORTHEAST)
	var/obj/structure/east_outside = allocate(__IMPLIED_TYPE__, locate(destination.x + 2, destination.y + 1, destination.z))
	var/obj/structure/north_outside = allocate(__IMPLIED_TYPE__, locate(destination.x + 1, destination.y + 2, destination.z))
	east_outside.density = TRUE
	north_outside.density = TRUE
	TEST_ASSERT(pod.try_step_multiz(NORTHEAST), "A diagonal move required a phantom third clear row or column.")
	TEST_ASSERT_EQUAL(pod.loc, destination, "Obstacles beyond the destination footprint prevented a complete diagonal move.")

/// The public native planar API must work for single-tile and multi-tile callers alike.
/datum/unit_test/spacepod_native_step/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/list/fixtures = list(
		list("type" = /obj/structure, "size" = 32),
		list("type" = /obj/structure, "size" = 64),
		list("type" = /obj/vehicle/sealed/spacepod, "size" = 64),
	)
	for(var/list/fixture as anything in fixtures)
		var/atom/movable/subject = allocate(fixture["type"], origin)
		subject.bound_width = fixture["size"]
		subject.bound_height = fixture["size"]
		subject.density = TRUE
		subject.anchored = FALSE
		for(var/direction in list(NORTH, NORTHEAST))
			subject.forceMove(origin)
			subject.setDir(SOUTH)
			var/turf/target = get_step(origin, direction)
			TEST_ASSERT(subject.try_step_multiz(direction), "Native planar direction [direction] failed for [subject.type] with [fixture["size"]]-pixel bounds.")
			TEST_ASSERT_EQUAL(subject.loc, target, "Native planar direction [direction] ended at the wrong turf for [subject.type].")
			var/expected_tiles = (fixture["size"] / ICON_SIZE_X) ** 2
			TEST_ASSERT_EQUAL(length(subject.locs), expected_tiles, "Native planar movement changed the footprint of [subject.type].")
			TEST_ASSERT_EQUAL(subject.moving_diagonally, 0, "Native planar movement left a diagonal flag on [subject.type].")
		qdel(subject)

// Keep the reservation bit during Initialize so native openspace resolves its virtual lower deck.
/turf/open/openspace/spacepod_movement_test
	turf_flags = parent_type::turf_flags | RESERVATION_TURF

/// Probe the same partial stack that atmos can observe when the next deck's allocator yields.
/datum/turf_reservation/spacepod_movement_test
	var/partial_topology_checked = FALSE
	var/partial_topology_hidden = FALSE

/datum/turf_reservation/spacepod_movement_test/_reserve_area(width, height, zlevel)
	. = ..()
	if(!. || z_size < 2 || length(bottom_left_turfs) != 1)
		return
	var/turf/first_deck = bottom_left_turfs[1]
	partial_topology_checked = TRUE
	partial_topology_hidden = isnull(calculate_turf_bounds_information(first_deck)) && isnull(GET_TURF_ABOVE(first_deck)) && isnull(GET_TURF_BELOW(first_deck))
	first_deck.immediate_calculate_adjacent_turfs()
	// Model SSair consuming this entry before reserve() finishes the second deck.
	SSair.adjacent_rebuild -= first_deck

/// Native reservations provide two virtual decks without changing any station z links.
/datum/unit_test/spacepod_multiz
	abstract_type = /datum/unit_test/spacepod_multiz
	var/datum/turf_reservation/spacepod_movement_test/flight_reservation

/datum/unit_test/spacepod_multiz/Destroy()
	// Occupants and vehicles must leave before asynchronous reservation release empties its turfs.
	QDEL_LIST(allocated)
	QDEL_NULL(flight_reservation)
	return ..()

/datum/unit_test/spacepod_multiz/proc/create_flight_reservation()
	flight_reservation = SSmapping.request_turf_block_reservation(5, 5, 2, reservation_type = /datum/turf_reservation/spacepod_movement_test, turf_type_override = /turf/open/indestructible)
	if(!flight_reservation)
		return FALSE
	var/turf/upper_corner = flight_reservation.bottom_left_turfs[1]
	for(var/turf/upper_turf as anything in block(locate(upper_corner.x + 1, upper_corner.y + 1, upper_corner.z), locate(upper_corner.x + 2, upper_corner.y + 2, upper_corner.z)))
		upper_turf.ChangeTurf(/turf/open/openspace/spacepod_movement_test)
	return TRUE

/// A real two-deck trip must move the entire occupied cabin and clear native z-movement state.
/datum/unit_test/spacepod_multiz_roundtrip
	parent_type = /datum/unit_test/spacepod_multiz

/datum/unit_test/spacepod_multiz_roundtrip/Run()
	TEST_ASSERT(create_flight_reservation(), "Could not reserve two native virtual decks for flight.")
	TEST_ASSERT(flight_reservation.partial_topology_checked, "The fixture did not exercise a partially allocated virtual stack.")
	TEST_ASSERT(flight_reservation.partial_topology_hidden, "A partially allocated virtual stack exposed incomplete bounds or vertical links.")
	var/turf/upper_corner = flight_reservation.bottom_left_turfs[1]
	TEST_ASSERT(upper_corner in SSair.adjacent_rebuild, "Finishing the virtual stack did not requeue an atmos check consumed during allocation.")
	var/turf/lower_corner = flight_reservation.bottom_left_turfs[2]
	TEST_ASSERT_EQUAL(GET_TURF_BELOW(upper_corner), lower_corner, "The complete reservation did not expose its lower deck.")
	TEST_ASSERT_EQUAL(GET_TURF_ABOVE(lower_corner), upper_corner, "The complete reservation did not expose its upper deck.")
	var/turf/origin = locate(lower_corner.x + 1, lower_corner.y + 1, lower_corner.z)
	var/turf/destination = GET_TURF_ABOVE(origin)
	TEST_ASSERT_NOTNULL(destination, "The native virtual reservation did not expose an upper deck.")
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, origin)
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "Pilot could not board before vertical flight.")
	TEST_ASSERT(pod.mob_enter(passenger, silent = TRUE), "Passenger could not board before vertical flight.")
	TEST_ASSERT_EQUAL(pod.can_z_move(UP, origin), destination, "A fully open four-tile shaft rejected upward flight.")
	TEST_ASSERT(pod.try_step_multiz(UP), "Native multiz movement could not ascend through a fully open footprint.")
	TEST_ASSERT_EQUAL(pod.loc, destination, "The ascending pod did not reach the virtual upper deck.")
	TEST_ASSERT_EQUAL(length(pod.locs), 4, "Ascending changed the pod's four-tile footprint.")
	TEST_ASSERT_EQUAL(get_turf(pilot), destination, "The pilot stayed behind when its cabin ascended.")
	TEST_ASSERT_EQUAL(get_turf(passenger), destination, "The passenger stayed behind when its cabin ascended.")
	TEST_ASSERT(pod.is_driver(pilot), "Ascending removed the real pilot's control flags.")
	TEST_ASSERT_EQUAL(pod.currently_z_moving, FALSE, "Ascending left the pod's z-movement state set.")
	TEST_ASSERT_EQUAL(pod.can_z_move(DOWN, destination), origin, "The open shaft rejected descent to the lower deck.")
	TEST_ASSERT(pod.try_step_multiz(DOWN), "Native multiz movement could not descend through the open footprint.")
	TEST_ASSERT_EQUAL(pod.loc, origin, "The descending pod did not return to its lower deck.")
	TEST_ASSERT_EQUAL(passenger.loc, pod, "Descending detached a passenger from the cabin.")
	TEST_ASSERT_EQUAL(pod.currently_z_moving, FALSE, "Descending left the pod's z-movement state set.")
	qdel(pod)
	TEST_ASSERT(!QDELETED(pilot) && !QDELETED(passenger), "Deleting the pod after multiz travel deleted an occupant.")
	TEST_ASSERT_EQUAL(pilot.loc, origin, "The pilot was not safely returned to the lower deck after pod deletion.")
	TEST_ASSERT_EQUAL(passenger.loc, origin, "The passenger was not safely returned to the lower deck after pod deletion.")
	TEST_ASSERT(!HAS_TRAIT(passenger, TRAIT_HANDS_BLOCKED), "Multiz travel left a deleted pod's hand-blocking trait on its passenger.")
	QDEL_LIST(allocated)
	flight_reservation.Release()
	TEST_ASSERT_NULL(flight_reservation.calculate_turf_bounds_information(upper_corner), "A released reservation retained virtual bounds.")
	TEST_ASSERT_NULL(flight_reservation.get_turf_below(upper_corner), "A released reservation retained its lower virtual deck.")
	TEST_ASSERT_NULL(flight_reservation.get_turf_above(lower_corner), "A released reservation retained its upper virtual deck.")
	upper_corner.immediate_calculate_adjacent_turfs()

/// Every corner must clear both the arrival deck and the source ceiling before native zMove can forceMove.
/datum/unit_test/spacepod_multiz_obstacles
	parent_type = /datum/unit_test/spacepod_multiz

/datum/unit_test/spacepod_multiz_obstacles/Run()
	TEST_ASSERT(create_flight_reservation(), "Could not reserve virtual decks for multiz collision testing.")
	var/turf/lower_corner = flight_reservation.bottom_left_turfs[2]
	var/turf/origin = locate(lower_corner.x + 1, lower_corner.y + 1, lower_corner.z)
	var/turf/destination = GET_TURF_ABOVE(origin)
	TEST_ASSERT_NOTNULL(destination, "The collision fixture did not expose an upper deck.")
	var/obj/vehicle/sealed/spacepod/pod = allocate(__IMPLIED_TYPE__, origin)
	var/turf/upper_far_corner = locate(destination.x + 1, destination.y + 1, destination.z)
	var/obj/structure/obstacle = allocate(__IMPLIED_TYPE__, upper_far_corner)
	obstacle.density = TRUE
	TEST_ASSERT(!pod.can_z_move(UP, origin), "Vertical collision checks ignored a solid obstacle at the far corner.")
	TEST_ASSERT(!pod.try_step_multiz(UP), "Native zMove forced a far corner through a solid obstacle.")
	TEST_ASSERT_EQUAL(pod.loc, origin, "A failed upward collision changed the pod's origin.")
	TEST_ASSERT_EQUAL(pod.currently_z_moving, FALSE, "A failed upward collision left z-movement state set.")
	qdel(obstacle)
	upper_far_corner.ChangeTurf(/turf/open/indestructible)
	TEST_ASSERT(!pod.can_z_move(UP, origin), "Vertical clearance ignored a closed floor at the far corner.")
	TEST_ASSERT(!pod.try_step_multiz(UP), "Native zMove clipped a far corner through a closed upper floor.")
	TEST_ASSERT_EQUAL(pod.loc, origin, "A failed floor-clearance check changed the pod's origin.")
	upper_far_corner.ChangeTurf(/turf/open/openspace/spacepod_movement_test)
	var/obj/structure/source_ceiling = allocate(__IMPLIED_TYPE__, locate(origin.x + 1, origin.y + 1, origin.z))
	source_ceiling.density = FALSE
	source_ceiling.obj_flags |= BLOCK_Z_OUT_UP
	TEST_ASSERT(!pod.can_z_move(UP, origin), "Vertical clearance ignored a source ceiling outside the origin tile.")
	TEST_ASSERT(!pod.try_step_multiz(UP), "Native zMove crossed a blocked source ceiling at its far corner.")
	TEST_ASSERT_EQUAL(pod.loc, origin, "A failed ceiling-clearance check changed the pod's origin.")
	TEST_ASSERT_EQUAL(length(pod.locs), 4, "A failed vertical move changed the four-tile footprint.")
	qdel(source_ceiling)
	TEST_ASSERT(pod.try_step_multiz(UP), "Removing the final obstruction did not restore real vertical movement.")
	TEST_ASSERT_EQUAL(pod.loc, destination, "A repaired shaft did not let the cabin reach its upper deck.")
	TEST_ASSERT(pod.try_step_multiz(DOWN), "A repaired shaft did not allow the pod to return before fixture cleanup.")
