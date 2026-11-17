#define RESOMI_DAMAGE_ICON 'icons/bandastation/mob/species/resomi/damage.dmi'

/// Resomi head with a separate plumage overlay.
/obj/item/bodypart/head/resomi
	icon_greyscale = 'icons/bandastation/mob/species/resomi/bodyparts.dmi'
	limb_id = SPECIES_RESOMI
	dmg_overlay_type = SPECIES_RESOMI
	damage_overlay_icon = RESOMI_DAMAGE_ICON
	icon_husk = RESOMI_DAMAGE_ICON
	husk_type = SPECIES_RESOMI
	head_flags = HEAD_EYESPRITES|HEAD_EYECOLOR|HEAD_DEBRAIN
	brute_modifier = 1.35
	burn_modifier = 1.35

/obj/item/bodypart/head/resomi/Initialize(mapload)
	worn_head_offset = new(src, OFFSET_HEAD, offset_y = list("south" = -4))
	worn_glasses_offset = new(src, OFFSET_GLASSES, offset_y = list("south" = -6))
	worn_mask_offset = new(src, OFFSET_FACEMASK, offset_y = list("south" = -5))
	worn_ears_offset = new(src, OFFSET_EARS, offset_y = list("south" = -5))
	return ..()

/// Resomi torso.
/obj/item/bodypart/chest/resomi
	icon_greyscale = 'icons/bandastation/mob/species/resomi/bodyparts.dmi'
	limb_id = SPECIES_RESOMI
	dmg_overlay_type = SPECIES_RESOMI
	damage_overlay_icon = RESOMI_DAMAGE_ICON
	icon_husk = RESOMI_DAMAGE_ICON
	husk_type = SPECIES_RESOMI
	brute_modifier = 1.35
	burn_modifier = 1.35

/// Left feathered arm with claws.
/obj/item/bodypart/arm/left/resomi
	icon_greyscale = 'icons/bandastation/mob/species/resomi/bodyparts.dmi'
	limb_id = SPECIES_RESOMI
	dmg_overlay_type = SPECIES_RESOMI
	damage_overlay_icon = RESOMI_DAMAGE_ICON
	icon_husk = RESOMI_DAMAGE_ICON
	husk_type = SPECIES_RESOMI
	brute_modifier = 1.35
	burn_modifier = 1.35
	unarmed_attack_verbs = list("slash")
	grappled_attack_verb = "lacerate"
	unarmed_attack_effect = ATTACK_EFFECT_CLAW
	unarmed_attack_sound = 'sound/items/weapons/slice.ogg'
	unarmed_miss_sound = 'sound/items/weapons/slashmiss.ogg'

/obj/item/bodypart/arm/left/resomi/Initialize(mapload)
	held_hand_offset = new(
		attached_part = src,
		feature_key = OFFSET_HELD,
		offset_x = list("south" = -1, "north" = 2, "east" = 0, "west" = -4),
		offset_y = list("south" = -2, "east" = -3, "west" = -3),
	)
	return ..()

/// Right feathered arm with claws.
/obj/item/bodypart/arm/right/resomi
	icon_greyscale = 'icons/bandastation/mob/species/resomi/bodyparts.dmi'
	limb_id = SPECIES_RESOMI
	dmg_overlay_type = SPECIES_RESOMI
	damage_overlay_icon = RESOMI_DAMAGE_ICON
	icon_husk = RESOMI_DAMAGE_ICON
	husk_type = SPECIES_RESOMI
	brute_modifier = 1.35
	burn_modifier = 1.35
	unarmed_attack_verbs = list("slash")
	grappled_attack_verb = "lacerate"
	unarmed_attack_effect = ATTACK_EFFECT_CLAW
	unarmed_attack_sound = 'sound/items/weapons/slice.ogg'
	unarmed_miss_sound = 'sound/items/weapons/slashmiss.ogg'

/obj/item/bodypart/arm/right/resomi/Initialize(mapload)
	held_hand_offset = new(
		attached_part = src,
		feature_key = OFFSET_HELD,
		offset_x = list("south" = 2, "north" = -1, "east" = 4, "west" = 0),
		offset_y = list("south" = -2, "east" = -3, "west" = -3),
	)
	return ..()

/// Left feathered leg.
/obj/item/bodypart/leg/left/resomi
	icon_greyscale = 'icons/bandastation/mob/species/resomi/bodyparts.dmi'
	limb_id = SPECIES_RESOMI
	dmg_overlay_type = SPECIES_RESOMI
	damage_overlay_icon = RESOMI_DAMAGE_ICON
	icon_husk = RESOMI_DAMAGE_ICON
	husk_type = SPECIES_RESOMI
	brute_modifier = 1.35
	burn_modifier = 1.35
	footprint_sprite = FOOTPRINT_SPRITE_CLAWS
	footstep_type = FOOTSTEP_MOB_CLAW

/// Right feathered leg.
/obj/item/bodypart/leg/right/resomi
	icon_greyscale = 'icons/bandastation/mob/species/resomi/bodyparts.dmi'
	limb_id = SPECIES_RESOMI
	dmg_overlay_type = SPECIES_RESOMI
	damage_overlay_icon = RESOMI_DAMAGE_ICON
	icon_husk = RESOMI_DAMAGE_ICON
	husk_type = SPECIES_RESOMI
	brute_modifier = 1.35
	burn_modifier = 1.35
	footprint_sprite = FOOTPRINT_SPRITE_CLAWS
	footstep_type = FOOTSTEP_MOB_CLAW

#undef RESOMI_DAMAGE_ICON
