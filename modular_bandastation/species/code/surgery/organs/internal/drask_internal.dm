/obj/item/organ/brain/drask
	icon = 'icons/bandastation/mob/species/drask/organs.dmi'
	icon_state = "brain2"

/obj/item/organ/eyes/drask
	name = "глаза драска"
	desc = "Три глаза, приспособленные к слабому освещению и чувствительные к ярким вспышкам."
	icon = 'icons/bandastation/mob/species/drask/organs.dmi'
	eye_icon = 'icons/bandastation/mob/species/drask/drask_eyes.dmi'
	eye_icon_state = "drask_eyes"
	eyelid_icon = 'icons/bandastation/mob/species/drask/drask_eyes.dmi'
	has_center_eye = TRUE
	synchronized_blinking = FALSE
	iris_overlay = null
	lighting_cutoff = LIGHTING_CUTOFF_REAL_LOW
	flash_protect = FLASH_PROTECTION_SENSITIVE
	organ_traits = list(TRAIT_LUMINESCENT_EYES)

/obj/item/organ/tongue/drask
	name = "язык драска"
	desc = "Язык, способный воспроизводить гулкие звуки орлуума."
	say_mod = "гудит"
	languages_native = list(/datum/language/orluum)
	liked_foodtypes = DAIRY
	toxic_foodtypes = ALCOHOL | SUGAR
	emote_sounds = list(
		/datum/emote/living/scream::key = 'modular_bandastation/emote_panel/audio/drask/drasktalk2.ogg',
		/datum/emote/living/cough::key = 'modular_bandastation/emote_panel/audio/drask/draskcough.ogg',
		/datum/emote/living/sneeze::key = 'modular_bandastation/emote_panel/audio/drask/drasksneeze.ogg',
	)
	var/static/list/speech_replacements = list(
		new /regex("o+", "g") = "oo",
		new /regex("O+", "g") = "OO",
		new /regex("u+", "g") = "uu",
		new /regex("U+", "g") = "UU",
		new /regex("m+", "g") = "mm",
		new /regex("M+", "g") = "MM",
		new /regex("о+", "g") = "оо",
		new /regex("О+", "g") = "ОО",
		new /regex("у+", "g") = "уу",
		new /regex("У+", "g") = "УУ",
		new /regex("м+", "g") = "мм",
		new /regex("М+", "g") = "ММ",
	)

/obj/item/organ/tongue/drask/Initialize(mapload)
	. = ..()
	AddComponent(\
		/datum/component/speechmod,\
		replacements = speech_replacements,\
		should_modify_speech = CALLBACK(src, PROC_REF(should_modify_speech))\
	)

/obj/item/organ/tongue/drask/on_mob_insert(mob/living/carbon/receiver, special, movement_flags)
	. = ..()
	RegisterSignal(receiver, COMSIG_LIVING_SEND_SPEECH, PROC_REF(play_drask_speech_sound))

/obj/item/organ/tongue/drask/on_mob_remove(mob/living/carbon/organ_owner, special, movement_flags)
	UnregisterSignal(organ_owner, COMSIG_LIVING_SEND_SPEECH)
	return ..()

/obj/item/organ/tongue/drask/proc/play_drask_speech_sound(mob/living/speaker, list/listeners, list/message_mods, message_range, atom/speech_origin)
	SIGNAL_HANDLER
	if(speaker != speech_origin || message_range <= WHISPER_RANGE || message_range == INFINITY)
		return
	if(message_mods?[WHISPER_MODE] || message_mods?[MODE_CUSTOM_SAY_ERASE_INPUT] || HAS_TRAIT(speaker, TRAIT_SIGN_LANG) || HAS_TRAIT(speaker, TRAIT_UNKNOWN_VOICE))
		return
	if(!length(listeners) || !prob(20))
		return
	var/turf/source_turf = get_turf(speaker)
	if(!source_turf)
		return
	var/sound/blip = sound('modular_bandastation/emote_panel/audio/drask/drasktalk.ogg')
	for(var/mob/listener in listeners)
		listener.playsound_local(source_turf, vol = 30, sound_to_use = blip, max_distance = message_range, volume_preference = /datum/preference/numeric/volume/sound_tts_volume)

/obj/item/organ/heart/drask
	name = "сердце драска"
	icon = 'icons/bandastation/mob/species/drask/organs.dmi'
	zone = BODY_ZONE_HEAD

/obj/item/organ/lungs/drask
	name = "лёгкие драска"
	icon = 'icons/bandastation/mob/species/drask/organs.dmi'

/obj/item/organ/liver/drask
	name = "печень драска"
	icon = 'icons/bandastation/mob/species/drask/organs.dmi'
	icon_state = "kidneys"
	alcohol_tolerance = ALCOHOL_RATE * 4
