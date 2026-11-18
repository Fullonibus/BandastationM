

/mob/living/carbon/human/say(
	message,
	bubble_type,
	list/spans = list(),
	sanitize = TRUE,
	datum/language/language,
	ignore_spam = FALSE,
	forced,
	filterproof = FALSE,
	message_range = 7,
	datum/saymode/saymode,
	list/message_mods = list(),
)
	if(!HAS_TRAIT(src, TRAIT_SPEAKS_CLEARLY))
		var/static/regex/tongueless_lower = new("\[gdntke]+", "g")
		var/static/regex/tongueless_upper = new("\[GDNTKE]+", "g")
		if(message[1] != "*")
			message = tongueless_lower.Replace(message, pick("aa","oo","'"))
			message = tongueless_upper.Replace(message, pick("AA","OO","'"))
	return ..()

/mob/living/carbon/human/get_default_say_verb()
	var/obj/item/organ/tongue/tongue = get_organ_slot(ORGAN_SLOT_TONGUE)
	if(isnull(tongue))
		if(HAS_TRAIT(src, TRAIT_SIGN_LANG))
			return "signs"
		return "gurgles"
	return  ru_say_verb(tongue.temp_say_mod) || ru_say_verb(tongue.say_mod) || ..()

/// A covered face is identified only by the worn ID, never by the underlying voice name.
/mob/living/carbon/human/get_voice(add_id_name = FALSE)
	if(HAS_TRAIT(src, TRAIT_UNKNOWN_VOICE))
		return "Unknown"
	if(obscured_slots & HIDEFACE)
		return get_id_name("Неизвестный", honorifics = add_id_name)
	var/id_name = get_id_name("")
	if(HAS_TRAIT(src, TRAIT_VOICE_MATCHES_ID) && id_name)
		return id_name
	if(override_voice)
		return override_voice
	if(add_id_name && real_name == id_name) // Allows for "Captain John" to have the voice "Captain Join" and not "John"
		return get_id_name("", honorifics = TRUE)
	return real_name

/mob/living/carbon/human/get_message_voice(visible_name)
	. = ..()
	var/list/identity = list(null, null, null)
	SEND_SIGNAL(src, COMSIG_HUMAN_GET_VISIBLE_NAME, identity)
	if(identity[VISIBLE_NAME_ID])
		return "[.] (as [identity[VISIBLE_NAME_ID]])"
	if(. != name)
		. += " (as [get_id_name("Unknown", honorifics = TRUE)])"

/mob/living/carbon/human/binarycheck()
	if(IS_UNCONSCIOUS_OR_CRIT(src))
		return FALSE
	var/area/our_area = get_area(src)
	if(our_area.area_flags & BINARY_JAMMING)
		return FALSE
	var/obj/item/organ/brain/cybernetic/ai/brain = get_organ_slot(ORGAN_SLOT_BRAIN)
	if(istype(brain))
		return TRUE
	// AI EDIT START - Dual ear slots
	// BANDASTATION EDIT START - Dual ear slots
	for(var/obj/item/radio/headset/dongle in list(ear_right, ear_left))
		if(dongle.special_channels & RADIO_SPECIAL_BINARY)
			return TRUE
	return FALSE
	// BANDASTATION EDIT END
	// AI EDIT END

// AI EDIT START - Dual ear slots
// BANDASTATION ADDITION START - Dual ear slots
/// Select one transmitter so wearing two headsets does not duplicate outgoing messages.
/mob/living/carbon/human/proc/get_headset_for_channel(channel)
	for(var/obj/item/radio/headset/headset in list(ear_right, ear_left))
		if(!headset.is_on() || !headset.get_broadcasting() || headset.wires.is_cut(WIRE_TX))
			continue
		if(channel)
			if(channel == MODE_DEPARTMENT && !length(headset.channels))
				continue
			var/headset_channel = channel == MODE_DEPARTMENT ? headset.channels[1] : channel
			if(!LAZYACCESS(headset.channels, headset_channel))
				continue
		return headset
	return null
// BANDASTATION ADDITION END
// AI EDIT END

/mob/living/carbon/human/radio(message, list/message_mods = list(), list/spans, language) //Poly has a copy of this, lazy bastard
	. = ..()
	if(.)
		return

	// AI EDIT START - Dual ear slots
	// BANDASTATION EDIT START - Dual ear slots
	var/channel = message_mods[RADIO_EXTENSION]
	if(message_mods[MODE_HEADSET])
		channel = null
	else if(channel != MODE_DEPARTMENT && !GLOB.default_radio_channels[channel])
		return FALSE

	var/obj/item/radio/headset/headset = get_headset_for_channel(channel)
	headset?.talk_into(src, message, channel, spans, language, message_mods)
	if(message_mods[MODE_HEADSET] || channel == MODE_DEPARTMENT || ear_right || ear_left)
		return ITALICS | REDUCE_RANGE
	return FALSE
	// BANDASTATION EDIT END
	// AI EDIT END
