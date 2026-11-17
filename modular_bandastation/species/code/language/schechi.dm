/// Schechi, the native language of the Resomi.
/datum/language/resomi
	name = "Schechi"
	desc = "Язык резоми, в котором много свистов и трелей."
	key = "e"
	flags = LANGUAGE_TONGUELESS_SPEECH
	space_chance = 50
	default_name_syllable_min = 1
	syllables = list(
		"ca", "ra", "ma", "sa", "na", "ta", "la", "sha", "scha", "a",
		"ce", "re", "me", "se", "ne", "te", "le", "she", "sche", "e",
		"ci", "ri", "mi", "si", "ni", "ti", "li", "shi", "schi", "i",
	)

/// Resomi speak both Galactic Common and Schechi.
/datum/language_holder/resomi
	understood_languages = list(
		/datum/language/common = list(LANGUAGE_ATOM),
		/datum/language/resomi = list(LANGUAGE_ATOM),
	)
	spoken_languages = list(
		/datum/language/common = list(LANGUAGE_ATOM),
		/datum/language/resomi = list(LANGUAGE_ATOM),
	)
