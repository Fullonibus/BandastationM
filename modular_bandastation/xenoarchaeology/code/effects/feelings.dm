// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/feelings.dm.
// Voidcrew: trimmed message lists, plain spans instead of font tags, dizziness only from dread.

/datum/artifact_effect/feelings
	tier = ARTIFACT_TIER_COMMON
	minor = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_PSIONIC)
	/// Strong feelings
	var/list/major_messages
	/// Passing feelings
	var/list/minor_messages
	var/major_mood_type
	var/minor_mood_type
	/// Span proc for messages
	var/good = TRUE

/datum/artifact_effect/feelings/do_effect_touch(mob/living/user)
	feel(user, 50, 100)

/datum/artifact_effect/feelings/do_effect_aura(seconds_per_tick)
	for(var/mob/living/carbon/human/target in living_in_range())
		if(SPT_PROB(2.5, seconds_per_tick))
			feel(target, 100, 0)
		else if(SPT_PROB(5, seconds_per_tick))
			feel(target, 0, 100)

/datum/artifact_effect/feelings/do_effect_pulse(power)
	for(var/mob/living/carbon/human/target in living_in_range())
		feel(target, 80, 100)

/// Gives `target` a strong feeling with `major_chance`, else a passing one with `minor_chance`.
/datum/artifact_effect/feelings/proc/feel(mob/living/target, major_chance, minor_chance)
	if(!ishuman(target) || prob(100 * (1 - artifact_exposure(target))))
		return
	if(prob(major_chance))
		to_chat(target, good ? span_nicegreen("<b>[pick(major_messages)]</b>") : span_boldwarning(pick(major_messages)))
		target.add_mood_event("artifact_feeling_major", major_mood_type)
		if(!good)
			target.adjust_dizzy_up_to(4 SECONDS, 20 SECONDS)
	else if(prob(minor_chance))
		to_chat(target, good ? span_nicegreen(pick(minor_messages)) : span_warning(pick(minor_messages)))
		target.add_mood_event("artifact_feeling_minor", minor_mood_type)

/datum/artifact_effect/feelings/good
	label_name = "Хорошее настроение"
	log_name = "Good feeling"
	good = TRUE
	major_mood_type = /datum/mood_event/artifact_good_major
	minor_mood_type = /datum/mood_event/artifact_good_minor
	major_messages = list(
		"Вам хочется обнять всех, кого встретите!",
		"Всё идёт так хорошо!",
		"У вас кружится голова от радости.",
		"Хочется танцевать.",
	)
	minor_messages = list(
		"Вам хорошо.",
		"У вас хорошее предчувствие.",
		"Чем-то вкусно пахнет.",
		"Вы еле сдерживаете улыбку.",
		"Цвета вокруг кажутся чуть ярче.",
		"Тревоги кажутся очень далёкими.",
	)

/datum/artifact_effect/feelings/bad
	label_name = "Ужас"
	log_name = "Bad feeling"
	good = FALSE
	major_mood_type = /datum/mood_event/artifact_bad_major
	minor_mood_type = /datum/mood_event/artifact_bad_minor
	major_messages = list(
		"Нужно убираться отсюда!",
		"Кто-то пытается вас убить!",
		"Там что-то есть!",
		"Что с вами происходит?",
	)
	minor_messages = list(
		"Вам тревожно.",
		"Что-то не так.",
		"У вас странное чувство внутри.",
		"У вас плохое предчувствие.",
		"По коже головы бегут мурашки.",
		"Тени кажутся длиннее, чем были.",
		"Стены будто стали ближе.",
	)

/datum/mood_event/artifact_good_major
	description = "Всё отлично, и я даже не знаю почему."
	mood_change = 6
	timeout = 5 MINUTES

/datum/mood_event/artifact_good_minor
	description = "Я странно спокоен."
	mood_change = 3
	timeout = 3 MINUTES

/datum/mood_event/artifact_bad_major
	description = "Здесь что-то очень, очень не так."
	mood_change = -6
	timeout = 5 MINUTES

/datum/mood_event/artifact_bad_minor
	description = "Мне тревожно, и я не знаю почему."
	mood_change = -3
	timeout = 3 MINUTES
