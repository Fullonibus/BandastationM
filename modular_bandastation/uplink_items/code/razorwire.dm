/obj/item/organ/cyberimp/arm/toolkit/razorwire
	name = "razorwire spool implant"
	contraband_type_categories = CONTRABAND_CATEGORY_UNCLASSIFIED
	desc = "Катушка моноструны в предплечье. Позволяет хлестать противника на расстоянии двух клеток, выбивая предметы из рук."
	icon = 'modular_bandastation/uplink_items/icons/items.dmi'
	icon_state = "razorwire_implant"
	items_to_create = list(/obj/item/melee/razorwire)
	hand_state = FALSE

/obj/item/melee/razorwire
	name = "implanted razorwire"
	contraband_type_categories = CONTRABAND_CATEGORY_UNCLASSIFIED
	desc = "Моноструна, выдвигающаяся из запястья. Достаёт на две клетки и выбивает предметы из рук. Броня защищает от неё вдвое эффективнее."
	icon = 'modular_bandastation/uplink_items/icons/items.dmi'
	icon_state = "razorwire"
	inhand_icon_state = "razorwire"
	lefthand_file = 'modular_bandastation/uplink_items/icons/implants_lefthand.dmi'
	righthand_file = 'modular_bandastation/uplink_items/icons/implants_righthand.dmi'
	w_class = WEIGHT_CLASS_BULKY
	force = 18
	weak_against_armour = TRUE
	reach = 2
	sharpness = SHARP_EDGED
	hitsound = 'sound/items/weapons/whip.ogg'
	attack_verb_continuous = list("slashes", "whips", "lashes")
	attack_verb_simple = list("slash", "whip", "lash")

/obj/item/melee/razorwire/afterattack(atom/target, mob/living/user, list/modifiers, list/attack_modifiers)
	. = ..()
	if(isliving(target) && target != user && !HAS_TRAIT(user, TRAIT_PACIFISM))
		var/mob/living/victim = target
		victim.drop_all_held_items()
