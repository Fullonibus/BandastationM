/datum/dna
	var/datum/tts_seed/tts_seed_dna

/datum/dna/copy_dna(datum/dna/new_dna, transfer_flags = COPY_DNA_SE|COPY_DNA_SPECIES)
	. = ..()
	new_dna.tts_seed_dna = tts_seed_dna
	if(istype(new_dna.holder))
		new_dna.holder.AddComponent(/datum/component/tts_component, new_dna.tts_seed_dna)

/atom/proc/add_tts_component()
	return

/atom/Initialize(mapload, ...)
	. = ..()
	add_tts_component()

/atom/proc/cast_tts(listener, message, atom/location, is_local = TRUE, is_radio = FALSE, list/effects, traits = TTS_TRAIT_RATE_FASTER, preSFX, postSFX, tts_seed_override, channel_override, check_deafness, radio_freq)
	SEND_SIGNAL(src, COMSIG_ATOM_TTS_CAST, listener, message, location, is_local, is_radio, effects, traits, preSFX, postSFX, tts_seed_override, channel_override, check_deafness, radio_freq)

/atom/movable/virtualspeaker/cast_tts(listener, message, atom/location, is_local, is_radio, list/effects, traits, preSFX, postSFX, tts_seed_override, channel_override, check_deafness, radio_freq)
	SEND_SIGNAL(source, COMSIG_ATOM_TTS_CAST, listener, message, location || (is_radio ? radio : null), is_local, is_radio, effects, traits, preSFX, postSFX, tts_seed_override, channel_override, check_deafness, radio_freq)

// TODO: Do it better?
/atom/proc/get_tts_seed()
	var/datum/component/tts_component/tts_component = GetComponent(/datum/component/tts_component)
	if(tts_component)
		return tts_component.tts_seed

/// Describes the radio voice after TTS overrides, even for listeners with playback disabled.
/atom/movable/proc/get_radio_voice_label(list/message_mods)
	var/datum/tts_seed/seed = get_tts_seed()
	if(!seed || HAS_TRAIT(src, TRAIT_UNKNOWN_VOICE))
		return "Неизвестный голос"

	var/list/tts_args = list(
		TTS_CAST_SPEAKER = src,
		TTS_CAST_SEED = LAZYACCESS(message_mods, MODE_TTS_SEED_OVERRIDE) || seed,
		TTS_PRIORITY = TTS_PRIORITY_VOICE,
		TTS_CAST_EFFECTS = list(),
		TTS_CHANNEL_OVERRIDE = CHANNEL_TTS_RADIO,
	)
	SEND_SIGNAL(src, COMSIG_TTS_COMPONENT_PRE_CAST_TTS, tts_args)
	seed = tts_args[TTS_CAST_SEED]
	if(ispath(seed, /datum/tts_seed))
		seed = SStts220.tts_seeds[initial(seed.name)]
	if(!istype(seed))
		return "Неизвестный голос"
	switch(seed.gender)
		if(TTS_GENDER_FEMALE)
			return "Женский голос"
		if(TTS_GENDER_MALE)
			return "Мужской голос"
	return "Неизвестный голос"

/atom/movable/virtualspeaker
	/// Resolved once per broadcast so all listeners see the same description.
	var/radio_voice_label

/atom/movable/virtualspeaker/get_radio_voice_label(list/message_mods)
	if(radio_voice_label)
		return radio_voice_label
	if(radio?.anonymize || QDELETED(source))
		return "Неизвестный голос"
	return source.get_radio_voice_label(message_mods)

/atom/proc/get_tts_effects(list/additional_effects)
	var/datum/component/tts_component/tts_component = GetComponent(/datum/component/tts_component)
	return tts_component.get_effects(additional_effects)

/atom/proc/change_tts_seed(mob/chooser, overrides, list/new_sound_effects)
	if(!get_tts_seed())
		if(alert(chooser, "Отсутствует TTS компонент. Создать?", "Изменение TTS", "Да", "Нет") == "Нет")
			return
		AddComponent(/datum/component/tts_component, /datum/tts_seed/silero/angel)
	SEND_SIGNAL(src, COMSIG_ATOM_TTS_SEED_CHANGE, chooser, overrides, new_sound_effects)

/atom/proc/tts_effects_add(list/effects)
	SEND_SIGNAL(src, COMSIG_ATOM_TTS_EFFECTS_ADD, effects)

/atom/proc/tts_effects_remove(list/effects)
	SEND_SIGNAL(src, COMSIG_ATOM_TTS_EFFECTS_REMOVE, effects)
