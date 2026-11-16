/**
 * Component for simplemobs and basicmobs that allow them to carry crates.
 */
/datum/component/crate_carrier
	/// The max number of crates we can carry
	var/crate_limit = 3
	/// Typecache of all the types we can pick up and carry
	var/list/carriable_cache
	/// A lazylist of all crates we are carrying
	var/list/atom/movable/crates_in_hand

/datum/component/crate_carrier/Initialize(crate_limit = 3, list/carriable_types)
	. = ..()
	if(!isanimal_or_basicmob(parent))
		return COMPONENT_INCOMPATIBLE

	src.crate_limit = crate_limit

	if(carriable_types)
		src.carriable_cache = typecacheof(carriable_types)

	else
		var/static/default_cache = typecacheof(list(/obj/structure/closet/crate))
		src.carriable_cache = default_cache

/datum/component/crate_carrier/Destroy(force)
	LAZYCLEARLIST(crates_in_hand)
	return ..()

/datum/component/crate_carrier/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine))
	RegisterSignal(parent, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_unarm_attack))
	RegisterSignal(parent, COMSIG_LIVING_DEATH, PROC_REF(on_death))
	RegisterSignal(parent, COMSIG_ATOM_EXITED, PROC_REF(on_exited))
	RegisterSignal(parent, COMSIG_ATOM_UPDATE_OVERLAYS, PROC_REF(on_update_overlays))

/datum/component/crate_carrier/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_LIVING_UNARMED_ATTACK, COMSIG_LIVING_DEATH, COMSIG_ATOM_EXAMINE, COMSIG_ATOM_EXITED, COMSIG_ATOM_UPDATE_OVERLAYS))

/// Draw one carried crate; its carrier can draw hands over this overlay.
/datum/component/crate_carrier/proc/on_update_overlays(mob/living/source, list/overlays)
	SIGNAL_HANDLER

	if(!length(crates_in_hand))
		return
	var/atom/movable/shown_crate = crates_in_hand[1]
	// Keep held items and the carrier's hands in front of the crate.
	var/mutable_appearance/crate_overlay = mutable_appearance(shown_crate.icon, shown_crate.icon_state, -HANDS_LAYER - 1, appearance_flags = KEEP_TOGETHER)
	crate_overlay.overlays = shown_crate.overlays
	crate_overlay.color = shown_crate.color
	overlays += crate_overlay

/// Keep the displayed crate current when its lid or markings change.
/datum/component/crate_carrier/proc/on_crate_icon_updated(atom/movable/source)
	SIGNAL_HANDLER

	var/mob/living/carrier = parent
	carrier.update_appearance(UPDATE_OVERLAYS)

/// Forced movement and deletion must also clear the carried crate's appearance.
/datum/component/crate_carrier/proc/on_exited(mob/living/source, atom/movable/gone)
	SIGNAL_HANDLER

	if(!(gone in crates_in_hand))
		return
	LAZYREMOVE(crates_in_hand, gone)
	UnregisterSignal(gone, COMSIG_ATOM_UPDATED_ICON)
	if(!QDELETED(source))
		source.update_held_items()

/// Signal proc for [COMSIG_ATOM_EXAMINE] to show when we're carrying crates
/datum/component/crate_carrier/proc/on_examine(mob/living/source, mob/examiner, list/examine_list)
	SIGNAL_HANDLER

	var/num_crates = LAZYLEN(crates_in_hand)
	if(num_crates > 0)
		examine_list += span_notice("[source.p_Theyre()] carrying [num_crates == 1 ? "a crate":"[num_crates] crates"].")

/// Signal proc for [COMSIG_LIVING_UNARMED_ATTACK] to allow mobs to pick up or drop crates
/datum/component/crate_carrier/proc/on_unarm_attack(mob/living/source, atom/target, proximity, modifiers)
	SIGNAL_HANDLER

	if(source.combat_mode)
		return

	if(is_type_in_typecache(target, carriable_cache))
		var/atom/movable/movable_target = target
		if(LAZYLEN(crates_in_hand) >= crate_limit)
			source.balloon_alert(source, "too many crates!")
			return COMPONENT_CANCEL_ATTACK_CHAIN

		for(var/mob/living/inside_mob in movable_target.get_all_contents())
			if(inside_mob.mob_size < MOB_SIZE_HUMAN)
				continue
			source.balloon_alert(source, "crate too heavy!")
			return COMPONENT_CANCEL_ATTACK_CHAIN

		LAZYADD(crates_in_hand, target)
		movable_target.forceMove(source)
		RegisterSignal(movable_target, COMSIG_ATOM_UPDATED_ICON, PROC_REF(on_crate_icon_updated))
		source.update_held_items()
		source.balloon_alert(source, "grabbed crate")
		return COMPONENT_CANCEL_ATTACK_CHAIN

	if(isopenturf(target) && LAZYLEN(crates_in_hand))
		drop_all_crates(target)
		source.balloon_alert(source, "dropped crate")
		return COMPONENT_CANCEL_ATTACK_CHAIN

/// Signal proc for [COMSIG_LIVING_DEATH], so we drop crates on death or gib
/datum/component/crate_carrier/proc/on_death(mob/living/source, gibbed)
	SIGNAL_HANDLER

	drop_all_crates(source.drop_location())

/// Drops all the crates in our crate list.
/datum/component/crate_carrier/proc/drop_all_crates(atom/drop_to)
	for(var/obj/structure/closet/crate/held_crate as anything in crates_in_hand?.Copy())
		held_crate.forceMove(drop_to)
