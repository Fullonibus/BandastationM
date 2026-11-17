GLOBAL_LIST_INIT(drask_skin_tones, list(
	"drask_lightest" = "#c0c0ff",
	"drask_lighter" = "#f8f8c5",
	"drask_light" = "#c0c0c0",
	"drask_mid" = "#a9a9a9",
	"drask_dark" = "#808080",
	"drask_darker" = "#505050",
	"drask_darkest" = "#303030",
))

/datum/preference/choiced/drask_skin_tone
	savefile_key = "drask_skin_tone"
	priority = PREFERENCE_PRIORITY_BODYPARTS
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	main_feature_name = "Тон кожи (Драск)"

/datum/preference/choiced/drask_skin_tone/init_possible_values()
	return assoc_to_keys(GLOB.drask_skin_tones)

/datum/preference/choiced/drask_skin_tone/create_default_value()
	return "drask_mid"

/datum/preference/choiced/drask_skin_tone/compile_constant_data()
	var/list/data = ..()
	data[CHOICED_PREFERENCE_DISPLAY_NAMES] = list(
		"drask_lightest" = "Светлейший",
		"drask_lighter" = "Светлее",
		"drask_light" = "Светлый",
		"drask_mid" = "Средний",
		"drask_dark" = "Тёмный",
		"drask_darker" = "Темнее",
		"drask_darkest" = "Темнейший",
	)
	return data

/datum/preference/choiced/drask_skin_tone/has_relevant_feature(datum/preferences/preferences)
	var/species_type = preferences.read_preference(/datum/preference/choiced/species)
	return species_type == /datum/species/drask

/// Limb tint for a saved Drask skin tone. Old or missing values use the default tone.
/proc/get_drask_tone_color(choice)
	return GLOB.drask_skin_tones[choice] || GLOB.drask_skin_tones["drask_mid"]

/datum/preference/choiced/drask_skin_tone/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	if(!istype(target.dna.species, /datum/species/drask))
		return
	target.dna.features[FEATURE_DRASK_SKIN_TONE] = value
	target.dna.features[FEATURE_MUTANT_COLOR] = get_drask_tone_color(value)
