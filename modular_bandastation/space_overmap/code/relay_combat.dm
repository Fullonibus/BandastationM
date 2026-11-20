/// Current attack position, shared with the other droids registered to this relay.
#define BB_RELAY_MELEE_SLOT "BB_relay_melee_slot"
/// Bound retries when the target is visible but the droid cannot reach its flank.
#define RELAY_MELEE_STALL_TIMEOUT (5 SECONDS)
/// Cap how many tiles a combat route can expand in one AI tick.
#define RELAY_MELEE_ROUTE_BUDGET 192
/// Wait briefly before planning again if a route or its destination becomes blocked.
#define RELAY_MELEE_REPATH_DELAY (0.4 SECONDS)

/// Combat subtree selected by the droid chassis while its target is visible.
/datum/bt_node/subtree/relay_combat

/// Close to a free flank and take one safe step during melee recovery.
/datum/bt_node/subtree/relay_combat/melee/New()
	. = ..()
	root = new /datum/bt_node/ai_behavior/relay_melee

/// Reserves and paths to one attack position at a time, using the relay's actual deployed units.
/datum/bt_node/ai_behavior/relay_melee
	/// The target's last observed turf, used to pause the move loop if the target moves.
	var/turf/target_turf
	/// The droid's last observed turf, used to detect progress.
	var/turf/previous_turf
	/// Earliest time to plan another route after an obstruction or a moving target.
	var/retry_at = 0
	/// Time at which to give up without movement progress or a usable attack position.
	var/stall_deadline = 0
	/// Set by the path loop when its route becomes unusable.
	var/path_failed = FALSE
	/// Earliest moment to take the single step after a swing. Infinity means the step was attempted.
	var/recover_at = 0
	/// Local pathing limits for verifying links without opening doors.
	var/datum/can_pass_info/pass_info

/datum/bt_node/ai_behavior/relay_melee/setup(datum/ai_controller/controller)
	var/mob/living/basic/relay_droid/unit = controller.pawn
	var/atom/target = controller.blackboard[BB_CURRENT_PET_TARGET]
	if(QDELETED(unit) || QDELETED(target) || !unit.can_receive_relay_order())
		return FALSE
	pass_info = new(unit, no_id = TRUE)
	stall_deadline = world.time + RELAY_MELEE_STALL_TIMEOUT
	RegisterSignal(unit, COMSIG_HOSTILE_POST_ATTACKINGTARGET, PROC_REF(on_swing))
	RegisterSignal(unit, COMSIG_MOB_AI_MOVEMENT_FAILED, PROC_REF(on_movement_failed))
	return TRUE

/datum/bt_node/ai_behavior/relay_melee/Destroy()
	// Changing a runtime override can delete its root before the next full tree reset.
	reset_tick_state()
	return ..()

/datum/bt_node/ai_behavior/relay_melee/finish_action(datum/ai_controller/controller, succeeded)
	if(controller.pawn)
		UnregisterSignal(controller.pawn, list(COMSIG_HOSTILE_POST_ATTACKINGTARGET, COMSIG_MOB_AI_MOVEMENT_FAILED))
	controller.ai_movement.stop_moving_towards(controller)
	controller.clear_blackboard_key(BB_RELAY_MELEE_SLOT)
	QDEL_NULL(pass_info)
	target_turf = null
	previous_turf = null
	retry_at = 0
	recover_at = 0
	path_failed = FALSE
	return ..()

/datum/bt_node/ai_behavior/relay_melee/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/basic/relay_droid/unit = controller.pawn
	var/atom/target = controller.blackboard[BB_CURRENT_PET_TARGET]
	var/obj/machinery/overmap_droid_relay/relay = unit.relay_ref?.resolve()
	target_turf = get_turf(target)
	var/turf/current = unit.loc
	if(QDELETED(target) || QDELETED(relay) || !target_turf || !isturf(current) || !unit.can_receive_relay_order())
		return AI_BEHAVIOR_FAILED
	if(previous_turf != current)
		previous_turf = current
		stall_deadline = world.time + RELAY_MELEE_STALL_TIMEOUT

	if(recover_at)
		if(world.time < unit.next_move)
			if(path_failed || current == controller.blackboard[BB_CURRENT_MOVEMENT_TARGET])
				controller.ai_movement.stop_moving_towards(controller)
				path_failed = FALSE
			if(world.time >= recover_at && recover_at != INFINITY)
				recover_at = INFINITY
				var/turf/sidestep = find_recovery_step(unit, relay, target)
				if(sidestep)
					controller.set_blackboard_key(BB_RELAY_MELEE_SLOT, sidestep)
					unit.face_atom(target)
					start_route(controller, list(sidestep), keep_facing = TRUE)
			return AI_BEHAVIOR_INSTANT
		recover_at = 0
		controller.ai_movement.stop_moving_towards(controller)

	var/turf/slot = controller.blackboard[BB_RELAY_MELEE_SLOT]
	var/turf/route_destination = controller.blackboard[BB_CURRENT_MOVEMENT_TARGET]
	if(path_failed || (slot && (!valid_slot(unit, relay, slot, target) || (slot != current && slot != route_destination))))
		path_failed = FALSE
		controller.clear_blackboard_key(BB_RELAY_MELEE_SLOT)
		controller.ai_movement.stop_moving_towards(controller)
		slot = null

	if(!slot)
		if(valid_slot(unit, relay, current, target))
			slot = current
			controller.set_blackboard_key(BB_RELAY_MELEE_SLOT, current)
		else if(world.time >= retry_at)
			retry_at = world.time + RELAY_MELEE_REPATH_DELAY
			var/list/turf/route = find_approach(unit, relay, target, current)
			if(length(route))
				slot = route[length(route)]
				controller.set_blackboard_key(BB_RELAY_MELEE_SLOT, slot)
				start_route(controller, route)

	if(current != slot)
		return world.time >= stall_deadline ? AI_BEHAVIOR_FAILED : AI_BEHAVIOR_INSTANT

	stall_deadline = world.time + RELAY_MELEE_STALL_TIMEOUT
	if(controller.blackboard[BB_CURRENT_MOVEMENT_TARGET])
		controller.ai_movement.stop_moving_towards(controller)
	if(world.time >= unit.next_move)
		INVOKE_ASYNC(src, PROC_REF(swing), controller, target)
	return AI_BEHAVIOR_INSTANT

/// Pass through the normal click chain for both living targets and structures.
/datum/bt_node/ai_behavior/relay_melee/proc/swing(datum/ai_controller/controller, atom/target)
	if(QDELETED(src) || QDELETED(controller) || !running || !controller.able_to_run || target != controller.blackboard[BB_CURRENT_PET_TARGET])
		return
	var/mob/living/basic/relay_droid/unit = controller.pawn
	if(QDELETED(unit) || !unit.can_receive_relay_order() || unit.order != "attack" || world.time < unit.next_move || !unit.can_strike_relay_target(target) || !target.IsReachableBy(unit))
		return
	controller.ai_interact(target, TRUE)

/// A click can be refused by cooldown, range or another interaction check before a swing occurs.
/datum/bt_node/ai_behavior/relay_melee/proc/on_swing(mob/living/source, atom/target, result)
	SIGNAL_HANDLER
	if(result && running && target == owning_controller.blackboard[BB_CURRENT_PET_TARGET])
		recover_at = world.time + (0.3 SECONDS)

/datum/bt_node/ai_behavior/relay_melee/proc/on_movement_failed()
	SIGNAL_HANDLER
	path_failed = TRUE

/// Find the shortest walkable route to any free flank with one bounded breadth-first search.
/datum/bt_node/ai_behavior/relay_melee/proc/find_approach(mob/living/basic/relay_droid/unit, obj/machinery/overmap_droid_relay/relay, atom/target, turf/start)
	var/list/slots = list()
	for(var/direction in GLOB.alldirs)
		var/turf/candidate = get_step(target_turf, direction)
		if(valid_slot(unit, relay, candidate, target))
			slots[candidate] = TRUE
	if(!length(slots))
		return null

	var/list/turf/frontier = list(start)
	var/list/turf/parents = list()
	parents[start] = start
	for(var/index = 1; index <= length(frontier) && index <= RELAY_MELEE_ROUTE_BUDGET; index++)
		var/turf/current = frontier[index]
		if(slots[current])
			var/list/turf/route = list()
			for(var/turf/step = current; step != start; step = parents[step])
				route += step
			return reverse_range(route)
		for(var/direction in GLOB.alldirs)
			var/turf/step = get_step(current, direction)
			if(!step || step == target_turf || parents[step] || !can_take_step(unit, relay, current, step))
				continue
			parents[step] = current
			frontier += step
	return null

/datum/bt_node/ai_behavior/relay_melee/proc/valid_slot(mob/living/basic/relay_droid/unit, obj/machinery/overmap_droid_relay/relay, turf/candidate, atom/target)
	if(QDELETED(candidate) || !can_use_turf(unit, relay, candidate))
		return FALSE
	if(candidate == unit.loc)
		return target.IsReachableBy(unit)
	return candidate != target_turf && target_turf.Adjacent(candidate, target = target, mover = unit)

/// During recovery, stay in striking range and leave the corridor behind the droid clear.
/datum/bt_node/ai_behavior/relay_melee/proc/find_recovery_step(mob/living/basic/relay_droid/unit, obj/machinery/overmap_droid_relay/relay, atom/target)
	if(!target.IsReachableBy(unit))
		return null
	var/turf/current = unit.loc
	for(var/direction in GLOB.alldirs)
		var/turf/candidate = get_step(current, direction)
		if(valid_slot(unit, relay, candidate, target) && can_take_step(unit, relay, current, candidate))
			return candidate
	return null

/// Check occupancy and reservations. Directional obstacles are checked by the links between tiles.
/datum/bt_node/ai_behavior/relay_melee/proc/can_use_turf(mob/living/basic/relay_droid/unit, obj/machinery/overmap_droid_relay/relay, turf/candidate)
	if(!candidate || candidate.density || !candidate.can_cross_safely(unit) || (isspaceturf(candidate) && !HAS_TRAIT(unit, TRAIT_SPACEWALK)))
		return FALSE
	for(var/atom/movable/obstacle as anything in candidate.contents)
		if(obstacle != unit && obstacle.density && !(obstacle.flags_1 & ON_BORDER_1) && !obstacle.CanPass(unit, NONE))
			return FALSE
	for(var/mob/living/basic/relay_droid/ally as anything in relay.droids)
		if(ally != unit && (ally.loc == candidate || ally.ai_controller?.blackboard[BB_RELAY_MELEE_SLOT] == candidate))
			return FALSE
	return TRUE

/// Both orders of a diagonal must be clear, so the move cannot stop partway through.
/datum/bt_node/ai_behavior/relay_melee/proc/can_take_step(mob/living/basic/relay_droid/unit, obj/machinery/overmap_droid_relay/relay, turf/current, turf/destination)
	if(!isturf(current) || !destination || destination == current || destination.z != current.z || get_dist(current, destination) > 1 || !can_use_turf(unit, relay, destination))
		return FALSE
	var/direction = get_dir(current, destination)
	if(!ISDIAGONALDIR(direction))
		return !current.LinkBlockedWithAccess(destination, pass_info)
	for(var/cardinal in GLOB.cardinals)
		if(!(direction & cardinal))
			continue
		var/turf/intermediate = get_step(current, cardinal)
		if(intermediate == target_turf || !can_use_turf(unit, relay, intermediate) || current.LinkBlockedWithAccess(intermediate, pass_info) || intermediate.LinkBlockedWithAccess(destination, pass_info))
			return FALSE
	return TRUE

/// Follow the planned route using the normal AI movement loop and order display.
/datum/bt_node/ai_behavior/relay_melee/proc/start_route(datum/ai_controller/controller, list/turf/route, keep_facing = FALSE)
	var/datum/ai_movement/jps/movement = controller.ai_movement
	var/datum/move_loop/has_target/jps/loop = movement.start_moving_towards(controller, route[length(route)], 0, initial_path = route)
	if(!loop)
		path_failed = TRUE
		return
	if(keep_facing)
		loop.flags |= MOVEMENT_LOOP_NO_DIR_UPDATE
	RegisterSignal(loop, COMSIG_MOVELOOP_PREPROCESS_CHECK, PROC_REF(check_step))
	RegisterSignal(loop, COMSIG_MOVELOOP_POSTPROCESS, PROC_REF(on_step_result))

/datum/bt_node/ai_behavior/relay_melee/proc/on_step_result(datum/move_loop/has_target/jps/source, result)
	SIGNAL_HANDLER
	if(result == MOVELOOP_FAILURE)
		path_failed = TRUE

/datum/bt_node/ai_behavior/relay_melee/proc/check_step(datum/move_loop/has_target/jps/source)
	SIGNAL_HANDLER
	var/mob/living/basic/relay_droid/unit = source.moving
	if(path_failed || QDELETED(unit) || !unit.can_receive_relay_order() || unit.order != "attack" || unit.loc == source.target)
		return MOVELOOP_SKIP_STEP
	if(get_turf(owning_controller.blackboard[BB_CURRENT_PET_TARGET]) != target_turf)
		return MOVELOOP_SKIP_STEP
	var/obj/machinery/overmap_droid_relay/relay = unit.relay_ref?.resolve()
	var/turf/next_step = length(source.movement_path) ? source.movement_path[1] : null
	if(relay && next_step != target_turf && can_take_step(unit, relay, unit.loc, next_step))
		return NONE
	path_failed = TRUE
	return MOVELOOP_SKIP_STEP

#undef RELAY_MELEE_REPATH_DELAY
#undef RELAY_MELEE_ROUTE_BUDGET
#undef RELAY_MELEE_STALL_TIMEOUT
#undef BB_RELAY_MELEE_SLOT
