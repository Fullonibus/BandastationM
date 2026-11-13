// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/drugs.dm.
// Voidcrew: real hallucinations as well as the colours, capped at a minute.

/datum/artifact_effect/hallucination
	label_name = "Галлюцинации"
	log_name = "Hallucination"
	tier = ARTIFACT_TIER_UNCOMMON
	minor = TRUE
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_PSIONIC, ARTIFACT_ENERGY_ORGANIC)

/datum/artifact_effect/hallucination/do_effect_touch(mob/living/user)
	if(dose(user, 20 SECONDS))
		to_chat(user, span_hypnophrase("Цвета расплываются по краям."))

/datum/artifact_effect/hallucination/do_effect_aura(seconds_per_tick)
	for(var/mob/living/carbon/target in living_in_range())
		if(SPT_PROB(20, seconds_per_tick) && dose(target, 5 SECONDS))
			to_chat(target, span_hypnophrase("Что-то шевелится на краю зрения."))

/datum/artifact_effect/hallucination/do_effect_pulse(power)
	for(var/mob/living/carbon/target in living_in_range())
		if(dose(target, power SECONDS))
			to_chat(target, span_hypnophrase("Всё начинает плыть."))

/datum/artifact_effect/hallucination/proc/dose(mob/living/target, duration)
	if(!iscarbon(target) || target.stat == DEAD)
		return FALSE
	var/exposure = artifact_exposure(target)
	if(exposure <= 0)
		return FALSE
	target.adjust_hallucinations_up_to(duration * exposure, 60 SECONDS)
	target.adjust_drugginess_up_to(duration * exposure, 30 SECONDS)
	log_harm(target)
	return TRUE
