/** Owns one exact Khaaroot role's mutations and its current body's actions. */
/datum/khaaroot_mutations
	/// Exact role that owns this controller, without retaining a removed membership.
	var/datum/weakref/antag_ref
	/// Current compatible body; role transfer explicitly rebinds it.
	var/datum/weakref/body_ref
	/// Thrall-only permanent choice: tendril, gland, or molt; the source receives all three.
	var/specialization
	/// Actions owned by this controller, recreated concealed on each body.
	var/list/datum/action/cooldown/khaaroot_mutation/actions = list()

/datum/khaaroot_mutations/New(datum/antagonist/antag)
	. = ..()
	antag_ref = WEAKREF(antag)

/datum/khaaroot_mutations/Destroy()
	unbind()
	antag_ref = null
	return ..()

/** Resolve the body used for cleanup, even if it can no longer activate mutations. */
/datum/khaaroot_mutations/proc/get_owner()
	return body_ref?.resolve()

/** Resolve the exact role that originally owned this controller. */
/datum/khaaroot_mutations/proc/get_antag()
	return antag_ref?.resolve()

/** Bind the exact role's current human body and create its concealed source or thrall action set. */
/datum/khaaroot_mutations/proc/bind(mob/living/body)
	unbind()
	body_ref = WEAKREF(body)
	if(!is_current_owner(body))
		body_ref = null
		return FALSE
	RegisterSignal(body, COMSIG_QDELETING, PROC_REF(on_body_deleted))
	var/list/action_types = list(/datum/action/cooldown/khaaroot_mutation/bone_spike, /datum/action/cooldown/khaaroot_mutation/recover)
	if(istype(get_antag(), /datum/antagonist/khaaroot_source))
		action_types += list(/datum/action/cooldown/khaaroot_mutation/tendril, /datum/action/cooldown/khaaroot_mutation/gland, /datum/action/cooldown/khaaroot_mutation/molt)
	else if(!specialization)
		action_types += /datum/action/cooldown/khaaroot_mutation/specialize
	for(var/action_type in action_types)
		var/datum/action/cooldown/khaaroot_mutation/ability = new action_type(src)
		actions += ability
		ability.Grant(body)
	if(specialization && istype(get_antag(), /datum/antagonist/khaaroot_thrall))
		grant_specialization()
	return TRUE

/** Remove every body-owned effect while retaining the membership's chosen specialization. */
/datum/khaaroot_mutations/proc/unbind()
	var/mob/living/body = get_owner()
	if(body)
		UnregisterSignal(body, COMSIG_QDELETING)
	conceal_all()
	QDEL_LIST(actions)
	actions = list()
	body_ref = null

/** Body deletion must clear actions even when no subsequent mind transfer occurs. */
/datum/khaaroot_mutations/proc/on_body_deleted(mob/living/source)
	SIGNAL_HANDLER
	unbind()

/** Validate only exact role, hive and current human body identity, independently of consciousness. */
/datum/khaaroot_mutations/proc/is_current_owner(mob/user)
	var/datum/antagonist/antag = get_antag()
	if(QDELETED(src) || !ishuman(user) || QDELETED(user) || user != get_owner() || !antag || antag.owner?.current != user || user.mind != antag.owner || user.mind.has_antag_datum(antag.type) != antag)
		return FALSE
	if(istype(antag, /datum/antagonist/khaaroot_source))
		var/datum/antagonist/khaaroot_source/source_role = antag
		var/datum/khaaroot_hivemind/hive = source_role.team?.hivemind_ref?.resolve()
		return source_role.mutations == src && hive?.active && hive.is_infector(user)
	if(istype(antag, /datum/antagonist/khaaroot_thrall))
		var/datum/antagonist/khaaroot_thrall/thrall_role = antag
		var/datum/khaaroot_hivemind/hive = thrall_role.team?.hivemind_ref?.resolve()
		return thrall_role.mutations == src && hive?.active && hive.get_thrall_antag(user.mind) == thrall_role
	return FALSE

/** Require a conscious, unphased current owner to activate a mutation, without admin exceptions. */
/datum/khaaroot_mutations/proc/can_use(mob/user, feedback = FALSE)
	if(!is_current_owner(user))
		if(feedback && !QDELETED(user))
			user.balloon_alert(user, "связь мутации утрачена")
		return FALSE
	if(IS_UNCONSCIOUS_OR_CRIT(user) || HAS_TRAIT(user, TRAIT_MAGICALLY_PHASED))
		if(feedback)
			user.balloon_alert(user, "не могу раскрыть мутацию")
		return FALSE
	return TRUE

/** Commit one server-validated choice; a stale dialog or second choice has no effect. */
/datum/khaaroot_mutations/proc/set_specialization(mob/user, choice)
	if(!istype(get_antag(), /datum/antagonist/khaaroot_thrall) || !can_use(user) || specialization || !(choice in list("tendril", "gland", "molt")))
		return FALSE
	specialization = choice
	for(var/datum/action/cooldown/khaaroot_mutation/specialize/chooser in actions.Copy())
		actions -= chooser
		qdel(chooser)
	grant_specialization()
	return TRUE

/** Create the selected action on the current body, without changing the stored choice. */
/datum/khaaroot_mutations/proc/grant_specialization()
	var/action_type
	switch(specialization)
		if("tendril")
			action_type = /datum/action/cooldown/khaaroot_mutation/tendril
		if("gland")
			action_type = /datum/action/cooldown/khaaroot_mutation/gland
		if("molt")
			action_type = /datum/action/cooldown/khaaroot_mutation/molt
	if(!action_type || !get_owner())
		return
	var/datum/action/cooldown/khaaroot_mutation/ability = new action_type(src)
	actions += ability
	ability.Grant(get_owner())

/** Hide only effects owned by this controller, including any pending reveal or attack. */
/datum/khaaroot_mutations/proc/conceal_all()
	for(var/datum/action/cooldown/khaaroot_mutation/ability as anything in actions)
		ability.conceal(forced = TRUE)

/** Shared current-role validation and button appearance for Khaaroot mutations. */
/datum/action/cooldown/khaaroot_mutation
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_PHASED
	button_icon = 'modular_bandastation/prime_only/icons/khaaroot.dmi'
	background_icon = 'modular_bandastation/prime_only/icons/khaaroot.dmi'
	background_icon_state = "bg_khaaroot"
	overlay_icon = 'modular_bandastation/prime_only/icons/khaaroot.dmi'
	overlay_icon_state = "border_khaaroot"
	active_overlay_icon_state = "border_khaaroot_active"
	/// Weak ownership lookup; the action framework also links target deletion to our deletion.
	var/datum/weakref/mutations_ref

/datum/action/cooldown/khaaroot_mutation/New(datum/khaaroot_mutations/mutations)
	mutations_ref = WEAKREF(mutations)
	return ..(mutations)

/datum/action/cooldown/khaaroot_mutation/Destroy()
	conceal(forced = TRUE)
	mutations_ref = null
	return ..()

/** Resolve the membership's controller without retaining it after teardown. */
/datum/action/cooldown/khaaroot_mutation/proc/get_mutations() as /datum/khaaroot_mutations
	return mutations_ref?.resolve()

/datum/action/cooldown/khaaroot_mutation/IsAvailable(feedback = FALSE)
	var/datum/khaaroot_mutations/mutations = get_mutations()
	if(!mutations?.can_use(owner, feedback) || action_disabled)
		return FALSE
	// A revealed mutation remains retractable while its attack is cooling down.
	return is_revealed() || ..()

/datum/action/cooldown/khaaroot_mutation/Trigger(mob/clicker, trigger_flags, atom/target)
	if(clicker && clicker != owner)
		return FALSE
	return ..()

/datum/action/cooldown/khaaroot_mutation/is_action_active(atom/movable/screen/movable/action_button/current_button)
	return is_revealed() || ..()

/** Whether this action currently owns a visible mutation. */
/datum/action/cooldown/khaaroot_mutation/proc/is_revealed()
	return FALSE

/** Remove this action's visible effects; subclasses also cancel their pending effects here. */
/datum/action/cooldown/khaaroot_mutation/proc/conceal(forced = FALSE)
	return FALSE

/** One-use TGUI selector for the thrall's permanent membership specialization. */
/datum/action/cooldown/khaaroot_mutation/specialize
	name = "Выбрать мутацию"
	desc = "Выберите специализацию тела: ловчий жгут, железа разложения или линька. Выбор сохраняется до выхода из улья."
	button_icon_state = "specialize"
	/// Prevent multiple simultaneous dialogs from the same action.
	var/selecting = FALSE

/datum/action/cooldown/khaaroot_mutation/specialize/Activate(atom/target)
	if(selecting || !IsAvailable())
		return FALSE
	selecting = TRUE
	var/mob/living/carbon/human/user = owner
	var/list/choices = list("Ловчий" = "tendril", "Железа разложения" = "gland", "Линька" = "molt")
	var/choice = tgui_input_list(user, "Какую мутацию пробудит Улей? Этот выбор нельзя изменить до выхода из улья.", "Мутации Кхаарут", choices)
	selecting = FALSE
	if(QDELETED(src) || !IsAvailable() || owner != user || !choice)
		return FALSE
	var/datum/khaaroot_mutations/mutations = get_mutations()
	return mutations?.set_specialization(user, choices[choice])

/** Shared retractable arm-item lifecycle, including delayed reveal and empty-hand checks. */
/datum/action/cooldown/khaaroot_mutation/arm
	/// Concrete organic item grown by this mutation.
	var/item_type
	/// Current item, deleted as soon as the mutation retracts or leaves its owner's hand.
	var/obj/item/khaaroot_mutation_arm/held_item
	/// Time spent visibly unfolding before the arm item becomes usable.
	var/reveal_time = 0.8 SECONDS
	/// Directional one-shot state used while the arm unfolds.
	var/reveal_state
	/// The current world reveal effect, removed immediately on interruption or teardown.
	var/obj/effect/temp_visual/khaaroot_mutation_reveal/reveal_visual
	/// Whether an unfolding operation is currently in progress.
	var/revealing = FALSE
	/// Invalidates delayed reveals when a second toggle or forced conceal interrupts them.
	var/reveal_serial = 0

/datum/action/cooldown/khaaroot_mutation/arm/Grant(mob/granted_to)
	. = ..()
	if(owner)
		RegisterSignal(owner, COMSIG_CARBON_POST_REMOVE_LIMB, PROC_REF(on_limb_removed))

/datum/action/cooldown/khaaroot_mutation/arm/Remove(mob/removed_from)
	conceal(forced = TRUE)
	UnregisterSignal(removed_from, COMSIG_CARBON_POST_REMOVE_LIMB)
	return ..()

/datum/action/cooldown/khaaroot_mutation/arm/Activate(atom/target)
	if(!IsAvailable())
		return FALSE
	if(is_revealed() || revealing)
		return conceal()
	var/mob/living/carbon/human/user = owner
	var/hand_index = user.active_hand_index
	if(user.get_active_held_item() || !user.has_hand_for_held_index(hand_index))
		user.balloon_alert(user, "нужна свободная рука")
		return FALSE
	revealing = TRUE
	reveal_serial++
	var/current_reveal = reveal_serial
	reveal_visual = new(get_turf(user), reveal_state)
	reveal_visual.setDir(user.dir)
	playsound(user, 'sound/effects/blob/blobattack.ogg', 35, TRUE)
	user.visible_message(span_warning("Плоть на руке [user.declent_ru(GENITIVE)] начинает расходиться!"), span_notice("Вы раскрываете скрытую в руке мутацию."))
	var/revealed = do_after(user, reveal_time, target = user)
	if(QDELETED(src) || current_reveal != reveal_serial)
		return FALSE
	revealing = FALSE
	QDEL_NULL(reveal_visual)
	if(!revealed || !IsAvailable() || owner != user || user.active_hand_index != hand_index || user.get_active_held_item() || !user.has_hand_for_held_index(hand_index))
		return FALSE
	var/obj/item/khaaroot_mutation_arm/new_item = new item_type(user, src)
	if(!user.put_in_active_hand(new_item))
		qdel(new_item)
		return FALSE
	held_item = new_item
	RegisterSignal(held_item, COMSIG_QDELETING, PROC_REF(on_item_deleted))
	RegisterSignal(held_item, COMSIG_MOVABLE_MOVED, PROC_REF(on_item_moved))
	build_all_button_icons()
	return TRUE

/datum/action/cooldown/khaaroot_mutation/arm/is_revealed()
	return !QDELETED(held_item)

/datum/action/cooldown/khaaroot_mutation/arm/conceal(forced = FALSE)
	var/had_mutation = revealing || !QDELETED(held_item)
	reveal_serial++
	revealing = FALSE
	QDEL_NULL(reveal_visual)
	if(held_item)
		UnregisterSignal(held_item, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
		QDEL_NULL(held_item)
	if(had_mutation && !forced && owner)
		playsound(owner, 'sound/effects/blob/blobattack.ogg', 25, TRUE)
		owner.visible_message(span_notice("Рука [owner.declent_ru(GENITIVE)] вновь принимает человеческий вид."))
	build_all_button_icons()
	return had_mutation

/** External item deletion must also invoke subtype cleanup, such as cancelling a tendril flight. */
/datum/action/cooldown/khaaroot_mutation/arm/proc/on_item_deleted(obj/item/khaaroot_mutation_arm/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
	held_item = null
	conceal(forced = TRUE)

/** Forced movement outside the equipped hand cannot leave a usable organic weapon behind. */
/datum/action/cooldown/khaaroot_mutation/arm/proc/on_item_moved(obj/item/khaaroot_mutation_arm/source)
	SIGNAL_HANDLER
	if(source.loc != owner || !owner?.is_holding(source))
		conceal(forced = TRUE)

/** The post-removal signal also covers hands removed without dropping their held item. */
/datum/action/cooldown/khaaroot_mutation/arm/proc/on_limb_removed(mob/living/carbon/source)
	SIGNAL_HANDLER
	if(held_item && !source.has_hand_for_held_index(source.get_held_index_of_item(held_item)))
		conceal(forced = TRUE)

/** Every Khaaroot participant's concealed organic blade. */
/datum/action/cooldown/khaaroot_mutation/bone_spike
	parent_type = /datum/action/cooldown/khaaroot_mutation/arm
	name = "Костяной шип"
	desc = "Раскройте костяной клинок в свободной активной руке. Повторное нажатие или использование в руке скроет его."
	button_icon_state = "bone_spike"
	item_type = /obj/item/khaaroot_mutation_arm/bone_spike
	reveal_state = "reveal_spike"

/** A hand-bound organic item that only its current mutation owner can use. */
/obj/item/khaaroot_mutation_arm
	icon = 'modular_bandastation/prime_only/icons/khaaroot_mutations.dmi'
	lefthand_file = 'modular_bandastation/prime_only/icons/khaaroot_mutations_lefthand.dmi'
	righthand_file = 'modular_bandastation/prime_only/icons/khaaroot_mutations_righthand.dmi'
	item_flags = ABSTRACT | DROPDEL
	w_class = WEIGHT_CLASS_HUGE
	throwforce = 0
	throw_range = 0
	/// Weak backlink to the action that owns and retracts this item.
	var/datum/weakref/mutation_action_ref

/obj/item/khaaroot_mutation_arm/Initialize(mapload, datum/action/cooldown/khaaroot_mutation/arm/action)
	. = ..()
	mutation_action_ref = WEAKREF(action)
	ADD_TRAIT(src, TRAIT_NODROP, INNATE_TRAIT)

/obj/item/khaaroot_mutation_arm/Destroy()
	mutation_action_ref = null
	return ..()

/** Resolve a usable mutation only while this is still in that current owner's equipped hand. */
/obj/item/khaaroot_mutation_arm/proc/get_mutation_action()
	var/datum/action/cooldown/khaaroot_mutation/arm/action = mutation_action_ref?.resolve()
	var/datum/khaaroot_mutations/mutations = action?.get_mutations()
	if(!action || action.held_item != src || !mutations?.can_use(action.owner) || loc != action.owner || !action.owner.is_holding(src))
		return null
	return action

/obj/item/khaaroot_mutation_arm/attack_self(mob/user, modifiers)
	var/datum/action/cooldown/khaaroot_mutation/arm/action = get_mutation_action()
	if(action?.owner == user)
		return action.conceal()
	return ..()

/** A modest edged blade without inherited changeling door-prying or armor penetration. */
/obj/item/khaaroot_mutation_arm/bone_spike
	name = "костяной шип"
	desc = "Изогнутый шип из бледной кости, оплетённый тёмными нервными волокнами."
	icon_state = "bone_spike"
	inhand_icon_state = "bone_spike"
	force = 25
	sharpness = SHARP_EDGED
	hitsound = 'sound/items/weapons/bladeslice.ogg'
	attack_verb_continuous = list("режет", "пронзает")
	attack_verb_simple = list("режет", "пронзает")

/** Directional world animation shared by mutation reveals. */
/obj/effect/temp_visual/khaaroot_mutation_reveal
	icon = 'modular_bandastation/prime_only/icons/khaaroot_mutations.dmi'
	duration = 0.8 SECONDS
	randomdir = FALSE

/obj/effect/temp_visual/khaaroot_mutation_reveal/Initialize(mapload, state)
	if(state)
		icon_state = state
	. = ..()
	alpha = 0
	transform = matrix().Scale(0.5)
	animate(src, alpha = 255, transform = matrix(), time = 0.3 SECONDS, easing = QUAD_EASING|EASE_OUT)
	animate(time = 0.2 SECONDS)
	animate(alpha = 0, time = 0.3 SECONDS, easing = QUAD_EASING|EASE_IN)
