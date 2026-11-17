/// A luxurious officer's cloak in Midnight colors with upgraded protection.
/obj/item/clothing/neck/cloak/centcom/admiral/midnight
	name = "\improper Midnight luxurious cloak"
	desc = "Роскошный плащ из угольно-чёрной дюраткани с красной отделкой."
	icon = 'modular_bandastation/prime_only/icons/object/midnight_cloak.dmi'
	worn_icon = 'modular_bandastation/prime_only/icons/mob/midnight_cloak.dmi'
	icon_state = "midnight_luxurious"
	armor_type = /datum/armor/centcom_cloak/midnight

/// One protection class above the standard officer's cloak in every armor rating.
/datum/armor/centcom_cloak/midnight
	melee = 20
	bullet = 20
	laser = 20
	energy = 20
	bomb = 10
	bio = 10
	fire = 10
	acid = 10
	wound = 20
	consume = 10
