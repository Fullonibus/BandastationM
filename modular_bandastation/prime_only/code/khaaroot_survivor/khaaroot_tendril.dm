/// A retractable arm which catches distant victims and turns a physical arrival into a grab.
/datum/action/cooldown/khaaroot_mutation/tendril
	parent_type = /datum/action/cooldown/khaaroot_mutation/arm
	name = "Ловчий жгут"
	desc = "Раскрыть или скрыть ловчий отросток. Клик жгутом притягивает жертву и удерживает её в агрессивном захвате."
	button_icon_state = "tendril"
	cooldown_time = 10 SECONDS
	item_type = /obj/item/khaaroot_mutation_arm/tendril
	reveal_state = "reveal_tendril"
	/// Maximum projectile reach and return distance.
	var/tendril_range = 8
	/// Speed of the native return throw, in tiles per decisecond.
	var/return_speed = 2
	/// The only pending projectile or return throw owned by this revealed arm.
	var/datum/khaaroot_tendril_flight/pending_shot

/datum/action/cooldown/khaaroot_mutation/tendril/Destroy()
	QDEL_NULL(pending_shot)
	return ..()

/datum/action/cooldown/khaaroot_mutation/tendril/conceal(forced = FALSE)
	QDEL_NULL(pending_shot)
	return ..()

/// Fire from the real held arm; a revealed toggle being available does not bypass its shot cooldown.
/datum/action/cooldown/khaaroot_mutation/tendril/proc/fire_tendril(atom/target, mob/living/user, list/modifiers)
	if(user != owner || !IsAvailable(feedback = TRUE) || next_use_time > world.time || pending_shot)
		return FALSE
	if(held_item?.get_mutation_action() != src || user.get_active_held_item() != held_item)
		return FALSE
	if(!isturf(user.loc) || !(user.mobility_flags & MOBILITY_USE))
		return FALSE
	var/turf/target_turf = get_turf(target)
	if(QDELETED(target) || target == user || !target_turf || target_turf.z != user.z || get_dist(user, target_turf) > tendril_range)
		return FALSE
	if(!isturf(target) && !isturf(target.loc))
		return FALSE

	StartCooldown()
	pending_shot = new(src)
	pending_shot.launch(target, modifiers)
	return TRUE

/obj/item/khaaroot_mutation_arm/tendril
	name = "ловчий жгут"
	desc = "Раскрытая кисть разошлась на мясистые нити, сплетённые вокруг костяного крючка."
	icon_state = "tendril"
	inhand_icon_state = "tendril"
	item_flags = ABSTRACT|DROPDEL|NOBLUDGEON
	force = 0

/obj/item/khaaroot_mutation_arm/tendril/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	return ranged_interact_with_atom(interacting_with, user, modifiers)

/obj/item/khaaroot_mutation_arm/tendril/ranged_interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/action/cooldown/khaaroot_mutation/tendril/action = get_mutation_action()
	if(!istype(action) || !action.fire_tendril(interacting_with, user, modifiers))
		return ITEM_INTERACT_BLOCKING
	return ITEM_INTERACT_SUCCESS

/**
 * One shot owns its beam through both projectile travel and the native return throw.
 * The throw callback retains only a weak reference, so cancellation never leaves a deleted flight alive.
 */
/datum/khaaroot_tendril_flight
	/// Current mutation action, invalidated by removal, concealment, or body transfer.
	var/datum/weakref/action_ref
	/// The body which launched this shot, never a replacement body on the same mind.
	var/datum/weakref/owner_ref
	/// The projectile, until it hits or expires.
	var/datum/weakref/projectile_ref
	/// The actual hit victim, during the native return throw.
	var/datum/weakref/victim_ref
	/// Visual connection, replaced with an owner-to-victim beam after impact.
	var/datum/beam/beam
	/// Projectile deletion must not cancel a return throw which has already started.
	var/retracting = FALSE
	/// Guard the landing boundary against repeated or reentrant completion.
	var/finished = FALSE

/datum/khaaroot_tendril_flight/New(datum/action/cooldown/khaaroot_mutation/tendril/action)
	. = ..()
	action_ref = WEAKREF(action)
	owner_ref = WEAKREF(action.owner)

/datum/khaaroot_tendril_flight/Destroy()
	var/datum/action/cooldown/khaaroot_mutation/tendril/action = action_ref?.resolve()
	if(action?.pending_shot == src)
		action.pending_shot = null
	var/obj/projectile/khaaroot_tendril/projectile = projectile_ref?.resolve()
	if(projectile)
		projectile.flight_ref = null
		qdel(projectile)
	var/mob/living/victim = victim_ref?.resolve()
	if(victim)
		UnregisterSignal(victim, COMSIG_QDELETING)
	QDEL_NULL(beam)
	action_ref = null
	owner_ref = null
	projectile_ref = null
	victim_ref = null
	return ..()

/// Resolve through the shared item validator, which checks current body, membership, and held slot.
/datum/khaaroot_tendril_flight/proc/get_action()
	var/datum/action/cooldown/khaaroot_mutation/tendril/action = action_ref?.resolve()
	if(!action || action.pending_shot != src || action.owner != owner_ref?.resolve())
		return null
	if(action.held_item?.get_mutation_action() != action)
		return null
	return action

/// Configure all ownership before firing: an adjacent hit can start and finish synchronously.
/datum/khaaroot_tendril_flight/proc/launch(atom/target, list/modifiers)
	var/datum/action/cooldown/khaaroot_mutation/tendril/action = get_action()
	if(!action)
		qdel(src)
		return
	var/mob/living/user = owner_ref.resolve()
	var/obj/projectile/khaaroot_tendril/projectile = new(get_turf(user))
	projectile_ref = WEAKREF(projectile)
	projectile.flight_ref = WEAKREF(src)
	projectile.range = action.tendril_range
	projectile.maximum_range = action.tendril_range
	projectile.firer = user
	projectile.fired_from = action.held_item
	projectile.original = target
	if(!projectile.aim_projectile(target, user, modifiers))
		qdel(src)
		return
	beam = user.Beam(projectile, icon_state = "tentacle", emissive = NONE)
	playsound(user, 'sound/effects/splat.ogg', 60, TRUE)
	projectile.fire(direct_target = target)

/// Begin a real collision-sensitive return throw; finishing that throw is not itself proof of arrival.
/datum/khaaroot_tendril_flight/proc/retract(mob/living/victim)
	var/datum/action/cooldown/khaaroot_mutation/tendril/action = get_action()
	if(!action || retracting || QDELETED(victim) || victim.anchored || victim.throwing || !isturf(victim.loc))
		qdel(src)
		return
	var/mob/living/user = owner_ref.resolve()
	if(victim == user || !isturf(user.loc))
		qdel(src)
		return

	retracting = TRUE
	victim_ref = WEAKREF(victim)
	RegisterSignal(victim, COMSIG_QDELETING, PROC_REF(on_victim_deleted))
	QDEL_NULL(beam)
	beam = user.Beam(victim, icon_state = "tentacle", emissive = NONE)
	victim.visible_message(
		span_danger("Мясистый жгут [user.declent_ru(GENITIVE)] обвивает [victim.declent_ru(ACCUSATIVE)] и тянет к себе!"),
		span_userdanger("Мясистый жгут обвивает вас и тянет к [user.declent_ru(DATIVE)]!"),
	)
	if(!victim.throw_at(
		target = get_step_towards(user, victim),
		range = action.tendril_range,
		speed = action.return_speed,
		thrower = user,
		spin = FALSE,
		diagonals_first = TRUE,
		callback = CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(khaaroot_tendril_landed), WEAKREF(src)),
		gentle = TRUE,
	))
		qdel(src)

/// Release a missed projectile immediately, while allowing its successful return beam to outlive it.
/datum/khaaroot_tendril_flight/proc/projectile_deleted()
	projectile_ref = null
	if(!retracting)
		qdel(src)

/datum/khaaroot_tendril_flight/proc/on_victim_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// Revalidate after travel, then promote only an established native pull to an aggressive grab.
/datum/khaaroot_tendril_flight/proc/arrive()
	if(finished)
		return
	finished = TRUE
	var/datum/action/cooldown/khaaroot_mutation/tendril/action = get_action()
	var/mob/living/user = owner_ref?.resolve()
	var/mob/living/victim = victim_ref?.resolve()
	if(!action || !victim || !isturf(user.loc) || !isturf(victim.loc) || !user.Adjacent(victim))
		qdel(src)
		return

	var/grab_result = user.grab(victim)
	if(QDELETED(src))
		if(!QDELETED(user) && user.pulling == victim)
			user.stop_pulling()
		return
	if(grab_result != GRAB_SUCCESS || user.pulling != victim || victim.pulledby != user)
		qdel(src)
		return
	if(get_action() != action || QDELETED(victim) || !isturf(user.loc) || !isturf(victim.loc) || !user.Adjacent(victim))
		if(user.pulling == victim)
			user.stop_pulling()
		qdel(src)
		return
	if(user.grab_state < GRAB_AGGRESSIVE)
		victim.grippedby(user, instant = TRUE)
		victim.update_incapacitated()
	qdel(src)

/// Native thrownthing callbacks must not retain the cancelled shot or its previous role/body.
/proc/khaaroot_tendril_landed(datum/weakref/flight_ref)
	var/datum/khaaroot_tendril_flight/flight = flight_ref?.resolve()
	flight?.arrive()

/obj/projectile/khaaroot_tendril
	name = "ловчий жгут"
	icon_state = "tentacle_end"
	pass_flags = PASSTABLE
	damage = 0
	range = 8
	hitsound = 'sound/items/weapons/shove.ogg'
	/// Pending action-owned shot; projectile deletion only ends it before a return throw starts.
	var/datum/weakref/flight_ref

/obj/projectile/khaaroot_tendril/Destroy()
	var/datum/khaaroot_tendril_flight/flight = flight_ref?.resolve()
	flight_ref = null
	flight?.projectile_deleted()
	return ..()

/obj/projectile/khaaroot_tendril/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	var/datum/khaaroot_tendril_flight/flight = flight_ref?.resolve()
	if(!flight)
		return .
	if(. != BULLET_ACT_HIT || blocked >= 100 || !isliving(target))
		qdel(flight)
		return .
	flight.retract(target)
