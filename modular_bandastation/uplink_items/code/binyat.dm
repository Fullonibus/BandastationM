/obj/item/organ/cyberimp/brain/binyat
	name = "Binyat wireless hacking system"
	contraband_type_categories = CONTRABAND_CATEGORY_UNCLASSIFIED
	desc = "Нейронный имплант для дистанционного взлома машинерии и дверей. Взлом занимает три секунды, работает в радиусе трёх клеток и вызывает ожоги."
	icon = 'modular_bandastation/uplink_items/icons/items.dmi'
	icon_state = "hackerman"
	slot = ORGAN_SLOT_BRAIN_CNS
	organ_flags = ORGAN_ROBOTIC | ORGAN_HIDDEN
	actions_types = list(/datum/action/cooldown/binyat)
	emp_stun_duration = 0
	var/obj/item/card/emag/sequencer

/obj/item/organ/cyberimp/brain/binyat/Initialize(mapload)
	. = ..()
	sequencer = new(src)

/obj/item/organ/cyberimp/brain/binyat/Destroy()
	QDEL_NULL(sequencer)
	return ..()

/obj/item/organ/cyberimp/brain/binyat/emp_act(severity)
	. = ..()
	if((. & EMP_PROTECT_SELF) || !owner)
		return
	owner.adjust_stamina_loss(40 / severity)
	owner.adjust_bodytemperature(400 / severity)
	to_chat(owner, span_warning("Ваш Binyat опасно перегревается!"))

/datum/action/cooldown/binyat
	name = "Дистанционный взлом"
	desc = "Взламывает устройство в радиусе трёх клеток за три секунды. Камеры отключаются на 30 секунд. Взлом вызывает ожоги, усиливающиеся при частом использовании."
	button_icon = 'modular_bandastation/uplink_items/icons/items.dmi'
	button_icon_state = "hackerman"
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED
	click_to_activate = TRUE
	cooldown_time = 10 SECONDS
	var/hacking = FALSE
	var/recent_hacking = 0

/datum/action/cooldown/binyat/IsAvailable(feedback = FALSE)
	var/obj/item/organ/cyberimp/brain/binyat/implant = target
	return ..() && !hacking && implant.owner == owner && !(implant.organ_flags & ORGAN_FAILING) && !implant.cybernetic_rejection

/datum/action/cooldown/binyat/proc/can_hack(atom/hack_target)
	return isobj(hack_target) && !QDELETED(hack_target) && hack_target != owner && isturf(owner?.loc) && isturf(hack_target.loc) && get_dist(owner, hack_target) <= 3 && (hack_target in view(3, owner))

/datum/action/cooldown/binyat/Activate(atom/hack_target)
	if(!IsAvailable() || !can_hack(hack_target))
		return FALSE
	hacking = TRUE
	var/mob/living/hacker = owner
	var/datum/beam/beam = hacker.Beam(hack_target, icon_state = "sm_arc_supercharged", time = 3 SECONDS)
	hacker.visible_message(span_warning("Между [hacker] и [hack_target] проскакивает потрескивающий разряд."))
	var/completed = do_after(hacker, 3 SECONDS, hack_target)
	qdel(beam)
	if(QDELETED(src))
		return FALSE
	hacking = FALSE
	if(!completed || owner != hacker || !IsAvailable() || !can_hack(hack_target))
		return FALSE
	if(!hack(hack_target, hacker))
		hacker.balloon_alert(hacker, "взлом не удался!")
		StartCooldown(3 SECONDS)
		return FALSE
	hack_target.add_hiddenprint(hacker)
	log_combat(hacker, hack_target, "remotely emagged", target)
	playsound(hack_target, 'sound/machines/terminal/terminal_processing.ogg', 15, TRUE)
	hacker.adjust_fire_loss(5 + recent_hacking * 3)
	recent_hacking++
	addtimer(CALLBACK(src, PROC_REF(lower_recent_hacking)), 1 MINUTES)
	StartCooldown()
	return TRUE

/datum/action/cooldown/binyat/proc/hack(atom/hack_target, mob/living/hacker)
	if(istype(hack_target, /obj/machinery/camera))
		var/obj/machinery/camera/camera = hack_target
		if(!camera.can_use())
			return FALSE
		camera.emp_act(EMP_HEAVY, reset_time = 30 SECONDS)
		return !camera.can_use()
	var/obj/item/organ/cyberimp/brain/binyat/implant = target
	if(!istype(hack_target, /obj/machinery/door) && !implant.sequencer.can_emag(hack_target, hacker))
		return FALSE
	return hack_target.emag_act(hacker, implant.sequencer)

/datum/action/cooldown/binyat/proc/lower_recent_hacking()
	recent_hacking--
