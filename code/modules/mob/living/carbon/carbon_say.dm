/mob/living/carbon/can_speak(allow_mimes = FALSE)
	// If we're not a nobreath species, and we don't have lungs, we can't talk
	if(dna?.species && !HAS_TRAIT_FROM(src, TRAIT_NOBREATH, SPECIES_TRAIT) && !get_organ_slot(ORGAN_SLOT_LUNGS))
		// How do species that don't breathe, talk? Magic, that's what.
		return FALSE

	return ..()

/// A tongue can articulate its usual languages and special languages learned through upbringing.
/mob/living/carbon/could_speak_language(datum/language/language_path)
	var/obj/item/organ/tongue/spoken_with = get_organ_slot(ORGAN_SLOT_TONGUE)
	if(spoken_with)
		// the tower of babel needs to bypass the tongue language restrictions without giving omnitongue
		if(HAS_MIND_TRAIT(src, TRAIT_TOWER_OF_BABEL) || spoken_with.could_speak_language(language_path))
			return TRUE
		if(spoken_with.cybernetic_rejection || language_path == /datum/language/common)
			return FALSE
		// A new language holder checks articulation while it is still being created.
		var/datum/language_holder/holder = get_language_holder(create_if_missing = FALSE)
		return LANGUAGE_BACKGROUND in holder?.spoken_languages?[language_path]

	return initial(language_path.flags) & LANGUAGE_TONGUELESS_SPEECH
