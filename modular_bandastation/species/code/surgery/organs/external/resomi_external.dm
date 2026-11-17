/obj/item/organ/resomi_crest
	name = "resomi crest"
	desc = "A cluster of resomi head feathers."
	icon = 'icons/bandastation/mob/species/resomi/sprite_accessories/crests.dmi'
	icon_state = "m_resomi_crest_default_FRONT"
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_EXTERNAL_RESOMI_CREST
	organ_flags = parent_type::organ_flags | ORGAN_EXTERNAL
	bodypart_overlay = /datum/bodypart_overlay/mutant/resomi_crest
	dna_block = /datum/dna_block/feature/accessory/resomi_crest

/datum/bodypart_overlay/mutant/resomi_crest
	layers = list(EXTERNAL_FRONT = HAIR_LAYER)
	feature_key = FEATURE_RESOMI_CREST
	color_source = ORGAN_COLOR_FEATURE
	dna_color_feature_key = FEATURE_RESOMI_CREST_COLOR
	offset_location = UPPER_BODY

/datum/bodypart_overlay/mutant/resomi_crest/can_draw_on_bodypart(obj/item/bodypart/bodypart_owner, mob/living/carbon/owner)
	return ..() && !(bodypart_owner.owner?.obscured_slots & HIDEHAIR)

/obj/item/organ/tail/resomi
	name = "resomi tail"
	desc = "A small feathered tail."
	icon = 'icons/bandastation/mob/species/resomi/sprite_accessories/tails.dmi'
	icon_state = "default"
	bodypart_overlay = /datum/bodypart_overlay/mutant/tail/resomi
	sprite_accessory_override = /datum/sprite_accessory/tails/resomi/default
	dna_block = null
	restyle_flags = NONE

/datum/bodypart_overlay/mutant/tail/resomi
	layers = list(EXTERNAL_BEHIND = BODY_BEHIND_LAYER)
	feature_key = FEATURE_RESOMI_TAIL
