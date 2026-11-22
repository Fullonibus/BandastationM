/mob/living/basic/relay_operator
	name = "оператор реле"
	icon = 'modular_bandastation/space_overmap/icons/droid_relay.dmi'
	icon_state = "operator"
	icon_living = "operator"
	icon_dead = "operator"
	density = FALSE
	habitable_atmos = null
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	/// Physical home and command interface.
	var/datum/weakref/relay_ref

/mob/living/basic/relay_operator/Initialize(mapload, obj/machinery/overmap_droid_relay/relay)
	. = ..()
	if(QDELETED(relay))
		return INITIALIZE_HINT_QDEL
	relay_ref = WEAKREF(relay)
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, INNATE_TRAIT)
	RegisterSignal(src, COMSIG_MOB_CLICKON, PROC_REF(capture_click))
	RegisterSignal(src, COMSIG_MOB_LOGOUT, PROC_REF(end_camera))
	GRANT_ACTION(/datum/action/innate/relay_open)
	GRANT_ACTION(/datum/action/innate/relay_hivemind)

/mob/living/basic/relay_operator/proc/capture_click(datum/source, atom/target, list/modifiers)
	SIGNAL_HANDLER
	var/obj/machinery/overmap_droid_relay/relay = relay_ref?.resolve()
	relay?.handle_tactical_click(target, modifiers)
	return COMSIG_MOB_CANCEL_CLICKON

/mob/living/basic/relay_operator/proc/end_camera()
	SIGNAL_HANDLER
	var/obj/machinery/overmap_droid_relay/relay = relay_ref?.resolve()
	relay?.clear_camera()

/mob/living/basic/relay_droid
	name = "боевой дроид"
	desc = "Автономный робот с зашифрованной связью с командным реле."
	icon = 'modular_bandastation/space_overmap/icons/droid_relay.dmi'
	icon_state = "droid"
	icon_living = "droid"
	icon_dead = "droid_dead"
	gender = NEUTER
	mob_biotypes = MOB_ROBOTIC
	health = 65
	maxHealth = 65
	melee_damage_lower = 12
	melee_damage_upper = 15
	// Reinforced airlocks deflect weaker hits.
	obj_damage = 35
	melee_attack_cooldown = 1.5 SECONDS
	attack_verb_continuous = "strikes"
	attack_verb_simple = "strike"
	attack_sound = SFX_PUNCH
	habitable_atmos = null
	minimum_survivable_temperature = TCMB
	physiology = list(STAMINA = 0)
	combat_mode = TRUE
	ai_controller = /datum/ai_controller/basic_controller/relay_droid
	/// Installation which owns this body and its communications.
	var/datum/weakref/relay_ref
	/// Sector entered on the last launch.
	var/datum/weakref/sector_ref
	/// Map site entered by a remote launch.
	var/datum/weakref/site_ref
	/// True while a supply pod is delivering the body.
	var/in_transit = FALSE
	/// True while reserved for a guest poll.
	var/polling = FALSE
	/// True while the self-destruct countdown is running.
	var/detonating = FALSE
	/// Last autonomous order, shown on the console.
	var/order = "hold"
	/// Endpoints of the current patrol.
	var/turf/patrol_first
	/// Endpoints of the current patrol.
	var/turf/patrol_second

/mob/living/basic/relay_droid/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/dextrous, hands_count = 1)
	AddElement(/datum/element/relay_attackers)
	AddComponent(/datum/component/basic_inhands)
	RegisterSignal(src, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_relay_attacked))
	GRANT_ACTION(/datum/action/innate/relay_hivemind)
	GRANT_ACTION(/datum/action/innate/relay_return)

/mob/living/basic/relay_droid/can_hold_items(obj/item/item)
	return (!item || istype(item, /obj/item/relay_beacon)) && ..()

/mob/living/basic/relay_droid/put_in_hand_check(obj/item/item)
	return can_hold_items(item) && ..()

/mob/living/basic/relay_droid/death(gibbed)
	var/obj/machinery/overmap_droid_relay/relay = relay_ref?.resolve()
	relay?.release_control(src)
	return ..()

/mob/living/basic/relay_droid/ghostize(can_reenter_corpse = TRUE, forced = FALSE)
	. = ..()
	if(. && !can_reenter_corpse)
		var/obj/machinery/overmap_droid_relay/relay = relay_ref?.resolve()
		relay?.release_control(src)

/mob/living/basic/relay_droid/Destroy()
	var/obj/machinery/overmap_droid_relay/relay = relay_ref?.resolve()
	relay?.release_control(src)
	relay_ref = null
	sector_ref = null
	site_ref = null
	patrol_first = null
	patrol_second = null
	return ..()

/// Whether the deployed body can execute directives from the relay.
/mob/living/basic/relay_droid/proc/can_receive_relay_order()
	return !QDELETED(src) && !client && !key && !mind && !polling && !in_transit && !detonating && ai_controller && stat == STABLE && isturf(loc)

/// Check whether this droid can see and damage the target of an autonomous attack.
/mob/living/basic/relay_droid/proc/can_attack_relay_target(atom/target)
	if(!ai_controller)
		return FALSE
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(/datum/targeting_strategy/basic/relay_droid)
	return strategy?.is_valid_target(src, target, ai_controller.max_target_distance, ai_controller) || FALSE

/// Clear both the order and any running path.
/mob/living/basic/relay_droid/proc/clear_order()
	clear_combat_intent()
	order = "hold"
	patrol_first = null
	patrol_second = null
	ai_controller?.cancel_current_plan()
	ai_controller?.clear_blackboard_key(BB_CURRENT_PET_TARGET)
	ai_controller?.set_behavior_tree_override(SUBPLAN_ID_PET_COMMAND, null)

/// Issue a path or combat directive to an unoccupied autonomous body.
/mob/living/basic/relay_droid/proc/receive_order(command, atom/target, turf/first)
	if(!can_receive_relay_order())
		return FALSE
	var/datum/bt_node/subtree/subtree_type
	switch(command)
		if("hold")
			clear_order()
			return TRUE
		if("move")
			if(!isturf(target))
				return FALSE
			subtree_type = /datum/bt_node/subtree/pet_command/move_to
		if("follow")
			if(!isliving(target) || target == src)
				return FALSE
			subtree_type = /datum/bt_node/subtree/pet_command/follow
		if("patrol")
			if(!isturf(target) || !first || first == target)
				return FALSE
			subtree_type = /datum/bt_node/subtree/relay_patrol
		if("attack")
			if(!can_attack_relay_target(target))
				return FALSE
			clear_order()
			start_combat_order(target)
			return TRUE
		else
			return FALSE
	clear_order()
	patrol_first = first
	patrol_second = command == "patrol" ? target : null
	set_relay_order(command, first || target, subtree_type)
	return TRUE

/// Give occupants a visible countdown and commit to destroying only this body.
/mob/living/basic/relay_droid/proc/arm_self_destruct(mob/issuer)
	if(detonating || in_transit || stat == DEAD || !isturf(loc))
		return
	detonating = TRUE
	to_chat(src, span_danger("Самоуничтожение через 3 секунды!"))
	visible_message(span_warning("[src] подаёт сигнал самоуничтожения."))
	log_game("[key_name(issuer)] armed [src] for self-destruct at [AREACOORD(src)].")
	addtimer(CALLBACK(src, PROC_REF(self_destruct)), 3 SECONDS)

/mob/living/basic/relay_droid/proc/self_destruct()
	if(stat == DEAD || !isturf(loc) || in_transit)
		detonating = FALSE
		return
	var/obj/machinery/overmap_droid_relay/relay = relay_ref?.resolve()
	relay?.release_control(src)
	explosion(src, light_impact_range = 1, flame_range = 0, flash_range = 1, explosion_cause = src)
	gib()

/datum/ai_controller/basic_controller/relay_droid
	behavior_tree_json = null
	behavior_nodes = list(/datum/bt_node/subtree/relay_order)
	ai_traits = DEFAULT_AI_FLAGS | RUN_WHILE_UNWATCHED
	ai_movement = /datum/ai_movement/jps
	blackboard = alist(
		BB_PET_TARGETING_STRATEGY = /datum/targeting_strategy/basic/relay_droid,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
	)

/datum/bt_node/subtree/relay_order
	override_id = SUBPLAN_ID_PET_COMMAND

/datum/bt_node/subtree/relay_order/tick(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/relay_droid/unit = controller.pawn
	if(!unit.can_receive_relay_order())
		if(override_node?.has_active_descendants())
			controller.cancel_current_plan()
		return BT_FAILURE
	unit.update_combat_order()
	if(!override_node)
		return BT_FAILURE
	// A replaced subtree starts next tick; its decorators see this tick as cancelled.
	if(controller.cancelled_during_tick)
		return BT_RUNNING
	var/atom/target = controller.blackboard[BB_CURRENT_PET_TARGET]
	if(QDELETED(target))
		. = BT_FAILURE
	else
		. = ..()
	if(unit.combat_priority && . != BT_RUNNING)
		unit.finish_engagement(. == BT_FAILURE)
	else if(. == BT_FAILURE || (. == BT_SUCCESS && unit.order == "move"))
		unit.clear_order()

/datum/bt_node/subtree/relay_patrol/New()
	. = ..()
	root = new /datum/bt_node/ai_behavior/move_to_target/relay_patrol

/datum/bt_node/ai_behavior/move_to_target/relay_patrol
	target_key = BB_CURRENT_PET_TARGET
	required_dist = 0

/datum/bt_node/ai_behavior/move_to_target/relay_patrol/perform(seconds_per_tick, datum/ai_controller/controller)
	. = ..()
	var/mob/living/basic/relay_droid/unit = controller.pawn
	if(. & AI_BEHAVIOR_SUCCEEDED)
		controller.set_blackboard_key(target_key, tracked_target == unit.patrol_first ? unit.patrol_second : unit.patrol_first)

/datum/targeting_strategy/basic/relay_droid
	ignore_faction = TRUE

/datum/targeting_strategy/basic/relay_droid/is_valid_target(mob/living/basic/relay_droid/unit, atom/target, vision_range, datum/ai_controller/controller)
	if(QDELETED(unit) || QDELETED(target) || unit == target || !isturf(unit.loc) || unit.is_blind())
		return FALSE
	var/obj/machinery/overmap_droid_relay/relay = unit.relay_ref?.resolve()
	if(!relay || target == relay || target == relay.operator || (target in relay.droids))
		return FALSE
	var/obj/docking_port/mobile/stationtrauma_space/ship = relay.linked_ship()
	if(ship?.is_in_shuttle_bounds(unit) || ship?.is_in_shuttle_bounds(target))
		return FALSE
	if(isnull(vision_range))
		vision_range = unit.ai_controller.max_target_distance
	if(isliving(target))
		return ..(unit, target, vision_range, controller)
	if(!isobj(target) || !isturf(target.loc) || unit.z != target.z || unit.see_invisible < target.invisibility)
		return FALSE
	var/obj/obstacle = target
	if(!obstacle.uses_integrity || !obstacle.get_integrity() || (obstacle.resistance_flags & INDESTRUCTIBLE))
		return FALSE
	if(isitem(obstacle) && !(obstacle.obj_flags & CAN_BE_HIT))
		return FALSE
	var/damage = unit.obj_damage || unit.melee_damage_upper
	if(damage <= 0 || damage < obstacle.damage_deflection || PENETRATE_ARMOUR(obstacle.get_armor_rating(MELEE), unit.armour_penetration) >= 100)
		return FALSE
	return !obstacle.IsObscured() && can_see(unit, obstacle, vision_range)

/datum/action/innate/relay_open
	name = "Пульт реле"
	desc = "Открыть интерфейс отряда."
	button_icon = 'modular_bandastation/space_overmap/icons/droid_relay_actions.dmi'
	button_icon_state = "panel"

/datum/action/innate/relay_open/Activate()
	var/mob/living/basic/relay_operator/operator = owner
	var/obj/machinery/overmap_droid_relay/relay = operator.relay_ref?.resolve()
	relay?.ui_interact(operator)

/datum/action/innate/relay_hivemind
	name = "Канал реле"
	desc = "Передать сообщение по закрытому каналу отряда."
	button_icon = 'modular_bandastation/space_overmap/icons/droid_relay_actions.dmi'
	button_icon_state = "hivemind"

/datum/action/innate/relay_hivemind/Activate()
	var/datum/weakref/relay_ref
	if(istype(owner, /mob/living/basic/relay_operator))
		var/mob/living/basic/relay_operator/operator = owner
		relay_ref = operator.relay_ref
	else if(istype(owner, /mob/living/basic/relay_droid))
		var/mob/living/basic/relay_droid/unit = owner
		relay_ref = unit.relay_ref
	var/obj/machinery/overmap_droid_relay/relay = relay_ref?.resolve()
	relay?.hivemind(owner)

/datum/action/innate/relay_return
	name = "Вернуться в реле"
	desc = "Передать управление корпусом обратно автоматике."
	button_icon = 'modular_bandastation/space_overmap/icons/droid_relay_actions.dmi'
	button_icon_state = "return"

/datum/action/innate/relay_return/IsAvailable(feedback = FALSE)
	var/mob/living/basic/relay_droid/unit = owner
	var/obj/machinery/overmap_droid_relay/relay = unit?.relay_ref?.resolve()
	return relay && relay.controlled == owner && ..()

/datum/action/innate/relay_return/Activate()
	var/mob/living/basic/relay_droid/unit = owner
	var/obj/machinery/overmap_droid_relay/relay = unit.relay_ref?.resolve()
	relay?.release_control(unit, keep_camera = TRUE)
