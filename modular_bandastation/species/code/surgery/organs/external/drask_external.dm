/obj/item/organ/thermal_spine
	name = "термонарост"
	desc = "Орган терморегуляции драска."
	organ_flags = ORGAN_ORGANIC | ORGAN_PROMINENT
	healing_factor = 0.002
	abstract_type = /obj/item/organ/thermal_spine

/obj/item/organ/thermal_spine/proc/get_thermal_integrity()
	return clamp(1 - damage / maxHealth, 0, 1)

/obj/item/organ/thermal_spine/central
	name = "центральный терморегулятор"
	slot = ORGAN_SLOT_THERMAL_REGULATOR
	zone = BODY_ZONE_CHEST
	icon = 'icons/bandastation/mob/species/drask/organs.dmi'
	icon_state = "innards"

/obj/item/organ/thermal_spine/arm_l
	name = "термонарост левой руки"
	slot = ORGAN_SLOT_ARM_SPINES_L
	zone = BODY_ZONE_L_ARM
	icon = 'icons/bandastation/mob/species/drask/sprite_accessories/arm_spines.dmi'
	icon_state = "m_drask_arm_spines_default_FRONT_left"
	bodypart_overlay = /datum/bodypart_overlay/mutant/arm_spine
	sprite_accessory_override = /datum/sprite_accessory/drask_arm_spines/default
	organ_flags = parent_type::organ_flags | ORGAN_EXTERNAL

/obj/item/organ/thermal_spine/arm_r
	name = "термонарост правой руки"
	slot = ORGAN_SLOT_ARM_SPINES_R
	zone = BODY_ZONE_R_ARM
	icon = 'icons/bandastation/mob/species/drask/sprite_accessories/arm_spines.dmi'
	icon_state = "m_drask_arm_spines_default_FRONT_right"
	bodypart_overlay = /datum/bodypart_overlay/mutant/arm_spine
	sprite_accessory_override = /datum/sprite_accessory/drask_arm_spines/default
	organ_flags = parent_type::organ_flags | ORGAN_EXTERNAL

/datum/bodypart_overlay/mutant/arm_spine
	layers = list(EXTERNAL_FRONT = BODY_FRONT_LAYER)
	feature_key = FEATURE_DRASK_ARM_SPINES
	color_source = ORGAN_COLOR_FEATURE
	dna_color_feature_key = FEATURE_DRASK_ARM_SPINES_COLOR
	offset_location = UPPER_BODY

/datum/bodypart_overlay/mutant/arm_spine/can_draw_on_bodypart(obj/item/bodypart/bodypart_owner, mob/living/carbon/owner)
	return ..() && !(bodypart_owner.owner?.obscured_slots & HIDEJUMPSUIT)

/datum/bodypart_overlay/mutant/arm_spine/build_icon_state(layer_index, obj/item/bodypart/limb)
	var/side = limb?.body_zone == BODY_ZONE_L_ARM ? "left" : "right"
	return "[..()]_[side]"
