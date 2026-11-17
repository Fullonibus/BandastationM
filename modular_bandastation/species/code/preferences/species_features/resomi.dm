/datum/preference/choiced/species_feature/resomi_crest
	savefile_key = "feature_resomi_crest"
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_FEATURES
	main_feature_name = "Хохолок"
	should_generate_icons = TRUE
	relevant_organ = /obj/item/organ/resomi_crest

/datum/preference/choiced/species_feature/resomi_crest/create_default_value()
	return /datum/sprite_accessory/resomi_crest/plumage::name

/datum/preference/choiced/species_feature/resomi_crest/icon_for(value)
	var/datum/sprite_accessory/crest = get_accessory_for_value(value)
	var/datum/universal_icon/preview = uni_icon(crest.icon, "m_resomi_crest_[crest.icon_state]_FRONT")
	preview.crop(7, 14, 25, 32)
	preview.scale(32, 32)
	return preview

/datum/preference/choiced/species_feature/resomi_crest/compile_constant_data()
	var/list/data = ..()
	data[SUPPLEMENTAL_FEATURE_KEY] = /datum/preference/color/resomi_crest_color::savefile_key
	return data

/datum/preference/color/resomi_crest_color
	savefile_key = "resomi_crest_color"
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_SUPPLEMENTAL_FEATURES
	relevant_organ = /obj/item/organ/resomi_crest

/datum/preference/color/resomi_crest_color/create_default_value()
	return COLOR_WHITE

/datum/preference/color/resomi_crest_color/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	target.dna.features[FEATURE_RESOMI_CREST_COLOR] = value

/datum/preference/choiced/species_feature/resomi_markings
	savefile_key = "feature_resomi_markings"
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	relevant_body_markings = /datum/bodypart_overlay/simple/body_marking/resomi

/datum/preference/choiced/species_feature/resomi_markings/create_default_value()
	return SPRITE_ACCESSORY_NONE

/datum/preference/color/resomi_markings_color
	savefile_key = "resomi_markings_color"
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	relevant_body_markings = /datum/bodypart_overlay/simple/body_marking/resomi

/datum/preference/color/resomi_markings_color/create_default_value()
	return COLOR_WHITE

/datum/preference/color/resomi_markings_color/is_accessible(datum/preferences/preferences)
	return ..() && preferences.read_preference(/datum/preference/choiced/species_feature/resomi_markings) != SPRITE_ACCESSORY_NONE

/datum/preference/color/resomi_markings_color/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	target.dna.features[FEATURE_RESOMI_MARKINGS_COLOR] = value
