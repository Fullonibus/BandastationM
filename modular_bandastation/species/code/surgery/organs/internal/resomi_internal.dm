/// Resomi eyes see well in low light and are sensitive to bright flashes.
/obj/item/organ/eyes/resomi
	name = "resomi eyes"
	desc = "Глаза, приспособленные к сумеркам."
	eye_icon = 'icons/bandastation/mob/species/resomi/eyes.dmi'
	blink_animation = FALSE
	lighting_cutoff = LIGHTING_CUTOFF_REAL_LOW
	flash_protect = FLASH_PROTECTION_HYPER_SENSITIVE

/// Resomi lungs cope with a lower partial pressure of oxygen.
/obj/item/organ/lungs/resomi
	name = "resomi lungs"
	safe_oxygen_min = 12

/// Resomi need to eat more often.
/obj/item/organ/stomach/resomi
	name = "resomi stomach"
	hunger_modifier = 1.5

/// A tongue specialized for trills and whistles.
/obj/item/organ/tongue/resomi
	name = "resomi tongue"
	say_mod = "щебечет"
	languages_native = list(/datum/language/resomi)
	liked_foodtypes = MEAT|SEAFOOD
	emote_sounds = list(
		/datum/emote/living/scream::key = 'modular_bandastation/emote_panel/audio/resomi/resomiscream.ogg',
		/datum/emote/living/cough::key = 'modular_bandastation/emote_panel/audio/resomi/resomicough.ogg',
		/datum/emote/living/sneeze::key = 'modular_bandastation/emote_panel/audio/resomi/resomisneeze.ogg',
		/datum/emote/living/chuckle::key = 'modular_bandastation/emote_panel/audio/resomi/cackle.ogg',
		/datum/emote/living/laugh::key = 'modular_bandastation/emote_panel/audio/resomi/cackle.ogg',
		/datum/emote/living/giggle::key = 'modular_bandastation/emote_panel/audio/resomi/resomilaugh.ogg',
	)

/// Vocalizations available to Resomi through the regular emote panel.
/datum/emote/living/carbon/human/resomi
	species_type_whitelist_typecache = list(/datum/species/resomi)
	emote_type = EMOTE_AUDIBLE
	cooldown = 2 SECONDS

/datum/emote/living/carbon/human/resomi/chirp
	name = "Чирикнуть"
	key = "resomichirp"
	message = "чирикает."
	sound = 'modular_bandastation/emote_panel/audio/resomi/resomichirp.ogg'

/datum/emote/living/carbon/human/resomi/trill
	name = "Издать трель"
	key = "resomitrill"
	message = "издаёт трель."
	sound = 'modular_bandastation/emote_panel/audio/resomi/resomitrill.ogg'
