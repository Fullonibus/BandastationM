/obj/item/garrote
	name = "fiber wire garrote"
	contraband_type_categories = CONTRABAND_CATEGORY_UNCLASSIFIED
	desc = "Тонкая проволока с деревянными рукоятками. Возьмите её в обе руки и атакуйте жертву со спины. Повторная атака мгновенно усиливает захват до удушения."
	icon = 'modular_bandastation/uplink_items/icons/items.dmi'
	icon_state = "garrot_wrap"
	inhand_icon_state = "coil_red"
	lefthand_file = 'icons/mob/inhands/equipment/tools_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/tools_righthand.dmi'
	w_class = WEIGHT_CLASS_TINY
	var/mob/living/carbon/human/strangling
	var/datum/weakref/strangler_ref

/obj/item/garrote/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/two_handed, unwield_callback = CALLBACK(src, PROC_REF(stop_strangling)))

/obj/item/garrote/Destroy()
	stop_strangling()
	return ..()

/obj/item/garrote/update_icon_state()
	. = ..()
	icon_state = HAS_TRAIT(src, TRAIT_WIELDED) ? "garrot_unwrap" : "garrot_wrap"

/obj/item/garrote/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!ishuman(user) || !ishuman(target) || target == user || !user.is_holding(src) || !user.Adjacent(target) || user.incapacitated || HAS_TRAIT(user, TRAIT_PACIFISM))
		return TRUE
	if(!HAS_TRAIT(src, TRAIT_WIELDED))
		balloon_alert(user, "нужны обе руки!")
		return TRUE
	if(strangling)
		if(strangling == target && user.pulling == target)
			user.setGrabState(GRAB_KILL)
			log_combat(user, target, "strangled", src)
		return TRUE
	if(get_dir(user, target) != target.dir && !target.incapacitated)
		balloon_alert(user, "зайдите со спины!")
		return TRUE
	if(!user.start_pulling(target, supress_message = TRUE))
		return TRUE
	user.setGrabState(GRAB_AGGRESSIVE)
	user.setGrabState(GRAB_NECK)
	user.set_pull_offsets(target, GRAB_NECK)
	strangling = target
	strangler_ref = WEAKREF(user)
	strangling.add_traits(list(TRAIT_MUTE, TRAIT_EMOTEMUTE), REF(src))
	RegisterSignals(strangling, list(COMSIG_ATOM_NO_LONGER_PULLED, COMSIG_QDELETING), PROC_REF(on_released))
	RegisterSignal(strangling, COMSIG_LIVING_ADJUST_OXY_DAMAGE, PROC_REF(prevent_oxy_healing))
	RegisterSignal(user, COMSIG_MOVABLE_GRABBED_RESISTING, PROC_REF(prevent_escape))
	START_PROCESSING(SSobj, src)
	add_fingerprint(user)
	update_appearance(UPDATE_ICON_STATE)
	playsound(src, 'sound/items/weapons/cablecuff.ogg', 15, TRUE)
	user.visible_message(span_danger("[user] затягивает [src] на шее [target]!"), span_notice("Вы затягиваете удавку на шее [target]."))
	log_combat(user, target, "garroted", src)
	return TRUE

/obj/item/garrote/process(seconds_per_tick)
	var/mob/living/strangler = strangler_ref?.resolve()
	if(QDELETED(strangling) || !strangler || loc != strangler || !strangler.is_holding(src) || !HAS_TRAIT(src, TRAIT_WIELDED) || strangler.incapacitated || strangler.pulling != strangling || strangler.grab_state < GRAB_NECK || !strangler.Adjacent(strangling))
		stop_strangling()
		return
	if(strangler.grab_state >= GRAB_KILL)
		strangling.losebreath = max(strangling.losebreath, 3)
		strangling.adjust_oxy_loss(2 * seconds_per_tick)

/obj/item/garrote/proc/prevent_oxy_healing(mob/living/source, damage_type, amount, forced)
	SIGNAL_HANDLER
	var/mob/living/strangler = strangler_ref?.resolve()
	if(amount < 0 && !forced && strangler?.pulling == source && strangler.grab_state >= GRAB_KILL)
		return COMPONENT_IGNORE_CHANGE

/obj/item/garrote/proc/on_released()
	SIGNAL_HANDLER
	stop_strangling()

/obj/item/garrote/proc/prevent_escape(mob/living/source, mob/living/victim, list/grab_stats)
	SIGNAL_HANDLER
	if(victim == strangling)
		grab_stats[GRAB_STAT_ESCAPE_CHANCE] = 0

/obj/item/garrote/dropped(mob/user, silent = FALSE)
	. = ..()
	stop_strangling()

/obj/item/garrote/proc/stop_strangling()
	STOP_PROCESSING(SSobj, src)
	if(strangling)
		UnregisterSignal(strangling, list(COMSIG_ATOM_NO_LONGER_PULLED, COMSIG_QDELETING, COMSIG_LIVING_ADJUST_OXY_DAMAGE))
		strangling.remove_traits(list(TRAIT_MUTE, TRAIT_EMOTEMUTE), REF(src))
		var/mob/living/strangler = strangler_ref?.resolve()
		if(strangler)
			UnregisterSignal(strangler, COMSIG_MOVABLE_GRABBED_RESISTING)
		var/mob/living/carbon/human/victim = strangling
		strangling = null
		if(strangler?.pulling == victim)
			strangler.stop_pulling()
	strangler_ref = null
	update_appearance(UPDATE_ICON_STATE)

/datum/uplink_item/stealthy_weapons/garrote
	name = "Fiber Wire Garrote"
	desc = "Удавка для бесшумного удушения со спины. Требует обе руки. Повторная атака мгновенно усиливает захват; жертва не может говорить, дышать или восстанавливать гипоксию."
	item = /obj/item/garrote
	cost = 4
