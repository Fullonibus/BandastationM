/// An independent space area keeps the shared unit-test room and its gravity untouched.
/area/space/spacepod_vacuum_test
	name = "Spacepod vacuum test enclosure"
	area_flags_mapping = NONE

/datum/unit_test/spacepod_vacuum
	abstract_type = /datum/unit_test/spacepod_vacuum
	/// This is deliberately distinct from the inherited static unit-test reservation.
	var/datum/turf_reservation/vacuum_block
	var/area/space/spacepod_vacuum_test/vacuum_area
	var/list/original_areas = list()
	var/turf/open/space/vacuum_origin

/datum/unit_test/spacepod_vacuum/New()
	..()
	vacuum_block = SSmapping.request_turf_block_reservation(15, 15, 1, turf_type_override = /turf/open/space)
	if(!vacuum_block)
		return
	vacuum_area = new
	for(var/turf/tile as anything in vacuum_block.reserved_turfs)
		var/area/original_area = get_area(tile)
		original_areas[tile] = original_area
		tile.change_area(original_area, vacuum_area)
	vacuum_area.reg_in_areas_in_z()
	var/turf/bottom_left = vacuum_block.bottom_left_turfs[1]
	vacuum_origin = locate(bottom_left.x + 6, bottom_left.y + 6, bottom_left.z)

/datum/unit_test/spacepod_vacuum/Destroy()
	// Delete occupants and vehicles while the reservation and its turfs still exist.
	QDEL_LIST(allocated)
	for(var/turf/tile as anything in original_areas)
		tile.change_area(get_area(tile), original_areas[tile])
	original_areas.Cut()
	vacuum_origin = null
	QDEL_NULL(vacuum_area)
	QDEL_NULL(vacuum_block)
	return ..()

/// Keep deterministic flight ticks separate from life support and subsystem scheduling.
/datum/unit_test/spacepod_vacuum/proc/create_flight_pod(pod_type = /obj/vehicle/sealed/spacepod/civilian)
	if(!vacuum_origin)
		return
	var/obj/vehicle/sealed/spacepod/pod = allocate(pod_type, vacuum_origin)
	STOP_PROCESSING(SSobj, pod)
	STOP_PROCESSING(SSnewtonian_movement, pod.flight)
	pod.enter_delay = 0
	pod.setDir(NORTH)
	pod.flight.heading = 0
	pod.flight.desired_heading = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
	if(!pod.mob_try_enter(pilot))
		return
	return pod

/// Input restarts the native processor; deterministic cases advance that same controller explicitly.
/datum/unit_test/spacepod_vacuum/proc/advance_flight(obj/vehicle/sealed/spacepod/pod)
	STOP_PROCESSING(SSnewtonian_movement, pod.flight)
	pod.flight.process(0.05)

/// A private hangar provides a real gravity boundary without changing the station.
/area/spacepod_gravity_test
	name = "Spacepod gravity test hangar"
	area_flags_mapping = NONE
	default_gravity = STANDARD_GRAVITY

/datum/unit_test/spacepod_vacuum/gravity_transition
	/// Released after the inherited fixture restores the reservation's original areas.
	var/area/spacepod_gravity_test/hangar

/datum/unit_test/spacepod_vacuum/gravity_transition/Destroy()
	. = ..()
	QDEL_NULL(hangar)

/// Returning from space must retain continuous flight and sub-tile displacement at the hangar speed.
/datum/unit_test/spacepod_vacuum/gravity_transition/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve the gravity transition enclosure.")
	hangar = new
	var/boundary_x = vacuum_origin.x
	for(var/turf/tile as anything in vacuum_block.reserved_turfs)
		if(tile.x < boundary_x)
			tile = tile.ChangeTurf(/turf/open/indestructible)
			tile.change_area(get_area(tile), hangar)
	hangar.reg_in_areas_in_z()
	var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(pod, "Could not board the gravity transition pod.")
	pod.forceMove(locate(boundary_x - 2, vacuum_origin.y, vacuum_origin.z))
	TEST_ASSERT(pod.has_gravity(), "The hangar fixture does not have real gravity.")
	for(var/direction in list(EAST, WEST))
		pod.flight.velocity_x = direction == EAST ? 4 : -4
		for(var/tick in 1 to 24)
			advance_flight(pod)
			if(direction == EAST ? pod.x > boundary_x : pod.x < boundary_x)
				break
		TEST_ASSERT(direction == EAST ? !pod.has_gravity() : pod.has_gravity(), "Flight did not cross the real gravity boundary for [direction].")
		var/previous_x = pod.x + pod.flight.offset_x
		advance_flight(pod)
		var/speed = abs(pod.flight.velocity_x)
		TEST_ASSERT(speed > 0 && speed <= 2.5, "The returning or departing cabin lost momentum or exceeded the hangar speed.")
		TEST_ASSERT(abs(pod.x + pod.flight.offset_x - previous_x - pod.flight.velocity_x * 0.05) < 0.001, "Crossing the gravity boundary lost sub-tile distance.")
		TEST_ASSERT_EQUAL(pod.animate_movement, NO_STEPS, "Crossing gravity restored jerky tile animation.")
		TEST_ASSERT_NULL(pod.drift_handler, "Crossing gravity started a competing native drift loop.")
	var/charge_before_coast = pod.battery.charge
	var/start_x = pod.x + pod.flight.offset_x
	for(var/tick in 1 to 4)
		advance_flight(pod)
	TEST_ASSERT(abs(pod.x + pod.flight.offset_x - start_x + 0.5) < 0.001, "Coasting in the hangar stalled or snapped to a tile.")
	TEST_ASSERT_EQUAL(pod.battery.charge, charge_before_coast, "Gravity coasting consumed propulsion energy.")
	TEST_ASSERT(pod.flight.aim(45), "Returning to gravity disabled steering.")
	TEST_ASSERT(pod.relaymove(pod.pilot, NORTH), "Returning to gravity disabled relative thrust.")
	advance_flight(pod)
	TEST_ASSERT(pod.flight.heading > 0 && pod.flight.heading < 45, "Gravity did not interpolate the requested heading.")
	TEST_ASSERT(pod.flight.velocity_y > 0, "Gravity did not apply forward thrust relative to the nose.")
	TEST_ASSERT(pod.battery.charge < charge_before_coast, "Powered gravity flight consumed no energy.")

/// Turbo doubles translation and its power draw, while preserving angular controls and free momentum.
/datum/unit_test/spacepod_vacuum/turbo_flight/Run()
	var/list/outcomes = list()
	for(var/boosted in list(FALSE, TRUE))
		var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
		TEST_ASSERT_NOTNULL(pod, "Could not prepare the [boosted] turbo comparison fixture.")
		var/mob/living/pilot = pod.pilot
		if(boosted)
			TEST_ASSERT(pod.flight.toggle_turbo(), "The pilot could not enable turbo.")
		var/start_y = pod.y + pod.flight.offset_y
		var/initial_charge = pod.battery.charge
		for(var/tick in 1 to 10)
			TEST_ASSERT(pod.relaymove(pilot, NORTH), "The comparison pilot's forward thrust was rejected.")
			advance_flight(pod)
		var/list/outcome = list("velocity" = pod.flight.velocity_y, "distance" = pod.y + pod.flight.offset_y - start_y, "energy" = initial_charge - pod.battery.charge)
		var/charge_before_turn = pod.battery.charge
		TEST_ASSERT(pod.flight.aim(90), "The comparison pilot could not aim the hull.")
		advance_flight(pod)
		outcome["heading"] = pod.flight.heading
		outcome["turn_energy"] = charge_before_turn - pod.battery.charge
		outcomes += list(outcome)
		qdel(pod)
		qdel(pilot)
	var/list/normal = outcomes[1]
	var/list/boosted = outcomes[2]
	TEST_ASSERT(normal["velocity"] > 0 && normal["distance"] > 0 && normal["energy"] > 0, "The normal comparison did not actually accelerate, move and consume power.")
	for(var/measurement in list("velocity", "distance", "energy"))
		TEST_ASSERT(abs(boosted[measurement] - 2 * normal[measurement]) < 0.001, "Turbo did not double the real [measurement] over the same thrust interval.")
	TEST_ASSERT_EQUAL(normal["heading"], 18, "The normal angular-control fixture did not turn one physics tick.")
	TEST_ASSERT_EQUAL(boosted["heading"], normal["heading"], "Turbo also accelerated mouse steering.")
	TEST_ASSERT_EQUAL(boosted["turn_energy"], normal["turn_energy"], "Turbo multiplied angular-control energy consumption.")
	var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(pod, "Could not prepare the turbo speed-cap fixture.")
	var/mob/living/pilot = pod.pilot
	TEST_ASSERT(pod.flight.toggle_turbo(), "The speed-cap pilot could not enable turbo.")
	pod.flight.velocity_x = 7.8
	pod.flight.velocity_y = 10.4
	TEST_ASSERT(pod.relaymove(pilot, NORTHEAST), "The speed-cap diagonal thrust was rejected.")
	advance_flight(pod)
	var/speed = sqrt(pod.flight.velocity_x ** 2 + pod.flight.velocity_y ** 2)
	TEST_ASSERT(abs(speed - 13.333333) < 0.001, "Turbo did not cap the diagonal vector's magnitude at its doubled maximum.")
	var/velocity_x = pod.flight.velocity_x
	var/velocity_y = pod.flight.velocity_y
	TEST_ASSERT(pod.flight.toggle_turbo(), "The pilot could not disable turbo at speed.")
	var/start_x = pod.x + pod.flight.offset_x
	var/start_y = pod.y + pod.flight.offset_y
	var/coast_charge = pod.battery.charge
	for(var/tick in 1 to 5)
		advance_flight(pod)
	TEST_ASSERT(abs(pod.flight.velocity_x - velocity_x) < 0.00001 && abs(pod.flight.velocity_y - velocity_y) < 0.00001, "Disabling turbo acted as a free brake on existing momentum.")
	TEST_ASSERT(abs(pod.x + pod.flight.offset_x - start_x - velocity_x * 0.25) < 0.001 && abs(pod.y + pod.flight.offset_y - start_y - velocity_y * 0.25) < 0.001, "High-speed coasting lost or duplicated diagonal distance.")
	TEST_ASSERT_EQUAL(pod.battery.charge, coast_charge, "High-speed coasting continued drawing turbo power.")
	TEST_ASSERT(pod.relaymove(pilot, NORTHEAST), "Normal thrust was rejected after disabling turbo.")
	advance_flight(pod)
	TEST_ASSERT(abs(sqrt(pod.flight.velocity_x ** 2 + pod.flight.velocity_y ** 2) - speed) < 0.001, "Normal thrust accelerated past retained turbo speed or abruptly clamped it down.")
	qdel(pod)
	qdel(pilot)
	pod = create_flight_pod(/obj/vehicle/sealed/spacepod/sec)
	TEST_ASSERT_NOTNULL(pod, "Could not prepare the reinforced turbo collision fixture.")
	TEST_ASSERT(pod.flight.toggle_turbo(), "The collision pilot could not enable turbo.")
	var/obj/structure/blocker = allocate(__IMPLIED_TYPE__, locate(pod.x + 1, pod.y + 2, pod.z))
	blocker.density = TRUE
	blocker.anchored = TRUE
	pod.flight.velocity_y = 13.333333
	var/turf/origin = pod.loc
	var/initial_integrity = pod.get_integrity()
	advance_flight(pod)
	TEST_ASSERT_EQUAL(pod.loc, origin, "Turbo speed clipped the cabin's far corner through an obstacle.")
	TEST_ASSERT_EQUAL(pod.flight.velocity_y, 0, "A turbo collision retained velocity into the obstacle.")
	TEST_ASSERT(abs(initial_integrity - pod.get_integrity() - 168.8) < 0.001, "A turbo collision changed the existing impact-damage rule.")

/// Stronger brakes stop short vectors exactly, and turbo cannot manufacture unpaid thrust.
/datum/unit_test/spacepod_vacuum/turbo_brakes_and_power/Run()
	var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(pod, "Could not prepare turbo braking and power checks.")
	TEST_ASSERT(pod.flight.toggle_turbo() && pod.flight.toggle_brakes(), "The pilot could not enable turbo braking.")
	pod.flight.velocity_x = 0.05
	pod.flight.velocity_y = 0.1
	var/initial_charge = pod.battery.charge
	advance_flight(pod)
	TEST_ASSERT_EQUAL(pod.flight.velocity_x, 0, "Turbo braking overshot a short lateral velocity vector.")
	TEST_ASSERT_EQUAL(pod.flight.velocity_y, 0, "Turbo braking overshot a short forward velocity vector.")
	TEST_ASSERT(pod.battery.charge < initial_charge, "Turbo braking stopped momentum without paying for counter-thrust.")
	TEST_ASSERT(pod.flight.toggle_brakes(), "The pilot could not release turbo brakes.")
	pod.battery.charge = SPACEPOD_ENERGY_UNIT
	TEST_ASSERT(pod.relaymove(pod.pilot, NORTH), "A positive but insufficient battery never reached the real payment boundary.")
	advance_flight(pod)
	TEST_ASSERT_EQUAL(pod.flight.velocity_y, 0, "An insufficient battery supplied turbo acceleration.")
	TEST_ASSERT_EQUAL(pod.battery.charge, SPACEPOD_ENERGY_UNIT, "A rejected turbo payment partially drained the cell.")
	TEST_ASSERT_EQUAL(length(get_thruster_flames(pod)), 0, "Rejected turbo payment ignited the main engine.")
	pod.battery.charge = 0
	TEST_ASSERT(!pod.relaymove(pod.pilot, NORTH), "An empty battery accepted turbo thrust.")
	pod.flight.velocity_x = 0.1
	pod.flight.velocity_y = 0.2
	TEST_ASSERT(pod.flight.toggle_brakes(), "The pilot could not select brakes with an empty cell.")
	var/start_y = pod.y + pod.flight.offset_y
	advance_flight(pod)
	TEST_ASSERT(abs(pod.flight.velocity_x - 0.1) < 0.00001 && abs(pod.flight.velocity_y - 0.2) < 0.00001, "Unpowered turbo brakes removed existing momentum.")
	TEST_ASSERT(pod.y + pod.flight.offset_y > start_y, "An empty cell froze a coasting turbo cabin.")
	TEST_ASSERT_EQUAL(pod.battery.charge, 0, "Unpowered turbo flight changed an empty cell's charge.")

/// Gravity flight keeps continuous rendering, with doubled turbo speed and paid thrust.
/datum/unit_test/spacepod_vacuum/turbo_ground/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/normal_energy
	for(var/boosted in list(FALSE, TRUE))
		var/obj/vehicle/sealed/spacepod/pod = allocate(/obj/vehicle/sealed/spacepod/civilian, origin)
		STOP_PROCESSING(SSobj, pod)
		pod.enter_delay = 0
		pod.setDir(NORTH)
		var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
		TEST_ASSERT(pod.mob_try_enter(pilot) && pod.has_gravity(), "Could not board the ordinary-gravity turbo fixture.")
		if(boosted)
			TEST_ASSERT(pod.flight.toggle_turbo(), "The grounded pilot could not enable turbo.")
		pod.flight.velocity_x = 3
		pod.flight.velocity_y = 4
		var/start_x = pod.x + pod.flight.offset_x
		var/start_y = pod.y + pod.flight.offset_y
		var/initial_charge = pod.battery.charge
		TEST_ASSERT(pod.relaymove(pilot, NORTH), "Gravity flight rejected forward thrust.")
		advance_flight(pod)
		var/speed = sqrt(pod.flight.velocity_x ** 2 + pod.flight.velocity_y ** 2)
		TEST_ASSERT(abs(speed - (boosted ? 5 : 2.5)) < 0.001, "Gravity flight did not cap the whole diagonal velocity vector.")
		TEST_ASSERT(abs(pod.x + pod.flight.offset_x - start_x - pod.flight.velocity_x * 0.05) < 0.001 && abs(pod.y + pod.flight.offset_y - start_y - pod.flight.velocity_y * 0.05) < 0.001, "Gravity flight did not preserve continuous diagonal displacement.")
		TEST_ASSERT_EQUAL(pod.animate_movement, NO_STEPS, "Gravity turbo restored tile animation.")
		if(boosted)
			TEST_ASSERT(abs(initial_charge - pod.battery.charge - 2 * normal_energy) < 0.001, "Gravity turbo did not double thrust energy consumption.")
		else
			normal_energy = initial_charge - pod.battery.charge
		var/coast_charge = pod.battery.charge
		advance_flight(pod)
		TEST_ASSERT(abs(sqrt(pod.flight.velocity_x ** 2 + pod.flight.velocity_y ** 2) - speed) < 0.001, "Releasing gravity thrust lost inertia.")
		TEST_ASSERT_EQUAL(pod.battery.charge, coast_charge, "Gravity coasting consumed propulsion energy.")
		TEST_ASSERT(pod.flight.toggle_brakes(), "Gravity flight rejected the brake control.")
		advance_flight(pod)
		TEST_ASSERT(sqrt(pod.flight.velocity_x ** 2 + pod.flight.velocity_y ** 2) < speed && pod.battery.charge < coast_charge, "Gravity brakes did not apply paid counter-thrust.")
		qdel(pod)
		qdel(pilot)

/// Hull damage follows impact speed, while rejected movement alone is not an impact.
/datum/unit_test/spacepod_vacuum/collision_damage/Run()
	var/list/impacts = list(
		list("speed" = 0.5, "damage" = 0),
		list("speed" = 1, "damage" = 0),
		list("speed" = 2, "damage" = 0),
		list("speed" = 2.5, "damage" = 0),
		list("speed" = 3, "damage" = 0),
		list("speed" = 3.1, "damage" = 0.6),
		list("speed" = 4, "damage" = 7),
		list("speed" = 1 / 0.15, "damage" = 35.4),
	)
	for(var/list/impact as anything in impacts)
		var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
		TEST_ASSERT_NOTNULL(pod, "Could not prepare the [impact["speed"]]-tile/s collision fixture.")
		var/mob/living/carbon/pilot = pod.pilot
		var/obj/structure/blocker = allocate(__IMPLIED_TYPE__, locate(pod.x + 1, pod.y + 2, pod.z))
		blocker.density = TRUE
		blocker.anchored = TRUE
		pod.flight.velocity_y = impact["speed"]
		if(impact["speed"] >= 5)
			pilot.Unconscious(1 SECONDS)
		var/turf/origin = pod.loc
		var/initial_integrity = pod.get_integrity()
		advance_flight(pod)
		TEST_ASSERT_EQUAL(pod.loc, origin, "An impact clipped the cabin's far corner through its blocker.")
		TEST_ASSERT_EQUAL(pod.flight.velocity_y, 0, "An impact retained velocity into its blocker.")
		TEST_ASSERT(abs(initial_integrity - pod.get_integrity() - impact["damage"]) < 0.001, "Impact speed [impact["speed"]] caused [initial_integrity - pod.get_integrity()] hull damage, expected [impact["damage"]].")
		TEST_ASSERT(abs(pilot.get_brute_loss() - impact["damage"] * 0.5) < 0.1, "The seated pilot did not receive half of the collision's hull damage.")
		if(impact["speed"] >= 5)
			TEST_ASSERT_EQUAL(length(pilot.all_wounds), 1, "A high-speed impact did not cause exactly one pilot injury.")
			TEST_ASSERT(istype(pilot.all_wounds[1], /datum/wound/blunt/bone/severe), "A high-speed impact did not cause a closed fracture.")
		else
			TEST_ASSERT_EQUAL(length(pilot.all_wounds), 0, "A low-speed impact fractured the pilot.")
		qdel(blocker)
		qdel(pod)
		qdel(pilot)
	var/obj/vehicle/sealed/spacepod/rejected_pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(rejected_pod, "Could not prepare the movement-denial control.")
	rejected_pod.flight.velocity_y = 4
	RegisterSignal(rejected_pod, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(block_without_collision))
	var/initial_integrity = rejected_pod.get_integrity()
	advance_flight(rejected_pod)
	TEST_ASSERT_EQUAL(rejected_pod.flight.velocity_y, 0, "The movement-denial control did not reach the rejected step.")
	TEST_ASSERT_EQUAL(rejected_pod.get_integrity(), initial_integrity, "A denied movement without a real collision damaged the hull.")
	TEST_ASSERT_EQUAL(rejected_pod.pilot.get_brute_loss(), 0, "Movement denial without a collision injured the pilot.")
	UnregisterSignal(rejected_pod, COMSIG_MOVABLE_PRE_MOVE)
	qdel(rejected_pod.pilot)
	qdel(rejected_pod)
	var/obj/vehicle/sealed/spacepod/fragile_pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(fragile_pod, "Could not prepare the fatal-impact fixture.")
	var/obj/structure/fatal_blocker = allocate(__IMPLIED_TYPE__, locate(fragile_pod.x + 1, fragile_pod.y + 2, fragile_pod.z))
	fatal_blocker.density = TRUE
	fatal_blocker.anchored = TRUE
	fragile_pod.update_integrity(5)
	fragile_pod.flight.velocity_y = 4
	var/datum/spacepod_flight/fatal_flight = fragile_pod.flight
	advance_flight(fragile_pod)
	var/deleted_immediately = QDELETED(fragile_pod)
	var/flight_deleted_immediately = QDELETED(fatal_flight)
	var/flight_stopped_immediately = !(fatal_flight in SSnewtonian_movement.processing)
	var/explosion_deadline = world.time + 8 SECONDS
	while(SSexplosions.is_exploding() && world.time < explosion_deadline)
		stoplag(1)
	allocated |= get_wreckage()
	TEST_ASSERT(!SSexplosions.is_exploding(), "The immediate collision blast did not finish its native queue before fixture cleanup.")
	TEST_ASSERT(deleted_immediately, "A fatal collision retained the cabin instead of detonating immediately.")
	TEST_ASSERT(flight_deleted_immediately, "A fatal collision retained the destroyed cabin's flight controller.")
	TEST_ASSERT(flight_stopped_immediately, "A fatal collision retained scheduled flight processing.")

/datum/unit_test/spacepod_vacuum/collision_damage/proc/block_without_collision(datum/source)
	SIGNAL_HANDLER
	return COMPONENT_MOVABLE_BLOCK_PRE_MOVE

/// A fast real hull step clears a full-width ordinary wall without bypassing stronger turfs.
/datum/unit_test/spacepod_vacuum/collision_breach/Run()
	var/list/cases = list(
		list("wall" = /turf/closed/wall, "speed" = 4, "breach" = FALSE, "cracks" = TRUE),
		list("wall" = /turf/closed/wall, "speed" = 5, "breach" = TRUE),
		list("wall" = /turf/closed/wall/rust, "speed" = 5, "breach" = TRUE),
		list("wall" = /turf/closed/wall/r_wall, "speed" = 5, "breach" = FALSE, "cracks" = TRUE),
		list("wall" = /turf/closed/wall/r_wall/rust, "speed" = 5, "breach" = FALSE, "cracks" = TRUE),
		list("wall" = /turf/closed/wall/r_wall/heretic_rust, "speed" = 5, "breach" = FALSE, "cracks" = TRUE),
		list("wall" = /turf/closed/wall/r_wall/plastitanium/syndicate, "speed" = 5, "breach" = FALSE),
		list("wall" = /turf/closed/indestructible, "speed" = 5, "breach" = FALSE),
	)
	for(var/list/scenario as anything in cases)
		var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
		TEST_ASSERT_NOTNULL(pod, "Could not prepare the wall-breach fixture.")
		var/mob/living/pilot = pod.pilot
		var/turf/origin = pod.loc
		var/turf/left_wall = locate(pod.x, pod.y + 2, pod.z)
		var/turf/right_wall = locate(pod.x + 1, pod.y + 2, pod.z)
		left_wall = left_wall.ChangeTurf(scenario["wall"])
		right_wall = right_wall.ChangeTurf(scenario["wall"])
		pod.flight.velocity_y = scenario["speed"]
		var/initial_integrity = pod.get_integrity()
		advance_flight(pod)
		if(scenario["breach"])
			TEST_ASSERT(!left_wall.density && !right_wall.density, "A high-speed collision did not clear both contacted normal wall tiles.")
			TEST_ASSERT_EQUAL(pod.loc, get_step(origin, NORTH), "The pod failed to pass through its full-width breach using native movement.")
			TEST_ASSERT_EQUAL(initial_integrity - pod.get_integrity(), 16, "Successful breach lost or duplicated the collision's hull damage.")
		else
			TEST_ASSERT(istype(left_wall, scenario["wall"]) && istype(right_wall, scenario["wall"]), "A low-speed or protected-wall collision destroyed a wall tile.")
			TEST_ASSERT_EQUAL(pod.loc, origin, "The pod crossed an intact wall.")
			TEST_ASSERT_EQUAL(pod.flight.velocity_y, 0, "A protected or low-speed wall collision retained forward velocity.")
			if(scenario["cracks"])
				var/cracked_tiles = !!left_wall.GetComponent(/datum/component/torn_wall) + !!right_wall.GetComponent(/datum/component/torn_wall)
				TEST_ASSERT_EQUAL(cracked_tiles, 1, "One stopped hull impact did not crack exactly its first contacted wall tile.")
			else
				TEST_ASSERT_NULL(left_wall.GetComponent(/datum/component/torn_wall), "A collision cracked a protected wall.")
				TEST_ASSERT_NULL(right_wall.GetComponent(/datum/component/torn_wall), "A collision cracked the protected wall beneath the far corner.")
		allocated |= left_wall.contents | right_wall.contents
		qdel(pod)
		qdel(pilot)
		left_wall.ChangeTurf(/turf/open/space)
		right_wall.ChangeTurf(/turf/open/space)

/// Repeated real impacts progress dragon-style cracks once each, then open the checked hull step.
/datum/unit_test/spacepod_vacuum/collision_wall_cracks/Run()
	var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(pod, "Could not prepare the staged wall-impact fixture.")
	var/turf/origin = pod.loc
	var/turf/wall_turf = locate(pod.x + 1, pod.y + 2, pod.z)
	wall_turf = wall_turf.ChangeTurf(/turf/closed/wall)
	var/datum/component/torn_wall/cracks
	for(var/impact in 1 to 3)
		pod.flight.velocity_y = 4
		var/initial_integrity = pod.get_integrity()
		var/initial_pilot_brute = pod.pilot.get_brute_loss()
		advance_flight(pod)
		TEST_ASSERT_EQUAL(initial_integrity - pod.get_integrity(), 7, "A staged wall impact lost or duplicated its hull damage.")
		TEST_ASSERT(abs(pod.pilot.get_brute_loss() - initial_pilot_brute - 3.5) < 0.1, "A staged wall impact lost or duplicated the pilot's damage.")
		if(impact < 3)
			TEST_ASSERT(wall_turf.density, "One medium-speed impact consumed multiple wall-damage stages.")
			TEST_ASSERT_EQUAL(pod.loc, origin, "The pod crossed a wall before its final damage stage.")
			TEST_ASSERT_EQUAL(pod.flight.velocity_y, 0, "The intact cracked wall did not stop the hull.")
			cracks = wall_turf.GetComponent(/datum/component/torn_wall)
			TEST_ASSERT_NOTNULL(cracks, "A medium-speed collision did not apply native wall cracks.")
			TEST_ASSERT_EQUAL(cracks.current_stage, impact - 1, "A wall contact advanced more than one native damage stage.")
			if(impact == 1)
				var/visible_crack = FALSE
				for(var/mutable_appearance/overlay as anything in wall_turf.overlays)
					if(overlay.icon_state == "explodable")
						visible_crack = TRUE
				TEST_ASSERT(visible_crack, "The damaged wall has no native crack overlay.")
				for(var/tick in 1 to 10)
					TEST_ASSERT(pod.relaymove(pod.pilot, NORTH), "Could not hold low-speed thrust against the cracked wall.")
					advance_flight(pod)
				TEST_ASSERT_EQUAL(cracks.current_stage, 0, "Holding thrust against a wall advanced its cracks without a new impact.")
				TEST_ASSERT_EQUAL(pod.get_integrity(), initial_integrity - 7, "Holding thrust against the cracked wall repeatedly damaged the hull.")
				TEST_ASSERT(abs(pod.pilot.get_brute_loss() - initial_pilot_brute - 3.5) < 0.1, "Holding thrust against the cracked wall repeatedly injured the pilot.")
		else
			TEST_ASSERT(!wall_turf.density && QDELETED(cracks), "The final impact did not destroy the wall and release its crack component.")
			TEST_ASSERT_NULL(wall_turf.GetComponent(/datum/component/torn_wall), "The breached turf retained the old wall's crack component.")
			TEST_ASSERT_EQUAL(pod.loc, get_step(origin, NORTH), "The native hull step did not pass through the final wall breach.")
	allocated |= wall_turf.contents

/// Reinforcement needs six real impacts instead of an instant breach or repeated work in one tick.
/datum/unit_test/spacepod_vacuum/collision_reinforced_wall/Run()
	var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(pod, "Could not prepare the reinforced-wall impact fixture.")
	var/turf/origin = pod.loc
	var/turf/wall_turf = locate(pod.x + 1, pod.y + 2, pod.z)
	wall_turf = wall_turf.ChangeTurf(/turf/closed/wall/r_wall)
	var/datum/component/torn_wall/cracks
	for(var/impact in 1 to 6)
		pod.flight.velocity_y = 4
		var/initial_integrity = pod.get_integrity()
		var/initial_pilot_brute = pod.pilot.get_brute_loss()
		advance_flight(pod)
		TEST_ASSERT_EQUAL(initial_integrity - pod.get_integrity(), 7, "A reinforced-wall impact lost or duplicated its hull damage.")
		TEST_ASSERT(abs(pod.pilot.get_brute_loss() - initial_pilot_brute - 3.5) < 0.1, "A reinforced-wall impact lost or duplicated the pilot's damage.")
		if(impact < 6)
			TEST_ASSERT(wall_turf.density, "Reinforcement broke before six separate impacts.")
			TEST_ASSERT_EQUAL(pod.loc, origin, "The pod crossed intact reinforcement.")
			TEST_ASSERT_EQUAL(pod.flight.velocity_y, 0, "The reinforced wall did not stop the hull.")
			cracks = wall_turf.GetComponent(/datum/component/torn_wall)
			TEST_ASSERT_NOTNULL(cracks, "A reinforced-wall impact did not apply native wall cracks.")
			if(impact == 1)
				var/stage_after_impact = cracks.current_stage
				for(var/tick in 1 to 10)
					TEST_ASSERT(pod.relaymove(pod.pilot, NORTH), "Could not hold thrust against the reinforced wall.")
					advance_flight(pod)
				TEST_ASSERT_EQUAL(cracks.current_stage, stage_after_impact, "Holding thrust advanced reinforced-wall damage without a new impact.")
				TEST_ASSERT_EQUAL(pod.get_integrity(), initial_integrity - 7, "Holding thrust against reinforcement repeatedly damaged the hull.")
				TEST_ASSERT(abs(pod.pilot.get_brute_loss() - initial_pilot_brute - 3.5) < 0.1, "Holding thrust against reinforcement repeatedly injured the pilot.")
		else
			TEST_ASSERT(!wall_turf.density && QDELETED(cracks), "The sixth impact did not destroy reinforcement and release its cracks.")
			TEST_ASSERT_NULL(wall_turf.GetComponent(/datum/component/torn_wall), "The breached reinforced turf retained its crack component.")
			TEST_ASSERT_EQUAL(pod.loc, get_step(origin, NORTH), "The native hull step did not pass through the reinforced-wall breach.")
	allocated |= wall_turf.contents

/// Glass uses native hull exit checks and reinforcement retains its ordinary integrity and armor.
/datum/unit_test/spacepod_vacuum/collision_glass/Run()
	var/list/cases = list(
		list("window" = /obj/structure/window, "speed" = 4, "hull_damage" = 7, "window_damage" = 3.5),
		list("window" = /obj/structure/window, "speed" = 5, "hull_damage" = 16, "breach" = TRUE),
		list("window" = /obj/structure/window/reinforced, "speed" = 4, "hull_damage" = 7, "window_damage" = 0),
		list("window" = /obj/structure/window/reinforced, "speed" = 5, "hull_damage" = 16, "window_damage" = 3.2),
		list("window" = /obj/structure/window/reinforced/plasma, "speed" = 5, "hull_damage" = 16, "window_damage" = 0, "protected" = TRUE),
		list("window" = /obj/structure/window/reinforced, "speed" = 5, "hull_damage" = 16, "window_damage" = 0, "protected" = TRUE, "indestructible" = TRUE),
	)
	for(var/list/scenario as anything in cases)
		var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
		TEST_ASSERT_NOTNULL(pod, "Could not prepare the directional-glass collision fixture.")
		var/mob/living/pilot = pod.pilot
		var/turf/origin = pod.loc
		var/turf/window_turf = locate(pod.x + 1, pod.y + 1, pod.z)
		var/obj/structure/window/window = allocate(scenario["window"], window_turf)
		window.setDir(NORTH)
		if(scenario["indestructible"])
			window.resistance_flags |= INDESTRUCTIBLE
		pod.flight.velocity_y = scenario["speed"]
		var/initial_integrity = pod.get_integrity()
		var/initial_window_integrity = window.get_integrity()
		advance_flight(pod)
		if(scenario["breach"])
			TEST_ASSERT(QDELETED(window), "A high-speed hull step did not shatter ordinary glass blocking exit.")
			TEST_ASSERT_EQUAL(pod.loc, get_step(origin, NORTH), "Shattering the exit window did not let the real hull step complete.")
		else
			TEST_ASSERT(!QDELETED(window), "One impact unexpectedly destroyed the exit glass.")
			TEST_ASSERT_EQUAL(pod.loc, origin, "The pod crossed an intact exit window.")
			TEST_ASSERT(abs(initial_window_integrity - window.get_integrity() - scenario["window_damage"]) < 0.001, "The glass material or native armor did not preserve its expected collision resistance.")
		TEST_ASSERT_EQUAL(initial_integrity - pod.get_integrity(), scenario["hull_damage"], "The exit-window contact lost or duplicated collision damage.")
		if(scenario["window"] == /obj/structure/window/reinforced && scenario["speed"] == 5 && !scenario["protected"])
			window.update_integrity(3)
			pod.flight.velocity_y = 5
			initial_integrity = pod.get_integrity()
			advance_flight(pod)
			TEST_ASSERT(QDELETED(window), "A real impact did not shatter already damaged reinforced glass.")
			TEST_ASSERT_EQUAL(pod.loc, get_step(origin, NORTH), "Native movement did not continue through destroyed reinforced glass.")
			TEST_ASSERT_EQUAL(initial_integrity - pod.get_integrity(), 16, "The reinforced-glass breach lost or duplicated collision damage.")
		allocated |= window_turf.contents
		qdel(window)
		qdel(pod)
		qdel(pilot)

/// Tangential speed survives a glancing collision and does not increase its damage.
/datum/unit_test/spacepod_vacuum/collision_glancing/Run()
	for(var/list/impact as anything in list(list("normal" = 2, "damage" = 0), list("normal" = 4, "damage" = 7)))
		var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
		TEST_ASSERT_NOTNULL(pod, "Could not prepare the glancing-impact fixture.")
		var/mob/living/pilot = pod.pilot
		var/obj/structure/blocker = allocate(__IMPLIED_TYPE__, locate(pod.x + 1, pod.y + 2, pod.z))
		blocker.density = TRUE
		blocker.anchored = TRUE
		pod.flight.velocity_x = 4
		pod.flight.velocity_y = impact["normal"]
		var/start_x = pod.x + pod.flight.offset_x
		var/start_y = pod.y
		var/initial_integrity = pod.get_integrity()
		advance_flight(pod)
		TEST_ASSERT(pod.x + pod.flight.offset_x > start_x, "A glancing collision stopped unobstructed lateral travel.")
		TEST_ASSERT_EQUAL(pod.y, start_y, "A glancing collision clipped through its north blocker.")
		TEST_ASSERT_EQUAL(pod.flight.velocity_x, 4, "A glancing collision removed tangential velocity.")
		TEST_ASSERT_EQUAL(pod.flight.velocity_y, 0, "A glancing collision retained normal velocity.")
		TEST_ASSERT(abs(initial_integrity - pod.get_integrity() - impact["damage"]) < 0.001, "Glancing damage included tangential speed or lost the normal impact.")
		TEST_ASSERT(abs(pilot.get_brute_loss() - impact["damage"] * 0.5) < 0.1, "The pilot's glancing-impact damage included tangential speed or lost the normal impact.")
		qdel(blocker)
		qdel(pod)
		qdel(pilot)

/datum/unit_test/spacepod_vacuum/collision_corner
	/// Observe real damage without replacing or intercepting it.
	var/damage_events = 0

/// Two stopped axes form one impact; holding thrust against that corner cannot repeat the hit.
/datum/unit_test/spacepod_vacuum/collision_corner/Run()
	var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(pod, "Could not prepare the corner-impact fixture.")
	var/obj/structure/east_blocker = allocate(__IMPLIED_TYPE__, locate(pod.x + 2, pod.y + 1, pod.z))
	var/obj/structure/north_blocker = allocate(__IMPLIED_TYPE__, locate(pod.x + 1, pod.y + 2, pod.z))
	east_blocker.density = TRUE
	north_blocker.density = TRUE
	east_blocker.anchored = TRUE
	north_blocker.anchored = TRUE
	pod.flight.velocity_x = 3
	pod.flight.velocity_y = 3
	RegisterSignal(pod, COMSIG_ATOM_TAKE_DAMAGE, PROC_REF(on_collision_damage))
	var/initial_integrity = pod.get_integrity()
	advance_flight(pod)
	TEST_ASSERT_EQUAL(pod.flight.velocity_x, 0, "The corner did not stop eastward motion.")
	TEST_ASSERT_EQUAL(pod.flight.velocity_y, 0, "The corner did not stop northward motion.")
	TEST_ASSERT_EQUAL(damage_events, 1, "Two corner contacts applied more than one damage event in a physics tick.")
	TEST_ASSERT(abs(initial_integrity - pod.get_integrity() - 9) < 0.001, "The corner did not combine its two stopped velocity components into one impact.")
	TEST_ASSERT(abs(pod.pilot.get_brute_loss() - 4.5) < 0.1, "The corner injured the pilot more than once or lost one collision axis.")
	var/integrity_after_impact = pod.get_integrity()
	var/pilot_brute_after_impact = pod.pilot.get_brute_loss()
	for(var/tick in 1 to 20)
		TEST_ASSERT(pod.relaymove(pod.pilot, NORTHEAST), "The intact cabin rejected thrust against its corner.")
		advance_flight(pod)
	TEST_ASSERT_EQUAL(pod.get_integrity(), integrity_after_impact, "Holding thrust against a wall repeatedly damaged the stopped cabin.")
	TEST_ASSERT_EQUAL(damage_events, 1, "Low-speed thrust against the corner emitted additional damage events.")
	TEST_ASSERT_EQUAL(pod.pilot.get_brute_loss(), pilot_brute_after_impact, "Holding thrust against a corner repeatedly injured the pilot.")
	UnregisterSignal(pod, COMSIG_ATOM_TAKE_DAMAGE)

/datum/unit_test/spacepod_vacuum/collision_corner/proc/on_collision_damage(datum/source)
	SIGNAL_HANDLER
	damage_events++

/// The flight controller accelerates the cabin, coasts without fuel and uses native cargo/collision checks.
/datum/unit_test/spacepod_vacuum/flight/Run()
	var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(pod, "Could not board the vacuum flight fixture.")
	TEST_ASSERT_EQUAL(length(pod.locs), 4, "The flight fixture lost its 2x2 footprint.")
	TEST_ASSERT(!pod.has_gravity(), "The flight fixture is not in zero gravity.")
	var/initial_charge = pod.battery.charge
	for(var/tick in 1 to 20)
		TEST_ASSERT(pod.relaymove(pod.pilot, NORTH), "The pilot could not apply forward thrust.")
		advance_flight(pod)
	TEST_ASSERT(pod.flight.velocity_y > 3.9 && pod.flight.velocity_y < 4.1, "One second of forward thrust did not accelerate the cabin to four tiles per second.")
	TEST_ASSERT(abs(pod.flight.velocity_x) < 0.00001, "Forward thrust added lateral velocity.")
	TEST_ASSERT(pod.battery.charge < initial_charge, "Forward acceleration consumed no battery energy.")
	var/obj/item/spacepod_equipment/cargo/ore/cargo = allocate(__IMPLIED_TYPE__, pod)
	TEST_ASSERT(pod.add_equipment(null, cargo, cargo.slot), "Could not install the vacuum ore collector.")
	var/obj/structure/ore_box/ore_box = allocate(__IMPLIED_TYPE__, cargo)
	cargo.storage = ore_box
	var/obj/item/stack/ore/iron/ore = allocate(__IMPLIED_TYPE__, locate(pod.x + 1, pod.y + 2, pod.z))
	allocate(/obj/structure/lattice, get_step(pod, SOUTH))
	var/coast_charge = pod.battery.charge
	var/coast_velocity = pod.flight.velocity_y
	for(var/tick in 1 to 12)
		advance_flight(pod)
	TEST_ASSERT_EQUAL(ore.loc, ore_box, "The coasting cabin did not collect ore beneath its far corner.")
	TEST_ASSERT(abs(pod.flight.velocity_y - coast_velocity) < 0.00001, "Coasting past a lattice changed the cabin's speed.")
	TEST_ASSERT_EQUAL(pod.battery.charge, coast_charge, "Passive flight consumed propulsion energy.")
	var/turf/blocked_position = get_turf(pod)
	var/obj/structure/window/blocker = allocate(__IMPLIED_TYPE__, locate(pod.x + 1, pod.y + 1, pod.z))
	blocker.setDir(NORTH)
	for(var/tick in 1 to 20)
		advance_flight(pod)
	TEST_ASSERT_EQUAL(pod.loc, blocked_position, "Coasting pushed the cabin's far corner through a directional window.")
	TEST_ASSERT(abs(pod.flight.velocity_y) < 0.00001, "A collision retained velocity into the blocking window.")
	var/lateral_start = pod.x + pod.flight.offset_x
	for(var/tick in 1 to 3)
		pod.relaymove(pod.pilot, NORTHEAST)
		advance_flight(pod)
	TEST_ASSERT(pod.flight.velocity_x > 0 && pod.x + pod.flight.offset_x > lateral_start, "A blocked forward axis also stopped unobstructed lateral thrust.")
	TEST_ASSERT(abs(pod.flight.velocity_y) < 0.00001, "Diagonal thrust crossed the blocking window instead of sliding along it.")
	TEST_ASSERT_NULL(pod.drift_handler, "The flight controller also started a competing native drift loop.")

/// Releasing cardinal or diagonal thrust preserves the vector and continuous displacement.
/datum/unit_test/spacepod_vacuum/linear_coast/Run()
	for(var/direction in list(NORTH, NORTHEAST))
		var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
		TEST_ASSERT_NOTNULL(pod, "Could not prepare the [direction] coasting fixture.")
		for(var/tick in 1 to 16)
			TEST_ASSERT(pod.relaymove(pod.pilot, direction), "The [direction] input was rejected.")
			advance_flight(pod)
		var/velocity_x = pod.flight.velocity_x
		var/velocity_y = pod.flight.velocity_y
		TEST_ASSERT(velocity_y > 0 && (direction == NORTH || velocity_x > 0), "The commanded flight did not build the required velocity vector.")
		var/start_x = pod.x + pod.flight.offset_x
		var/start_y = pod.y + pod.flight.offset_y
		var/initial_charge = pod.battery.charge
		for(var/tick in 1 to 10)
			advance_flight(pod)
		TEST_ASSERT(abs(pod.flight.velocity_x - velocity_x) < 0.00001 && abs(pod.flight.velocity_y - velocity_y) < 0.00001, "Releasing [direction] thrust changed the flight velocity.")
		TEST_ASSERT(abs(pod.x + pod.flight.offset_x - start_x - velocity_x * 0.5) < 0.001, "Coasting lost or duplicated horizontal distance.")
		TEST_ASSERT(abs(pod.y + pod.flight.offset_y - start_y - velocity_y * 0.5) < 0.001, "Coasting lost or duplicated vertical distance.")
		TEST_ASSERT_EQUAL(pod.battery.charge, initial_charge, "Releasing [direction] thrust continued consuming propulsion power.")
		qdel(pod)

/// Mouse heading rotates gradually; keyboard thrust follows the hull and brakes require power.
/datum/unit_test/spacepod_vacuum/relative_controls_and_braking/Run()
	var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(pod, "Could not prepare the relative-flight fixture.")
	pod.flight.aim(90)
	advance_flight(pod)
	TEST_ASSERT(pod.flight.heading > 0 && pod.flight.heading < 90, "A new aim direction did not begin a gradual turn.")
	for(var/tick in 1 to 4)
		advance_flight(pod)
	TEST_ASSERT(abs(pod.flight.heading - 90) < 0.001, "The hull did not complete a 90-degree turn within a quarter second.")
	advance_flight(pod)
	TEST_ASSERT_EQUAL(pod.flight.angular_velocity, 0, "The hull kept spinning after reaching its mouse heading.")
	pod.flight.aim(350)
	for(var/tick in 1 to 6)
		advance_flight(pod)
	TEST_ASSERT(abs(pod.flight.heading - 350) < 0.001, "The hull failed to reach the wraparound-turn fixture heading.")
	pod.flight.aim(10)
	advance_flight(pod)
	TEST_ASSERT(abs(pod.flight.heading - 8) < 0.001, "Turning from 350 to 10 degrees took the long route or overshot the target.")
	advance_flight(pod)
	TEST_ASSERT(abs(pod.flight.heading - 10) < 0.001, "The short wraparound turn overshot its target.")
	advance_flight(pod)
	TEST_ASSERT_EQUAL(pod.flight.angular_velocity, 0, "The hull kept spinning after its wraparound turn.")
	pod.flight.aim(90)
	for(var/tick in 1 to 5)
		advance_flight(pod)
	for(var/tick in 1 to 10)
		pod.relaymove(pod.pilot, NORTH)
		advance_flight(pod)
	TEST_ASSERT(pod.flight.velocity_x > 1.8 && abs(pod.flight.velocity_y) < 0.01, "Forward input did not follow the east-facing hull.")
	var/velocity_before_reverse = pod.flight.velocity_x
	for(var/tick in 1 to 5)
		pod.relaymove(pod.pilot, SOUTH)
		advance_flight(pod)
	TEST_ASSERT(abs(velocity_before_reverse - pod.flight.velocity_x - 0.75) < 0.001, "Reverse counter-thrust did not reduce forward velocity by the configured responsive rate.")
	for(var/tick in 1 to 10)
		pod.relaymove(pod.pilot, WEST)
		advance_flight(pod)
	TEST_ASSERT(pod.flight.velocity_y > 1.4 && pod.flight.velocity_y < 1.6, "Left strafe did not accelerate north relative to an east-facing hull.")
	var/charge_before_braking = pod.battery.charge
	pod.flight.toggle_brakes()
	for(var/tick in 1 to 20)
		advance_flight(pod)
	TEST_ASSERT(abs(pod.flight.velocity_x) < 0.00001 && abs(pod.flight.velocity_y) < 0.00001, "Powered brakes did not stop the existing velocity vector within one second.")
	TEST_ASSERT(pod.battery.charge < charge_before_braking, "Braking applied thrust without consuming energy.")
	pod.flight.toggle_brakes()
	for(var/tick in 1 to 10)
		pod.relaymove(pod.pilot, NORTH)
		advance_flight(pod)
	var/unpowered_velocity = pod.flight.velocity_x
	TEST_ASSERT(unpowered_velocity > 0, "The cabin did not resume thrust after releasing its brakes.")
	pod.battery.charge = 0
	pod.flight.toggle_brakes()
	var/start_x = pod.x + pod.flight.offset_x
	for(var/tick in 1 to 10)
		advance_flight(pod)
	TEST_ASSERT(abs(pod.flight.velocity_x - unpowered_velocity) < 0.00001, "Unpowered brakes magically removed existing momentum.")
	TEST_ASSERT(pod.x + pod.flight.offset_x > start_x, "An empty battery froze the coasting cabin.")
	TEST_ASSERT_EQUAL(pod.battery.charge, 0, "Unpowered flight changed the empty battery's charge.")

/// Exercise the real 20 Hz scheduler as well as the deterministic physics cases above.
/datum/unit_test/spacepod_vacuum/flight_subsystem/Run()
	var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(pod, "Could not prepare scheduled flight.")
	START_PROCESSING(SSnewtonian_movement, pod.flight)
	for(var/tick in 1 to 10)
		TEST_ASSERT(pod.relaymove(pod.pilot, NORTH), "The scheduled pilot input was rejected.")
		sleep(world.tick_lag)
	var/coast_velocity = pod.flight.velocity_y
	TEST_ASSERT(coast_velocity > 0.5, "The Newtonian subsystem did not process repeated pilot thrust.")
	var/charge_before_coasting = pod.battery.charge
	var/previous_y = pod.y + pod.flight.offset_y
	var/continuous_steps = 0
	for(var/tick in 1 to 8)
		sleep(world.tick_lag)
		var/current_y = pod.y + pod.flight.offset_y
		if(current_y > previous_y)
			continuous_steps++
		previous_y = current_y
	TEST_ASSERT(continuous_steps >= 6, "Coasting did not update continuously on the movement subsystem's ticks.")
	TEST_ASSERT(abs(pod.flight.velocity_y - coast_velocity) < 0.00001, "The real scheduler slowed down flight after input stopped.")
	TEST_ASSERT_EQUAL(pod.battery.charge, charge_before_coasting, "Scheduled coasting continued drawing propulsion energy.")
	var/datum/spacepod_flight/flight = pod.flight
	qdel(pod)
	TEST_ASSERT(QDELETED(flight), "Deleting the cabin retained its flight controller.")
	TEST_ASSERT(!(flight in SSnewtonian_movement.processing), "Deleting the cabin retained scheduled flight processing.")

/// No legacy ion particles may accompany the attached flame.
/datum/unit_test/spacepod_vacuum/proc/get_thrust_particles(list/turfs)
	if(isnull(turfs))
		turfs = vacuum_block.reserved_turfs
	var/list/particles = list()
	for(var/turf/tile as anything in turfs)
		for(var/obj/effect/particle_effect/ion_trails/particle in tile)
			if(!QDELETED(particle))
				particles += particle
	return particles

/// Inspect the attached appearance rather than treating its state flag as proof of rendering.
/datum/unit_test/spacepod_vacuum/proc/get_thruster_flames(obj/vehicle/sealed/spacepod/pod)
	var/list/flames = list()
	for(var/mutable_appearance/overlay as anything in pod.overlays)
		if(overlay.icon == 'icons/effects/effects.dmi' && overlay.icon_state == "jetfire")
			flames += overlay
	return flames

/// The main engine's actual flame stays behind the hull and follows paid forward input only.
/datum/unit_test/spacepod_vacuum/thruster_flame/Run()
	var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(pod, "Could not prepare the attached-flame fixture.")
	TEST_ASSERT_EQUAL(length(get_thruster_flames(pod)), 0, "An idle cabin has an attached engine flame.")
	for(var/tick in 1 to 3)
		TEST_ASSERT(pod.relaymove(pod.pilot, NORTH), "The pilot could not fire the main engine.")
		advance_flight(pod)
		TEST_ASSERT_EQUAL(length(get_thruster_flames(pod)), 1, "Forward thrust lost or stacked its attached flame.")
	var/list/facings = list(
		list("dir" = NORTH, "x" = 16, "y" = -4, "angle" = 0),
		list("dir" = EAST, "x" = -4, "y" = 16, "angle" = 90),
		list("dir" = SOUTH, "x" = 16, "y" = 36, "angle" = 180),
		list("dir" = WEST, "x" = 36, "y" = 16, "angle" = 270),
	)
	for(var/list/facing as anything in facings)
		pod.setDir(facing["dir"])
		var/list/flames = get_thruster_flames(pod)
		TEST_ASSERT_EQUAL(length(flames), 1, "Turning the cabin lost or duplicated its attached flame.")
		var/mutable_appearance/flame = flames[1]
		TEST_ASSERT_EQUAL(flame.dir, NORTH, "The flame's sprite direction compounds the hull's rotation.")
		TEST_ASSERT_EQUAL(flame.pixel_x, facing["x"], "The flame is not centered behind this hull facing.")
		TEST_ASSERT_EQUAL(flame.pixel_y, facing["y"], "The flame is not centered behind this hull facing.")
		var/matrix/expected = matrix().Turn(facing["angle"])
		var/matrix/actual = flame.transform || matrix()
		TEST_ASSERT_EQUAL(actual.a, expected.a, "The flame has the wrong local rotation.")
		TEST_ASSERT_EQUAL(actual.b, expected.b, "The flame has the wrong local rotation.")
		TEST_ASSERT_EQUAL(actual.d, expected.d, "The flame has the wrong local rotation.")
		TEST_ASSERT_EQUAL(actual.e, expected.e, "The flame has the wrong local rotation.")
		TEST_ASSERT(!(flame.appearance_flags & RESET_TRANSFORM), "The attached flame ignores continuous hull rotation.")
	pod.update_integrity(pod.max_integrity / 2)
	var/has_damage_overlay = FALSE
	for(var/mutable_appearance/overlay as anything in pod.overlays)
		if(overlay.icon_state == "pod_damage")
			has_damage_overlay = TRUE
	TEST_ASSERT(has_damage_overlay, "The damaged hull did not rebuild its damage appearance.")
	TEST_ASSERT_EQUAL(length(get_thruster_flames(pod)), 1, "Rebuilding the damage appearance removed the active flame.")
	advance_flight(pod)
	TEST_ASSERT(pod.flight.velocity_y > 0, "The released-input fixture did not keep coasting.")
	TEST_ASSERT_EQUAL(length(get_thruster_flames(pod)), 0, "Releasing forward thrust left an attached flame on the coasting hull.")
	for(var/direction in list(EAST, SOUTH))
		TEST_ASSERT(pod.relaymove(pod.pilot, direction), "A powered secondary thruster input was rejected.")
		advance_flight(pod)
		TEST_ASSERT_EQUAL(length(get_thruster_flames(pod)), 0, "Side or reverse thrust incorrectly ignited the rear main-engine flame.")
	TEST_ASSERT(pod.relaymove(pod.pilot, NORTHEAST), "Combined forward and side thrust was rejected.")
	advance_flight(pod)
	TEST_ASSERT_EQUAL(length(get_thruster_flames(pod)), 1, "Combined forward and side thrust lost the main-engine flame.")

/// The scheduler must clear the last flame even when a blocked thrust tick leaves no velocity.
/datum/unit_test/spacepod_vacuum/blocked_flame_release/Run()
	var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(pod, "Could not prepare the blocked-flame fixture.")
	var/obj/structure/blocker = allocate(__IMPLIED_TYPE__, locate(pod.x + 1, pod.y + 2, pod.z))
	blocker.density = TRUE
	blocker.anchored = TRUE
	TEST_ASSERT(pod.relaymove(pod.pilot, NORTH), "Forward thrust against a blocker was rejected.")
	var/deadline = world.time + 1 SECONDS
	while(!length(get_thruster_flames(pod)) && world.time < deadline)
		sleep(world.tick_lag)
	TEST_ASSERT_EQUAL(length(get_thruster_flames(pod)), 1, "The actual movement processor did not show a flame for paid thrust into a wall.")
	TEST_ASSERT_EQUAL(pod.flight.velocity_y, 0, "The flame fixture did not actually collide with its blocker.")
	while(length(get_thruster_flames(pod)) && world.time < deadline)
		sleep(world.tick_lag)
	TEST_ASSERT_EQUAL(length(get_thruster_flames(pod)), 0, "The last blocked input left a permanent flame after the processor became idle.")
	TEST_ASSERT_NULL(pod.thruster_flame_timer, "Vacuum flight incorrectly uses a ground-step flame timer.")

/// Paid thrust uses cabin sound and its attached flame, without the removed ion-particle trail.
/datum/unit_test/spacepod_vacuum/thrust_effects/Run()
	var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(pod, "Could not prepare the flight-effects fixture.")
	for(var/tick in 1 to 20)
		TEST_ASSERT(pod.relaymove(pod.pilot, NORTH), "Powered flight input was rejected.")
		advance_flight(pod)
	TEST_ASSERT_EQUAL(length(get_thrust_particles()), 0, "Forward thrust recreated the removed ion-particle trail.")
	TEST_ASSERT_EQUAL(length(get_thruster_flames(pod)), 1, "Removing the ion trail also removed the paid main-engine flame.")
	var/datum/looping_sound/spacepod_engine/engine_sound = pod.engine_sounds[pod.pilot]
	TEST_ASSERT_NOTNULL(engine_sound, "Paid thrust did not create cabin engine sound.")
	TEST_ASSERT(engine_sound.is_active(), "Paid thrust left its engine sound inactive.")
	for(var/tick in 1 to 10)
		advance_flight(pod)
	TEST_ASSERT_EQUAL(length(get_thrust_particles()), 0, "Coasting recreated the removed ion-particle trail.")
	TEST_ASSERT(QDELETED(engine_sound) && !length(pod.engine_sounds), "Releasing thrust left engine sound playing during passive flight.")
	pod.battery.charge = 0
	TEST_ASSERT(!pod.relaymove(pod.pilot, NORTH), "An empty battery accepted new thrust.")
	advance_flight(pod)
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 0, "Unpowered flight started engine sound.")
	TEST_ASSERT_EQUAL(length(get_thruster_flames(pod)), 0, "Unpowered flight retained the attached flame.")

/// Gravity uses the same paid flame and cabin engine loop, without a detached particle trail.
/datum/unit_test/spacepod_vacuum/thrust_on_floor/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, origin)
	STOP_PROCESSING(SSobj, pod)
	pod.enter_delay = 0
	pod.setDir(NORTH)
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	TEST_ASSERT(pod.mob_try_enter(pilot), "The station-floor test pilot could not board the pod.")
	TEST_ASSERT(pod.has_gravity(), "The station-floor fixture does not have normal gravity.")
	var/list/floor_turfs = get_area_turfs(get_area(origin))
	TEST_ASSERT(pod.relaymove(pilot, NORTH), "A powered movement across station floor failed.")
	advance_flight(pod)
	var/list/particles = get_thrust_particles(floor_turfs)
	allocated |= particles
	TEST_ASSERT_EQUAL(length(particles), 0, "Movement on station floor created a space exhaust trail.")
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 1, "Paid gravity thrust did not start the cabin engine loop.")
	TEST_ASSERT_NULL(pod.drift_handler, "A powered movement in gravity started a space drift loop.")
	TEST_ASSERT_EQUAL(length(get_thruster_flames(pod)), 1, "A powered ground step did not display its attached engine flame.")
	TEST_ASSERT_NULL(pod.thruster_flame_timer, "Continuous gravity flight retained a tile-step flame timer.")
	advance_flight(pod)
	TEST_ASSERT_EQUAL(length(get_thruster_flames(pod)), 0, "Releasing gravity thrust left an attached engine flame.")
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 0, "Releasing gravity thrust left cabin engine sound playing.")

/// Continuous thrust refreshes the same cabin channels across the original sample's lifetime.
/datum/unit_test/spacepod_vacuum/engine_sound_motion/Run()
	var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(pod, "Could not prepare the engine-sound fixture.")
	pod.max_passengers = 1
	pod.max_occupants = 2
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(pod, SOUTH))
	TEST_ASSERT(pod.mob_try_enter(passenger), "The sound-test passenger could not board.")
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 0, "An idle cabin allocated engine sound channels.")
	pod.relaymove(pod.pilot, EAST)
	advance_flight(pod)
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 2, "Paid thrust did not create one loop per occupant.")
	var/list/initial_sounds = pod.engine_sounds.Copy()
	var/list/sound_channels = list()
	for(var/mob/living/listener as anything in initial_sounds)
		var/datum/looping_sound/spacepod_engine/engine_sound = initial_sounds[listener]
		TEST_ASSERT(engine_sound.is_active() && engine_sound.direct, "The cabin loop is inactive or not directed to its listener.")
		TEST_ASSERT_EQUAL(engine_sound.parent, listener, "A cabin loop is attached to the wrong listener.")
		TEST_ASSERT_EQUAL(engine_sound.volume, 15, "The engine sound changed its original volume.")
		TEST_ASSERT_NOTNULL(engine_sound.sound_channel, "A cabin loop has no allocated sound channel.")
		TEST_ASSERT_EQUAL(SSsounds.using_channels[num2text(engine_sound.sound_channel)], engine_sound, "A cabin channel is not owned by its native sound datum.")
		sound_channels[engine_sound] = engine_sound.sound_channel
	TEST_ASSERT(!pod.relaymove(passenger, EAST), "A passenger operated the thrusters.")
	var/flight_started = world.time
	for(var/cycle in 1 to 16)
		for(var/direction in list(EAST, WEST))
			for(var/tick in 1 to 5)
				TEST_ASSERT(pod.relaymove(pod.pilot, direction), "Sustained pilot input was rejected.")
				advance_flight(pod)
				TEST_ASSERT_EQUAL(length(pod.engine_sounds), 2, "Sustained thrust layered or lost cabin sound loops.")
				for(var/mob/living/listener as anything in initial_sounds)
					TEST_ASSERT_EQUAL(pod.engine_sounds[listener], initial_sounds[listener], "Repeated thrust replaced an active cabin loop.")
				sleep(world.tick_lag)
	TEST_ASSERT(world.time - flight_started > 6.2 SECONDS, "Sustained thrust did not exceed the original sound sample's length.")
	pod.mob_exit(passenger, silent = TRUE)
	var/datum/looping_sound/spacepod_engine/passenger_sound = initial_sounds[passenger]
	TEST_ASSERT(QDELETED(passenger_sound), "A departing passenger retained their cabin loop.")
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 1, "A departing passenger stopped or retained the wrong cabin loops.")
	var/mob/living/pilot = pod.pilot
	TEST_ASSERT_EQUAL(pod.engine_sounds[pilot], initial_sounds[pilot], "A departing passenger replaced the pilot's loop.")
	pod.mob_exit(pilot, silent = TRUE)
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 0, "A departing pilot left cabin sound playing.")
	TEST_ASSERT_NULL(pod.engine_sound_timer, "Losing the pilot retained an engine sound timer.")
	for(var/datum/looping_sound/spacepod_engine/engine_sound as anything in sound_channels)
		TEST_ASSERT(QDELETED(engine_sound), "The completed flight retained a live cabin loop.")
		TEST_ASSERT(SSsounds.using_channels[num2text(sound_channels[engine_sound])] != engine_sound, "The completed flight retained a reserved audio channel.")
		TEST_ASSERT(!length(SSsounds.using_channels_by_datum[engine_sound]), "The completed flight leaked managed sound channel ownership.")

/// Interrupt actual engine playback and verify native datum/channel cleanup.
/datum/unit_test/spacepod_vacuum/engine_sound_interruptions/Run()
	for(var/scenario in list("blocked", "empty cell", "removed cell", "EMP", "pilot exit", "logout", "reset", "meltdown", "deletion"))
		var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
		TEST_ASSERT_NOTNULL(pod, "Could not prepare the [scenario] interruption fixture.")
		for(var/tick in 1 to 20)
			pod.relaymove(pod.pilot, NORTH)
			advance_flight(pod)
		var/datum/looping_sound/spacepod_engine/engine_sound = pod.engine_sounds[pod.pilot]
		TEST_ASSERT_NOTNULL(engine_sound, "The [scenario] fixture has no cabin engine loop.")
		TEST_ASSERT(engine_sound.is_active(), "The [scenario] fixture has no active cabin engine sound.")
		TEST_ASSERT_EQUAL(length(get_thruster_flames(pod)), 1, "The [scenario] fixture has no actual attached engine flame.")
		var/channel = engine_sound.sound_channel
		var/sound_stop_timer = pod.engine_sound_timer
		var/obj/item/stock_parts/power_store/cell/cell = pod.battery
		var/mob/living/pilot = pod.pilot
		var/datum/spacepod_flight/flight = pod.flight
		switch(scenario)
			if("blocked")
				var/obj/structure/window/blocker = allocate(__IMPLIED_TYPE__, locate(pod.x + 1, pod.y + 1, pod.z))
				blocker.setDir(NORTH)
				for(var/tick in 1 to 20)
					pod.relaymove(pilot, NORTH)
					advance_flight(pod)
				TEST_ASSERT(abs(pod.flight.velocity_y) < 0.00001, "Blocked thrust crossed a real directional window.")
				qdel(blocker)
			if("empty cell")
				cell.charge = 0
				TEST_ASSERT(!pod.relaymove(pilot, NORTH), "An empty cell accepted new thrust during engine playback.")
			if("removed cell")
				cell.forceMove(get_step(pod, SOUTH))
			if("EMP")
				pod.emp_act(EMP_HEAVY)
			if("pilot exit")
				pod.mob_exit(pilot, silent = TRUE)
			if("logout")
				pilot.Logout()
			if("reset")
				pod.flight.reset_motion()
			if("meltdown")
				pod.atom_destruction(BOMB)
			if("deletion")
				qdel(pod)
		if(scenario == "meltdown")
			var/deleted_immediately = QDELETED(pod) && QDELETED(flight)
			var/explosion_deadline = world.time + 8 SECONDS
			while(SSexplosions.is_exploding() && world.time < explosion_deadline)
				stoplag(1)
			allocated |= get_wreckage()
			TEST_ASSERT(!SSexplosions.is_exploding(), "The immediate core blast did not drain before the next interruption fixture.")
			TEST_ASSERT(deleted_immediately, "Core destruction did not immediately delete the cabin and flight controller.")
		if(!QDELETED(pod))
			if(scenario != "blocked" && scenario != "empty cell")
				TEST_ASSERT_EQUAL(length(get_thruster_flames(pod)), 0, "[scenario] did not immediately remove the attached engine flame.")
			advance_flight(pod)
		TEST_ASSERT(QDELETED(engine_sound), "[scenario] did not delete the active cabin loop.")
		TEST_ASSERT(SSsounds.using_channels[num2text(channel)] != engine_sound, "[scenario] retained the native engine channel.")
		TEST_ASSERT(!length(SSsounds.using_channels_by_datum[engine_sound]), "[scenario] leaked managed engine channel ownership.")
		TEST_ASSERT(isnull(timeleft(sound_stop_timer)), "[scenario] retained the engine sound timer.")
		if(!QDELETED(pod))
			TEST_ASSERT_EQUAL(length(pod.engine_sounds), 0, "[scenario] left sound listeners registered in the cabin.")
			TEST_ASSERT_EQUAL(length(get_thruster_flames(pod)), 0, "[scenario] left an attached engine flame after thrust stopped.")
			TEST_ASSERT_NULL(pod.thruster_flame_timer, "[scenario] retained an attached-flame timer.")
			qdel(pod)
		qdel(cell)
		qdel(pilot)

/// Queued input must be revalidated after pilot loss, EMP or depletion before it can accelerate.
/datum/unit_test/spacepod_vacuum/flight_control_denials/Run()
	for(var/scenario in list("empty cell", "EMP", "pilot exit"))
		var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
		TEST_ASSERT_NOTNULL(pod, "Could not prepare the [scenario] control fixture.")
		pod.max_passengers = 1
		pod.max_occupants = 2
		var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(pod, SOUTH))
		TEST_ASSERT(pod.mob_try_enter(passenger), "Could not board the control-test passenger.")
		TEST_ASSERT(!pod.relaymove(passenger, NORTH), "A passenger queued flight input.")
		advance_flight(pod)
		TEST_ASSERT_EQUAL(pod.flight.velocity_y, 0, "Rejected passenger input accelerated the cabin.")
		TEST_ASSERT(pod.relaymove(pod.pilot, NORTH), "The valid pilot input was rejected before invalidation.")
		TEST_ASSERT(pod.flight.aim(90), "The valid pilot aim was rejected before invalidation.")
		switch(scenario)
			if("empty cell")
				pod.battery.charge = 0
			if("EMP")
				pod.emp_act(EMP_HEAVY)
			if("pilot exit")
				pod.mob_exit(pod.pilot, silent = TRUE)
		var/charge_before_tick = pod.battery.charge
		advance_flight(pod)
		TEST_ASSERT_EQUAL(pod.flight.velocity_y, 0, "Queued input accelerated the cabin after [scenario].")
		TEST_ASSERT_EQUAL(pod.flight.angular_velocity, 0, "Queued aim turned the cabin after [scenario].")
		TEST_ASSERT_EQUAL(pod.battery.charge, charge_before_tick, "Invalidated input consumed propulsion energy after [scenario].")
		qdel(pod)

/// Exercise the human's real lungs and environmental Life path without a suit or internals.
/datum/unit_test/spacepod_vacuum/human_breathing/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve a vacuum enclosure for breathing.")
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
	TEST_ASSERT_NULL(pilot.internal, "The breathing subject unexpectedly has personal internals.")
	TEST_ASSERT_NULL(pilot.wear_mask, "The breathing subject unexpectedly has a breathing mask.")
	TEST_ASSERT_NULL(pilot.wear_suit, "The breathing subject unexpectedly has a protective suit.")
	TEST_ASSERT(!HAS_TRAIT(pilot, TRAIT_NOBREATH) && !HAS_TRAIT(pilot, TRAIT_GODMODE) && !HAS_TRAIT(pilot, TRAIT_NO_BREATHLESS_DAMAGE), "The breathing subject is immune to vacuum suffocation.")
	TEST_ASSERT(pod.mob_try_enter(pilot), "The breathing subject could not board the cabin.")
	TEST_ASSERT_EQUAL(vacuum_origin.return_air().total_moles(), 0, "The exterior of the cabin is not a vacuum.")
	var/starting_oxygen = pod.cabin_air.moles[/datum/gas/oxygen]
	pilot.Life(SSMOBS_DT)
	for(var/breath in 1 to 6)
		pilot.breathe(SSMOBS_DT)
		var/exhaled_co2 = pod.cabin_air.moles[/datum/gas/carbon_dioxide] || 0
		TEST_ASSERT(exhaled_co2 > 0, "Native human exhalation did not return CO2 to the cabin before life-support processing.")
		pod.process(SSMOBS_DT)
		TEST_ASSERT((pod.cabin_air.moles[/datum/gas/carbon_dioxide] || 0) < exhaled_co2, "Life support did not remove native human exhalation from the cabin.")
	TEST_ASSERT(!pilot.failed_last_breath && !pilot.has_alert(ALERT_NOT_ENOUGH_OXYGEN), "A human cannot breathe cabin air while the pod is in space.")
	TEST_ASSERT_EQUAL(pilot.get_oxy_loss(), 0, "A healthy human accumulated oxygen damage inside the pressurized cabin.")
	TEST_ASSERT(pod.cabin_air.moles[/datum/gas/oxygen] < starting_oxygen, "Native human breathing did not consume the cabin's oxygen.")
	TEST_ASSERT((pod.cabin_air.moles[/datum/gas/carbon_dioxide] || 0) <= MOLAR_ACCURACY, "The powered filter retained CO2 after an ordinary human breath.")
	TEST_ASSERT(pod.toggle_internal_tank(pilot), "The pilot could not switch to exterior air.")
	TEST_ASSERT_EQUAL(pod.return_air(), vacuum_origin.return_air(), "Exterior mode does not expose the actual space atmosphere.")
	var/oxygen_damage_before = pilot.get_oxy_loss()
	for(var/breath in 1 to 3)
		pilot.breathe(SSMOBS_DT)
	TEST_ASSERT(pilot.failed_last_breath && pilot.has_alert(ALERT_NOT_ENOUGH_OXYGEN), "Switching to exterior vacuum did not cause suffocation.")
	TEST_ASSERT(pilot.get_oxy_loss() > oxygen_damage_before, "The human's real lungs did not apply oxygen damage in exterior vacuum mode.")
	var/oxygen_damage_in_vacuum = pilot.get_oxy_loss()
	TEST_ASSERT(pod.toggle_internal_tank(pilot), "A conscious pilot could not reconnect the cabin's internal air supply.")
	pilot.breathe(SSMOBS_DT)
	TEST_ASSERT(!pilot.failed_last_breath && !pilot.has_alert(ALERT_NOT_ENOUGH_OXYGEN), "Reconnecting cabin air failed to restore native human breathing.")
	TEST_ASSERT(pilot.get_oxy_loss() < oxygen_damage_in_vacuum, "Breathing cabin air did not begin healing vacuum hypoxia.")

/// A real, limited tank may equalize with the cabin but cannot manufacture an atmosphere.
/datum/unit_test/spacepod_vacuum/finite_tank/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve a vacuum enclosure for the finite tank.")
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	var/datum/gas_mixture/tank_air = pod.internal_tank.return_air()
	qdel(pod.cabin_air.remove_ratio(1))
	qdel(tank_air.remove_ratio(1))
	var/limited_moles = 0.2 * ONE_ATMOSPHERE * pod.cabin_air.volume / (R_IDEAL_GAS_EQUATION * T20C)
	tank_air.set_gas(/datum/gas/oxygen, limited_moles * O2STANDARD)
	tank_air.set_gas(/datum/gas/nitrogen, limited_moles * N2STANDARD)
	var/initial_tank_moles = tank_air.total_moles()
	for(var/step in 1 to 24)
		var/before = tank_air.total_moles() + pod.cabin_air.total_moles()
		pod.give_air()
		var/after = tank_air.total_moles() + pod.cabin_air.total_moles()
		TEST_ASSERT(abs(before - after) <= MAXIMUM_ERROR_GAS_REMOVAL, "A finite-tank regulator step created or destroyed more gas than native quantization permits.")
	TEST_ASSERT(tank_air.total_moles() < initial_tank_moles, "Refilling the cabin did not consume the real tank's finite gas supply.")
	TEST_ASSERT(pod.cabin_air.total_moles() > 0, "The finite tank did not transfer any gas into the empty cabin.")
	var/maximum_possible_pressure = initial_tank_moles * R_IDEAL_GAS_EQUATION * T20C / pod.cabin_air.volume
	var/pressure_tolerance = MAXIMUM_ERROR_GAS_REMOVAL * R_IDEAL_GAS_EQUATION * T20C / pod.cabin_air.volume
	TEST_ASSERT(pod.cabin_air.return_pressure() <= maximum_possible_pressure + pressure_tolerance, "The tank produced cabin pressure beyond what its initial gas supply could provide.")
	TEST_ASSERT(pod.cabin_air.return_pressure() < ONE_ATMOSPHERE, "An insufficient gas supply somehow filled the cabin to one atmosphere.")
	qdel(pod.cabin_air.remove_ratio(1))
	qdel(tank_air.remove_ratio(1))
	for(var/step in 1 to 8)
		pod.process(SSMOBS_DT)
	TEST_ASSERT_EQUAL(pod.cabin_air.total_moles(), 0, "An exhausted tank regenerated gas in an empty cabin.")
	TEST_ASSERT_EQUAL(tank_air.total_moles(), 0, "An exhausted tank regenerated its own gas supply.")

/// Excess pressure must vent into real space, while temperature regulation uses cabin air.
/datum/unit_test/spacepod_vacuum/pressure_and_temperature/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve a vacuum enclosure for pressure regulation.")
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	pod.cabin_air.set_gas(/datum/gas/oxygen, 2 * ONE_ATMOSPHERE * O2STANDARD * pod.cabin_air.volume / (R_IDEAL_GAS_EQUATION * T20C))
	pod.cabin_air.set_gas(/datum/gas/nitrogen, 2 * ONE_ATMOSPHERE * N2STANDARD * pod.cabin_air.volume / (R_IDEAL_GAS_EQUATION * T20C))
	var/datum/gas_mixture/tank_air = pod.internal_tank.return_air()
	var/tank_before = tank_air.total_moles()
	var/cabin_before = pod.cabin_air.total_moles()
	pod.process(SSMOBS_DT)
	var/pressure_tolerance = MAXIMUM_ERROR_GAS_REMOVAL * R_IDEAL_GAS_EQUATION * T20C / pod.cabin_air.volume
	TEST_ASSERT(abs(pod.cabin_air.return_pressure() - ONE_ATMOSPHERE) <= pressure_tolerance, "An overpressurized cabin was not vented back to one atmosphere.")
	TEST_ASSERT(pod.cabin_air.total_moles() < cabin_before, "Overpressure correction did not remove gas from the cabin.")
	TEST_ASSERT_EQUAL(tank_air.total_moles(), tank_before, "Venting an overpressurized cabin consumed gas from its supply tank.")
	TEST_ASSERT_EQUAL(vacuum_origin.return_air().total_moles(), 0, "Venting into space left a persistent atmosphere outside the pod.")
	pod.cabin_air.temperature = T20C + 40
	var/hot_temperature = pod.cabin_air.temperature
	pod.process(SSMOBS_DT)
	TEST_ASSERT(pod.cabin_air.temperature < hot_temperature && pod.cabin_air.temperature >= T20C, "The cabin regulator did not cool overheated cabin air toward its target.")
	pod.cabin_air.temperature = T20C - 40
	var/cold_temperature = pod.cabin_air.temperature
	pod.process(SSMOBS_DT)
	TEST_ASSERT(pod.cabin_air.temperature > cold_temperature && pod.cabin_air.temperature <= T20C, "The cabin regulator did not warm cold cabin air toward its target.")
	TEST_ASSERT(pod.cabin_air.temperature > vacuum_origin.return_temperature(), "The cabin temperature followed exterior vacuum instead of its internal regulator.")

/// A real mining volley must drill a real ore wall through native projectile processing.
/datum/unit_test/spacepod_vacuum/mining/Run()
	TEST_ASSERT_NOTNULL(vacuum_block, "Could not reserve a vacuum enclosure for pod mining.")
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
	TEST_ASSERT(pod.mob_try_enter(pilot), "The mining pilot could not board a real pod in space.")
	pod.setDir(EAST)
	var/obj/item/spacepod_equipment/weaponry/mining_laser_basic/weapon = allocate(__IMPLIED_TYPE__, pod)
	TEST_ASSERT(pod.add_equipment(null, weapon, "weapon_system"), "The real mining accelerator could not be installed in the pod.")
	TEST_ASSERT(!pod.has_gravity(), "The mining pod is not in actual zero-gravity space.")
	var/turf/target_space = locate(vacuum_origin.x + 3, vacuum_origin.y, vacuum_origin.z)
	TEST_ASSERT(target_space in vacuum_block.reserved_turfs, "The mining target is outside the private test reservation.")
	var/turf/closed/mineral/iron/target = target_space.ChangeTurf(/turf/closed/mineral/iron)
	var/expected_ore = target.mineral_amt
	var/target_x = target.x
	var/target_y = target.y
	var/target_z = target.z
	var/initial_hull = pod.get_integrity()
	var/initial_pilot_brute = pilot.get_brute_loss()
	var/initial_charge = pod.battery.charge
	TEST_ASSERT(pod.fireWeapon(pilot), "A charged mining accelerator could not fire from its real pilot controls.")
	TEST_ASSERT_EQUAL(pod.battery.charge, initial_charge - weapon.shot_cost * SPACEPOD_ENERGY_UNIT, "A mining volley consumed the wrong amount of real battery power.")
	// Let SSprojectiles move and impact both barrels; do not invoke impact or mining callbacks.
	var/deadline = world.time + 3 SECONDS
	var/projectiles_remaining = TRUE
	while(projectiles_remaining && world.time < deadline)
		projectiles_remaining = FALSE
		for(var/turf/tile as anything in vacuum_block.reserved_turfs)
			for(var/obj/projectile/projectile in tile)
				if(projectile.firer == pod && !QDELETED(projectile))
					projectiles_remaining = TRUE
		if(projectiles_remaining)
			sleep(0.1 SECONDS)
	TEST_ASSERT(!projectiles_remaining, "The real mining volley did not finish processing within three seconds.")
	var/turf/mined_turf = locate(target_x, target_y, target_z)
	TEST_ASSERT(!ismineralturf(mined_turf) && isopenturf(mined_turf), "Real mining projectiles failed to drill the iron-bearing mineral wall.")
	var/obj/item/stack/ore/iron/ore = locate() in mined_turf
	TEST_ASSERT_NOTNULL(ore, "Drilling the real mineral wall did not produce an iron ore stack.")
	TEST_ASSERT_EQUAL(ore.get_amount(), expected_ore, "The mined ore amount differs from the real mineral wall's yield.")
	TEST_ASSERT_EQUAL(pod.get_integrity(), initial_hull, "The pod's own mining volley damaged its hull.")
	TEST_ASSERT_EQUAL(pilot.get_brute_loss(), initial_pilot_brute, "The pod's own mining volley struck its pilot.")
	TEST_ASSERT_EQUAL(pilot.loc, pod, "Mining ejected the pilot from the cabin.")

/// The far leading hull corner hits standing people, with safe contact and speed-scaled injury.
/datum/unit_test/spacepod_vacuum/runover_speed/Run()
	for(var/list/impact as anything in list(list("speed" = 3, "damage" = 0), list("speed" = 4, "damage" = 7), list("speed" = 5, "damage" = 16)))
		var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
		TEST_ASSERT_NOTNULL(pod, "Could not prepare the run-over speed fixture.")
		var/turf/origin = pod.loc
		var/turf/victim_turf = locate(pod.x + 1, pod.y + 2, pod.z)
		var/mob/living/carbon/human/consistent/victim = allocate(__IMPLIED_TYPE__, victim_turf)
		TEST_ASSERT(victim.density && victim.body_position == STANDING_UP, "The exterior victim was not standing in the hull's path.")
		pod.flight.velocity_y = impact["speed"]
		advance_flight(pod)
		TEST_ASSERT(abs(victim.get_brute_loss() - impact["damage"]) < 0.4, "Speed [impact["speed"]] inflicted the wrong run-over damage.")
		TEST_ASSERT_EQUAL(victim.loc, victim_turf, "The collision threw or relocated the exterior victim.")
		if(impact["speed"] == 3)
			TEST_ASSERT(!victim.IsKnockdown(), "Safe-speed contact knocked a person down.")
			TEST_ASSERT_EQUAL(pod.loc, origin, "Safe-speed contact crossed a standing person.")
		else
			TEST_ASSERT(victim.IsKnockdown() && victim.body_position == LYING_DOWN, "A fast collision did not knock the exterior victim prone.")
			TEST_ASSERT_EQUAL(victim.AmountKnockdown(), impact["speed"] == 4 ? 1 SECONDS : 2 SECONDS, "Run-over knockdown did not scale with impact speed.")
			TEST_ASSERT_EQUAL(pod.loc, get_step(origin, NORTH), "The checked native hull step did not pass over the knocked-down victim.")
		qdel(victim)
		qdel(pod.pilot)
		qdel(pod)

/// Real clothing armor softens the impact, while native godmode prevents both injury and knockdown.
/datum/unit_test/spacepod_vacuum/runover_protection/Run()
	for(var/godmode in list(FALSE, TRUE))
		var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
		TEST_ASSERT_NOTNULL(pod, "Could not prepare the protected run-over fixture.")
		var/turf/origin = pod.loc
		var/mob/living/carbon/human/consistent/victim = allocate(__IMPLIED_TYPE__, locate(pod.x + 1, pod.y + 2, pod.z))
		if(godmode)
			ADD_TRAIT(victim, TRAIT_GODMODE, TRAIT_GENERIC)
		else
			var/obj/item/clothing/suit/armor/riot/suit = allocate(__IMPLIED_TYPE__, victim.loc)
			var/obj/item/clothing/head/helmet/toggleable/riot/helmet = allocate(__IMPLIED_TYPE__, victim.loc)
			TEST_ASSERT(victim.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "Could not equip real riot body armor.")
			TEST_ASSERT(victim.equip_to_slot_if_possible(helmet, ITEM_SLOT_HEAD), "Could not equip the real riot helmet.")
			TEST_ASSERT_EQUAL(victim.getarmor(null, MELEE), 50, "The clothing fixture does not provide uniform melee protection.")
		pod.flight.velocity_y = 5
		advance_flight(pod)
		if(godmode)
			TEST_ASSERT_EQUAL(victim.get_brute_loss(), 0, "A run-over bypassed native godmode damage immunity.")
			TEST_ASSERT(!victim.IsKnockdown() && victim.density, "A run-over bypassed native godmode knockdown immunity.")
			TEST_ASSERT_EQUAL(pod.loc, origin, "The pod crossed a victim who remained standing.")
		else
			TEST_ASSERT(abs(victim.get_brute_loss() - 8) < 0.4, "The run-over ignored or applied melee armor more than once.")
			TEST_ASSERT(victim.IsKnockdown(), "Armor incorrectly prevented the native collision knockdown.")
			TEST_ASSERT_EQUAL(pod.loc, get_step(origin, NORTH), "The pod did not pass over the armored prone victim.")
		qdel(victim)
		qdel(pod.pilot)
		qdel(pod)

/datum/unit_test/spacepod_vacuum/runover_repeat
	/// Count the real damage entry point without replacing or cancelling it.
	var/damage_events = 0

/// One resistant exterior victim can block both diagonal halves, but receives only one hit.
/datum/unit_test/spacepod_vacuum/runover_repeat/Run()
	var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(pod, "Could not prepare the repeated run-over fixture.")
	// Isolate unrelated random pilot fractures from the later held-thrust check.
	ADD_TRAIT(pod.pilot, TRAIT_NEVER_WOUNDED, TRAIT_GENERIC)
	var/turf/origin = pod.loc
	var/mob/living/carbon/human/consistent/victim = allocate(__IMPLIED_TYPE__, get_step(origin, NORTHEAST))
	victim.status_flags &= ~CANKNOCKDOWN
	RegisterSignal(victim, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_victim_damage))
	pod.flight.velocity_x = 4
	pod.flight.velocity_y = 4
	advance_flight(pod)
	TEST_ASSERT_EQUAL(damage_events, 1, "Two cardinal halves applied multiple run-over hits to the same victim.")
	TEST_ASSERT(abs(victim.get_brute_loss() - 7) < 0.4, "The resistant victim received duplicate or combined-axis damage.")
	TEST_ASSERT(!victim.IsKnockdown() && victim.density, "The collision bypassed the victim's native knockdown resistance.")
	TEST_ASSERT_EQUAL(pod.loc, origin, "The pod crossed a victim who remained dense.")
	TEST_ASSERT_EQUAL(pod.flight.velocity_x, 0, "The resistant victim did not stop the first diagonal half.")
	TEST_ASSERT_EQUAL(pod.flight.velocity_y, 0, "The resistant victim did not stop the second diagonal half.")
	var/damage_after_impact = victim.get_brute_loss()
	for(var/tick in 1 to 10)
		TEST_ASSERT(pod.relaymove(pod.pilot, NORTH), "Could not hold low-speed thrust against the resistant victim.")
		advance_flight(pod)
	TEST_ASSERT_EQUAL(damage_events, 1, "Holding thrust repeatedly invoked run-over damage without a new impact.")
	TEST_ASSERT_EQUAL(victim.get_brute_loss(), damage_after_impact, "Holding thrust repeatedly injured the resistant victim.")
	UnregisterSignal(victim, COMSIG_MOB_APPLY_DAMAGE)

/datum/unit_test/spacepod_vacuum/runover_repeat/proc/on_victim_damage(datum/source)
	SIGNAL_HANDLER
	damage_events++

/// Passing over prone or nondense people and movement denial without contact cannot injure them.
/datum/unit_test/spacepod_vacuum/runover_noncontact/Run()
	for(var/condition in list("prone", "nondense", "denied"))
		var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
		TEST_ASSERT_NOTNULL(pod, "Could not prepare the noncontact run-over fixture.")
		var/turf/origin = pod.loc
		var/mob/living/carbon/human/consistent/victim = allocate(__IMPLIED_TYPE__, locate(pod.x + 1, pod.y + 2, pod.z))
		switch(condition)
			if("prone")
				victim.set_lying_down()
			if("nondense")
				ADD_TRAIT(victim, TRAIT_UNDENSE, TRAIT_GENERIC)
			if("denied")
				RegisterSignal(pod, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(block_without_collision))
		pod.flight.velocity_y = 5
		advance_flight(pod)
		TEST_ASSERT_EQUAL(victim.get_brute_loss(), 0, "The [condition] control injured a person without a dense collision.")
		TEST_ASSERT(!victim.IsKnockdown(), "The [condition] control applied collision knockdown without contact.")
		TEST_ASSERT_EQUAL(pod.loc, condition == "denied" ? origin : get_step(origin, NORTH), "The [condition] control did not reach its real movement boundary.")
		UnregisterSignal(pod, COMSIG_MOVABLE_PRE_MOVE)
		qdel(victim)
		qdel(pod.pilot)
		qdel(pod)

/datum/unit_test/spacepod_vacuum/runover_noncontact/proc/block_without_collision(datum/source)
	SIGNAL_HANDLER
	return COMPONENT_MOVABLE_BLOCK_PRE_MOVE

/datum/unit_test/spacepod_vacuum/runover_relocation
	/// Only retained until teardown; the signal relocates this real hull during victim damage.
	var/obj/vehicle/sealed/spacepod/collision_pod
	/// A different, free turf inside the same private reservation.
	var/turf/relocation_target

/datum/unit_test/spacepod_vacuum/runover_relocation/Destroy()
	collision_pod = null
	relocation_target = null
	return ..()

/// A damage callback moving the hull aborts the old step before knockdown or cabin impact damage.
/datum/unit_test/spacepod_vacuum/runover_relocation/Run()
	collision_pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(collision_pod, "Could not prepare the relocation run-over fixture.")
	relocation_target = locate(vacuum_origin.x + 3, vacuum_origin.y + 3, vacuum_origin.z)
	var/mob/living/carbon/human/consistent/victim = allocate(__IMPLIED_TYPE__, locate(collision_pod.x + 1, collision_pod.y + 2, collision_pod.z))
	RegisterSignal(victim, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_victim_damage))
	var/initial_integrity = collision_pod.get_integrity()
	collision_pod.flight.velocity_y = 4
	advance_flight(collision_pod)
	TEST_ASSERT_EQUAL(collision_pod.loc, relocation_target, "The real victim damage callback did not relocate the hull.")
	TEST_ASSERT(abs(victim.get_brute_loss() - 7) < 0.4, "Relocating the hull lost or duplicated the original victim injury.")
	TEST_ASSERT(!victim.IsKnockdown() && victim.body_position == STANDING_UP, "The old collision knocked down a victim after hull relocation.")
	TEST_ASSERT_EQUAL(collision_pod.get_integrity(), initial_integrity, "The old collision damaged the relocated hull.")
	TEST_ASSERT_EQUAL(collision_pod.pilot.get_brute_loss(), 0, "The old collision injured the relocated pilot.")
	TEST_ASSERT_EQUAL(collision_pod.flight.velocity_y, 0, "Hull relocation retained old collision momentum.")
	UnregisterSignal(victim, COMSIG_MOB_APPLY_DAMAGE)

/datum/unit_test/spacepod_vacuum/runover_relocation/proc/on_victim_damage(datum/source)
	SIGNAL_HANDLER
	collision_pod.forceMove(relocation_target)
