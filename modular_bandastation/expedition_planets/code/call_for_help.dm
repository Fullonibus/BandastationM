/// Planet fauna hears nearby faction members through obstacles, without learning an unseen enemy's position.
#define EXPEDITION_HELP_RANGE 12
/// A hurt creature cannot keep calling its neighbours on every hit.
#define EXPEDITION_HELP_COOLDOWN (15 SECONDS)
/// A call is a short investigation, not an indefinite pursuit of an unseen attacker.
#define EXPEDITION_HELP_DURATION (30 SECONDS)
/// Fixed place where a planet creature called for help.
#define BB_EXPEDITION_HELP_LOCATION "expedition_help_location"
/// Marks a planet nest already subscribed to its native spawner component.
#define TRAIT_EXPEDITION_HELP_SPAWNER "expedition_help_spawner"

/** Only basic fauna has the combat-tree contract; legacy animals keep their existing AI. */
/mob/living/proc/add_expedition_help()
	if(!isbasicmob(src) || !istype(ai_controller, /datum/ai_controller/basic_controller))
		return
	AddElement(/datum/element/stationtrauma_call_for_help)

/** Hurt planet fauna recruits idle faction members; ordinary station fauna is unchanged. */
/datum/element/stationtrauma_call_for_help

/datum/element/stationtrauma_call_for_help/Attach(datum/target)
	. = ..()
	var/mob/living/basic/creature = target
	if(!istype(creature) || !istype(creature.ai_controller, /datum/ai_controller/basic_controller))
		return ELEMENT_INCOMPATIBLE
	var/datum/bt_node/ai_behavior/move_to_target/expedition_help/existing = locate() in creature.ai_controller.behavior_nodes
	if(existing)
		return
	creature.AddElement(/datum/element/relay_attackers)
	RegisterSignal(creature, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_attacked))
	RegisterSignal(creature, COMSIG_PAWN_POSSESSED_BY_AI_CONTROLLER, PROC_REF(on_controller_changed))
	install_investigation(creature.ai_controller)

/datum/element/stationtrauma_call_for_help/Detach(datum/source, ...)
	var/mob/living/basic/creature = source
	UnregisterSignal(source, list(COMSIG_ATOM_WAS_ATTACKED, COMSIG_PAWN_POSSESSED_BY_AI_CONTROLLER))
	var/datum/ai_controller/controller = creature.ai_controller
	var/datum/bt_node/ai_behavior/move_to_target/expedition_help/investigation = locate() in controller?.behavior_nodes
	if(investigation)
		controller.cancel_current_plan()
		controller.clear_blackboard_key(BB_EXPEDITION_HELP_LOCATION)
		controller.behavior_nodes -= investigation
		qdel(investigation)
		controller.finalize_tree()
	return ..()

/** Retain the mob's original tree and give an outstanding investigation priority over idle wandering. */
/datum/element/stationtrauma_call_for_help/proc/install_investigation(datum/ai_controller/controller)
	if(!istype(controller, /datum/ai_controller/basic_controller))
		return
	var/datum/bt_node/ai_behavior/move_to_target/expedition_help/existing = locate() in controller.behavior_nodes
	if(existing)
		return
	var/datum/bt_node/node = controller.resolve_child_node(/datum/bt_node/ai_behavior/move_to_target/expedition_help)
	controller.behavior_nodes.Insert(1, node)
	controller.finalize_tree()

/datum/element/stationtrauma_call_for_help/proc/on_controller_changed(mob/living/basic/source, datum/ai_controller/controller)
	SIGNAL_HANDLER
	install_investigation(controller)

/datum/element/stationtrauma_call_for_help/proc/on_attacked(mob/living/basic/victim, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	var/mob/living/hostile = attacker
	var/datum/ai_controller/controller = victim.ai_controller
	if(!(attack_flags & ATTACKER_DAMAGING_ATTACK) || !istype(hostile) || QDELETED(hostile) || hostile.stat == DEAD \
		|| hostile == victim || victim.stat == DEAD || !controller || controller.forced_off || victim.faction_check_atom(hostile))
		return
	// Being attacked takes precedence over investigating somebody else's call.
	if(controller.blackboard[BB_EXPEDITION_HELP_LOCATION])
		controller.cancel_current_plan()
		controller.clear_blackboard_key(BB_EXPEDITION_HELP_LOCATION)
	if(world.time < controller.blackboard[BB_BASIC_MOB_REINFORCEMENTS_COOLDOWN])
		return
	controller.set_blackboard_key(BB_BASIC_MOB_REINFORCEMENTS_COOLDOWN, world.time + EXPEDITION_HELP_COOLDOWN)
	INVOKE_ASYNC(src, PROC_REF(shout), victim, controller.blackboard[BB_REINFORCEMENTS_SAY], controller.blackboard[BB_REINFORCEMENTS_EMOTE])
	for(var/mob/living/basic/ally in range(EXPEDITION_HELP_RANGE, victim))
		var/datum/ai_controller/ally_controller = ally.ai_controller
		if(ally == victim || ally.stat || ally.client || !ally_controller || ally_controller.forced_off \
			|| !victim.faction_check_atom(ally) || ally.faction_check_atom(hostile) || (hostile in ally_controller.blackboard[BB_FRIENDS_LIST]) \
			|| ally_controller.blackboard[BB_CURRENT_TARGET] || ally_controller.blackboard[BB_EXPEDITION_HELP_LOCATION])
			continue
		var/datum/bt_node/ai_behavior/move_to_target/expedition_help/investigation = locate() in ally_controller.behavior_nodes
		if(!investigation)
			continue
		ally_controller.cancel_current_plan()
		investigation.attacker_ref = WEAKREF(hostile)
		investigation.expires_at = world.time + EXPEDITION_HELP_DURATION
		ally_controller.set_blackboard_key(BB_EXPEDITION_HELP_LOCATION, get_turf(victim))
		ally_controller.reset_ai_status()

/** Speech can sleep, so it runs outside the attack signal. */
/datum/element/stationtrauma_call_for_help/proc/shout(mob/living/victim, say_text, emote_text)
	if(QDELETED(victim) || victim.stat == DEAD)
		return
	if(say_text)
		victim.say(say_text, forced = "AI Controller")
	else
		victim.manual_emote(emote_text || "зовёт своих на помощь!")

/** Walk to a fixed reported location, then hand visible enemies to the original combat tree. */
/datum/bt_node/ai_behavior/move_to_target/expedition_help
	target_key = BB_EXPEDITION_HELP_LOCATION
	/// Remember identity without retaining a deleted enemy or following its hidden movements.
	var/datum/weakref/attacker_ref
	/// Absolute end of this investigation; movement does not extend it.
	var/expires_at = 0

/datum/bt_node/ai_behavior/move_to_target/expedition_help/Destroy()
	attacker_ref = null
	return ..()

/datum/bt_node/ai_behavior/move_to_target/expedition_help/setup(datum/ai_controller/controller)
	if(!controller.blackboard[target_key])
		return FALSE
	return ..()

/datum/bt_node/ai_behavior/move_to_target/expedition_help/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/hostile = attacker_ref?.resolve()
	var/turf/hostile_turf = get_turf(hostile)
	var/turf/our_turf = get_turf(controller.pawn)
	if(!hostile || hostile.stat == DEAD || !hostile_turf || !our_turf || hostile_turf.z != our_turf.z \
		|| world.time >= expires_at || controller.blackboard[BB_CURRENT_TARGET])
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(controller.blackboard[BB_TARGETING_STRATEGY])
	if(strategy && can_see(controller.pawn, hostile, 9) && strategy.is_valid_target(controller.pawn, hostile, 9, controller))
		controller.set_blackboard_key_assoc_lazylist(BB_BASIC_MOB_RETALIATE_LIST, hostile, world.time)
		controller.set_blackboard_key(BB_CURRENT_TARGET, hostile)
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	return ..()

/datum/bt_node/ai_behavior/move_to_target/expedition_help/finish_action(datum/ai_controller/controller, succeeded)
	. = ..()
	controller.clear_blackboard_key(target_key)
	attacker_ref = null
	expires_at = 0

/** Planet dens give the same local help behaviour to their future offspring. */
/datum/element/stationtrauma_help_spawner

/datum/element/stationtrauma_help_spawner/Attach(datum/target)
	. = ..()
	var/obj/structure/spawner/den = target
	if(!istype(den))
		return ELEMENT_INCOMPATIBLE
	var/datum/component/spawner/spawning = den.GetComponent(/datum/component/spawner)
	if(!spawning)
		return ELEMENT_INCOMPATIBLE
	if(HAS_TRAIT(den, TRAIT_EXPEDITION_HELP_SPAWNER))
		return
	ADD_TRAIT(den, TRAIT_EXPEDITION_HELP_SPAWNER, REF(src))
	RegisterSignal(spawning, COMSIG_SPAWNER_SPAWNED, PROC_REF(on_spawned))
	for(var/datum/weakref/member as anything in spawning.spawned_things)
		var/mob/living/creature = member.resolve()
		creature?.add_expedition_help()

/datum/element/stationtrauma_help_spawner/Detach(datum/source, ...)
	var/obj/structure/spawner/den = source
	var/datum/component/spawner/spawning = den.GetComponent(/datum/component/spawner)
	if(spawning)
		UnregisterSignal(spawning, COMSIG_SPAWNER_SPAWNED)
	REMOVE_TRAIT(den, TRAIT_EXPEDITION_HELP_SPAWNER, REF(src))
	return ..()

/datum/element/stationtrauma_help_spawner/proc/on_spawned(datum/source, mob/living/creature)
	SIGNAL_HANDLER
	creature.add_expedition_help()

#undef EXPEDITION_HELP_RANGE
#undef EXPEDITION_HELP_COOLDOWN
#undef EXPEDITION_HELP_DURATION
#undef BB_EXPEDITION_HELP_LOCATION
#undef TRAIT_EXPEDITION_HELP_SPAWNER
