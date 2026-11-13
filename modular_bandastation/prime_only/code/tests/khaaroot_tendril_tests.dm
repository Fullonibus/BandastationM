/// Real item, projectile, and throw fixtures for the Khaaroot catching mutation.
/datum/unit_test/khaaroot_tendril
	parent_type = /datum/unit_test/khaaroot_hivemind
	abstract_type = /datum/unit_test/khaaroot_tendril
	/// The revealed mutation belonging to the current infected body.
	var/datum/action/cooldown/khaaroot_mutation/tendril/tendril
	/// A conscious, unarmored person in the projectile's path.
	var/mob/living/carbon/human/victim

/datum/unit_test/khaaroot_tendril/Destroy()
	tendril = null
	victim = null
	return ..()

/// Select and reveal through the same controller and action entry points as a player.
/datum/unit_test/khaaroot_tendril/proc/create_tendril()
	if(!create_hive())
		return FALSE
	member.forceMove(locate(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z))
	victim = create_person()
	victim.forceMove(locate(run_loc_floor_top_right.x, member.y, member.z))
	if(!isopenturf(get_turf(member)) || !isopenturf(get_turf(victim)) || member.Adjacent(victim))
		return FALSE
	var/datum/antagonist/khaaroot_thrall/antag = hive.get_thrall_antag(member.mind)
	if(!antag.mutations.set_specialization(member, "tendril"))
		return FALSE
	tendril = locate() in member.actions
	if(!tendril?.Trigger(member))
		return FALSE
	return tendril.is_revealed()

/// Shoot with the mutation item, then wait only until a real throw begins or the shot ends.
/datum/unit_test/khaaroot_tendril/proc/start_retraction()
	var/obj/item/khaaroot_mutation_arm/tendril/arm_item = tendril.held_item
	if(arm_item.ranged_interact_with_atom(victim, member, list()) != ITEM_INTERACT_SUCCESS)
		return FALSE
	var/deadline = world.time + 5 SECONDS
	UNTIL(victim.throwing || !tendril.pending_shot || world.time >= deadline)
	return !!victim.throwing

/// A physical arrival becomes an aggressive grab even while the other hand holds a weapon.
/datum/unit_test/khaaroot_tendril/arrival/Run()
	if(!create_tendril())
		TEST_FAIL("Could not select and reveal the tendril")
		return
	var/obj/item/knife = allocate(/obj/item/knife/combat)
	if(!member.put_in_inactive_hand(knife))
		TEST_FAIL("Could not fill the second hand before using the tendril")
		return
	if(!start_retraction())
		TEST_FAIL("The real tendril projectile did not start pulling its target back")
		return
	var/datum/khaaroot_tendril_flight/flight = tendril.pending_shot
	var/obj/item/khaaroot_mutation_arm/tendril/arm_item = tendril.held_item
	if(arm_item.ranged_interact_with_atom(victim, member, list()) != ITEM_INTERACT_BLOCKING || tendril.pending_shot != flight)
		TEST_FAIL("A second click replaced the pending tendril shot during cooldown")
		return
	var/deadline = world.time + 5 SECONDS
	UNTIL(!tendril.pending_shot || world.time >= deadline)
	if(tendril.pending_shot || member.pulling != victim || victim.pulledby != member || member.grab_state != GRAB_AGGRESSIVE)
		TEST_FAIL("A successful physical tendril arrival did not establish a real aggressive grab")
		return
	if(!member.Adjacent(victim) || victim.get_brute_loss() || victim.get_fire_loss())
		TEST_FAIL("The tendril grabbed remotely or automatically attacked with the other weapon")
		return
	if(victim.mind.has_antag_datum(/datum/antagonist/khaaroot_thrall))
		TEST_FAIL("The tendril automatically infected its victim")
		return
	if(!tendril.is_revealed() || tendril.next_use_time <= world.time)
		TEST_FAIL("The successful shot consumed the arm form or omitted its cooldown")

/// A new obstruction on the return path must stop the target without a remote grab.
/datum/unit_test/khaaroot_tendril/obstruction
	/// Ensures this scenario actually entered the native throwing boundary.
	var/intercepted_throw = FALSE

/datum/unit_test/khaaroot_tendril/obstruction/Run()
	if(!create_tendril())
		TEST_FAIL("Could not select and reveal the tendril")
		return
	RegisterSignal(victim, COMSIG_MOVABLE_POST_THROW, PROC_REF(block_return_path))
	var/obj/item/khaaroot_mutation_arm/tendril/arm_item = tendril.held_item
	arm_item.ranged_interact_with_atom(victim, member, list())
	var/deadline = world.time + 5 SECONDS
	UNTIL(!tendril.pending_shot || world.time >= deadline)
	UnregisterSignal(victim, COMSIG_MOVABLE_POST_THROW)
	if(!intercepted_throw || tendril.pending_shot)
		TEST_FAIL("The obstructed fixture did not complete a real tendril return throw")
		return
	if(member.pulling || victim.pulledby || member.grab_state != GRAB_PASSIVE || member.Adjacent(victim))
		TEST_FAIL("A victim stopped by an obstruction was captured remotely")

/// Close the last return tile after impact, before the throwing subsystem moves the victim.
/datum/unit_test/khaaroot_tendril/obstruction/proc/block_return_path(mob/living/source, datum/thrownthing/throw_datum, spin)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_MOVABLE_POST_THROW)
	intercepted_throw = TRUE
	allocate(/obj/structure/closet, get_step_towards(member, source))

/// The action button must retract during cooldown and invalidate an already launched throw.
/datum/unit_test/khaaroot_tendril/retract_during_return/Run()
	if(!create_tendril() || !start_retraction())
		TEST_FAIL("Could not start a real tendril return throw")
		return
	var/datum/khaaroot_tendril_flight/flight = tendril.pending_shot
	var/datum/beam/return_beam = flight.beam
	if(QDELETED(return_beam))
		TEST_FAIL("The native return throw had no owner-to-victim beam")
		return
	if(!tendril.Trigger(member))
		TEST_FAIL("The tendril could not be hidden during its attack cooldown")
		return
	if(tendril.pending_shot || tendril.is_revealed() || !QDELETED(flight) || !QDELETED(return_beam))
		TEST_FAIL("Hiding the tendril retained its pending effect, item, or return beam")
		return
	var/deadline = world.time + 5 SECONDS
	UNTIL(!victim.throwing || world.time >= deadline)
	if(victim.throwing || member.pulling || victim.pulledby || member.grab_state != GRAB_PASSIVE)
		TEST_FAIL("A cancelled tendril callback captured the victim after retraction")

/// Removing the real role during the asynchronous flight invalidates the landing effect.
/datum/unit_test/khaaroot_tendril/removed_membership/Run()
	if(!create_tendril() || !start_retraction())
		TEST_FAIL("Could not start a real tendril return throw")
		return
	var/datum/khaaroot_tendril_flight/flight = tendril.pending_shot
	var/datum/beam/return_beam = flight.beam
	member.mind.remove_antag_datum(/datum/antagonist/khaaroot_thrall)
	if(!QDELETED(tendril) || !QDELETED(flight) || !QDELETED(return_beam))
		TEST_FAIL("Role removal retained the pending tendril or its visual")
		return
	var/deadline = world.time + 5 SECONDS
	UNTIL(!victim.throwing || world.time >= deadline)
	if(victim.throwing || member.pulling || victim.pulledby || member.grab_state != GRAB_PASSIVE)
		TEST_FAIL("An old membership's delayed tendril callback captured a victim")
