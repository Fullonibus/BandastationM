/datum/preference/color/drask_arm_spines_color
	savefile_key = "drask_arm_spines_color"
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	relevant_organ = /obj/item/organ/thermal_spine/arm_l

/datum/preference/color/drask_arm_spines_color/create_default_value()
	return "#66FFAA"

/datum/preference/color/drask_arm_spines_color/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	target.dna.features[FEATURE_DRASK_ARM_SPINES_COLOR] = value
