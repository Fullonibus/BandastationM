/// Keep destructive landing checks away from the station and the shared unit-test room.
/datum/unit_test/spacepod_shuttle
	parent_type = /datum/unit_test/spacepod_vacuum
	abstract_type = /datum/unit_test/spacepod_shuttle
	var/list/ports = list()
	var/list/shuttle_tiles = list()
	var/area/shuttle/cargo_area

/datum/unit_test/spacepod_shuttle/New()
	..()
	cargo_area = new

/datum/unit_test/spacepod_shuttle/Destroy()
	QDEL_LIST(allocated)
	for(var/obj/docking_port/mobile/port as anything in ports)
		qdel(port, force = TRUE)
	ports = null
	for(var/list/saved as anything in shuttle_tiles)
		var/turf/location = locate(saved[1], saved[2], saved[3])
		location = location.ChangeTurf(saved[4], flags = CHANGETURF_IGNORE_AIR)
		location.baseturfs = saved[5]
		location.change_area(get_area(location), vacuum_area)
	shuttle_tiles = null
	QDEL_NULL(cargo_area)
	return ..()

/datum/unit_test/spacepod_shuttle/proc/make_port()
	var/obj/docking_port/mobile/port = new(locate(vacuum_origin.x + 4, vacuum_origin.y + 4, vacuum_origin.z), list(cargo_area))
	port.register()
	port.setDir(NORTH)
	ports += port
	return port

/datum/unit_test/spacepod_shuttle/proc/make_shuttle_floor(turf/location)
	shuttle_tiles += list(list(location.x, location.y, location.z, location.type, islist(location.baseturfs) ? location.baseturfs.Copy() : location.baseturfs))
	location = location.ChangeTurf(/turf/open/floor/iron, flags = CHANGETURF_IGNORE_AIR)
	location.change_area(get_area(location), cargo_area)
	location.baseturfs = list(/turf/open/space, /turf/baseturf_skipover/shuttle, /turf/open/floor/iron)
	return location

/// The native landing callback must destroy either the anchor or a far-corner overlap exactly once.
/datum/unit_test/spacepod_shuttle/crush/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve an isolated shuttle landing site.")
	var/obj/docking_port/mobile/shuttle = make_port()
	var/turf/source = locate(vacuum_origin.x + 4, vacuum_origin.y, vacuum_origin.z)
	for(var/impact in list("anchor", "far_corner"))
		var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
		var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
		var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
		TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "The shuttle-crush pilot could not board.")
		TEST_ASSERT(pod.mob_enter(passenger, silent = TRUE), "The shuttle-crush passenger could not board.")
		var/obj/item/spacepod_equipment/misc/tracker/tracker = pod.misc_system
		var/list/actions = pilot.actions.Copy()
		var/pod_trait_source = REF(pod)
		var/list/turf/footprint = pod.locs.Copy()
		var/turf/impact_turf = impact == "anchor" ? vacuum_origin : locate(vacuum_origin.x + 1, vacuum_origin.y + 1, vacuum_origin.z)
		TEST_ASSERT(pod in impact_turf.contents, "The [impact] landing fixture does not physically overlap the pod.")
		var/explosions_before = SSexplosions.explosion_index
		var/result = impact_turf.toShuttleMove(source, MOVE_TURF | MOVE_CONTENTS, shuttle)
		TEST_ASSERT_EQUAL(result, MOVE_TURF | MOVE_CONTENTS, "Crushing a pod changed the shuttle's permitted movement flags.")
		TEST_ASSERT(QDELETED(pod), "A native shuttle landing left the [impact]-overlapping pod alive on the receiving tile.")
		TEST_ASSERT_EQUAL(SSexplosions.explosion_index, explosions_before + 1, "The crushed pod did not trigger exactly one real core blast.")
		// A landing handles every covered turf; the former 2x2 footprint must not detonate four times.
		for(var/turf/tile as anything in footprint)
			tile.toShuttleMove(source, MOVE_TURF, shuttle)
		TEST_ASSERT_EQUAL(SSexplosions.explosion_index, explosions_before + 1, "Repeated landing callbacks detonated one cabin more than once.")
		TEST_ASSERT(!(pod in GLOB.spacepods_list), "A shuttle-crushed pod remains registered.")
		TEST_ASSERT(!(tracker in GLOB.pod_trackers), "A shuttle-crushed pod left its tracker registered.")
		TEST_ASSERT_EQUAL(length(pod.occupants), 0, "The crushed cabin retains occupants.")
		TEST_ASSERT_NULL(pod.pilot, "The crushed cabin retains its pilot reference.")
		for(var/mob/living/occupant as anything in list(pilot, passenger))
			TEST_ASSERT(QDELETED(occupant) || occupant.loc != pod, "A crew member remains inside the deleted cabin.")
			TEST_ASSERT(!HAS_TRAIT_FROM(occupant, TRAIT_HANDS_BLOCKED, VEHICLE_TRAIT), "The deleted cabin still blocks a crew member's hands.")
			TEST_ASSERT(!HAS_TRAIT_FROM(occupant, TRAIT_RUNECHAT_HIDDEN, pod_trait_source), "The deleted cabin retains its crew's hidden-runechat source.")
		for(var/datum/action/vehicle/sealed/spacepod/action in actions)
			TEST_ASSERT(QDELETED(action) || !action.IsAvailable(), "The destroyed pod left an available control action behind.")
		var/deadline = world.time + 6 SECONDS
		while(SSexplosions.is_exploding() && world.time < deadline)
			stoplag(1)
		TEST_ASSERT(!SSexplosions.is_exploding(), "The native shuttle-crush blast did not finish processing.")
		while(length(get_wreckage()) < 4 && world.time < deadline)
			stoplag(1)
		var/list/debris = get_wreckage()
		allocated |= debris
		TEST_ASSERT_EQUAL(length(debris), 4, "A crushed 2x2 cabin did not leave its four mechanical fragments.")
		for(var/obj/effect/decal/remains/robot/spacepod/fragment as anything in debris)
			qdel(fragment)
		qdel(pilot)
		qdel(passenger)

/// Source cargo survives overlapping docking regions and the real preflight/takeoff pipeline.
/datum/unit_test/spacepod_shuttle/carried/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve an isolated cargo shuttle fixture.")
	var/obj/docking_port/mobile/shuttle = make_port()
	var/turf/source = locate(vacuum_origin.x + 4, vacuum_origin.y, vacuum_origin.z)
	var/list/old_turfs = list()
	var/list/new_turfs = list()
	for(var/dy in 0 to 1)
		for(var/dx in 0 to 1)
			old_turfs += make_shuttle_floor(locate(source.x + dx, source.y + dy, source.z))
			var/turf/target = locate(vacuum_origin.x + dx, vacuum_origin.y + dy, vacuum_origin.z)
			shuttle_tiles += list(list(target.x, target.y, target.z, target.type, islist(target.baseturfs) ? target.baseturfs.Copy() : target.baseturfs))
			new_turfs += target
	cargo_area.reg_in_areas_in_z()
	source = locate(source.x, source.y, source.z)
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, source)
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(source, SOUTH))
	// Keep breathing-driven life support out of the shuttle's power-use assertion.
	ADD_TRAIT(pilot, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "The carried pod's pilot could not board.")
	var/initial_integrity = pod.get_integrity()
	var/initial_charge = pod.battery.charge
	var/explosions_before = SSexplosions.explosion_index
	for(var/turf/tile as anything in old_turfs)
		TEST_ASSERT(isshuttleturf(tile), "The source cargo fixture lacks actual shuttle baseturfs.")
		tile.toShuttleMove(source, MOVE_TURF | MOVE_CONTENTS, shuttle)
	TEST_ASSERT(!QDELETED(pod), "Overlapping docking regions crushed cargo already aboard the moving shuttle.")
	TEST_ASSERT_EQUAL(pod.loc, source, "Preflight pushed the carried pod out of its source position.")
	var/list/areas_to_move = list()
	var/list/underlying_areas = list()
	TEST_ASSERT(!shuttle.preflight_check(old_turfs, new_turfs, areas_to_move, underlying_areas, 0), "The real shuttle preflight rejected the pod-carrying fixture.")
	var/list/moved_atoms = list()
	shuttle.takeoff(old_turfs, new_turfs, moved_atoms, 0, NORTH, null, vacuum_area)
	TEST_ASSERT_EQUAL(pod.loc, vacuum_origin, "The real shuttle takeoff did not carry the pod from its source turf.")
	TEST_ASSERT(!QDELETED(pod) && !pod.melting_down, "Ordinary shuttle transport destroyed the carried pod.")
	TEST_ASSERT_EQUAL(pod.get_integrity(), initial_integrity, "Ordinary shuttle transport damaged the carried hull.")
	TEST_ASSERT_EQUAL(pod.battery.charge, initial_charge, "Ordinary shuttle transport consumed pod power.")
	TEST_ASSERT_EQUAL(SSexplosions.explosion_index, explosions_before, "Transporting onboard cargo caused a core explosion.")
	TEST_ASSERT(pilot.loc == pod && pod.is_occupant(pilot) && pod.can_control(pilot), "Shuttle transport detached the pod's pilot or controls.")
	TEST_ASSERT(pod in moved_atoms, "The native shuttle did not record the pod among its transported objects.")

/// Respect explicit crush protection and avoid turning content-only movement into a landing impact.
/datum/unit_test/spacepod_shuttle/protection/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve the protected landing fixture.")
	var/obj/docking_port/mobile/shuttle = make_port()
	var/turf/source = locate(vacuum_origin.x + 4, vacuum_origin.y, vacuum_origin.z)
	var/obj/vehicle/sealed/spacepod/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	var/explosions_before = SSexplosions.explosion_index
	pod.resistance_flags |= SHUTTLE_CRUSH_PROOF
	vacuum_origin.toShuttleMove(source, MOVE_TURF, shuttle)
	TEST_ASSERT(!QDELETED(pod) && pod.loc == vacuum_origin, "The pod-specific landing path ignored SHUTTLE_CRUSH_PROOF.")
	pod.resistance_flags &= ~SHUTTLE_CRUSH_PROOF
	vacuum_origin.toShuttleMove(source, MOVE_CONTENTS, shuttle)
	TEST_ASSERT(!QDELETED(pod) && pod.loc == vacuum_origin, "A contents-only shuttle movement crushed the pod without replacing its turf.")
	TEST_ASSERT_EQUAL(SSexplosions.explosion_index, explosions_before, "A protected or non-landing operation created an explosion.")
	var/turf/item_origin = locate(vacuum_origin.x + 3, vacuum_origin.y, vacuum_origin.z)
	var/obj/item/plain_cargo = allocate(__IMPLIED_TYPE__, item_origin)
	item_origin.toShuttleMove(source, MOVE_TURF, shuttle)
	TEST_ASSERT_EQUAL(plain_cargo.loc, get_step(item_origin, NORTH), "The pod-specific impact changed native displacement of ordinary loose cargo.")

/// A queued core timer must not produce another blast after a landing has already destroyed its owner.
/datum/unit_test/spacepod_shuttle/pending_core/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve the failing-core landing fixture.")
	var/obj/docking_port/mobile/shuttle = make_port()
	var/obj/vehicle/sealed/spacepod/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	pod.take_damage(pod.max_integrity + 1, BRUTE, MELEE, sound_effect = FALSE)
	TEST_ASSERT(pod.melting_down && !QDELETED(pod), "The failing-core fixture did not start its real three-second timer.")
	var/explosions_before = SSexplosions.explosion_index
	vacuum_origin.toShuttleMove(locate(vacuum_origin.x + 4, vacuum_origin.y, vacuum_origin.z), MOVE_TURF, shuttle)
	TEST_ASSERT(QDELETED(pod), "A core already failing survived the landing impact until its old timer.")
	var/deadline = world.time + 4 SECONDS
	while(world.time < deadline)
		stoplag(1)
	TEST_ASSERT_EQUAL(SSexplosions.explosion_index, explosions_before + 1, "The deleted pod's pending meltdown timer produced a second blast.")
	allocated |= get_wreckage()
