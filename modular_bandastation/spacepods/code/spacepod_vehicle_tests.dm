/// Real boarding must assign only one pilot and enforce the installed passenger seat.
/datum/unit_test/spacepod_boarding/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/overflow = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	TEST_ASSERT(pod.mob_try_enter(pilot), "A conscious human could not enter an unlocked pod.")
	TEST_ASSERT_EQUAL(pod.pilot, pilot, "The first occupant was not assigned the pilot seat.")
	TEST_ASSERT(pod.mob_try_enter(passenger), "The installed passenger seat could not be boarded.")
	TEST_ASSERT(passenger in pod.passengers, "The second occupant did not become a passenger.")
	TEST_ASSERT(!pod.is_driver(passenger), "A passenger received pilot controls.")
	TEST_ASSERT(!pod.mob_try_enter(overflow), "The pod accepted an occupant without a seat.")
	pod.exit_pod(passenger)
	TEST_ASSERT_EQUAL(passenger.loc, origin, "A passenger was not returned to the turf on exit.")
	TEST_ASSERT(!pod.is_occupant(passenger), "An exited passenger remains registered.")
	TEST_ASSERT(!HAS_TRAIT(passenger, TRAIT_HANDS_BLOCKED), "Vehicle hand blocking survived the passenger's exit.")
	pod.unlocked = FALSE
	TEST_ASSERT(!pod.mob_try_enter(overflow), "The locked cabin accepted a new passenger.")
	pod.unlocked = TRUE
	var/obj/item/storage/backpack/backpack = allocate(__IMPLIED_TYPE__, overflow)
	// The fake shares the blocked type without the real disk's station-only teleportation.
	var/obj/item/disk/nuclear/fake/disk = allocate(__IMPLIED_TYPE__, backpack)
	TEST_ASSERT_EQUAL(disk.loc, backpack, "The disk test fixture was not placed inside the backpack.")
	TEST_ASSERT_EQUAL(backpack.loc, overflow, "The disk test fixture's backpack is not carried by the prospective passenger.")
	TEST_ASSERT(disk in overflow.get_all_contents_type(/obj/item/disk/nuclear), "The native recursive-content API did not find the nested disk.")
	TEST_ASSERT(!pod.mob_try_enter(overflow), "The cabin accepted a nuclear disk hidden inside a backpack.")
	TEST_ASSERT(pod.mob_try_enter(passenger), "A vacated passenger seat could not be boarded again.")
	pod.exit_pod(pilot)
	TEST_ASSERT_NULL(pod.pilot, "The exited pilot retains the pilot seat.")
	TEST_ASSERT(!pod.remove_equipment(null, pod.sec_cargo_system, "sec_cargo_system"), "Removing the pilot allowed an occupied passenger seat to be dismantled.")

/// Pilot controls must work despite the sealed vehicle's own hand-blocking trait.
/datum/unit_test/spacepod_pilot_controls/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	pod.mob_try_enter(pilot)
	pod.mob_try_enter(passenger)
	TEST_ASSERT(pod.can_control(pilot), "The pilot cannot operate the console after entering.")
	var/initial_charge = pod.battery.charge
	TEST_ASSERT(!pod.relaymove(passenger, EAST), "A passenger moved the pod.")
	TEST_ASSERT_EQUAL(pod.battery.charge, initial_charge, "A rejected passenger input consumed energy.")
	TEST_ASSERT(pod.relaymove(pilot, EAST), "The pilot could not move a powered pod across open floor.")
	STOP_PROCESSING(SSnewtonian_movement, pod.flight)
	pod.flight.process(0.05)
	TEST_ASSERT(pod.battery.charge < initial_charge, "The accepted pilot thrust consumed no energy.")
	TEST_ASSERT(pod.flight.velocity_x || pod.flight.velocity_y, "The accepted pilot thrust did not accelerate the cabin.")
	ADD_TRAIT(pilot, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!pod.can_control(pilot), "A restrained pilot retained the controls.")
	REMOVE_TRAIT(pilot, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	pod.mob_exit(pilot, silent = TRUE)
	TEST_ASSERT(!pod.can_control(pilot), "An exited pilot retained console access.")

/// Breaths must use the cabin, and switching to exterior air must affect the real air API.
/datum/unit_test/spacepod_cabin_air/Run()
	var/obj/vehicle/sealed/spacepod/pod = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT_EQUAL(pod.return_air(), pod.cabin_air, "Internal mode does not expose the actual cabin air.")
	TEST_ASSERT(pod.cabin_air.return_pressure() > ONE_ATMOSPHERE * 0.99, "The cabin starts without breathable pressure.")
	var/initial_moles = pod.cabin_air.total_moles()
	var/datum/gas_mixture/breath = pod.remove_air(initial_moles / 100)
	TEST_ASSERT(pod.cabin_air.total_moles() < initial_moles, "Breathing does not remove gas from the cabin.")
	pod.assume_air(breath)
	qdel(breath)
	TEST_ASSERT(abs(pod.cabin_air.total_moles() - initial_moles) < 0.00001, "Exhaled gas disappeared instead of returning to the cabin.")
	pod.use_internal_tank = FALSE
	TEST_ASSERT_EQUAL(pod.return_air(), pod.loc.return_air(), "External mode still exposes the cabin atmosphere.")
	pod.use_internal_tank = TRUE
	var/datum/gas_mixture/removed = pod.cabin_air.remove_ratio(1)
	qdel(removed)
	var/datum/gas_mixture/tank_air = pod.internal_tank.return_air()
	var/total_before = tank_air.total_moles() + pod.cabin_air.total_moles()
	pod.give_air()
	TEST_ASSERT(pod.cabin_air.total_moles() > 0, "The internal tank failed to refill an empty cabin.")
	TEST_ASSERT(tank_air.total_moles() < total_before, "Refilling the cabin did not deplete the finite tank.")
	var/transfer_error = total_before - tank_air.total_moles() - pod.cabin_air.total_moles()
	log_test("Spacepod regulator: before=[num2text(total_before, 16)] tank_after=[num2text(tank_air.total_moles(), 16)] cabin_after=[num2text(pod.cabin_air.total_moles(), 16)] error=[num2text(transfer_error, 16)] mol")
	// Native gas amounts are quantized to MOLAR_ACCURACY, and the large tank uses float32 sums.
	TEST_ASSERT(abs(transfer_error) <= MAXIMUM_ERROR_GAS_REMOVAL, "The cabin regulator violated native gas conservation tolerance: [transfer_error] mol.")

/// A 2x2 cabin must collide on its far corner, without requiring a third clear tile.
/datum/unit_test/spacepod_footprint/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/pod = allocate(__IMPLIED_TYPE__, origin)
	TEST_ASSERT_EQUAL(length(pod.locs), 4, "The pod does not occupy exactly four tiles.")
	var/obj/structure/blocker = allocate(/obj/structure, locate(origin.x + 2, origin.y + 1, origin.z))
	blocker.density = TRUE
	blocker.anchored = TRUE
	TEST_ASSERT(!pod.Move(get_step(origin, EAST), EAST), "A pod clipped its far corner through a solid obstacle.")
	TEST_ASSERT_EQUAL(pod.loc, origin, "A blocked cardinal move changed the pod's origin.")
	blocker.forceMove(locate(origin.x + 3, origin.y + 1, origin.z))
	TEST_ASSERT(pod.Move(get_step(origin, EAST), EAST), "A solid obstacle outside the 2x2 destination blocked the pod.")
	TEST_ASSERT_EQUAL(length(pod.locs), 4, "Movement changed the pod's four-tile footprint.")

/// Destruction must return registered occupants and unregistered replacement mobs to safety.
/datum/unit_test/spacepod_evacuation/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/replacement = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	pod.mob_try_enter(pilot)
	pod.mob_try_enter(passenger)
	replacement.forceMove(pod)
	var/obj/item/spacepod_equipment/misc/tracker/tracker = pod.misc_system
	TEST_ASSERT(pod in GLOB.spacepods_list, "The pod is absent from the global registry before destruction.")
	qdel(pod)
	for(var/mob/living/occupant as anything in list(pilot, passenger, replacement))
		TEST_ASSERT(!QDELETED(occupant), "Destroying the pod deleted an occupant.")
		TEST_ASSERT_EQUAL(occupant.loc, origin, "Destroying the pod stranded an occupant inside a deleted container.")
		TEST_ASSERT(!HAS_TRAIT(occupant, TRAIT_HANDS_BLOCKED), "An evacuated occupant retained the vehicle's blocked-hands trait.")
	TEST_ASSERT(!(pod in GLOB.spacepods_list), "A deleted pod remains in the global registry.")
	TEST_ASSERT(!(tracker in GLOB.pod_trackers), "A deleted pod's tracker remains in the tracker registry.")

/// Native damage and repair must keep the donor hull strengths and EMP movement lockout.
/datum/unit_test/spacepod_hull_and_emp/Run()
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT_EQUAL(pod.get_integrity(), 250, "Civilian hull strength differs from the donor.")
	pod.take_damage(80, BRUTE, MELEE, sound_effect = FALSE)
	TEST_ASSERT_EQUAL(pod.get_integrity(), 170, "Native attacks do not damage the pod hull correctly.")
	pod.repair_damage(10)
	TEST_ASSERT_EQUAL(pod.get_integrity(), 180, "Welding-sized repairs did not restore hull integrity.")
	pod.emp_act(EMP_LIGHT)
	TEST_ASSERT(!COOLDOWN_FINISHED(pod, cooldown_emp), "An EMP did not disable pod movement.")
	TEST_ASSERT_EQUAL(pod.get_integrity(), 140, "Light EMP hull damage differs from the donor's 40 damage.")
	var/obj/vehicle/sealed/spacepod/sec/security = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right)
	TEST_ASSERT_EQUAL(security.get_integrity(), 600, "Security hull strength differs from the donor.")
	var/obj/vehicle/sealed/spacepod/syndi/syndicate = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right)
	TEST_ASSERT_EQUAL(syndicate.get_integrity(), 400, "Syndicate hull strength differs from the donor.")
	var/obj/vehicle/sealed/spacepod/civilian/damaged/damaged = allocate(__IMPLIED_TYPE__, run_loc_floor_top_right)
	TEST_ASSERT_EQUAL(damaged.get_integrity(), 50, "The damaged civilian variant did not start with its donor hull damage.")

/// External relocation of a module must invalidate its slot and capabilities immediately.
/datum/unit_test/spacepod_module_relocation/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	pod.mob_try_enter(pilot)
	pod.mob_try_enter(passenger)
	var/obj/item/spacepod_equipment/weaponry/weapon = pod.weapon_system
	weapon.forceMove(run_loc_floor_top_right)
	TEST_ASSERT_NULL(pod.weapon_system, "A teleported weapon remains in the pod's active weapon slot.")
	TEST_ASSERT_NULL(weapon.my_atom, "A teleported weapon retains its pod owner.")
	TEST_ASSERT(!(weapon in pod.installed_modules), "A teleported weapon remains in the installed module list.")
	var/obj/item/spacepod_equipment/sec_cargo/chair/chair = pod.sec_cargo_system
	chair.forceMove(run_loc_floor_top_right)
	TEST_ASSERT_NULL(pod.sec_cargo_system, "A teleported passenger seat remains installed.")
	TEST_ASSERT_EQUAL(pod.max_passengers, 0, "A teleported passenger seat still adds passenger capacity.")
	TEST_ASSERT_EQUAL(pod.max_occupants, 1, "A teleported passenger seat still adds total occupant capacity.")
	TEST_ASSERT_EQUAL(passenger.loc, origin, "A teleported passenger seat stranded its occupant in a nonexistent seat.")
	TEST_ASSERT(!pod.is_occupant(passenger), "A passenger with a removed seat remains registered.")

/// Shared movement must also handle rectangular, offset and single-tile callers.
/datum/unit_test/spacepod_native_bounds/Run()
	var/turf/horizontal_origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_top_right.y, run_loc_floor_bottom_left.z)
	var/obj/structure/horizontal = allocate(__IMPLIED_TYPE__, horizontal_origin)
	horizontal.bound_width = 96
	horizontal.bound_height = 32
	horizontal.bound_x = -32
	TEST_ASSERT_EQUAL(length(horizontal.locs), 3, "An offset 96x32 fixture does not cover three tiles.")
	TEST_ASSERT(horizontal.Move(get_step(horizontal_origin, EAST), EAST), "An offset 96x32 object was blocked by walls outside its footprint.")
	qdel(horizontal)
	var/turf/vertical_origin = locate(run_loc_floor_top_right.x, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/structure/vertical = allocate(__IMPLIED_TYPE__, vertical_origin)
	vertical.bound_width = 32
	vertical.bound_height = 96
	vertical.bound_y = -32
	TEST_ASSERT_EQUAL(length(vertical.locs), 3, "An offset 32x96 fixture does not cover three tiles.")
	TEST_ASSERT(vertical.Move(get_step(vertical_origin, NORTH), NORTH), "An offset 32x96 object was blocked by walls outside its footprint.")
	qdel(vertical)
	var/turf/single_origin = get_step(run_loc_floor_top_right, WEST)
	var/obj/structure/single = allocate(__IMPLIED_TYPE__, single_origin)
	TEST_ASSERT(single.Move(run_loc_floor_top_right, EAST), "The shared footprint fix broke single-tile movement.")
	TEST_ASSERT_EQUAL(length(single.locs), 1, "Single-tile movement changed the object's footprint.")

/// Forced movement must report the actual departed/entered footprint, including overlaps.
/datum/unit_test/spacepod_native_forcedmove
	var/obj/structure/subject
	var/list/monitored_turfs = list()
	var/list/entered_turfs = list()
	var/list/exited_turfs = list()
	var/atom/entered_oldloc
	var/list/entered_oldlocs

/datum/unit_test/spacepod_native_forcedmove/Destroy()
	for(var/turf/monitored as anything in monitored_turfs)
		UnregisterSignal(monitored, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_EXITED))
	monitored_turfs.Cut()
	entered_turfs.Cut()
	exited_turfs.Cut()
	entered_oldloc = null
	entered_oldlocs = null
	subject = null
	return ..()

/datum/unit_test/spacepod_native_forcedmove/proc/on_entered(atom/source, atom/movable/arrived, atom/oldloc, list/oldlocs)
	SIGNAL_HANDLER
	if(arrived == subject)
		entered_turfs |= source
		entered_oldloc = oldloc
		entered_oldlocs = oldlocs

/datum/unit_test/spacepod_native_forcedmove/proc/on_exited(atom/source, atom/movable/departed, direction)
	SIGNAL_HANDLER
	if(departed == subject)
		exited_turfs |= source

/datum/unit_test/spacepod_native_forcedmove/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	subject = allocate(/obj/structure, origin)
	subject.bound_width = 64
	subject.bound_height = 64
	var/list/old_footprint = subject.locs
	monitored_turfs = block(run_loc_floor_bottom_left, run_loc_floor_top_right)
	for(var/turf/monitored as anything in monitored_turfs)
		RegisterSignal(monitored, COMSIG_ATOM_ENTERED, PROC_REF(on_entered))
		RegisterSignal(monitored, COMSIG_ATOM_EXITED, PROC_REF(on_exited))
	subject.forceMove(get_step(origin, EAST))
	TEST_ASSERT_EQUAL(length(entered_turfs), 2, "A one-tile forced move of a 2x2 object did not enter exactly two new turfs.")
	TEST_ASSERT_EQUAL(length(exited_turfs), 2, "A one-tile forced move of a 2x2 object did not leave exactly two old turfs.")
	TEST_ASSERT_EQUAL(entered_oldloc, origin, "Forced movement passed a direction instead of the old loc to Entered.")
	TEST_ASSERT_EQUAL(length(entered_oldlocs), 4, "Forced movement did not report its complete old footprint.")
	for(var/turf/expected_entered as anything in subject.locs - old_footprint)
		TEST_ASSERT(expected_entered in entered_turfs, "Forced movement missed an actual entered turf.")
	for(var/turf/expected_exited as anything in old_footprint - subject.locs)
		TEST_ASSERT(expected_exited in exited_turfs, "Forced movement missed an actual exited turf.")
	entered_turfs.Cut()
	exited_turfs.Cut()
	subject.moveToNullspace()
	TEST_ASSERT_EQUAL(length(exited_turfs), 4, "Moving a 2x2 object to nullspace did not notify all departed turfs.")
	TEST_ASSERT_EQUAL(length(entered_turfs), 0, "Moving an object to nullspace reported phantom entered turfs.")

/// The native movement-lock signal must turn the cabin without authorizing a movement input.
/datum/unit_test/spacepod_movement_lock/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, origin)
	pod.enter_delay = 0
	pod.setDir(NORTH)
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	TEST_ASSERT(pod.mob_try_enter(pilot), "The pilot could not board for the movement-lock test.")
	TEST_ASSERT(pod.mob_try_enter(passenger), "The passenger could not board for the movement-lock test.")
	var/initial_charge = pod.battery.charge
	// This is the exact signal and subsequent facing branch used by native keyLoop for Alt+direction.
	var/keybind_result = SEND_SIGNAL(pilot, COMSIG_MOVABLE_KEYBIND_FACE_DIR, EAST)
	TEST_ASSERT(!(keybind_result & COMSIG_IGNORE_MOVEMENT_LOCK), "Alt+direction incorrectly authorizes the client's movement branch.")
	pilot.keybind_face_direction(EAST)
	STOP_PROCESSING(SSnewtonian_movement, pod.flight)
	for(var/tick in 1 to 6)
		pod.flight.process(0.05)
	TEST_ASSERT_EQUAL(pod.loc, origin, "Turning with the native movement-lock signal moved the pod.")
	TEST_ASSERT_EQUAL(pod.dir, EAST, "The movement-lock signal did not turn the cabin.")
	TEST_ASSERT_EQUAL(pilot.dir, EAST, "Turning the cabin did not turn its pilot.")
	TEST_ASSERT_EQUAL(passenger.dir, EAST, "Turning the cabin did not turn its passenger.")
	TEST_ASSERT(pod.battery.charge < initial_charge, "Powered turning in place consumed no flight energy.")
	var/charge_after_turn = pod.battery.charge
	TEST_ASSERT(pod.relaymove(pilot, NORTH), "Ordinary pilot movement stopped working after turning in place.")
	STOP_PROCESSING(SSnewtonian_movement, pod.flight)
	pod.flight.process(0.05)
	TEST_ASSERT_EQUAL(pod.loc, get_step(origin, EAST), "Forward thrust did not follow the newly aimed nose.")
	TEST_ASSERT(pod.battery.charge < charge_after_turn, "Forward thrust after turning consumed no energy.")

/datum/unit_test/spacepod_interaction
	parent_type = /datum/unit_test/spacepod_vacuum
	abstract_type = /datum/unit_test/spacepod_interaction
	var/obj/vehicle/sealed/spacepod/interaction_pod
	var/mob/living/carbon/human/consistent/interactor
	var/obj/item/crowbar/crowbar
	var/list/barrier_turfs = list()

/datum/unit_test/spacepod_interaction/Destroy()
	for(var/turf/route as anything in barrier_turfs)
		route.ChangeTurf(/turf/open/space)
	barrier_turfs.Cut()
	interaction_pod = null
	interactor = null
	crowbar = null
	return ..()

/datum/unit_test/spacepod_interaction/proc/prepare_interaction()
	if(!vacuum_origin)
		return FALSE
	interaction_pod = allocate(/obj/vehicle/sealed/spacepod/civilian, vacuum_origin)
	STOP_PROCESSING(SSobj, interaction_pod)
	interaction_pod.enter_delay = 0
	interactor = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
	interactor.mock_client = allocate(/datum/client_interface)
	interactor.set_combat_mode(FALSE)
	crowbar = allocate(__IMPLIED_TYPE__, interactor.loc)
	return interactor.put_in_active_hand(crowbar)

/// Keep the native drag checks and restore the ambient actor before any assertion can return.
/datum/unit_test/spacepod_interaction/proc/drag_self_into_pod()
	var/mob/previous_usr = usr
	usr = interactor
	interactor.MouseDrop(interaction_pod)
	usr = previous_usr

/// Real tool clicks and self-drag boarding work around the whole hull, without extending its range.
/datum/unit_test/spacepod_interaction/perimeter/Run()
	TEST_ASSERT(prepare_interaction(), "Could not prepare the full-hull interaction fixture.")
	var/list/perimeter = list(list(2, 2), list(1, 2), list(0, 2), list(-1, 2), list(2, 1), list(2, 0), list(2, -1), list(1, -1), list(0, -1), list(-1, -1), list(-1, 0), list(-1, 1))
	for(var/list/offset as anything in perimeter)
		interactor.forceMove(locate(vacuum_origin.x + offset[1], vacuum_origin.y + offset[2], vacuum_origin.z))
		click_wrapper(interactor, interaction_pod, list(LEFT_CLICK = TRUE))
		TEST_ASSERT(interaction_pod.hatch_open, "A real crowbar click could not open the hatch from hull offset ([offset[1]],[offset[2]]).")
		click_wrapper(interactor, interaction_pod, list(LEFT_CLICK = TRUE))
		TEST_ASSERT(!interaction_pod.hatch_open, "A real crowbar click could not close the hatch from the same edge.")
		drag_self_into_pod()
		TEST_ASSERT_EQUAL(interactor.loc, interaction_pod, "Self-drag boarding failed from hull offset ([offset[1]],[offset[2]]).")
		TEST_ASSERT_EQUAL(interaction_pod.pilot, interactor, "Successful perimeter boarding did not assign pilot controls.")
		TEST_ASSERT(interaction_pod.mob_exit(interactor, silent = TRUE), "The perimeter pilot could not leave before the next edge test.")
		TEST_ASSERT(interactor.put_in_active_hand(crowbar), "Could not re-equip the crowbar dropped by native vehicle hand blocking.")
	for(var/list/offset as anything in list(list(3, 1), list(1, 3), list(3, 3)))
		interactor.forceMove(locate(vacuum_origin.x + offset[1], vacuum_origin.y + offset[2], vacuum_origin.z))
		click_wrapper(interactor, interaction_pod, list(LEFT_CLICK = TRUE))
		drag_self_into_pod()
		TEST_ASSERT(!interaction_pod.hatch_open && interactor.loc != interaction_pod, "Interaction reached beyond the hull's one-tile perimeter.")
	TEST_ASSERT(run_loc_floor_bottom_left.z != vacuum_origin.z, "The cross-Z control is not on a separate level.")
	interactor.forceMove(run_loc_floor_bottom_left)
	click_wrapper(interactor, interaction_pod, list(LEFT_CLICK = TRUE))
	drag_self_into_pod()
	TEST_ASSERT(!interaction_pod.hatch_open && interactor.loc != interaction_pod, "Interaction reached a hull on another Z level.")
	var/obj/structure/closet/crate/container = allocate(__IMPLIED_TYPE__, locate(vacuum_origin.x + 2, vacuum_origin.y + 1, vacuum_origin.z))
	interactor.forceMove(container)
	click_wrapper(interactor, interaction_pod, list(LEFT_CLICK = TRUE))
	drag_self_into_pod()
	TEST_ASSERT(!interaction_pod.hatch_open && interactor.loc == container, "A closed unrelated container allowed external tool use or boarding.")
	interactor.forceMove(locate(vacuum_origin.x + 2, vacuum_origin.y + 2, vacuum_origin.z))
	var/obj/item/spacepod_equipment/lock/keyed/lock = allocate(__IMPLIED_TYPE__, interaction_pod)
	TEST_ASSERT(interaction_pod.add_equipment(null, lock, lock.slot), "Could not install the lock control fixture.")
	interaction_pod.unlocked = FALSE
	click_wrapper(interactor, interaction_pod, list(LEFT_CLICK = TRUE))
	drag_self_into_pod()
	TEST_ASSERT(!interaction_pod.hatch_open && interactor.loc != interaction_pod, "Full-hull reach bypassed the installed door lock.")

/// Hull reach retains window borders and the native two-path rule for diagonal corners.
/datum/unit_test/spacepod_interaction/barriers/Run()
	TEST_ASSERT(prepare_interaction(), "Could not prepare the hull-barrier fixture.")
	interactor.forceMove(locate(vacuum_origin.x + 2, vacuum_origin.y + 1, vacuum_origin.z))
	var/obj/structure/window/lower_window = allocate(__IMPLIED_TYPE__, locate(vacuum_origin.x + 1, vacuum_origin.y, vacuum_origin.z))
	var/obj/structure/window/upper_window = allocate(__IMPLIED_TYPE__, locate(vacuum_origin.x + 1, vacuum_origin.y + 1, vacuum_origin.z))
	lower_window.setDir(EAST)
	upper_window.setDir(EAST)
	click_wrapper(interactor, interaction_pod, list(LEFT_CLICK = TRUE))
	drag_self_into_pod()
	TEST_ASSERT(!interaction_pod.hatch_open && interactor.loc != interaction_pod, "Tool use or boarding crossed a complete window barrier.")
	qdel(upper_window)
	click_wrapper(interactor, interaction_pod, list(LEFT_CLICK = TRUE))
	TEST_ASSERT(interaction_pod.hatch_open, "Removing the nearer window did not restore real crowbar access.")
	click_wrapper(interactor, interaction_pod, list(LEFT_CLICK = TRUE))
	drag_self_into_pod()
	TEST_ASSERT_EQUAL(interactor.loc, interaction_pod, "Removing the nearer window did not restore self-drag boarding.")
	TEST_ASSERT(interaction_pod.mob_exit(interactor, silent = TRUE), "The window control pilot could not exit.")
	TEST_ASSERT(interactor.put_in_active_hand(crowbar), "Could not re-equip the crowbar before the diagonal-path checks.")
	qdel(lower_window)
	interactor.forceMove(locate(vacuum_origin.x + 2, vacuum_origin.y + 2, vacuum_origin.z))
	var/turf/north_route = locate(vacuum_origin.x + 1, vacuum_origin.y + 2, vacuum_origin.z)
	var/turf/east_route = locate(vacuum_origin.x + 2, vacuum_origin.y + 1, vacuum_origin.z)
	barrier_turfs += list(north_route, east_route)
	north_route = north_route.ChangeTurf(/turf/closed/indestructible)
	east_route = east_route.ChangeTurf(/turf/closed/indestructible)
	click_wrapper(interactor, interaction_pod, list(LEFT_CLICK = TRUE))
	drag_self_into_pod()
	TEST_ASSERT(!interaction_pod.hatch_open && interactor.loc != interaction_pod, "Interaction crossed a diagonally sealed hull corner.")
	north_route = north_route.ChangeTurf(/turf/open/space)
	click_wrapper(interactor, interaction_pod, list(LEFT_CLICK = TRUE))
	TEST_ASSERT(interaction_pod.hatch_open, "Opening one diagonal path did not restore the real tool interaction.")
	drag_self_into_pod()
	TEST_ASSERT_EQUAL(interactor.loc, interaction_pod, "Opening one diagonal path did not restore boarding.")
	east_route.ChangeTurf(/turf/open/space)

/// Delayed boarding rechecks range and locking after the actual timed action has started.
/datum/unit_test/spacepod_interaction/boarding_invalidation/Run()
	TEST_ASSERT(prepare_interaction(), "Could not prepare delayed perimeter boarding.")
	var/obj/item/spacepod_equipment/lock/keyed/lock = allocate(__IMPLIED_TYPE__, interaction_pod)
	TEST_ASSERT(interaction_pod.add_equipment(null, lock, lock.slot), "Could not install the timed-boarding lock.")
	interaction_pod.enter_delay = 0.5 SECONDS
	interactor.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 1)
	for(var/condition in list("none", "user moves", "pod moves", "locks"))
		interaction_pod.forceMove(vacuum_origin)
		interaction_pod.unlocked = TRUE
		interactor.forceMove(locate(vacuum_origin.x + 2, vacuum_origin.y + 2, vacuum_origin.z))
		var/list/outcome = list("finished" = FALSE, "success" = FALSE)
		ASYNC
			outcome["success"] = interaction_pod.enter_pod(interactor)
			outcome["finished"] = TRUE
		TEST_ASSERT(DOING_INTERACTION(interactor, interaction_pod), "Perimeter boarding did not enter the actual timed action for [condition].")
		switch(condition)
			if("user moves")
				interactor.forceMove(locate(vacuum_origin.x + 4, vacuum_origin.y + 4, vacuum_origin.z))
			if("pod moves")
				interaction_pod.forceMove(locate(vacuum_origin.x - 3, vacuum_origin.y - 3, vacuum_origin.z))
			if("locks")
				interaction_pod.unlocked = FALSE
		var/deadline = world.time + 2 SECONDS
		while(!outcome["finished"] && world.time < deadline)
			sleep(world.tick_lag)
		TEST_ASSERT(outcome["finished"], "The timed perimeter boarding did not finish for [condition].")
		TEST_ASSERT(!DOING_INTERACTION(interactor, interaction_pod), "Completed perimeter boarding retained its timed interaction.")
		if(condition == "none")
			TEST_ASSERT(outcome["success"] && interactor.loc == interaction_pod, "Uninterrupted timed boarding from the far corner failed.")
			TEST_ASSERT(interaction_pod.mob_exit(interactor, silent = TRUE), "The timed boarding control could not exit.")
		else
			TEST_ASSERT(!outcome["success"] && interactor.loc != interaction_pod, "Timed boarding ignored [condition] after starting at the hull's far corner.")
