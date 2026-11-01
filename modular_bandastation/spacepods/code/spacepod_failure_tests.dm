// AI EDIT START - Isolate the meltdown test from unrelated world explosions
/// Count real blasts at the test pod's origin independently of explosions elsewhere.
/datum/unit_test/spacepod_failure_meltdown
	/// The test pod's epicenter, retained until signal cleanup.
	var/turf/explosion_origin
	/// Number of blasts observed at this test's epicenter.
	var/explosions_at_origin = 0

/datum/unit_test/spacepod_failure_meltdown/Destroy()
	UnregisterSignal(SSdcs, COMSIG_GLOB_EXPLOSION)
	explosion_origin = null
	return ..()

/datum/unit_test/spacepod_failure_meltdown/proc/on_explosion(datum/source, turf/epicenter)
	SIGNAL_HANDLER
	if(epicenter == explosion_origin)
		explosions_at_origin++
// AI EDIT END

/// Lethal damage must immediately destroy the cabin, without a second delayed blast.
/datum/unit_test/spacepod_failure_meltdown/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/loader = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	// Consistent dummies normally reduce timed actions to zero; use live-game timing here.
	loader.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 1)
	TEST_ASSERT_EQUAL(loader.cached_multiplicative_actions_slowdown, 1, "The cargo loader must use normal live-game action timing.")
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/obj/item/spacepod_equipment/cargo/crate/cargo = allocate(__IMPLIED_TYPE__, origin)
	TEST_ASSERT(pod.add_equipment(null, cargo, cargo.slot), "The test cargo bay could not be installed.")
	var/obj/structure/closet/crate/crate = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/obj/item/pod_parts/core/payload = allocate(__IMPLIED_TYPE__, crate)
	TEST_ASSERT(pod.load_cargo(loader, crate), "Real timed crate loading failed before the destruction scenario.")
	TEST_ASSERT(pod.mob_try_enter(pilot), "The pilot could not board before core failure.")
	TEST_ASSERT(pod.mob_try_enter(passenger), "The passenger could not board before core failure.")
	var/list/old_actions = list()
	for(var/datum/action/vehicle/sealed/spacepod/action in pilot.actions)
		old_actions += action
	TEST_ASSERT(length(old_actions), "The boarded pilot did not receive any pod action datums.")
	var/obj/item/spacepod_equipment/misc/tracker/tracker = pod.misc_system
	var/list/turf/wreckage_turfs = pod.locs.Copy()
	// AI EDIT START - Observe only the test pod's explosion epicenter
	explosion_origin = origin
	RegisterSignal(SSdcs, COMSIG_GLOB_EXPLOSION, PROC_REF(on_explosion))
	// AI EDIT END
	pod.take_damage(pod.max_integrity + 1, BRUTE, MELEE, sound_effect = FALSE)
	var/destroyed_immediately = QDELETED(pod)
	var/immediate_explosions = explosions_at_origin
	var/observe_until = world.time + 4 SECONDS
	var/deadline = world.time + 8 SECONDS
	// Preserve the synchronous result, then drain even a failing regression's blast before cleanup.
	while(world.time < deadline && (world.time < observe_until || SSexplosions.is_exploding()))
		stoplag(1)
	TEST_ASSERT(!SSexplosions.is_exploding(), "The pod blast did not finish processing within the bounded test interval.")
	TEST_ASSERT(destroyed_immediately, "A lethal native hit did not immediately destroy the pod.")
	TEST_ASSERT_EQUAL(immediate_explosions, 1, "Lethal damage did not immediately produce exactly one core explosion.")
	// AI EDIT START - Preserve the strict single-blast assertion without a global counter
	TEST_ASSERT_EQUAL(explosions_at_origin, 1, "A lethal core failure produced an additional delayed explosion.")
	// AI EDIT END
	for(var/turf/tile as anything in wreckage_turfs)
		var/obj/effect/decal/remains/robot/spacepod/debris
		while(!debris && world.time < deadline)
			debris = locate(/obj/effect/decal/remains/robot/spacepod) in tile
			if(!debris)
				stoplag(1)
		TEST_ASSERT_NOTNULL(debris, "The cabin's own blast removed or failed to leave its mechanical wreckage.")
		allocated += debris
	for(var/mob/living/occupant as anything in list(pilot, passenger))
		// Paradise inflicts 300 brute damage before the native blast; evacuation need not preserve life.
		TEST_ASSERT(!QDELETED(occupant), "Deleting the destroyed cabin deleted an occupant's body.")
		TEST_ASSERT(isturf(occupant.loc), "An occupant remains inside a deleted cabin after core failure.")
		TEST_ASSERT(!HAS_TRAIT_FROM(occupant, TRAIT_HANDS_BLOCKED, VEHICLE_TRAIT), "An occupant retained the deleted vehicle's blocked-hands trait source.")
		TEST_ASSERT(occupant.get_brute_loss() > 0, "Core detonation failed to hurt an occupant.")
	TEST_ASSERT(!(pod in GLOB.spacepods_list), "A detonated pod remains in the global registry.")
	TEST_ASSERT(!(tracker in GLOB.pod_trackers), "A detonated tracker remains in the global tracker registry.")
	for(var/datum/action/vehicle/sealed/spacepod/action as anything in old_actions)
		TEST_ASSERT(QDELETED(action) || !action.IsAvailable(), "A stale pilot action remains usable after detonation.")
	TEST_ASSERT(!QDELETED(crate), "Deleting the cargo fitting silently deleted the loaded crate.")
	TEST_ASSERT(isturf(crate.loc), "The loaded crate remains inside a deleted cargo fitting.")
	TEST_ASSERT_EQUAL(payload.loc, crate, "Destroying the pod deleted or detached the cargo crate's contents.")

/// Power must stop and recover through native battery events and the real EMP expiry time.
/datum/unit_test/spacepod_failure_power_restore/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/technician = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	TEST_ASSERT(pod.mob_try_enter(pilot), "The power-recovery pilot could not board.")
	var/obj/item/stock_parts/power_store/cell/cell = pod.battery
	TEST_ASSERT(technician.put_in_active_hand(cell, forced = TRUE), "The technician could not remove the existing battery through native inventory movement.")
	TEST_ASSERT_NULL(pod.battery, "Removing the battery did not clear the vehicle's battery reference.")
	TEST_ASSERT(!pod.relaymove(pilot, EAST), "The pod moved without a battery.")
	TEST_ASSERT_EQUAL(pod.loc, origin, "A rejected powerless move changed the pod's position.")
	pod.hatch_open = TRUE
	TEST_ASSERT(cell.use(cell.charge), "The native battery could not be discharged for the empty-cell scenario.")
	TEST_ASSERT(pod.item_interaction(technician, cell, list()) & ITEM_INTERACT_SUCCESS, "The technician could not reinstall the empty battery.")
	TEST_ASSERT_EQUAL(pod.battery, cell, "Battery installation did not restore the actual cell reference.")
	while(!COOLDOWN_FINISHED(pod, cooldown_vehicle_move))
		stoplag(1)
	TEST_ASSERT(!pod.relaymove(pilot, EAST), "The pod moved with an empty battery.")
	TEST_ASSERT_EQUAL(cell.charge, 0, "Rejected empty-battery movement created charge.")
	cell.give(cell.maxcharge)
	pod.hatch_open = FALSE
	while(!COOLDOWN_FINISHED(pod, cooldown_vehicle_move))
		stoplag(1)
	TEST_ASSERT(pod.relaymove(pilot, EAST), "The pod did not recover after its battery was recharged.")
	STOP_PROCESSING(SSnewtonian_movement, pod.flight)
	pod.flight.process(0.05)
	TEST_ASSERT(pod.loc != origin, "Recharging accepted input without restoring actual movement.")
	var/turf/emp_origin = pod.loc
	pod.emp_act(EMP_LIGHT)
	TEST_ASSERT(!COOLDOWN_FINISHED(pod, cooldown_emp), "A real EMP did not start its movement lockout.")
	while(!COOLDOWN_FINISHED(pod, cooldown_vehicle_move))
		stoplag(1)
	TEST_ASSERT(!pod.relaymove(pilot, WEST), "The pod moved during its EMP lockout.")
	TEST_ASSERT_EQUAL(pod.loc, emp_origin, "EMP-disabled movement changed the pod's position.")
	var/deadline = world.time + 45 SECONDS
	while(!COOLDOWN_FINISHED(pod, cooldown_emp) && world.time < deadline)
		stoplag(1)
	TEST_ASSERT(COOLDOWN_FINISHED(pod, cooldown_emp), "The real light-EMP cooldown failed to expire.")
	TEST_ASSERT(pod.relaymove(pilot, WEST), "The pod did not recover movement after the EMP naturally expired.")
	STOP_PROCESSING(SSnewtonian_movement, pod.flight)
	var/charge_after_emp = cell.charge
	pod.flight.process(0.05)
	TEST_ASSERT(cell.charge < charge_after_emp, "The recovered pod accepted input without applying paid thrust.")
	TEST_ASSERT(pod.mob_exit(pilot, silent = TRUE), "The recovered pilot could not leave the pod.")
	pilot.forceMove(run_loc_floor_bottom_left)
	var/old_lights = pod.lights
	var/old_air_mode = pod.use_internal_tank
	TEST_ASSERT(!pod.can_control(pilot), "An exited pilot retained control authorization.")
	TEST_ASSERT(!pod.toggleLights(pilot), "An exited pilot remotely toggled the pod's lights.")
	TEST_ASSERT(!pod.toggle_internal_tank(pilot), "An exited pilot remotely changed the pod's air source.")
	TEST_ASSERT(!pod.fireWeapon(pilot), "An exited pilot remotely fired the pod's weapon slot.")
	TEST_ASSERT_EQUAL(pod.lights, old_lights, "A rejected remote command still changed the lights.")
	TEST_ASSERT_EQUAL(pod.use_internal_tank, old_air_mode, "A rejected remote command still changed the cabin air source.")

/// Every mutation happens after the actual installation do_after has started.
/datum/unit_test/spacepod_failure_install_races/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	for(var/invalidation in list("hatch", "lock", "slot", "held_item"))
		var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, origin)
		pod.hatch_open = TRUE
		var/mob/living/carbon/human/consistent/technician = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
		technician.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 1)
		TEST_ASSERT_EQUAL(technician.cached_multiplicative_actions_slowdown, 1, "The installer must use the real two-second action delay.")
		var/obj/item/spacepod_equipment/misc/tracker/module = allocate(__IMPLIED_TYPE__, technician)
		TEST_ASSERT(technician.put_in_active_hand(module, forced = TRUE), "The installer cannot hold its module fixture.")
		// spawn copies local scalar values; a shared list carries the async result back to the test.
		var/list/outcome = list("finished" = FALSE, "success" = FALSE)
		ASYNC
			outcome["success"] = pod.add_equipment(technician, module, module.slot)
			outcome["finished"] = TRUE
		TEST_ASSERT(DOING_INTERACTION(technician, pod), "Installation did not enter the real timed interaction for [invalidation].")
		var/obj/item/spacepod_equipment/misc/tracker/competing_module
		switch(invalidation)
			if("hatch")
				pod.hatch_open = FALSE
			if("lock")
				pod.unlocked = FALSE
			if("slot")
				competing_module = allocate(/obj/item/spacepod_equipment/misc/tracker, origin)
				TEST_ASSERT(pod.add_equipment(null, competing_module, competing_module.slot), "The competing slot fixture could not be installed during the pending interaction.")
			if("held_item")
				TEST_ASSERT(technician.dropItemToGround(module), "The installer could not drop the pending module.")
		var/deadline = world.time + 5 SECONDS
		while(!outcome["finished"] && world.time < deadline)
			stoplag(1)
		TEST_ASSERT(outcome["finished"], "Installation never finished after its [invalidation] invalidation.")
		TEST_ASSERT(!DOING_INTERACTION(technician, pod), "A finished installation left its timed interaction registered.")
		TEST_ASSERT(!outcome["success"], "Installation ignored a mid-action [invalidation] change.")
		TEST_ASSERT_NULL(module.my_atom, "A rejected installation still assigned its module owner.")
		TEST_ASSERT(!(module in pod.installed_modules), "A rejected module remains registered as installed.")
		TEST_ASSERT(module.loc != pod, "A rejected installation moved the module into the pod.")
		if(competing_module)
			TEST_ASSERT_EQUAL(pod.misc_system, competing_module, "The pending install overwrote another installed module.")
			TEST_ASSERT_EQUAL(competing_module.my_atom, pod, "A competing module lost ownership during a rejected install.")
		else
			TEST_ASSERT_NULL(pod.misc_system, "A rejected installation populated its equipment slot.")
		qdel(pod)
		qdel(technician)
		qdel(module)

/// A stale removal must neither detach the replacement nor fetch an item to a remote actor.
/datum/unit_test/spacepod_failure_remove_races/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	for(var/invalidation in list("hatch", "lock", "slot"))
		var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, origin)
		pod.hatch_open = TRUE
		var/mob/living/carbon/human/consistent/technician = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
		technician.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 1)
		TEST_ASSERT_EQUAL(technician.cached_multiplicative_actions_slowdown, 1, "The remover must use the real two-second action delay.")
		var/obj/item/spacepod_equipment/misc/tracker/module = allocate(__IMPLIED_TYPE__, origin)
		TEST_ASSERT(pod.add_equipment(null, module, module.slot), "The removal fixture could not install its initial module.")
		var/list/outcome = list("finished" = FALSE, "success" = FALSE)
		ASYNC
			outcome["success"] = pod.remove_equipment(technician, module, module.slot)
			outcome["finished"] = TRUE
		TEST_ASSERT(DOING_INTERACTION(technician, pod), "Removal did not enter the real timed interaction for [invalidation].")
		var/obj/item/spacepod_equipment/misc/tracker/replacement
		switch(invalidation)
			if("hatch")
				pod.hatch_open = FALSE
			if("lock")
				pod.unlocked = FALSE
			if("slot")
				module.forceMove(run_loc_floor_top_right)
				replacement = allocate(/obj/item/spacepod_equipment/misc/tracker, origin)
				TEST_ASSERT(pod.add_equipment(null, replacement, replacement.slot), "The replacement could not occupy the slot during a pending removal.")
		var/deadline = world.time + 5 SECONDS
		while(!outcome["finished"] && world.time < deadline)
			stoplag(1)
		TEST_ASSERT(outcome["finished"], "Removal never finished after its [invalidation] invalidation.")
		TEST_ASSERT(!DOING_INTERACTION(technician, pod), "A finished removal left its timed interaction registered.")
		TEST_ASSERT(!outcome["success"], "Removal ignored a mid-action [invalidation] change.")
		TEST_ASSERT(!technician.is_holding(module), "A rejected removal fetched a stale module into the technician's hands.")
		if(replacement)
			TEST_ASSERT_EQUAL(pod.misc_system, replacement, "The stale removal detached its replacement module.")
			TEST_ASSERT_EQUAL(replacement.my_atom, pod, "A replacement module lost its owner during a stale removal.")
			TEST_ASSERT_NULL(module.my_atom, "A relocated old module retained its pod owner.")
		else
			TEST_ASSERT_EQUAL(pod.misc_system, module, "A rejected removal cleared its original equipment slot.")
			TEST_ASSERT_EQUAL(module.my_atom, pod, "A rejected removal still detached its original module.")
		pod.hatch_open = TRUE
		pod.unlocked = TRUE
		technician.forceMove(run_loc_floor_bottom_left)
		TEST_ASSERT(!pod.Adjacent(technician), "The remote-removal fixture must be outside the full cabin footprint's reach.")
		var/obj/item/spacepod_equipment/misc/tracker/current_module = pod.misc_system
		TEST_ASSERT(!pod.remove_equipment(technician, current_module, current_module.slot), "A remote technician removed equipment without adjacency.")
		TEST_ASSERT_EQUAL(pod.misc_system, current_module, "A rejected remote removal still changed the slot.")
		qdel(pod)
		qdel(technician)
		if(!QDELETED(module))
			qdel(module)
