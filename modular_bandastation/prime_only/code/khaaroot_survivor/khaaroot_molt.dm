/** Shed an empty appearance snapshot while keeping the original body, mind, and possessions. */
/datum/action/cooldown/khaaroot_mutation/molt
	name = "Линька"
	desc = "Сбросить полую оболочку, выскользнув из чужого захвата. Ваше тело и все вещи остаются при вас."
	button_icon_state = "molt"
	cooldown_time = 45 SECONDS
	/// Only one shell belongs to this body-bound action at a time.
	var/obj/structure/khaaroot_molt_shell/shell
	/// Duration of the abandoned shell's physical presence.
	var/shell_lifetime = 20 SECONDS

/datum/action/cooldown/khaaroot_mutation/molt/Destroy()
	QDEL_NULL(shell)
	return ..()

/datum/action/cooldown/khaaroot_mutation/molt/Remove(mob/removed_from)
	QDEL_NULL(shell)
	return ..()

/datum/action/cooldown/khaaroot_mutation/molt/Activate(atom/target)
	if(!IsAvailable(feedback = TRUE) || !isturf(owner.loc))
		return FALSE
	var/mob/living/carbon/human/user = owner
	var/datum/khaaroot_mutations/mutations = get_mutations()
	var/turf/start_turf = user.loc
	var/mutable_appearance/shed_appearance = new(user.appearance)
	mutations.conceal_all()
	// Concealment can delete held mutation items and emit signals; verify this exact membership again.
	if(QDELETED(src) || owner != user || !mutations.can_use(user) || user.loc != start_turf)
		return FALSE
	if(user.pulledby?.pulling == user)
		user.pulledby.stop_pulling()
	QDEL_NULL(shell)
	shell = new(start_turf, shed_appearance, user.name, shell_lifetime)
	RegisterSignal(shell, COMSIG_QDELETING, PROC_REF(on_shell_deleted))
	var/obj/effect/temp_visual/khaaroot_mutation_reveal/reveal = new(start_turf, "reveal_molt")
	reveal.setDir(user.dir)
	playsound(start_turf, 'sound/effects/splat.ogg', 70, TRUE)
	user.visible_message(span_danger("[user.declent_ru(NOMINATIVE)] выскальзывает из собственной кожи, оставляя пульсирующую полую оболочку!"), span_notice("Вы сбрасываете полую оболочку и выскальзываете из захвата."))
	StartCooldown()

	var/turf/destination = get_step(user, user.dir)
	if(!user.buckled && !user.anchored && (user.mobility_flags & MOBILITY_MOVE) && isopenturf(destination) && !destination.is_blocked_turf(source_atom = user))
		user.Move(destination, user.dir)
	return TRUE

/// Forget a shell destroyed independently by attacks, fire, or its expiry timer.
/datum/action/cooldown/khaaroot_mutation/molt/proc/on_shell_deleted(datum/source)
	SIGNAL_HANDLER
	if(shell == source)
		shell = null

/** A destructible visual decoy with no mind, organs, medical corpse state, or real inventory. */
/obj/structure/khaaroot_molt_shell
	name = "полая оболочка"
	desc = "Кожа слабо пульсирует. Внутри нет тела: только влажная полость и рвущиеся нервные нити."
	obj_flags = CAN_BE_HIT
	max_integrity = 20
	armor_type = /datum/armor/none
	resistance_flags = FLAMMABLE
	anchored = TRUE
	density = FALSE
	interaction_flags_atom = INTERACT_ATOM_ATTACK_HAND
	/// Stoppable timer owned by this shell.
	var/expiry_timer

/obj/structure/khaaroot_molt_shell/Initialize(mapload, mutable_appearance/shed_appearance, owner_name, lifetime = 20 SECONDS)
	. = ..()
	if(shed_appearance)
		appearance = shed_appearance
	name = owner_name || name
	layer = MOB_LAYER
	plane = GAME_PLANE
	mouse_opacity = MOUSE_OPACITY_ICON
	animate(src, alpha = 190, time = 0.8 SECONDS, loop = -1)
	animate(alpha = 255, time = 0.8 SECONDS)
	expiry_timer = addtimer(CALLBACK(src, PROC_REF(collapse)), lifetime, TIMER_STOPPABLE | TIMER_DELETE_ME)

/obj/structure/khaaroot_molt_shell/Destroy(force)
	if(expiry_timer)
		deltimer(expiry_timer)
		expiry_timer = null
	return ..()

/obj/structure/khaaroot_molt_shell/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(. || !Adjacent(user))
		return .
	if(!user.combat_mode)
		to_chat(user, span_warning("Под пальцами прогибается пустая кожа. Нервные нити тянутся через полость оболочки."))
		return TRUE
	user.changeNext_move(CLICK_CD_MELEE)
	user.do_attack_animation(src)
	log_combat(user, src, "struck")
	take_damage(5, BRUTE, MELEE)
	return TRUE

/** Expiry uses the same native destruction path as damage, producing harmless organic debris. */
/obj/structure/khaaroot_molt_shell/proc/collapse()
	deconstruct(disassembled = FALSE)

/obj/structure/khaaroot_molt_shell/atom_deconstruct(disassembled = TRUE)
	. = ..()
	playsound(src, 'sound/effects/splat.ogg', 50, TRUE)
	new /obj/effect/decal/cleanable/blood/gibs(get_turf(src))
	var/obj/effect/temp_visual/khaaroot_mutation_reveal/reveal = new(get_turf(src), "reveal_molt")
	reveal.setDir(dir)
