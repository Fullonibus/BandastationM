/datum/language/orluum
	name = "Орлуум"
	desc = "Родной язык драсков. Его низкий гул напоминает пение китов."
	key = "2"
	syllables = list("хоорб", "вррм", "ооорм", "урррум", "ооум", "ээ", "ффм", "ххх", "мн", "онгг")
	always_use_default_namelist = TRUE
	icon = 'icons/bandastation/mob/species/drask/bodyparts.dmi'
	icon_state = "drask_head"
	default_priority = 90

/datum/language/orluum/default_name(gender)
	var/static/list/name_parts = list(
		"Хоорм", "Вииск", "Саар", "Мноо", "Оумн", "Фмонг", "Гнии", "Вррм", "Оорм",
		"Дромнн", "Ссоумн", "Овв", "Хоорб", "Ваар", "Гаар", "Гоом", "Руум", "Румум",
	)
	return "[pick(name_parts)]-[pick(name_parts)]-[pick(name_parts)]"

/datum/language_holder/drask
	understood_languages = list(
		/datum/language/common = list(LANGUAGE_ATOM),
		/datum/language/orluum = list(LANGUAGE_ATOM),
	)
	spoken_languages = list(
		/datum/language/common = list(LANGUAGE_ATOM),
		/datum/language/orluum = list(LANGUAGE_ATOM),
	)
