// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/health.dm.
// Voidcrew: healing shares one cap per person across every artifact (artifact_capped_heal()),
// so a heal artifact bolted in a corridor is a comfort, not a medbay. Robo variants work on
// silicons, robotic mobs and prosthetic limbs. Hurt effects log like weapons. Nova's numbers
// (pulses scaling to 250 healing or 160 damage) are cut to sane ranges.

/datum/artifact_effect/heal
	label_name = "Лечит"
	log_name = "Heal"
	tier = ARTIFACT_TIER_UNCOMMON
	minor = TRUE
	helpful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_ORGANIC)
	/// Which limbs it works on for carbons, and which mobs otherwise
	var/robotic = FALSE

/datum/artifact_effect/heal/do_effect_touch(mob/living/user)
	if(mend(user, 12))
		to_chat(user, span_notice((robotic ? "Ваши повреждённые детали срастаются обратно." : "По телу разливается успокаивающее тепло.")))

/datum/artifact_effect/heal/do_effect_aura(seconds_per_tick)
	for(var/mob/living/target as anything in living_in_range())
		if(mend(target, 0.75 * seconds_per_tick) && prob(10))
			to_chat(target, span_notice((robotic ? "Слабое гудение стабилизирует ваши системы." : "Вы чувствуете мягкое тепло от чего-то рядом.")))

/datum/artifact_effect/heal/do_effect_pulse(power)
	for(var/mob/living/target as anything in living_in_range())
		if(mend(target, clamp(power * 0.6, 4, 20)))
			to_chat(target, span_notice((robotic ? "Волна энергии чинит вашу обшивку." : "Вас омывает волна тепла.")))

/// Heals one mob within the shared cap. Returns the amount healed.
/datum/artifact_effect/heal/proc/mend(mob/living/target, amount)
	if(target.stat == DEAD)
		return 0
	amount *= artifact_exposure(target)
	if(iscarbon(target))
		return artifact_capped_heal(target, amount, robotic ? BODYTYPE_ROBOTIC : BODYTYPE_ORGANIC)
	if(robotic ? !(target.mob_biotypes & MOB_ROBOTIC) : !(target.mob_biotypes & MOB_ORGANIC))
		return 0
	return artifact_capped_heal(target, amount)

/datum/artifact_effect/heal/robotic
	label_name = "Чинит машины"
	log_name = "Robo-heal"
	possible_kinds = list(ARTIFACT_ENERGY_ELECTROMAGNETIC, ARTIFACT_ENERGY_PARTICLE)
	robotic = TRUE

/datum/artifact_effect/hurt
	label_name = "Ранит"
	log_name = "Hurt"
	tier = ARTIFACT_TIER_UNCOMMON
	minor = TRUE
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_CONCENTRATED, ARTIFACT_ENERGY_ORGANIC)
	var/robotic = FALSE

/datum/artifact_effect/hurt/do_effect_touch(mob/living/user)
	if(wound(user, 8))
		to_chat(user, span_warning((robotic ? "Ваши системы сообщают о внезапном повреждении!" : "Вас поражает болезненный разряд энергии!")))

/datum/artifact_effect/hurt/do_effect_aura(seconds_per_tick)
	for(var/mob/living/target as anything in living_in_range())
		if(wound(target, 0.5 * seconds_per_tick) && prob(10))
			to_chat(target, span_warning((robotic ? "Что-то рядом нагружает вашу обшивку." : "Вы чувствуете болезненную силу, исходящую от чего-то рядом.")))

/datum/artifact_effect/hurt/do_effect_pulse(power)
	for(var/mob/living/target as anything in living_in_range())
		if(wound(target, clamp(power * 0.3, 3, 12)))
			to_chat(target, span_warning((robotic ? "Волна энергии сминает вашу обшивку!" : "Волна энергии рвёт вашу кожу!")))

/// Hurts one mob, split between brute and burn. Returns TRUE if it took any.
/datum/artifact_effect/hurt/proc/wound(mob/living/target, amount)
	if(target.stat == DEAD)
		return FALSE
	amount *= artifact_exposure(target)
	if(amount <= 0)
		return FALSE
	if(iscarbon(target))
		var/before = target.get_brute_loss() + target.get_fire_loss()
		target.take_overall_damage(amount / 2, amount / 2, required_bodytype = robotic ? BODYTYPE_ROBOTIC : BODYTYPE_ORGANIC)
		if(target.get_brute_loss() + target.get_fire_loss() <= before)
			return FALSE
	else
		if(robotic ? !(target.mob_biotypes & MOB_ROBOTIC) : !(target.mob_biotypes & MOB_ORGANIC))
			return FALSE
		target.take_overall_damage(amount / 2, amount / 2)
	log_harm(target)
	return TRUE

/datum/artifact_effect/hurt/robotic
	label_name = "Повреждает машины"
	log_name = "Robo-hurt"
	possible_kinds = list(ARTIFACT_ENERGY_ELECTROMAGNETIC, ARTIFACT_ENERGY_PARTICLE)
	robotic = TRUE
