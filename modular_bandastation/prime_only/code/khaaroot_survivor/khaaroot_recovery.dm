/** A modest shared recovery channel bound to one exact Khaaroot role and human body. */
/datum/action/cooldown/khaaroot_mutation/recover
	name = "Сшивание плоти"
	desc = "За две секунды стянуть кровоточащие раны. Затем в течение тридцати секунд восстановить немного плоти и крови."
	button_icon_state = "recover"
	cooldown_time = 90 SECONDS
	/// Interruptible preparation before existing wounds close and healing begins.
	var/channel_time = 2 SECONDS
	/// Prevent repeated submissions while preparation is still in progress.
	var/channeling = FALSE
	/// Invalidates a delayed preparation when this body-bound action is removed.
	var/channel_revision = 0
	/// The one status effect owned by this action, cleared immediately when it ends.
	var/datum/status_effect/khaaroot_recovery/recovery_effect

/datum/action/cooldown/khaaroot_mutation/recover/Destroy()
	stop_recovery()
	return ..()

/datum/action/cooldown/khaaroot_mutation/recover/Remove(mob/removed_from)
	stop_recovery()
	return ..()

/datum/action/cooldown/khaaroot_mutation/recover/IsAvailable(feedback = FALSE)
	return !channeling && !recovery_effect && !owner?.has_status_effect(/datum/status_effect/khaaroot_recovery) && ..()

/datum/action/cooldown/khaaroot_mutation/recover/Activate(atom/target)
	if(!IsAvailable(feedback = TRUE))
		return FALSE
	var/mob/living/carbon/human/user = owner
	var/revision = ++channel_revision
	channeling = TRUE
	user.visible_message(span_warning("[user.declent_ru(NOMINATIVE)] замирает: под кожей натягиваются тёмные нити."), span_notice("Вы сосредотачиваетесь, стягивая повреждённую плоть."))
	playsound(user, 'sound/effects/singlebeat.ogg', 35, FALSE, -5)
	var/completed = do_after(user, channel_time, user, extra_checks = CALLBACK(src, PROC_REF(can_finish_recovery), user, revision))
	if(QDELETED(src))
		return FALSE
	if(!completed || !can_finish_recovery(user, revision))
		if(channel_revision == revision)
			channeling = FALSE
		return FALSE
	channeling = FALSE
	recovery_effect = user.apply_status_effect(/datum/status_effect/khaaroot_recovery, get_mutations())
	if(!recovery_effect)
		return FALSE
	RegisterSignal(recovery_effect, COMSIG_QDELETING, PROC_REF(on_recovery_ended))
	StartCooldown()
	return TRUE

/** Revalidate this exact conscious actor and role while the interruptible channel is pending. */
/datum/action/cooldown/khaaroot_mutation/recover/proc/can_finish_recovery(mob/living/carbon/human/user, revision)
	return !QDELETED(src) && channeling && channel_revision == revision && owner == user && !action_disabled && !user.has_status_effect(/datum/status_effect/khaaroot_recovery) && get_mutations()?.can_use(user)

/** Invalidate preparation and remove only this action's own active recovery on body or role teardown. */
/datum/action/cooldown/khaaroot_mutation/recover/proc/stop_recovery()
	channel_revision++
	channeling = FALSE
	QDEL_NULL(recovery_effect)

/// Do not retain an expired status effect from an action that may live much longer.
/datum/action/cooldown/khaaroot_mutation/recover/proc/on_recovery_ended(datum/source)
	SIGNAL_HANDLER
	if(recovery_effect == source)
		recovery_effect = null

/** Closes existing bleeding trauma once, then restores a small amount of organic damage and blood over time. */
/datum/status_effect/khaaroot_recovery
	id = "khaaroot_recovery"
	duration = 30 SECONDS
	tick_interval = 1 SECONDS
	status_type = STATUS_EFFECT_UNIQUE
	alert_type = /atom/movable/screen/alert/status_effect/khaaroot_recovery
	show_duration = TRUE
	remove_on_fullheal = TRUE
	on_remove_on_mob_delete = TRUE
	/// Exact membership and body identity, without requiring the healing patient to remain conscious.
	var/datum/weakref/mutations_ref
	/// Organic brute damage healed each second, up to fifteen over the complete duration.
	var/brute_heal_rate = 0.5
	/// Organic burn damage healed each second, up to fifteen over the complete duration.
	var/burn_heal_rate = 0.5
	/// Actual blood restored each second, capped at the normal volume.
	var/blood_heal_rate = 1

/datum/status_effect/khaaroot_recovery/on_creation(mob/living/new_owner, datum/khaaroot_mutations/mutations)
	mutations_ref = WEAKREF(mutations)
	return ..()

/datum/status_effect/khaaroot_recovery/Destroy()
	mutations_ref = null
	return ..()

/datum/status_effect/khaaroot_recovery/on_apply()
	var/datum/khaaroot_mutations/mutations = mutations_ref?.resolve()
	if(!mutations?.is_current_owner(owner) || owner.stat == DEAD)
		return FALSE
	RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(on_owner_death))
	close_existing_wounds()
	owner.visible_message(span_warning("Края ран [owner.declent_ru(GENITIVE)] сходятся, прошитые тонкими тёмными волокнами."), span_notice("Кровоточащие раны стягиваются. Плоть медленно восстанавливается."))
	return TRUE

/datum/status_effect/khaaroot_recovery/on_remove()
	UnregisterSignal(owner, COMSIG_LIVING_DEATH)

/** Native slash healing replaces its wound datum; fresh bounded passes follow the decreasing severity chain. */
/datum/status_effect/khaaroot_recovery/proc/close_existing_wounds()
	var/mob/living/carbon/human/user = owner
	for(var/obj/item/bodypart/bodypart as anything in user.get_bodyparts())
		if(bodypart.generic_bleedstacks > 0)
			bodypart.setBleedStacks(0)
	// Critical cuts need three native steps: critical -> severe -> moderate -> closed.
	for(var/pass in 1 to WOUND_SEVERITY_CRITICAL)
		if(!length(user.all_wounds))
			break
		var/had_bleeding_wound = FALSE
		for(var/datum/wound/wound as anything in user.all_wounds.Copy())
			if(QDELETED(wound) || wound.victim != user || wound.blood_flow <= 0 || (!istype(wound, /datum/wound/slash/flesh) && !istype(wound, /datum/wound/pierce/bleed)))
				continue
			had_bleeding_wound = TRUE
			wound.set_blood_flow(0)
		if(!had_bleeding_wound)
			break

/datum/status_effect/khaaroot_recovery/tick(seconds_between_ticks)
	var/datum/khaaroot_mutations/mutations = mutations_ref?.resolve()
	if(owner.stat == DEAD || !mutations?.is_current_owner(owner))
		qdel(src)
		return
	owner.heal_overall_damage(brute = brute_heal_rate * seconds_between_ticks, burn = burn_heal_rate * seconds_between_ticks, required_bodytype = BODYTYPE_ORGANIC)
	owner.adjust_blood_volume(blood_heal_rate * seconds_between_ticks, maximum = BLOOD_VOLUME_NORMAL)

/// Death ends recovery immediately; the same body cannot carry an unfinished effect into revival.
/datum/status_effect/khaaroot_recovery/proc/on_owner_death(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/** Remaining time and deliberately limited scope of the Khaaroot recovery. */
/atom/movable/screen/alert/status_effect/khaaroot_recovery
	name = "Сшивание плоти"
	desc = "Повреждённая плоть медленно восстанавливается. Новые раны всё ещё могут кровоточить; переломы и застрявшие предметы остаются."
	icon_state = "fleshmend"
