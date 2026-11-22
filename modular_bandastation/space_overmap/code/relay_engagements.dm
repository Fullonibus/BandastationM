#define RELAY_COMBAT_MARKED 1
#define RELAY_COMBAT_DEFENSE 2
#define RELAY_COMBAT_ORDER 3

/// Validate a living target independently of what any particular droid can see.
/obj/machinery/overmap_droid_relay/proc/valid_hostile_body(mob/living/target)
	if(!isliving(target) || QDELETED(target) || target.stat == DEAD || target == operator || (target in droids) || HAS_TRAIT(target, TRAIT_GODMODE))
		return FALSE
	var/obj/docking_port/mobile/stationtrauma_space/ship = linked_ship()
	return !ship?.is_in_shuttle_bounds(target)

/// Register a body explicitly identified by the operator. Keep the identification as it was given.
/obj/machinery/overmap_droid_relay/proc/mark_hostile(mob/living/target)
	if(!valid_hostile_body(target) || !isturf(target.loc))
		return FALSE
	var/datum/weakref/reference = WEAKREF(target)
	if(reference in hostile_targets)
		return FALSE
	hostile_targets[reference] = target.name
	RegisterSignals(target, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING), PROC_REF(on_hostile_lost))
	for(var/mob/living/basic/relay_droid/unit as anything in droids)
		COOLDOWN_RESET(unit, hostile_scan)
	update_order_displays()
	return TRUE

/// Remove an identification even when its body is outside camera coverage.
/obj/machinery/overmap_droid_relay/proc/unmark_hostile(datum/weakref/reference)
	if(!(reference in hostile_targets))
		return FALSE
	hostile_targets -= reference
	var/mob/living/target = reference.resolve()
	if(target)
		UnregisterSignal(target, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	update_order_displays()
	return TRUE

/obj/machinery/overmap_droid_relay/proc/on_hostile_lost(mob/living/target)
	SIGNAL_HANDLER
	unmark_hostile(target.weak_reference)

/mob/living/basic/relay_droid
	/// Combat tactics may differ between chassis while sharing the same target selection.
	var/combat_subtree = /datum/bt_node/subtree/relay_combat/melee
	/// Priority and identity of the current engagement. During a search the blackboard holds only a turf.
	var/combat_priority = 0
	var/datum/weakref/combat_target_ref
	var/turf/combat_last_contact
	var/combat_contact_until
	/// An autonomous engagement can pause one operator order without losing its destination.
	var/paused_order
	var/datum/weakref/paused_destination_ref
	/// Latest locally witnessed attack on a squadmate.
	var/datum/weakref/defense_target_ref
	var/defense_contact_until
	/// Avoid immediately retrying the same unreachable marked body.
	var/datum/weakref/failed_combat_target_ref
	COOLDOWN_DECLARE(failed_combat_retry)
	COOLDOWN_DECLARE(hostile_scan)

/// Respond to attributed attacks against this deployed body, including when it has a pilot.
/mob/living/basic/relay_droid/proc/on_relay_attacked(atom/source, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	if(!(attack_flags & (ATTACKER_DAMAGING_ATTACK | ATTACKER_STAMINA_ATTACK)) || (!isliving(attacker) && !isobj(attacker)))
		return
	var/obj/machinery/overmap_droid_relay/relay = relay_ref?.resolve()
	if(!relay?.reaches(src) || (isliving(attacker) && !relay.valid_hostile_body(attacker)))
		return
	for(var/mob/living/basic/relay_droid/unit as anything in relay.droids)
		if(unit.combat_priority >= RELAY_COMBAT_DEFENSE || !unit.can_receive_relay_order() || unit.z != z || get_dist(unit, src) > 6 || !relay.reaches(unit))
			continue
		if(unit.sees_combat_target(attacker))
			unit.defense_target_ref = WEAKREF(attacker)
			unit.defense_contact_until = world.time + 2 SECONDS

/// Autonomous acquisition uses real map visibility in addition to the attack strategy.
/mob/living/basic/relay_droid/proc/sees_combat_target(atom/target)
	if(QDELETED(target) || !target.alpha || !can_attack_relay_target(target) || !isturf(target.loc) || !in_fov(target))
		return FALSE
	var/range = min(MAX_CAMERA_RANGE, ai_controller.max_target_distance)
	return get_dist(src, target) <= range && (target in view(range, src))

/// A deferred swing must still have authorization and a visible, reachable target when it executes.
/mob/living/basic/relay_droid/proc/can_strike_relay_target(atom/target)
	var/obj/machinery/overmap_droid_relay/relay = relay_ref?.resolve()
	if(!combat_priority || combat_target_ref?.resolve() != target || !relay?.reaches(src))
		return FALSE
	if(combat_priority == RELAY_COMBAT_MARKED && !(combat_target_ref in relay.hostile_targets))
		return FALSE
	return isliving(target) ? sees_combat_target(target) : can_attack_relay_target(target)

/// Change the active behavior while keeping any previously saved order.
/mob/living/basic/relay_droid/proc/set_relay_order(command, atom/destination, datum/bt_node/subtree/subtree_type)
	ai_controller.cancel_current_plan()
	order = command
	ai_controller.set_blackboard_key(BB_CURRENT_PET_TARGET, destination)
	ai_controller.set_behavior_tree_override(SUBPLAN_ID_PET_COMMAND, subtree_type)

/mob/living/basic/relay_droid/proc/start_combat_order(atom/target)
	start_engagement(target, RELAY_COMBAT_ORDER)

/mob/living/basic/relay_droid/proc/start_engagement(atom/target, priority)
	if(!combat_priority && order != "hold")
		paused_order = order
		var/atom/destination = ai_controller.blackboard[BB_CURRENT_PET_TARGET]
		paused_destination_ref = destination ? WEAKREF(destination) : null
	combat_priority = priority
	combat_target_ref = WEAKREF(target)
	combat_last_contact = get_turf(target)
	combat_contact_until = world.time + 2 SECONDS
	set_relay_order("attack", target, combat_subtree)

/// Forget both active and requested combat when the operator deliberately changes orders.
/mob/living/basic/relay_droid/proc/clear_combat_intent()
	clear_engagement()
	paused_order = null
	paused_destination_ref = null
	defense_target_ref = null
	defense_contact_until = null
	failed_combat_target_ref = null
	COOLDOWN_RESET(src, failed_combat_retry)

/mob/living/basic/relay_droid/proc/clear_engagement()
	combat_priority = 0
	combat_target_ref = null
	combat_last_contact = null
	combat_contact_until = null

/// Resume the exact paused leg of the patrol or the previous movement/follow order.
/mob/living/basic/relay_droid/proc/finish_engagement(failed = FALSE)
	if(failed)
		failed_combat_target_ref = combat_target_ref
		COOLDOWN_START(src, failed_combat_retry, 3 SECONDS)
	clear_engagement()
	var/atom/destination = paused_destination_ref?.resolve()
	var/previous_order = paused_order
	paused_order = null
	paused_destination_ref = null
	if(destination && destination.z == z)
		switch(previous_order)
			if("move")
				set_relay_order(previous_order, destination, /datum/bt_node/subtree/pet_command/move_to)
				return
			if("follow")
				set_relay_order(previous_order, destination, /datum/bt_node/subtree/pet_command/follow)
				return
			if("patrol")
				set_relay_order(previous_order, destination, /datum/bt_node/subtree/relay_patrol)
				return
	patrol_first = null
	patrol_second = null
	ai_controller.clear_blackboard_key(BB_CURRENT_PET_TARGET)
	ai_controller.set_behavior_tree_override(SUBPLAN_ID_PET_COMMAND, null)
	order = "hold"

/// Look at the operator's marked bodies only. Keep an existing contact stable until it ends.
/mob/living/basic/relay_droid/proc/find_marked_combat_target(obj/machinery/overmap_droid_relay/relay)
	if(!length(relay.hostile_targets) || !COOLDOWN_FINISHED(src, hostile_scan))
		return null
	COOLDOWN_START(src, hostile_scan, 0.5 SECONDS)
	var/mob/living/closest
	var/closest_distance = MAX_CAMERA_RANGE + 1
	for(var/datum/weakref/reference as anything in relay.hostile_targets)
		if(reference == failed_combat_target_ref && !COOLDOWN_FINISHED(src, failed_combat_retry))
			continue
		var/mob/living/candidate = reference.resolve()
		if(!candidate || candidate.z != z)
			continue
		var/distance = get_dist(src, candidate)
		if(distance < closest_distance && sees_combat_target(candidate))
			closest = candidate
			closest_distance = distance
	return closest

/// Run targeting before movement and weapons, with the same priorities for every chassis.
/mob/living/basic/relay_droid/proc/update_combat_order()
	var/obj/machinery/overmap_droid_relay/relay = relay_ref?.resolve()
	if(!combat_priority && !defense_target_ref && (!length(relay?.hostile_targets) || !COOLDOWN_FINISHED(src, hostile_scan)))
		return
	if(!relay?.reaches(src))
		if(combat_priority)
			finish_engagement()
		return
	if(combat_priority < RELAY_COMBAT_DEFENSE && defense_target_ref)
		var/atom/attacker = defense_target_ref.resolve()
		defense_target_ref = null
		if(world.time <= defense_contact_until && attacker && sees_combat_target(attacker))
			start_engagement(attacker, RELAY_COMBAT_DEFENSE)
			return
	if(!combat_priority)
		var/mob/living/marked = find_marked_combat_target(relay)
		if(marked)
			start_engagement(marked, RELAY_COMBAT_MARKED)
		return

	var/atom/target = combat_target_ref?.resolve()
	if(!target || (combat_priority == RELAY_COMBAT_MARKED && !(combat_target_ref in relay.hostile_targets)))
		finish_engagement()
		return
	if(!isliving(target))
		if(!can_attack_relay_target(target))
			finish_engagement()
		return
	var/mob/living/body = target
	if(!relay.valid_hostile_body(body) || body.stat > HARD_CRIT)
		finish_engagement()
		return
	if(sees_combat_target(body))
		combat_last_contact = get_turf(body)
		combat_contact_until = world.time + 2 SECONDS
		if(ai_controller.blackboard[BB_CURRENT_PET_TARGET] != body)
			set_relay_order("attack", body, combat_subtree)
		return
	if(!combat_last_contact || combat_last_contact == loc || combat_last_contact.z != z || world.time >= combat_contact_until || combat_last_contact.is_blocked_turf(exclude_mobs = TRUE))
		finish_engagement(TRUE)
		return
	if(ai_controller.blackboard[BB_CURRENT_PET_TARGET] != combat_last_contact)
		set_relay_order("attack", combat_last_contact, /datum/bt_node/subtree/pet_command/move_to)

#undef RELAY_COMBAT_MARKED
#undef RELAY_COMBAT_DEFENSE
#undef RELAY_COMBAT_ORDER
